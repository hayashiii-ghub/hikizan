import { existsSync } from "node:fs"
import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"

type PluginContext = {
  directory?: string
  worktree?: string
}

type ToolInput = {
  tool: string
  sessionID?: string
}

type ToolOutput = {
  args?: Record<string, unknown>
}

type HookDecision = {
  hookSpecificOutput?: {
    hookEventName?: string
    permissionDecision?: string
    permissionDecisionReason?: string
  }
}

function findRoot(): string | undefined {
  const required = [
    "hooks/scripts/pre-push.sh",
    "hooks/scripts/pre-pr-create.sh",
    "hooks/scripts/pre-destructive.sh",
  ]
  const valid = (candidate: string) => required.every((path) => existsSync(resolve(candidate, path)))

  if (process.env.HIKIZAN_ROOT !== undefined) {
    return valid(process.env.HIKIZAN_ROOT) ? process.env.HIKIZAN_ROOT : undefined
  }

  const bundled = resolve(dirname(fileURLToPath(import.meta.url)), "../../..")
  return valid(bundled) ? bundled : undefined
}

async function runHook(
  root: string,
  script: string,
  payload: Record<string, unknown>,
  cwd: string,
  args: string[] = [],
) {
  const timeout = script.endsWith("pre-push.sh") ? 30_000
    : script.endsWith("pre-pr-create.sh") ? 15_000
    : 10_000
  const process = Bun.spawn({
    cmd: ["bash", resolve(root, script), ...args],
    cwd,
    env: { ...globalThis.process.env },
    stdin: Buffer.from(JSON.stringify(payload)),
    stdout: "pipe",
    stderr: "pipe",
  })
  let timedOut = false
  const timer = setTimeout(() => {
    timedOut = true
    process.kill()
  }, timeout)

  try {
    const [stdout, stderr, exitCode] = await Promise.all([
      new Response(process.stdout).text(),
      new Response(process.stderr).text(),
      process.exited,
    ])
    if (exitCode !== 0) {
      const status = timedOut ? `timeout after ${timeout}ms` : `exit ${exitCode}`
      throw new Error(stderr.trim() || `hikizan hook failed closed: ${script} (${status})`)
    }
    if (!stdout.trim()) return undefined

    const decision = JSON.parse(stdout) as HookDecision
    const output = decision.hookSpecificOutput
    if (
      output?.hookEventName !== "PreToolUse" ||
      !["allow", "deny"].includes(output.permissionDecision || "") ||
      (output.permissionDecisionReason !== undefined && typeof output.permissionDecisionReason !== "string")
    ) {
      throw new Error(`hikizan hook returned an invalid decision: ${script}`)
    }
    return decision
  } catch (error) {
    if (error instanceof SyntaxError) {
      throw new Error(`hikizan hook returned invalid JSON: ${script}`)
    }
    throw error
  } finally {
    clearTimeout(timer)
  }
}

export const HikizanPlugin = async (context: PluginContext) => {
  const root = findRoot()
  const cwd = context.worktree || context.directory || globalThis.process.cwd()

  return {
    "tool.execute.before": async (input: ToolInput, output: ToolOutput) => {
      if (!root || input.tool !== "bash") return
      const command = output.args?.command
      if (typeof command !== "string") return

      const payload = {
        tool_input: { command },
        cwd,
        session_id: input.sessionID || "",
      }
      const hooks: Array<[string, string[]]> = [
        ["hooks/scripts/pre-push.sh", []],
        ["hooks/scripts/pre-pr-create.sh", []],
        ["hooks/scripts/pre-destructive.sh", ["deny", "OpenCode"]],
      ]

      for (const [script, args] of hooks) {
        const decision = await runHook(root, script, payload, cwd, args)
        const result = decision?.hookSpecificOutput
        if (result?.permissionDecision === "deny") {
          throw new Error(result.permissionDecisionReason || "blocked by hikizan")
        }
      }
    },
  }
}

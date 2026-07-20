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
  args?: Record<string, unknown>
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
    "hooks/scripts/post-command.sh",
    "hooks/scripts/session-context.sh",
    "context/routing.md",
  ]
  const valid = (candidate: string) => required.every((path) => existsSync(resolve(candidate, path)))
  if (process.env.HIKIZAN_ROOT !== undefined) {
    return valid(process.env.HIKIZAN_ROOT) ? process.env.HIKIZAN_ROOT : undefined
  }
  const bundled = resolve(dirname(fileURLToPath(import.meta.url)), "..")
  return valid(bundled) ? bundled : undefined
}

async function runScript(
  root: string,
  script: string,
  payload: Record<string, unknown>,
  cwd: string,
  args: string[] = [],
) {
  const timeout = script.endsWith("pre-push.sh") ? 30_000
    : script.endsWith("pre-pr-create.sh") ? 15_000
    : 10_000
  const result = Bun.spawn({
    cmd: ["bash", resolve(root, script), ...args],
    cwd,
    env: { ...process.env, CLAUDE_PLUGIN_ROOT: root },
    stdin: Buffer.from(JSON.stringify(payload)),
    stdout: "pipe",
    stderr: "pipe",
    timeout,
  })
  let timedOut = false
  const timer = setTimeout(() => {
    timedOut = true
    result.kill()
  }, timeout)
  try {
    const [stdout, stderr, exitCode] = await Promise.all([
      new Response(result.stdout).text(),
      new Response(result.stderr).text(),
      result.exited,
    ])
    if (exitCode !== 0) {
      const status = timedOut ? `timeout after ${timeout}ms` : result.signalCode || `exit ${exitCode}`
      throw new Error(stderr.trim() || `hikizan hook failed closed: ${script} (${status})`)
    }
    return stdout.trim()
  } finally {
    clearTimeout(timer)
  }
}

async function runHook(
  root: string,
  script: string,
  payload: Record<string, unknown>,
  cwd: string,
  args: string[] = [],
) {
  const stdout = await runScript(root, script, payload, cwd, args)
  if (!stdout) return undefined
  try {
    const decision = JSON.parse(stdout) as HookDecision
    const output = decision?.hookSpecificOutput
    if (
      output?.hookEventName !== "PreToolUse" ||
      !["allow", "deny"].includes(output.permissionDecision || "") ||
      (output.permissionDecisionReason !== undefined && typeof output.permissionDecisionReason !== "string")
    ) {
      throw new Error()
    }
    return decision
  } catch {
    throw new Error(`hikizan hook returned an invalid decision: ${script}`)
  }
}

export const HikizanPlugin = async (context: PluginContext) => {
  const root = findRoot()
  const cwd = context.worktree || context.directory || process.cwd()
  const contextCache = new Map<string, string>()

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
        const permission = decision?.hookSpecificOutput?.permissionDecision
        if (permission && permission !== "allow") {
          throw new Error(decision?.hookSpecificOutput?.permissionDecisionReason || "blocked by hikizan")
        }
      }
    },
    "tool.execute.after": async (input: ToolInput) => {
      if (!root || input.tool !== "bash") return
      const command = input.args?.command
      if (typeof command !== "string") return
      try {
        await runScript(root, "hooks/scripts/post-command.sh", {
          tool_input: { command },
          cwd,
          session_id: input.sessionID || "",
        }, cwd, ["block"])
      } catch {
        // PostToolUse is observability-only; it must never break a completed tool.
      }
    },
    "experimental.chat.system.transform": async (
      input: { sessionID?: string },
      output: { system: string[] },
    ) => {
      if (!root) return
      const key = input.sessionID || "default"
      let injected = contextCache.get(key)
      if (injected === undefined) {
        try {
          injected = await runScript(root, "hooks/scripts/session-context.sh", {
            session_id: input.sessionID || "",
            cwd,
          }, cwd)
        } catch {
          // Context is guidance, not a floor; failure leaves skills-only behavior.
          injected = ""
        }
        contextCache.set(key, injected)
      }
      if (injected) output.system.push(injected)
    },
  }
}

import { existsSync, readFileSync } from "node:fs"
import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"

type PluginContext = {
  directory?: string
  worktree?: string
}

function findRoot(): string | undefined {
  const required = [
    "hooks/scripts/session-routing.sh",
    "hooks/routing.md",
  ]
  const valid = (candidate: string) => required.every((path) => existsSync(resolve(candidate, path)))

  if (process.env.HIKIZAN_ROOT !== undefined) {
    return valid(process.env.HIKIZAN_ROOT) ? process.env.HIKIZAN_ROOT : undefined
  }

  const bundled = resolve(dirname(fileURLToPath(import.meta.url)), "../../..")
  return valid(bundled) ? bundled : undefined
}

async function runProcess(
  command: string[],
  payload: Record<string, unknown>,
  cwd: string,
  timeout: number,
) {
  const process = Bun.spawn({
    cmd: command,
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
      throw new Error(stderr.trim() || `hikizan hook failed: ${status}`)
    }
    return stdout.trimEnd()
  } finally {
    clearTimeout(timer)
  }
}

async function loadSessionContext(root: string, cwd: string) {
  try {
    return await runProcess(
      ["bash", resolve(root, "hooks/scripts/session-routing.sh"), "plain"],
      { cwd },
      cwd,
      5_000,
    )
  } catch {
    return readFileSync(resolve(root, "hooks/routing.md"), "utf8").trimEnd()
  }
}

export const HikizanPlugin = async (context: PluginContext) => {
  const root = findRoot()
  const cwd = context.worktree || context.directory || globalThis.process.cwd()
  const sessionContext = root ? await loadSessionContext(root, cwd) : ""

  return {
    "experimental.chat.system.transform": async (
      _input: { sessionID?: string },
      output: { system: string[] },
    ) => {
      if (sessionContext) output.system.push(sessionContext)
    },
  }
}

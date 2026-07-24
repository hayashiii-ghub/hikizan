import { HikizanPlugin } from "../adapters/opencode/hikizan.ts"

const [action, root, cwd, command = ""] = process.argv.slice(2)
process.env.HIKIZAN_ROOT = root

const plugin = await HikizanPlugin({ directory: cwd, worktree: cwd } as never)

if (action === "surface") {
  console.log(JSON.stringify({ hooks: Object.keys(plugin).sort() }))
  process.exit(0)
}

try {
  await plugin["tool.execute.before"]?.(
    {
      tool: action === "before-non-bash" ? "read" : "bash",
      sessionID: "ses_hikizan_test",
      callID: "call_test",
    } as never,
    { args: { command } } as never,
  )
  console.log(JSON.stringify({ decision: "allow" }))
} catch (error) {
  console.log(JSON.stringify({
    decision: "deny",
    reason: error instanceof Error ? error.message : String(error),
  }))
}

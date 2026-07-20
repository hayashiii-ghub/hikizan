import { HikizanPlugin } from "../hikizan.ts"

const [action, root, cwd, command = ""] = process.argv.slice(2)
process.env.HIKIZAN_ROOT = root

const plugin = await HikizanPlugin({ directory: cwd, worktree: cwd } as never)

try {
  if (action === "before") {
    await plugin["tool.execute.before"]?.(
      { tool: "bash", sessionID: "ses_hikizan_test", callID: "call_test" } as never,
      { args: { command } } as never,
    )
    console.log(JSON.stringify({ decision: "allow" }))
  } else if (action === "before-non-bash") {
    await plugin["tool.execute.before"]?.(
      { tool: "read", sessionID: "ses_hikizan_test", callID: "call_test" } as never,
      { args: { command } } as never,
    )
    console.log(JSON.stringify({ decision: "allow" }))
  } else if (action === "after") {
    await plugin["tool.execute.after"]?.(
      { tool: "bash", sessionID: "ses_01JTESTABCDEF23456789", callID: "call_test", args: { command } } as never,
      { title: "bash", output: "", metadata: {} } as never,
    )
    console.log(JSON.stringify({ decision: "allow" }))
  } else if (action === "system") {
    const first = { system: [] as string[] }
    const second = { system: [] as string[] }
    await plugin["experimental.chat.system.transform"]?.(
      { sessionID: "ses_01JTESTABCDEF23456789" } as never,
      first as never,
    )
    await plugin["experimental.chat.system.transform"]?.(
      { sessionID: "ses_01JTESTABCDEF23456789" } as never,
      second as never,
    )
    console.log(JSON.stringify({ first: first.system.join("\n"), second: second.system.join("\n") }))
  } else {
    throw new Error(`unknown test action: ${action}`)
  }
} catch (error) {
  console.log(JSON.stringify({
    decision: "deny",
    reason: error instanceof Error ? error.message : String(error),
  }))
}

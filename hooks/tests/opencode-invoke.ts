import { HikizanPlugin } from "../adapters/opencode/hikizan.ts"

const [action, root, cwd] = process.argv.slice(2)
process.env.HIKIZAN_ROOT = root

const plugin = await HikizanPlugin({ directory: cwd, worktree: cwd } as never)

if (action === "surface") {
  console.log(JSON.stringify({ hooks: Object.keys(plugin).sort() }))
  process.exit(0)
}

if (action === "routing") {
  const output = { system: [] as string[] }
  await plugin["experimental.chat.system.transform"]?.(
    { sessionID: "ses_hikizan_test" } as never,
    output as never,
  )
  console.log(JSON.stringify(output))
  process.exit(0)
}

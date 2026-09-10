import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { stripTypeScriptTypes } from "node:module";
import test from "node:test";

const source = readFileSync(new URL("../adapters/pi/index.ts", import.meta.url), "utf8");
const code = stripTypeScriptTypes(source.replace(/^import .*;\n/gm, "").replace("export default ", ""));
const dependencies = ["registerProductionGuard", "shimonForPi", "rewindForPi", "registerClaudeDelegate", "registerExaSearchIfConfigured"];

test("pi keeps features and aliases without startup commands, prompt injection, or status writes", async () => {
  const registered = [];
  const events = new Map();
  const commands = new Map();
  const init = new Function(...dependencies, `${code}\nreturn hikizanForPi;`)(...dependencies.map(name => () => registered.push(name)));
  init({ on: (name, fn) => events.set(name, fn), registerCommand: (name, command) => commands.set(name, command) });
  assert.deepEqual(registered, dependencies);
  assert.deepEqual([...events.keys()], ["session_start", "session_shutdown"]);
  const headers = [];
  const messages = [];
  const ctx = { mode: "tui", ui: { setHeader: value => headers.push(value), notify() {} }, sendUserMessage: async (...args) => messages.push(args) };
  await events.get("session_start")({}, ctx);
  assert.deepEqual(headers[0]().render(20), ["", "  hikizan", ""]);
  assert.ok(headers[0]().render(80).length > 3);
  for (const name of ["tansaku", "sekkei", "jikkou", "sadoku", "teishutsu", "houkoku"]) {
    await commands.get(name).handler("  example  ", ctx);
    assert.deepEqual(messages.at(-1), [`/skill:${name} example`, { expandPromptTemplates: true }]);
  }
  await commands.get("hikizan").handler("", ctx);
  assert.equal(headers.at(-1), undefined);
  await events.get("session_shutdown")({}, ctx);
  await events.get("session_start")({}, { mode: "rpc" });
});

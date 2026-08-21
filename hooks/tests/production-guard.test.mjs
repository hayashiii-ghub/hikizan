import assert from "node:assert/strict";
import test from "node:test";
import { registerProductionGuard } from "../adapters/pi/production-guard.js";

function createHarness({ choice = "止める", exec } = {}) {
	let handler;
	let selections = 0;
	const pi = {
		on(name, callback) {
			if (name === "tool_call") handler = callback;
		},
		exec:
			exec ??
			(async (_command, args) => ({
				code: 0,
				stdout: args.includes("branch") ? "feature/login\n" : "origin/main\n",
				stderr: "",
			})),
	};
	registerProductionGuard(pi);
	return {
		async call(command, hasUI = true) {
			return handler(
				{ toolName: "bash", input: { command } },
				{
					cwd: "/repo",
					hasUI,
					ui: {
						async select() {
							selections += 1;
							return choice;
						},
					},
				},
			);
		},
		get selections() {
			return selections;
		},
	};
}

test("blocks guarded commands without a UI", async () => {
	const harness = createHarness();
	assert.equal((await harness.call("npm publish", false))?.block, true);
	assert.equal(harness.selections, 0);
});

test("blocks when the user chooses to stop", async () => {
	const harness = createHarness({ choice: "止める" });
	assert.equal((await harness.call("wrangler deploy"))?.block, true);
	assert.equal(harness.selections, 1);
});

test("continues only when the user explicitly chooses execution", async () => {
	const harness = createHarness({ choice: "実行する" });
	assert.equal(await harness.call("wrangler deploy"), undefined);
	assert.equal(harness.selections, 1);
});

test("does not prompt for an ordinary local command", async () => {
	const harness = createHarness();
	assert.equal(await harness.call("npm test"), undefined);
	assert.equal(harness.selections, 0);
});

test("uses repository context for an otherwise ambiguous push", async () => {
	const harness = createHarness({
		exec: async (_command, args) => ({
			code: 0,
			stdout: args.includes("branch") ? "main\n" : "origin/main\n",
			stderr: "",
		}),
	});
	assert.equal((await harness.call("git push"))?.block, true);
	assert.equal(harness.selections, 1);
});

test("fails safe when a quoted git -C push cannot use the current repository context", async () => {
	const harness = createHarness();
	assert.equal((await harness.call('git -C "app dir" push'))?.block, true);
	assert.equal(harness.selections, 1);
});

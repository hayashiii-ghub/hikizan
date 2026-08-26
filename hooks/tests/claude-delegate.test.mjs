import assert from "node:assert/strict";
import test from "node:test";

import {
	CLAUDE_READ_ONLY_SYSTEM_PROMPT,
	assertSubscriptionEnvironment,
	buildClaudeDelegateInvocation,
	resolveClaudeDelegateModel,
} from "../adapters/pi/claude-delegate-runtime.js";

test("builds a read-only one-shot Claude ACP invocation", () => {
	const invocation = buildClaudeDelegateInvocation({
		acpxCli: "/plugin/node_modules/acpx/dist/cli.js",
		claudeAgent: "/plugin/node_modules/@agentclientprotocol/claude-agent-acp/dist/index.js",
		cwd: "/repo",
		prompt: "review this change",
		nodePath: "/usr/local/bin/node",
	});

	assert.equal(invocation.command, "/usr/local/bin/node");
	assert.deepEqual(invocation.args, [
		"/plugin/node_modules/acpx/dist/cli.js",
		"--agent",
		"'/usr/local/bin/node' '/plugin/node_modules/@agentclientprotocol/claude-agent-acp/dist/index.js'",
		"--cwd",
		"/repo",
		"--timeout",
		"300",
		"--approve-reads",
		"--non-interactive-permissions",
		"deny",
		"--allowed-tools",
		"Read,Glob,Grep",
		"--max-turns",
		"12",
		"--append-system-prompt",
		CLAUDE_READ_ONLY_SYSTEM_PROMPT,
		"--format",
		"quiet",
		"exec",
		"review this change",
	]);
});

test("uses an optional Claude model override", () => {
	assert.equal(resolveClaudeDelegateModel({}), undefined);
	assert.equal(resolveClaudeDelegateModel({ HIKIZAN_CLAUDE_MODEL: " opus " }), "opus");

	const invocation = buildClaudeDelegateInvocation({
		acpxCli: "/plugin/acpx.js",
		claudeAgent: "/plugin/claude-acp.js",
		cwd: "/repo",
		prompt: "review",
		nodePath: "/usr/local/bin/node",
		model: "opus",
	});
	const modelIndex = invocation.args.indexOf("--model");
	assert.notEqual(modelIndex, -1);
	assert.equal(invocation.args[modelIndex + 1], "opus");
});

test("refuses API-billed or gateway-routed Claude environments", () => {
	assert.doesNotThrow(() => assertSubscriptionEnvironment({}));
	assert.throws(
		() => assertSubscriptionEnvironment({ ANTHROPIC_API_KEY: "secret" }),
		/ANTHROPIC_API_KEY/,
	);
	assert.throws(
		() => assertSubscriptionEnvironment({ CLAUDE_CODE_USE_BEDROCK: "1" }),
		/CLAUDE_CODE_USE_BEDROCK/,
	);
});

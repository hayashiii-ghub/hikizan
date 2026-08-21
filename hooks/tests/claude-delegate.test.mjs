import assert from "node:assert/strict";
import test from "node:test";

import {
	assertSubscriptionEnvironment,
	buildClaudeDelegateInvocation,
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
		"--format",
		"quiet",
		"exec",
		"review this change",
	]);
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

import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { once } from "node:events";
import { dirname, resolve } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

import { hardenClaudeSessionNew } from "../adapters/pi/claude-agent-acp-read-only.js";

import {
	CLAUDE_READ_ONLY_SYSTEM_PROMPT,
	assertSubscriptionEnvironment,
	buildClaudeDelegateInvocation,
	resolveClaudeDelegateModel,
} from "../adapters/pi/claude-delegate-runtime.js";

const testDirectory = dirname(fileURLToPath(import.meta.url));

test("builds a read-only one-shot Claude ACP invocation", () => {
	const invocation = buildClaudeDelegateInvocation({
		acpxCli: "/plugin/node_modules/acpx/dist/cli.js",
		claudeAgent: "/plugin/node_modules/@agentclientprotocol/claude-agent-acp/dist/index.js",
		claudeAgentProxy: "/plugin/hooks/adapters/pi/claude-agent-acp-read-only.js",
		cwd: "/repo",
		prompt: "review this change",
		nodePath: "/usr/local/bin/node",
	});

	assert.equal(invocation.command, "/usr/local/bin/node");
	assert.deepEqual(invocation.args, [
		"/plugin/node_modules/acpx/dist/cli.js",
		"--agent",
		"'/usr/local/bin/node' '/plugin/hooks/adapters/pi/claude-agent-acp-read-only.js' '/plugin/node_modules/@agentclientprotocol/claude-agent-acp/dist/index.js'",
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

test("restricts Claude session metadata to read-only built-in tools", () => {
	const request = {
		jsonrpc: "2.0",
		id: 7,
		method: "session/new",
		params: {
			cwd: "/repo",
			mcpServers: [{ name: "project-server", command: "node", args: ["server.js"] }],
			_meta: {
				systemPrompt: { append: "stay focused" },
				claudeCode: {
					options: {
						allowedTools: ["Bash", "Write"],
						maxTurns: 12,
						model: "opus",
						settingSources: ["project", "local"],
					},
				},
			},
		},
	};

	assert.deepEqual(hardenClaudeSessionNew(request), {
		...request,
		params: {
			...request.params,
			mcpServers: [],
			_meta: {
				...request.params._meta,
				claudeCode: {
					options: {
						...request.params._meta.claudeCode.options,
						tools: ["Read", "Glob", "Grep"],
						allowedTools: ["Read", "Glob", "Grep"],
						settingSources: [],
						strictMcpConfig: true,
						mcpServers: {},
					},
				},
			},
		},
	});
});

test("rewrites session/new on the ACP stdio stream", async () => {
	const proxy = spawn(
		process.execPath,
		[
			resolve(testDirectory, "../adapters/pi/claude-agent-acp-read-only.js"),
			resolve(testDirectory, "fixtures/echo-claude-agent-acp.mjs"),
		],
		{ stdio: ["pipe", "pipe", "pipe"] },
	);
	let stdout = "";
	let stderr = "";
	proxy.stdout.setEncoding("utf8");
	proxy.stderr.setEncoding("utf8");
	proxy.stdout.on("data", (chunk) => {
		stdout += chunk;
	});
	proxy.stderr.on("data", (chunk) => {
		stderr += chunk;
	});

	proxy.stdin.end(`${JSON.stringify({ jsonrpc: "2.0", id: 1, method: "session/new", params: {} })}\n`);
	const [code] = await once(proxy, "close");

	assert.equal(code, 0, stderr);
	const message = JSON.parse(stdout);
	assert.deepEqual(message.params._meta.claudeCode.options.tools, ["Read", "Glob", "Grep"]);
	assert.deepEqual(message.params._meta.claudeCode.options.settingSources, []);
	assert.deepEqual(message.params.mcpServers, []);
});

test("uses an optional Claude model override", () => {
	assert.equal(resolveClaudeDelegateModel({}), undefined);
	assert.equal(resolveClaudeDelegateModel({ HIKIZAN_CLAUDE_MODEL: " opus " }), "opus");

	const invocation = buildClaudeDelegateInvocation({
		acpxCli: "/plugin/acpx.js",
		claudeAgent: "/plugin/claude-acp.js",
		claudeAgentProxy: "/plugin/claude-agent-acp-read-only.js",
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

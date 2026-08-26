/**
 * Claude CodeをACPの一回限りの読み取り専用エージェントとして起動する。
 * API従量課金へ切り替えず、Claudeのサブスク認証だけを使うために分離する。
 */

import { createRequire } from "node:module";
import { dirname, resolve } from "node:path";

const require = createRequire(import.meta.url);
const BLOCKED_ENV = [
	"ANTHROPIC_API_KEY",
	"ANTHROPIC_AUTH_TOKEN",
	"ANTHROPIC_BASE_URL",
	"CLAUDE_CODE_USE_BEDROCK",
	"CLAUDE_CODE_USE_VERTEX",
];

export const CLAUDE_READ_ONLY_SYSTEM_PROMPT =
	"This is a strictly read-only delegated review. You MUST use only Read, Glob, and Grep tools. " +
	"Never call Bash, Terminal, Write, Edit, Notebook, Task, Web, or MCP tools. Do not modify files. " +
	"If Read, Glob, and Grep are insufficient, report the limitation instead of requesting another tool. " +
	"Keep the review focused and finish with the evidence already gathered.";

function quoteCommandPart(value) {
	return `'${value.replaceAll("'", `'"'"'`)}'`;
}

export function assertSubscriptionEnvironment(env = process.env) {
	const configured = BLOCKED_ENV.filter((name) => env[name]?.trim());
	if (configured.length === 0) return;
	throw new Error(
		`ClaudeのAPI課金または外部プロバイダー設定を検出したため停止しました: ${configured.join(", ")}。` +
			"サブスク枠で使うには該当する環境変数を外してpiを起動し直してください。",
	);
}

export function resolveClaudeDelegateModel(env = process.env) {
	return env.HIKIZAN_CLAUDE_MODEL?.trim() || undefined;
}

export function resolveClaudeAcpRuntime() {
	const acpxPackage = require.resolve("acpx/package.json");
	const claudeAgentPackage = require.resolve("@agentclientprotocol/claude-agent-acp/package.json");
	return {
		acpxCli: resolve(dirname(acpxPackage), "dist/cli.js"),
		claudeAgent: resolve(dirname(claudeAgentPackage), "dist/index.js"),
	};
}

export function buildClaudeDelegateInvocation({
	acpxCli,
	claudeAgent,
	cwd,
	prompt,
	model,
	nodePath = process.execPath,
}) {
	const agentCommand = `${quoteCommandPart(nodePath)} ${quoteCommandPart(claudeAgent)}`;
	const args = [
		acpxCli,
		"--agent",
		agentCommand,
		"--cwd",
		cwd,
		"--timeout",
		"300",
		"--approve-reads",
		"--non-interactive-permissions",
		"deny",
		"--allowed-tools",
		"Read,Glob,Grep",
	];
	if (model?.trim()) args.push("--model", model.trim());
	args.push(
		"--max-turns",
		"12",
		"--append-system-prompt",
		CLAUDE_READ_ONLY_SYSTEM_PROMPT,
		"--format",
		"quiet",
		"exec",
		prompt,
	);
	return { command: nodePath, args };
}

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
	nodePath = process.execPath,
}) {
	const agentCommand = `${quoteCommandPart(nodePath)} ${quoteCommandPart(claudeAgent)}`;
	return {
		command: nodePath,
		args: [
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
			"--format",
			"quiet",
			"exec",
			prompt,
		],
	};
}

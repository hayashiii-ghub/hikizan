/**
 * Claude CodeをACPの一回限りの読み取り専用エージェントとして起動する。
 * API従量課金へ切り替えず、Claudeのサブスク認証だけを使うために分離する。
 */

import { createRequire } from "node:module";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const BLOCKED_ENV = [
	"ANTHROPIC_API_KEY",
	"ANTHROPIC_AUTH_TOKEN",
	"ANTHROPIC_BASE_URL",
	"CLAUDE_CODE_USE_BEDROCK",
	"CLAUDE_CODE_USE_VERTEX",
];
const DEFAULT_SESSION_CONTEXT_MAX_CHARS = 30_000;
const OMITTED_SESSION_CONTEXT = "[... earlier visible session context omitted ...]";

export const CLAUDE_READ_ONLY_SYSTEM_PROMPT =
	"This is a strictly read-only delegated review. You MUST use only Read, Glob, and Grep tools. " +
	"Never call Bash, Terminal, Write, Edit, Notebook, Task, Web, or MCP tools. Do not modify files. " +
	"Use the provided Pi session context as background for the delegate request. " +
	"Do not browse the workspace merely to discover the subject; inspect only files clearly relevant to that context and request. " +
	"If Read, Glob, and Grep are insufficient, report the limitation instead of requesting another tool. " +
	"Keep the review focused and finish with the evidence already gathered.";

function visibleText(content) {
	if (typeof content === "string") return content.trim();
	if (!Array.isArray(content)) return "";
	return content
		.filter((item) => item?.type === "text" && typeof item.text === "string")
		.map((item) => item.text.trim())
		.filter(Boolean)
		.join("\n");
}

function renderVisibleSessionMessage(message) {
	if (!message || typeof message !== "object") return "";
	if (message.role === "user" || message.role === "assistant") {
		const text = visibleText(message.content);
		if (!text) return "";
		return `${message.role === "user" ? "User" : "Assistant"}:\n${text}`;
	}
	if (message.role === "compactionSummary" && typeof message.summary === "string") {
		return `Session summary:\n${message.summary.trim()}`;
	}
	if (message.role === "branchSummary" && typeof message.summary === "string") {
		return `Branch summary:\n${message.summary.trim()}`;
	}
	return "";
}

function selectRecentContext(chunks, maxChars) {
	if (chunks.length === 0 || maxChars <= 0) return "";
	const kept = [];
	let used = 0;
	let omitted = false;

	for (let index = chunks.length - 1; index >= 0; index -= 1) {
		const chunk = chunks[index];
		const separatorLength = kept.length === 0 ? 0 : 2;
		if (used + separatorLength + chunk.length <= maxChars) {
			kept.unshift(chunk);
			used += separatorLength + chunk.length;
			continue;
		}
		omitted = true;
		break;
	}

	if (kept.length === 0) {
		const newest = chunks.at(-1);
		kept.push(newest.slice(Math.max(0, newest.length - maxChars)));
		omitted = chunks.length > 1 || newest.length > maxChars;
	}
	return [omitted ? OMITTED_SESSION_CONTEXT : "", ...kept].filter(Boolean).join("\n\n");
}

export function buildClaudeDelegatePrompt(request, messages = [], maxContextChars = DEFAULT_SESSION_CONTEXT_MAX_CHARS) {
	const chunks = Array.isArray(messages) ? messages.map(renderVisibleSessionMessage).filter(Boolean) : [];
	const sessionContext = selectRecentContext(chunks, maxContextChars);
	return [
		"<pi-session-context>",
		sessionContext || "(no visible Pi session context)",
		"</pi-session-context>",
		"",
		"<delegate-request>",
		request.trim(),
		"</delegate-request>",
	].join("\n");
}

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
		claudeAgentProxy: resolve(dirname(fileURLToPath(import.meta.url)), "claude-agent-acp-read-only.js"),
	};
}

export function buildClaudeDelegateInvocation({
	acpxCli,
	claudeAgent,
	claudeAgentProxy,
	cwd,
	prompt,
	model,
	nodePath = process.execPath,
}) {
	const agentCommand = [nodePath, claudeAgentProxy, claudeAgent].map(quoteCommandPart).join(" ");
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

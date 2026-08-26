/**
 * piへClaude CodeのACP委譲ツールとコマンドを追加する。
 * 通常ターンはpiのまま、独立した読み取り専用の意見が必要な時だけClaudeを使う。
 */

import {
	sessionEntryToContextMessages,
	type ExtensionAPI,
	type ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";
import {
	assertSubscriptionEnvironment,
	buildClaudeDelegatePrompt,
	buildClaudeDelegateInvocation,
	resolveClaudeAcpRuntime,
	resolveClaudeDelegateModel,
} from "./claude-delegate-runtime.js";

interface DelegateDetails {
	elapsedMs: number;
	cwd: string;
}

async function delegateToClaude(
	pi: ExtensionAPI,
	prompt: string,
	ctx: ExtensionContext,
	signal?: AbortSignal,
): Promise<{ text: string; details: DelegateDetails }> {
	assertSubscriptionEnvironment();
	const sessionMessages = ctx.sessionManager.buildContextEntries().flatMap(sessionEntryToContextMessages);
	const invocation = buildClaudeDelegateInvocation({
		...resolveClaudeAcpRuntime(),
		cwd: ctx.cwd,
		prompt: buildClaudeDelegatePrompt(prompt, sessionMessages),
		model: resolveClaudeDelegateModel(),
	});
	const startedAt = Date.now();
	const result = await pi.exec(invocation.command, invocation.args, {
		cwd: ctx.cwd,
		signal,
		timeout: 310_000,
	});
	if (result.code !== 0) {
		const detail = result.stderr.trim() || result.stdout.trim() || `exit ${result.code}`;
		throw new Error(`ClaudeへのACP委譲に失敗しました: ${detail}`);
	}
	const text = result.stdout.trim();
	if (!text) throw new Error("Claudeから応答が返りませんでした。");
	return { text, details: { elapsedMs: Date.now() - startedAt, cwd: ctx.cwd } };
}

export function registerClaudeDelegate(pi: ExtensionAPI): void {
	pi.registerTool({
		name: "delegate_claude",
		label: "Delegate Claude",
		description:
			"Ask Claude Code for an independent, read-only second opinion through ACP with the current visible Pi session as context. Use for focused review, diagnosis, or design comparison when another agent materially improves confidence. Claude cannot modify files in this mode.",
		promptSnippet: "Delegate a focused read-only second opinion to Claude Code through ACP",
		promptGuidelines: [
			"Use delegate_claude only when an independent Claude review or comparison adds clear value.",
			"The current visible Pi session is included automatically; give Claude a focused question and verify its claims before acting on them.",
			"Do not claim Claude changed files; delegated runs are read-only.",
		],
		parameters: Type.Object({
			prompt: Type.String({
				minLength: 1,
				maxLength: 20_000,
				description: "Focused question for Claude; the current visible Pi session is included automatically",
			}),
		}),
		executionMode: "sequential",

		async execute(_toolCallId, params, signal, _onUpdate, ctx) {
			const result = await delegateToClaude(pi, params.prompt.trim(), ctx, signal);
			return {
				content: [{ type: "text", text: result.text }],
				details: result.details,
			};
		},

		renderCall(args, theme) {
			const prompt = args.prompt.length > 72 ? `${args.prompt.slice(0, 69)}...` : args.prompt;
			return new Text(`${theme.fg("toolTitle", theme.bold("delegate_claude"))} ${theme.fg("muted", prompt)}`, 0, 0);
		},

		renderResult(result, { isPartial }, theme, context) {
			if (isPartial) return new Text(theme.fg("warning", "Asking Claude through ACP..."), 0, 0);
			const details = result.details as DelegateDetails | undefined;
			if (details) return new Text(theme.fg("success", `Claude · ${Math.round(details.elapsedMs / 1000)}s`), 0, 0);
			const text = result.content.find((item) => item.type === "text");
			return new Text(
				text?.type === "text" ? theme.fg(context.isError ? "error" : "muted", text.text) : "",
				0,
				0,
			);
		},
	});

	pi.registerCommand("delegate", {
		description: "現在のPiセッションを添えてClaudeへ読み取り専用の意見を求める: /delegate claude <依頼>",
		handler: async (args, ctx) => {
			const match = args.trim().match(/^claude\s+([\s\S]+)$/i);
			if (!match) {
				ctx.ui.notify("使い方: /delegate claude <依頼>", "warning");
				return;
			}
			if (!ctx.isIdle()) {
				ctx.ui.notify("piの応答完了後に実行してください。", "warning");
				return;
			}

			ctx.ui.setStatus("hikizan-delegate", ctx.ui.theme.fg("accent", "claude: reviewing"));
			try {
				const result = await delegateToClaude(pi, match[1].trim(), ctx);
				pi.sendMessage({
					customType: "hikizan-claude-delegate",
					content: `Claude (ACP)\n\n${result.text}`,
					display: true,
					details: result.details,
				});
			} catch (error) {
				ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
			} finally {
				ctx.ui.setStatus("hikizan-delegate", undefined);
			}
		},
	});
}

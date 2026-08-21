/**
 * piへhikizanの起動情報と最小限のブランド表示を接続する。
 * ポータブルなskillsを変えず、pi固有のライフサイクルとTUIだけを扱うために使う。
 */

import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import shimonForPi from "@hayashiii/shimon/extensions/pi/index.ts";
import { registerClaudeDelegate } from "./claude-delegate.ts";
import { registerExaSearchIfConfigured } from "./exa-search.ts";
import { registerProductionGuard } from "./production-guard.js";

const ADAPTER_DIR = dirname(fileURLToPath(import.meta.url));
const SESSION_ROUTING = resolve(ADAPTER_DIR, "../../scripts/session-routing.sh");
const STATUS_ID = "hikizan";
const SKILL_ALIASES = ["tansaku", "sekkei", "jikkou", "sadoku", "teishutsu", "houkoku"] as const;

function renderHeader(width: number): string[] {
	if (width < 38) return ["", "  hikizan", ""];

	return [
		"",
		"      __    _ __   _",
		"     / /_  (_) /__(_)___  ____ _____",
		"    / __ \\/ / //_/ /_  / / __ `/ __ \\",
		"   / / / / / ,< / / / /_/ /_/ / / / /",
		"  /_/ /_/_/_/|_/_/ /___/\\__,_/_/ /_/",
		"",
	];
}

function installHeader(ctx: ExtensionContext): void {
	ctx.ui.setHeader(() => ({
		render(width: number): string[] {
			return renderHeader(width);
		},
		invalidate() {},
	}));
}

function setStatus(ctx: ExtensionContext, text: string, tone: "accent" | "muted" | "success" = "muted"): void {
	if (ctx.mode !== "tui") return;
	ctx.ui.setStatus(STATUS_ID, ctx.ui.theme.fg(tone, text));
}

function registerSkillAliases(pi: ExtensionAPI): void {
	for (const name of SKILL_ALIASES) {
		pi.registerCommand(name, {
			description: `${name}スキルを明示的に使う`,
			handler: async (args, ctx) => {
				const suffix = args.trim();
				await ctx.sendUserMessage(`/skill:${name}${suffix ? ` ${suffix}` : ""}`, {
					expandPromptTemplates: true,
				});
			},
		});
	}
}

export default function hikizanForPi(pi: ExtensionAPI) {
	registerProductionGuard(pi);
	shimonForPi(pi);
	registerClaudeDelegate(pi);
	registerExaSearchIfConfigured(pi);
	registerSkillAliases(pi);

	let startupContext = "";
	let headerVisible = true;
	let activeTools = 0;

	pi.on("session_start", async (_event, ctx) => {
		let routingFailed = false;
		try {
			const result = await pi.exec("bash", [SESSION_ROUTING, "pi"], {
				cwd: ctx.cwd,
				timeout: 10_000,
			});
			startupContext = result.code === 0 ? result.stdout.trim() : "";
			routingFailed = result.code !== 0;
		} catch {
			startupContext = "";
			routingFailed = true;
		}

		if (ctx.mode === "tui") {
			if (headerVisible) installHeader(ctx);
			setStatus(ctx, "hikizan: ready");
			if (routingFailed) {
				ctx.ui.notify("hikizanの起動情報を読み込めませんでした。通常のpiとして続行します。", "warning");
			}
		}
	});

	pi.on("before_agent_start", (event) => {
		if (!startupContext) return;
		return { systemPrompt: `${event.systemPrompt}\n\n${startupContext}` };
	});

	pi.on("agent_start", (_event, ctx) => {
		setStatus(ctx, "hikizan: thinking", "accent");
	});

	pi.on("tool_execution_start", (_event, ctx) => {
		activeTools += 1;
		setStatus(ctx, "hikizan: running", "accent");
	});

	pi.on("tool_execution_end", (_event, ctx) => {
		activeTools = Math.max(0, activeTools - 1);
		if (activeTools === 0) setStatus(ctx, "hikizan: checking", "accent");
	});

	pi.on("agent_settled", (_event, ctx) => {
		activeTools = 0;
		setStatus(ctx, "hikizan: done", "success");
	});

	pi.on("session_shutdown", (_event, ctx) => {
		activeTools = 0;
		if (ctx.mode === "tui") {
			ctx.ui.setStatus(STATUS_ID, undefined);
			ctx.ui.setHeader(undefined);
		}
	});

	pi.registerCommand("hikizan", {
		description: "hikizanのヘッダーを表示または非表示にする",
		handler: async (_args, ctx) => {
			headerVisible = !headerVisible;
			ctx.ui.setHeader(undefined);
			if (headerVisible && ctx.mode === "tui") installHeader(ctx);
			ctx.ui.notify(`hikizanヘッダーを${headerVisible ? "表示" : "非表示"}にしました。`, "info");
		},
	});
}

/**
 * piへ追加機能、スキルの短縮コマンド、ブランド表示を接続する。
 * ポータブルなskillsを変えず、pi固有のライフサイクルとTUIだけを扱うために使う。
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import shimonForPi from "@hayashiii/shimon/extensions/pi/index.ts";
import rewindForPi from "pi-rewind/src/index.ts";
import { registerClaudeDelegate } from "./claude-delegate.ts";
import { registerExaSearchIfConfigured } from "./exa-search.ts";
import { registerProductionGuard } from "./production-guard.js";

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
	rewindForPi(pi);
	registerClaudeDelegate(pi);
	registerExaSearchIfConfigured(pi);
	registerSkillAliases(pi);

	let headerVisible = true;

	pi.on("session_start", (_event, ctx) => {
		if (ctx.mode === "tui" && headerVisible) installHeader(ctx);
	});

	pi.on("session_shutdown", (_event, ctx) => {
		if (ctx.mode === "tui") ctx.ui.setHeader(undefined);
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

/**
 * piのbash実行前に、本番・公開環境へ影響しやすい操作を利用者へ確認する。
 * プロンプト上の判断だけに頼らず、外部変更の直前に停止点を作るために使う。
 */

import { findGitPushRisk, findProductionRisk, hasGitPushCommand } from "./production-risk.js";

const EXECUTE_CHOICE = "実行する";

async function readGitPushContext(pi, cwd, command) {
	if (/\bgit\s+-C\b/.test(command) || /(?:^|[;&|])\s*cd\s+[^;&|]+(?:&&|;)/.test(command)) {
		return { currentBranch: "", defaultBranches: [] };
	}

	try {
		const [branch, defaults] = await Promise.all([
			pi.exec("git", ["branch", "--show-current"], { cwd, timeout: 2_000 }),
			pi.exec("git", ["for-each-ref", "--format=%(symref:short)", "refs/remotes/*/HEAD"], {
				cwd,
				timeout: 2_000,
			}),
		]);
		return {
			currentBranch: branch.code === 0 ? branch.stdout.trim() : "",
			defaultBranches:
				defaults.code === 0
					? defaults.stdout
							.split("\n")
							.map((value) => value.trim())
							.filter(Boolean)
							.map((value) => value.replace(/^[^/]+\//, ""))
					: [],
		};
	} catch {
		return { currentBranch: "", defaultBranches: [] };
	}
}

export function registerProductionGuard(pi) {
	pi.on("tool_call", async (event, ctx) => {
		if (event.toolName !== "bash" || typeof event.input?.command !== "string") return undefined;

		const command = event.input.command;
		let risk = findProductionRisk(command);
		if (!risk && hasGitPushCommand(command)) {
			const gitContext = await readGitPushContext(pi, ctx.cwd, command);
			risk = findGitPushRisk(command, gitContext);
		}
		if (!risk) return undefined;

		if (!ctx.hasUI) {
			return {
				block: true,
				reason: `本番変更ゲートが「${risk.label}」に該当するコマンドを停止しました。対話モードで確認してください。`,
			};
		}

		const choice = await ctx.ui.select(
			`本番変更の確認\n\n${risk.label}\n\n${command}\n\nこのコマンドを実行しますか？`,
			["止める", EXECUTE_CHOICE],
		);
		if (choice !== EXECUTE_CHOICE) {
			return { block: true, reason: "本番変更ゲートで利用者が実行を止めました。" };
		}

		return undefined;
	});
}

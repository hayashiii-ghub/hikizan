/**
 * 本番・公開環境へ影響しやすいコマンドを、実行前確認の対象として分類する。
 * 完全な権限制御ではなく、通常の開発操作を妨げない高確度の事故防止に絞る。
 */

const COMMAND_BOUNDARY = String.raw`(?:^|(?:&&|\|\||;|\||\(|\r?\n)\s*)`;
const OPTIONAL_SUDO = String.raw`(?:sudo\s+(?:(?:-E|-n|-H|-S|--preserve-env)\s+)*(?:-u\s+[^\s;&|]+\s+)?)?`;
const ENVIRONMENT_PREFIX = String.raw`(?:env\s+)?(?:[A-Za-z_][A-Za-z0-9_]*=(?:"[^"]*"|'[^']*'|[^\s;&|]+)\s+)*`;
const COMMAND_PREFIX = `${COMMAND_BOUNDARY}${ENVIRONMENT_PREFIX}${OPTIONAL_SUDO}(?:command\\s+)?`;
const EXECUTABLE_PATH = String.raw`(?:[^\s;&|]+/)?`;
const PACKAGE_RUNNER = String.raw`(?:(?:npx|bunx|pnpm\s+(?:exec|dlx)|yarn\s+dlx)\s+)?`;
const GIT_COMMAND = String.raw`${EXECUTABLE_PATH}git(?:\s+-C\s+(?:"[^"]*"|'[^']*'|[^\s;&|]+))*`;
const SCRIPT_SUFFIX = String.raw`(?:[-_:][A-Za-z0-9_-]+)*`;

const RULES = [
	{
		kind: "package-publish",
		label: "パッケージを公開します",
		pattern: new RegExp(
			`${COMMAND_PREFIX}${EXECUTABLE_PATH}(?:(?:npm|pnpm|bun|yarn)\\s+(?:(?:run|npm)\\s+)?(?:publish|release)${SCRIPT_SUFFIX}|cargo\\s+publish|gem\\s+push|twine\\s+upload)(?=\\s|$)`,
			"i",
		),
	},
	{
		kind: "deployment",
		label: "本番・公開環境へデプロイする可能性があります",
		pattern: new RegExp(
			`${COMMAND_PREFIX}${EXECUTABLE_PATH}(?:(?:npm|pnpm|bun|yarn)\\s+(?:run\\s+)?deploy${SCRIPT_SUFFIX}|(?:make|task)\\s+deploy${SCRIPT_SUFFIX}|${PACKAGE_RUNNER}(?:wrangler|firebase|fly|flyctl)\\s+deploy|${PACKAGE_RUNNER}railway\\s+up|${PACKAGE_RUNNER}netlify\\s+deploy\\b[^;&|\\n]*--prod|${PACKAGE_RUNNER}vercel\\b[^;&|\\n]*(?:--prod|--production)|just\\s+deploy${SCRIPT_SUFFIX})(?=\\s|$)`,
			"i",
		),
	},
	{
		kind: "deployment",
		label: "本番・公開環境へデプロイする可能性があります",
		pattern: new RegExp(
			`${COMMAND_PREFIX}(?:(?:bash|sh|zsh|node|bun)\\s+|\\./)[^;&|\\n\\s]*(?:deploy)[^;&|\\n\\s]*(?=\\s|$)`,
			"i",
		),
	},
	{
		kind: "remote-merge",
		label: "リモートのPRをマージします",
		pattern: new RegExp(`${COMMAND_PREFIX}gh\\s+pr\\s+merge(?=\\s|$)`, "i"),
	},
	{
		kind: "release",
		label: "公開リリースを変更します",
		pattern: new RegExp(
			`${COMMAND_PREFIX}gh\\s+release\\s+(?:create|delete|edit)(?=\\s|$)`,
			"i",
		),
	},
	{
		kind: "release",
		label: "公開リリースを変更します",
		pattern: new RegExp(
			`${COMMAND_PREFIX}${EXECUTABLE_PATH}(?:(?:make|task|just)\\s+(?:publish|release)${SCRIPT_SUFFIX}|(?:bash|sh|zsh|node|bun)\\s+[^;&|\\n\\s]*(?:publish|release)[^;&|\\n\\s]*|\\./[^;&|\\n\\s]*(?:publish|release)[^;&|\\n\\s]*)(?=\\s|$)`,
			"i",
		),
	},
	{
		kind: "protected-push",
		label: "保護対象になり得るGit参照を更新します",
		pattern: new RegExp(
			`${COMMAND_PREFIX}${GIT_COMMAND}\\s+push\\b[^;&|\\n]*(?:--force(?:-with-lease)?\\b|-f(?=\\s|$)|--tags\\b|--all\\b|--mirror\\b|--delete\\b|refs/tags/|(?:^|\\s|[+:])(?:HEAD:)?(?:main|master|trunk|production|prod)(?=\\s|$))`,
			"i",
		),
	},
	{
		kind: "infrastructure",
		label: "インフラストラクチャを変更します",
		pattern: new RegExp(
			`${COMMAND_PREFIX}(?:(?:terraform|tofu)\\s+(?:apply|destroy)|pulumi\\s+(?:up|destroy)|kubectl\\s+(?:apply|delete|patch|replace|scale|rollout|set)|helm\\s+(?:install|upgrade|uninstall|rollback))(?=\\s|$)`,
			"i",
		),
	},
	{
		kind: "data-migration",
		label: "共有データを変更するマイグレーションの可能性があります",
		pattern: new RegExp(
			`${COMMAND_PREFIX}${EXECUTABLE_PATH}(?:(?:npm|pnpm|bun|yarn)\\s+(?:run\\s+)?migrate${SCRIPT_SUFFIX}|(?:make|task|just)\\s+migrate${SCRIPT_SUFFIX}|prisma\\s+migrate\\s+deploy|knex\\s+migrate:latest|rails\\s+db:migrate|rake\\s+db:migrate|(?:bash|sh|zsh|node|bun)\\s+[^;&|\\n\\s]*migrate[^;&|\\n\\s]*|\\./[^;&|\\n\\s]*migrate[^;&|\\n\\s]*)(?=\\s|$)`,
			"i",
		),
	},
];

export function findProductionRisk(command) {
	if (typeof command !== "string" || command.trim() === "") return undefined;
	const rule = RULES.find(({ pattern }) => pattern.test(command));
	return rule ? { kind: rule.kind, label: rule.label } : undefined;
}

function shellWords(value) {
	return (value.match(/"[^"]*"|'[^']*'|[^\s]+/g) ?? []).map((word) => word.replace(/^(?:"|')|(?:"|')$/g, ""));
}

function normalizeBranch(value) {
	return value.replace(/^refs\/(?:heads|remotes\/[^/]+)\//, "");
}

function pushedBranches(argumentsText, currentBranch) {
	const words = shellWords(argumentsText);
	const positional = words.filter((word) => !word.startsWith("-"));
	const refspecs = positional.length > 1 ? positional.slice(1) : [];
	if (refspecs.length === 0) return currentBranch ? [currentBranch] : [];

	return refspecs.map((refspec) => {
		const withoutForce = refspec.replace(/^\+/, "");
		const colon = withoutForce.lastIndexOf(":");
		const destination = colon >= 0 ? withoutForce.slice(colon + 1) : withoutForce;
		if (destination === "HEAD") return currentBranch;
		return normalizeBranch(destination);
	});
}

export function findGitPushRisk(command, { currentBranch = "", defaultBranches = [] } = {}) {
	if (typeof command !== "string" || command.trim() === "") return undefined;
	const pattern = new RegExp(`${COMMAND_PREFIX}${GIT_COMMAND}\\s+push\\b([^;&|\\n]*)`, "gi");
	const defaults = defaultBranches.map(normalizeBranch).filter(Boolean);

	for (const match of command.matchAll(pattern)) {
		const branches = pushedBranches(match[1] ?? "", currentBranch);
		if (branches.length === 0 || defaults.length === 0) {
			return { kind: "ambiguous-push", label: "Git pushの送信先を特定できません" };
		}
		if (branches.some((branch) => !branch || defaults.includes(branch))) {
			return { kind: "protected-push", label: "リモートの既定ブランチを更新します" };
		}
	}

	return undefined;
}

export function hasGitPushCommand(command) {
	if (typeof command !== "string" || command.trim() === "") return false;
	return new RegExp(`${COMMAND_PREFIX}${GIT_COMMAND}\\s+push\\b`, "i").test(command);
}

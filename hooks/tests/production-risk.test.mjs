import assert from "node:assert/strict";
import test from "node:test";
import { findGitPushRisk, findProductionRisk, hasGitPushCommand } from "../adapters/pi/production-risk.js";

const guardedCommands = [
	["npm publish", "package-publish"],
	["cd app && npm run deploy", "deployment"],
	["NODE_ENV=production npm run deploy", "deployment"],
	["npm run deploy:prod", "deployment"],
	["make deploy", "deployment"],
	["just release", "release"],
	["./scripts/deploy.sh", "deployment"],
	["bash scripts/migrate-prod.sh", "data-migration"],
	["wrangler deploy", "deployment"],
	["npx wrangler deploy", "deployment"],
	["pnpm exec wrangler deploy", "deployment"],
	["vercel --prod", "deployment"],
	["gh pr merge 42 --squash", "remote-merge"],
	["gh release create v2.0.0", "release"],
	["git push origin main", "protected-push"],
	["git -C app push origin main", "protected-push"],
	["git push --force-with-lease origin feature/rework", "protected-push"],
	["git push origin refs/tags/v2.0.0", "protected-push"],
	["git push origin +HEAD:main", "protected-push"],
	["terraform apply", "infrastructure"],
	["kubectl delete deployment api", "infrastructure"],
	["prisma migrate deploy", "data-migration"],
];

for (const [command, kind] of guardedCommands) {
	test(`guards ${command}`, () => {
		assert.equal(findProductionRisk(command)?.kind, kind);
	});
}

test("guards a plain push from the default branch", () => {
	assert.equal(
		findGitPushRisk("git push", { currentBranch: "main", defaultBranches: ["main"] })?.kind,
		"protected-push",
	);
});

test("guards HEAD when the current branch is the default branch", () => {
	assert.equal(
		findGitPushRisk("git push origin HEAD", { currentBranch: "main", defaultBranches: ["main"] })?.kind,
		"protected-push",
	);
});

test("guards a custom default branch", () => {
	assert.equal(
		findGitPushRisk("git push origin stable", { currentBranch: "topic", defaultBranches: ["stable"] })?.kind,
		"protected-push",
	);
});

test("guards a custom default branch containing a slash", () => {
	assert.equal(
		findGitPushRisk("git push origin release/stable", {
			currentBranch: "topic",
			defaultBranches: ["release/stable"],
		})?.kind,
		"protected-push",
	);
});

test("recognizes quoted git -C pushes", () => {
	assert.equal(hasGitPushCommand('git -C "app dir" push'), true);
});

test("allows a plain push from a known feature branch", () => {
	assert.equal(
		findGitPushRisk("git push", { currentBranch: "feature/login", defaultBranches: ["main"] }),
		undefined,
	);
});

test("guards a push when its destination cannot be resolved", () => {
	assert.equal(findGitPushRisk("git push", { currentBranch: "", defaultBranches: [] })?.kind, "ambiguous-push");
});

const localCommands = [
	"npm test",
	"npm run build",
	"wrangler dev",
	"gh pr create --draft",
	"git push origin feature/main-layout",
	"terraform plan",
	"kubectl get pods",
	"prisma migrate dev",
];

for (const command of localCommands) {
	test(`allows ${command}`, () => {
		assert.equal(findProductionRisk(command), undefined);
	});
}

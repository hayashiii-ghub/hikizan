/**
 * packed Hikizanだけを読み込んだPiでrewindとundoを実行する。
 * コマンド登録だけでは検出できない復元UIとGit状態の回帰を防ぐために使う。
 */

import { spawn, spawnSync } from "node:child_process";
import { access, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

const [piBin, packageDir] = process.argv.slice(2);
if (!piBin || !packageDir) {
	throw new Error("usage: node scripts/test-pi-rewind-rpc.mjs <pi-bin> <package-dir>");
}

function runGit(cwd, args) {
	const result = spawnSync("git", args, { cwd, encoding: "utf8" });
	if (result.status !== 0) {
		throw new Error(result.stderr || `git ${args[0]} failed`);
	}
	return result.stdout.trim();
}

function exists(path) {
	return access(path).then(() => true).catch(() => false);
}

const root = await mkdtemp(join(tmpdir(), "hikizan-rewind-rpc-"));
const agentDir = join(root, "pi-agent");
const repo = join(root, "repo");
const demoPath = join(repo, "demo.txt");
const outputPath = join(repo, "new-output.txt");
let child;

try {
	await mkdir(repo);
	runGit(repo, ["init"]);
	runGit(repo, ["config", "user.email", "test@example.com"]);
	runGit(repo, ["config", "user.name", "Hikizan Rewind Test"]);
	await writeFile(demoPath, "before rewind\n");
	runGit(repo, ["add", "demo.txt"]);
	runGit(repo, ["commit", "-m", "initial"]);
	const initialHead = runGit(repo, ["rev-parse", "HEAD"]);

	child = spawn(
		piBin,
		[
			"--mode", "rpc",
			"--offline",
			"--no-session",
			"--no-context-files",
			"--approve",
			"-e", packageDir,
		],
		{
			cwd: repo,
			env: {
				...process.env,
				PI_CODING_AGENT_DIR: agentDir,
				HIKIZAN_SKIP_FETCH: "1",
			},
			stdio: ["pipe", "pipe", "pipe"],
		},
	);

	let buffer = "";
	let stderr = "";
	let phase = "startup";
	let finished = false;

	const send = (message) => {
		child.stdin.write(`${JSON.stringify(message)}\n`);
	};

	const done = new Promise((resolve, reject) => {
		const timer = setTimeout(() => {
			reject(new Error(`rewind RPC smoke timed out\n${stderr}`));
		}, 30_000);

		const succeed = () => {
			if (finished) return;
			finished = true;
			clearTimeout(timer);
			resolve();
		};

		const fail = (error) => {
			if (finished) return;
			finished = true;
			clearTimeout(timer);
			reject(error);
		};

		child.stderr.on("data", (chunk) => {
			stderr += chunk.toString();
		});

		child.on("error", fail);
		child.on("close", (code) => {
			if (!finished) fail(new Error(`Pi exited early (${code})\n${stderr}`));
		});

		child.stdout.on("data", async (chunk) => {
			buffer += chunk.toString();
			const lines = buffer.split("\n");
			buffer = lines.pop() || "";

			for (const line of lines) {
				let message;
				try {
					message = JSON.parse(line);
				} catch {
					continue;
				}

				try {
					if (
						phase === "startup"
						&& message.type === "extension_ui_request"
						&& message.method === "setStatus"
						&& message.statusKey === "rewind"
						&& message.statusText?.includes("1 checkpoint")
					) {
						await writeFile(demoPath, "after agent change\n");
						await writeFile(outputPath, "recoverable output\n");
						phase = "rewind";
						send({ type: "prompt", id: "rewind", message: "/rewind" });
						continue;
					}

					if (message.type !== "extension_ui_request") continue;

					if (message.method === "select" && message.title === "Rewind to checkpoint:") {
						const value = phase === "rewind"
							? message.options.find((option) => option.includes("Session start"))
							: message.options.find((option) => option.includes("Undo last rewind"));
						if (!value) throw new Error(`missing rewind option in ${JSON.stringify(message.options)}`);
						send({ type: "extension_ui_response", id: message.id, value });
						continue;
					}

					if (message.method === "select" && message.title === "Restore mode:") {
						send({
							type: "extension_ui_response",
							id: message.id,
							value: "Files only (keep conversation)",
						});
						continue;
					}

					if (message.method === "confirm") {
						if (message.title !== "Proceed with file restore?") {
							throw new Error(`unexpected confirmation title: ${message.title}`);
						}
						if (!message.message.includes("demo.txt")) {
							throw new Error("restore preview omitted demo.txt");
						}
						if (phase === "rewind" && !message.message.includes("new-output.txt")) {
							throw new Error("restore preview omitted the removable untracked file");
						}
						send({ type: "extension_ui_response", id: message.id, confirmed: true });
						continue;
					}

					if (message.method === "notify" && message.message?.startsWith("Rewound files")) {
						if (await readFile(demoPath, "utf8") !== "before rewind\n") {
							throw new Error("rewind did not restore tracked content");
						}
						if (await exists(outputPath)) throw new Error("rewind did not remove new untracked content");
						if (runGit(repo, ["rev-parse", "HEAD"]) !== initialHead) {
							throw new Error("rewind moved HEAD");
						}
						phase = "undo";
						send({ type: "prompt", id: "undo", message: "/rewind" });
						continue;
					}

					if (message.method === "notify" && message.message?.startsWith("Undo successful")) {
						if (await readFile(demoPath, "utf8") !== "after agent change\n") {
							throw new Error("undo did not restore tracked content");
						}
						if (await readFile(outputPath, "utf8") !== "recoverable output\n") {
							throw new Error("undo did not restore untracked content");
						}
						if (runGit(repo, ["rev-parse", "HEAD"]) !== initialHead) {
							throw new Error("undo moved HEAD");
						}
						succeed();
					}
				} catch (error) {
					fail(error);
				}
			}
		});
	});

	await done;
	process.stdout.write("PI_REWIND_SMOKE_OK\n");
} finally {
	if (child && !child.killed) child.kill("SIGTERM");
	await rm(root, { recursive: true, force: true });
}

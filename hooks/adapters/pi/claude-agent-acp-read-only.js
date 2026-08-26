/**
 * Claude Agent ACPのsession/newを、読み取り専用の実ツール集合へ固定する。
 * acpxのallowedToolsは自動承認だけなので、ACPメタデータを中継して利用可能性も絞る。
 */

import { spawn } from "node:child_process";
import { pathToFileURL } from "node:url";

const READ_ONLY_TOOLS = ["Read", "Glob", "Grep"];

function asRecord(value) {
	return value && typeof value === "object" && !Array.isArray(value) ? value : {};
}

export function hardenClaudeSessionNew(message) {
	if (asRecord(message).method !== "session/new") return message;

	const params = asRecord(message.params);
	const meta = asRecord(params._meta);
	const claudeCode = asRecord(meta.claudeCode);
	const options = asRecord(claudeCode.options);

	return {
		...message,
		params: {
			...params,
			mcpServers: [],
			_meta: {
				...meta,
				claudeCode: {
					...claudeCode,
					options: {
						...options,
						tools: [...READ_ONLY_TOOLS],
						allowedTools: [...READ_ONLY_TOOLS],
						settingSources: [],
						strictMcpConfig: true,
						mcpServers: {},
					},
				},
			},
		},
	};
}

function runProxy(claudeAgentPath) {
	if (!claudeAgentPath) throw new Error("Claude Agent ACPの実行パスがありません。");

	const child = spawn(process.execPath, [claudeAgentPath], {
		env: process.env,
		stdio: ["pipe", "pipe", "pipe"],
	});
	child.stdout.pipe(process.stdout);
	child.stderr.pipe(process.stderr);

	let input = "";
	let failed = false;
	const fail = (error) => {
		if (failed) return;
		failed = true;
		process.stderr.write(`Claude read-only ACP proxy error: ${error instanceof Error ? error.message : String(error)}\n`);
		process.stdin.pause();
		child.stdin.destroy();
		child.kill("SIGTERM");
		process.exitCode = 1;
	};
	const forwardLine = (line) => {
		if (!line.trim() || failed) return;
		try {
			const message = JSON.parse(line);
			child.stdin.write(`${JSON.stringify(hardenClaudeSessionNew(message))}\n`);
		} catch (error) {
			fail(error);
		}
	};

	process.stdin.setEncoding("utf8");
	process.stdin.on("data", (chunk) => {
		input += chunk;
		let newlineIndex = input.indexOf("\n");
		while (newlineIndex >= 0) {
			forwardLine(input.slice(0, newlineIndex).replace(/\r$/, ""));
			input = input.slice(newlineIndex + 1);
			newlineIndex = input.indexOf("\n");
		}
	});
	process.stdin.on("end", () => {
		if (input.trim()) forwardLine(input.replace(/\r$/, ""));
		if (!failed) child.stdin.end();
	});
	child.on("error", fail);
	child.on("exit", (code) => {
		if (!failed) process.exitCode = code ?? 1;
	});

	for (const signal of ["SIGINT", "SIGTERM"]) {
		process.on(signal, () => child.kill(signal));
	}
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
	try {
		runProxy(process.argv[2]);
	} catch (error) {
		process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
		process.exitCode = 1;
	}
}

/**
 * EXA_API_KEYがあるpiだけへ低遅延のweb_searchを追加する。
 * hikizan単体の利用者へ外部API設定を要求せず、検索を任意機能に保つために使う。
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";
import { ExaSearchError, formatSearchResult, searchExa } from "./exa-client.js";

interface SearchDetails {
	query: string;
	count: number;
	elapsedMs: number;
	results: Array<{ title: string; url: string }>;
}

export function registerExaSearchIfConfigured(
	pi: ExtensionAPI,
	env: Record<string, string | undefined> = process.env,
): boolean {
	const apiKey = env.EXA_API_KEY?.trim();
	if (!apiKey) return false;

	pi.registerTool({
		name: "web_search",
		label: "Web Search",
		description:
			"Search the current web with Exa. Use for recent facts, official documentation, releases, news, and information that may have changed. Returns at most 10 compact results with short highlights.",
		promptSnippet: "Search the current web with Exa when freshness or external sources matter",
		promptGuidelines: [
			"Use web_search for current or externally verifiable information; use local tools for repository contents.",
			"Cite returned URLs near the claims they support.",
			"Do not retry a payment-required error or switch to a paid fallback.",
		],
		parameters: Type.Object({
			query: Type.String({ minLength: 1, description: "Natural-language web search query" }),
			limit: Type.Optional(
				Type.Integer({ minimum: 1, maximum: 10, default: 5, description: "Maximum number of results" }),
			),
		}),

		async execute(_toolCallId, params, signal) {
			const startedAt = Date.now();
			try {
				const search = await searchExa(params.query, { apiKey, limit: params.limit, signal });
				const details: SearchDetails = {
					query: search.query,
					count: search.results.length,
					elapsedMs: Date.now() - startedAt,
					results: search.results.map(({ title, url }) => ({ title, url })),
				};
				return {
					content: [{ type: "text", text: formatSearchResult(search) }],
					details,
				};
			} catch (error) {
				if (error instanceof ExaSearchError) throw new Error(error.message);
				throw error;
			}
		},

		renderCall(args, theme) {
			const query = args.query.length > 72 ? `${args.query.slice(0, 69)}...` : args.query;
			return new Text(`${theme.fg("toolTitle", theme.bold("web_search"))} ${theme.fg("muted", query)}`, 0, 0);
		},

		renderResult(result, { expanded, isPartial }, theme, context) {
			if (isPartial) return new Text(theme.fg("warning", "Searching Exa..."), 0, 0);
			const details = result.details as SearchDetails | undefined;
			if (!details) {
				const text = result.content.find((item) => item.type === "text");
				return new Text(
					text?.type === "text" ? theme.fg(context.isError ? "error" : "muted", text.text) : "",
					0,
					0,
				);
			}

			let text = theme.fg("success", `${details.count} results · ${details.elapsedMs}ms`);
			if (expanded) {
				for (const item of details.results) {
					text += `\n${theme.fg("muted", item.title)}\n${theme.fg("dim", item.url)}`;
				}
			}
			return new Text(text, 0, 0);
		},
	});

	return true;
}

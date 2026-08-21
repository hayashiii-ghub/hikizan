import assert from "node:assert/strict";
import test from "node:test";
import { ExaSearchError, formatSearchResult, searchExa } from "../adapters/pi/exa-client.js";

function jsonResponse(body, status = 200) {
	return new Response(JSON.stringify(body), {
		status,
		headers: { "Content-Type": "application/json" },
	});
}

test("uses fast search, capped highlights, and the requested limit", async () => {
	let request;
	const fetchImpl = async (_input, init) => {
		request = init;
		return jsonResponse({
			requestId: "request-1",
			results: [
				{
					title: "Exa docs",
					url: "https://exa.ai/docs",
					publishedDate: "2026-08-11",
					highlights: ["Search API reference"],
				},
			],
			costDollars: { total: 0.008 },
		});
	};

	const result = await searchExa("  Exa coding agent docs  ", {
		apiKey: "test-key",
		limit: 3,
		fetchImpl,
	});

	assert.equal(request?.method, "POST");
	assert.equal(request?.headers.Authorization, "Bearer test-key");
	assert.deepEqual(JSON.parse(String(request?.body)), {
		query: "Exa coding agent docs",
		type: "fast",
		numResults: 3,
		contents: { highlights: { maxCharacters: 600 } },
	});
	assert.equal(result.results.length, 1);
	assert.equal(result.costDollars, 0.008);
	assert.match(formatSearchResult(result), /https:\/\/exa\.ai\/docs/);
});

test("fails before making a request when the API key is absent", async () => {
	let called = false;
	await assert.rejects(
		searchExa("test", {
			apiKey: "",
			fetchImpl: async () => {
				called = true;
				return jsonResponse({ results: [] });
			},
		}),
		(error) => error instanceof ExaSearchError && error.code === "missing_key",
	);
	assert.equal(called, false);
});

test("stops on HTTP 402 without retrying", async () => {
	let calls = 0;
	await assert.rejects(
		searchExa("test", {
			apiKey: "test-key",
			fetchImpl: async () => {
				calls += 1;
				return jsonResponse({ tag: "API_KEY_BUDGET_EXCEEDED" }, 402);
			},
		}),
		(error) => error instanceof ExaSearchError && error.code === "payment_required" && error.status === 402,
	);
	assert.equal(calls, 1);
});

test("honors caller cancellation", async () => {
	const controller = new AbortController();
	const fetchImpl = async (_input, init) =>
		new Promise((_resolve, reject) => {
			init?.signal?.addEventListener("abort", () => reject(init.signal?.reason), { once: true });
		});
	const pending = searchExa("test", { apiKey: "test-key", signal: controller.signal, fetchImpl });
	controller.abort();
	await assert.rejects(pending, (error) => error instanceof ExaSearchError && error.code === "cancelled");
});

test("enforces the request timeout", async () => {
	const fetchImpl = async (_input, init) =>
		new Promise((_resolve, reject) => {
			init?.signal?.addEventListener("abort", () => reject(init.signal?.reason), { once: true });
		});
	await assert.rejects(
		searchExa("test", { apiKey: "test-key", timeoutMs: 5, fetchImpl }),
		(error) => error instanceof ExaSearchError && error.code === "timeout",
	);
});

test("rejects malformed success responses", async () => {
	await assert.rejects(
		searchExa("test", {
			apiKey: "test-key",
			fetchImpl: async () => jsonResponse({ result: [] }),
		}),
		(error) => error instanceof ExaSearchError && error.code === "invalid_response",
	);
});

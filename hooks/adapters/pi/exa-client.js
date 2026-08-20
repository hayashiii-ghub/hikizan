const EXA_SEARCH_URL = "https://api.exa.ai/search";
const DEFAULT_LIMIT = 5;
const MAX_LIMIT = 10;
const DEFAULT_TIMEOUT_MS = 10_000;
const HIGHLIGHT_CHARACTERS = 600;

export class ExaSearchError extends Error {
	constructor(message, code, status) {
		super(message);
		this.name = "ExaSearchError";
		this.code = code;
		this.status = status;
	}
}

function normalizeLimit(limit) {
	if (limit === undefined) return DEFAULT_LIMIT;
	if (!Number.isInteger(limit) || limit < 1 || limit > MAX_LIMIT) {
		throw new ExaSearchError(`limit must be an integer from 1 to ${MAX_LIMIT}.`, "request_failed");
	}
	return limit;
}

function createRequestSignal(signal, timeoutMs) {
	if (!Number.isFinite(timeoutMs) || timeoutMs <= 0) {
		throw new ExaSearchError("timeoutMs must be a positive finite number.", "request_failed");
	}

	const controller = new AbortController();
	let timedOut = false;
	const onAbort = () => controller.abort(signal?.reason);
	const timeout = setTimeout(() => {
		timedOut = true;
		controller.abort(new DOMException("Search timed out.", "TimeoutError"));
	}, timeoutMs);

	if (signal?.aborted) onAbort();
	else signal?.addEventListener("abort", onAbort, { once: true });

	return {
		signal: controller.signal,
		timedOut: () => timedOut,
		cleanup() {
			clearTimeout(timeout);
			signal?.removeEventListener("abort", onAbort);
		},
	};
}

async function readErrorMessage(response) {
	try {
		const body = await response.json();
		if (typeof body.error === "string") return body.error;
		if (body.error && typeof body.error.message === "string") return body.error.message;
		if (typeof body.message === "string") return body.message;
	} catch {
		// Use the status-specific fallback below.
	}
	return undefined;
}

async function responseError(response) {
	const detail = await readErrorMessage(response);
	switch (response.status) {
		case 401:
			return new ExaSearchError("EXA_API_KEY is invalid or inactive.", "unauthorized", 401);
		case 402:
			return new ExaSearchError(
				"Exa credits or the API-key budget are exhausted. Search stopped without a paid fallback.",
				"payment_required",
				402,
			);
		case 429:
			return new ExaSearchError("Exa rate limit exceeded. Try again later.", "rate_limited", 429);
		default:
			return new ExaSearchError(
				detail ? `Exa request failed: ${detail}` : `Exa request failed with HTTP ${response.status}.`,
				"request_failed",
				response.status,
			);
	}
}

function parseResult(value) {
	if (!value || typeof value !== "object") return undefined;
	if (typeof value.url !== "string" || value.url.length === 0) return undefined;

	return {
		title: typeof value.title === "string" && value.title.length > 0 ? value.title : value.url,
		url: value.url,
		publishedDate: typeof value.publishedDate === "string" ? value.publishedDate : undefined,
		highlights: Array.isArray(value.highlights)
			? value.highlights.filter((entry) => typeof entry === "string" && entry.length > 0)
			: [],
	};
}

export async function searchExa(query, options = {}) {
	const normalizedQuery = query.trim();
	if (!normalizedQuery) throw new ExaSearchError("query must not be empty.", "request_failed");
	if (!options.apiKey) {
		throw new ExaSearchError("EXA_API_KEY is not set. Add it to the environment before starting pi.", "missing_key");
	}

	const limit = normalizeLimit(options.limit);
	const timeoutMs = options.timeoutMs ?? DEFAULT_TIMEOUT_MS;
	const requestSignal = createRequestSignal(options.signal, timeoutMs);
	const fetchImpl = options.fetchImpl ?? fetch;

	try {
		const response = await fetchImpl(EXA_SEARCH_URL, {
			method: "POST",
			headers: {
				Authorization: `Bearer ${options.apiKey}`,
				"Content-Type": "application/json",
			},
			body: JSON.stringify({
				query: normalizedQuery,
				type: "fast",
				numResults: limit,
				contents: {
					highlights: { maxCharacters: HIGHLIGHT_CHARACTERS },
				},
			}),
			signal: requestSignal.signal,
		});

		if (!response.ok) throw await responseError(response);

		const body = await response.json();
		if (!Array.isArray(body.results)) {
			throw new ExaSearchError("Exa returned an invalid search response.", "invalid_response");
		}

		return {
			query: normalizedQuery,
			results: body.results.map(parseResult).filter((item) => item !== undefined),
			costDollars: typeof body.costDollars?.total === "number" ? body.costDollars.total : undefined,
		};
	} catch (error) {
		if (error instanceof ExaSearchError) throw error;
		if (options.signal?.aborted) throw new ExaSearchError("Exa search was cancelled.", "cancelled");
		if (requestSignal.timedOut()) {
			throw new ExaSearchError(`Exa search timed out after ${timeoutMs}ms.`, "timeout");
		}
		throw new ExaSearchError(
			error instanceof Error ? `Exa request failed: ${error.message}` : "Exa request failed.",
			"request_failed",
		);
	} finally {
		requestSignal.cleanup();
	}
}

export function formatSearchResult(search) {
	const lines = [`Web search results for: ${search.query}`];

	for (const [index, result] of search.results.entries()) {
		lines.push("", `${index + 1}. ${result.title}`, `   ${result.url}`);
		if (result.publishedDate) lines.push(`   Published: ${result.publishedDate}`);
		if (result.highlights.length > 0) lines.push(`   ${result.highlights.join(" ")}`);
	}

	if (search.results.length === 0) lines.push("", "No results found.");
	return lines.join("\n");
}

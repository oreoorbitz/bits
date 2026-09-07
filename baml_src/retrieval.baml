// bits/baml_src/retrieval.baml — retrieval-eval policy (hub#173).
//
// Cross-embedder agreement + calibration spread over recorded vendor
// rankings. BAML owns the shapes and the grading policy; the T2 arm
// (scripts/bits-t2.mjs `cross-embedder-agreement`) executes the same
// policy against test-backlog/retrieval/scores.json, and the literals
// in retrieval_test.baml mirror that fixture's query 1 + 2.
//
// Seed (live php-v1, 2026-09-06): hub#170 (voyage-4-large@1024 +
// rerank-2: 0.707/0.617/0.559) and hub#172 (embed-english-v3.0@1024 +
// rerank-english-v3.0: 0.9961/0.0562/0.0037) agree on rank 1
// (pdo-prepared#0) for 'prepared statements' with wildly different
// calibration. Pin it: a vendor swap or regression that flips rank 1
// fails loud naming the query, instead of silently rescoring.
//
// Deliberate asymmetry: agreement is ASSERTED (fail names the query);
// spread is RECORDED, never asserted — observation first, thresholds
// later. There is no threshold function in this file on purpose.

class ScoredHit {
    doc_id: string,
    score: float,
}

class VendorRanking {
    vendor: string,
    query: string,
    hits: ScoredHit[] @description("rank order, rank 1 first"),
}

class Agreement {
    query: string,
    agree: bool,
    voyage_top: string,
    cohere_top: string,
    reason: string @description("machine-readable slug; a disagree reason names the query"),
}

class Spread {
    vendor: string,
    query: string,
    top: float,
    tail: float,
    spread: float @description("top minus tail, recorded observation — never a gate"),
}

// Rank-1 doc id of a recorded ranking. Empty ranking has no top (""
// — the T2 arm treats an empty ranking as fixture-empty-ranking, loud).
function rank1(hits: ScoredHit[]) -> string {
    if (hits.length() == 0) {
        ""
    } else {
        hits[0].doc_id
    }
}

// Cross-embedder rank-1 agreement for one query. Agree iff both tops
// match; a disagree reason carries the query so the failure names it.
function check_agreement(query: string, voyage: ScoredHit[], cohere: ScoredHit[]) -> Agreement {
    let v = rank1(voyage);
    let c = rank1(cohere);
    if (v == c) {
        Agreement { query: query, agree: true, voyage_top: v, cohere_top: c, reason: "rank-agree" }
    } else {
        Agreement {
            query: query,
            agree: false,
            voyage_top: v,
            cohere_top: c,
            reason: "rank-disagree:" + query,
        }
    }
}

// Calibration spread for one vendor/query: top minus tail. Recorded,
// never asserted — callers log the Spread, they never gate on it.
function calibration_spread(vendor: string, query: string, hits: ScoredHit[]) -> Spread {
    let top = if (hits.length() == 0) {
        0.0
    } else {
        hits[0].score
    };
    let tail = if (hits.length() == 0) {
        0.0
    } else {
        hits[hits.length() - 1].score
    };
    Spread { vendor: vendor, query: query, top: top, tail: tail, spread: top - tail }
}

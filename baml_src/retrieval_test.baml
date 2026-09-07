// BITS T0 retrieval-eval tests (hub#173) — agreement policy + spread
// recording on literals, no LLM, milliseconds. Query-1 literals mirror
// test-backlog/retrieval/scores.json verbatim (live php-v1 2026-09-06:
// hub#170 voyage 0.707/0.617/0.559, hub#172 cohere 0.9961/0.0562/0.0037,
// rank 1 pdo-prepared#0); query-2 literals mirror the same fixture's
// plausible (non-live) entry. If scores.json changes, these change
// with it — that mirror is the tracer.
//
// Red-check (bi#57), observed 2026-09-06: neutered the agreement hunk
// in check_agreement (`==` -> `!=`); exactly the 3 agreement tests
// failed ("assertion failed: expected true" x3), both spread tests
// still passed (hunk is load-bearing for agreement only); restored,
// 19/19 green. A passing suite that cannot go red is camouflage.

// Lower-rank doc ids for query 1 were not captured in the hub#170/172
// bodies — the scores below are verbatim, the ids are declared
// placeholders (mirrors scores.json rank2-unrecorded/rank3-unrecorded).

testset "rank-1 agreement" {
    test "live prepared-statements agree on pdo-prepared#0" {
        let voyage = [
            ScoredHit { doc_id: "pdo-prepared#0", score: 0.707 },
            ScoredHit { doc_id: "rank2-unrecorded", score: 0.617 },
            ScoredHit { doc_id: "rank3-unrecorded", score: 0.559 },
        ];
        let cohere = [
            ScoredHit { doc_id: "pdo-prepared#0", score: 0.9961 },
            ScoredHit { doc_id: "rank2-unrecorded", score: 0.0562 },
            ScoredHit { doc_id: "rank3-unrecorded", score: 0.0037 },
        ];
        let a = check_agreement("prepared statements", voyage, cohere);
        assert.is_true(a.agree);
        assert.equal(a.voyage_top, "pdo-prepared#0");
        assert.equal(a.cohere_top, "pdo-prepared#0");
        assert.equal(a.reason, "rank-agree");
    }

    test "simulated rank flip fails naming the query" {
        let voyage = [
            ScoredHit { doc_id: "pdo-prepared#0", score: 0.707 },
            ScoredHit { doc_id: "rank2-unrecorded", score: 0.617 },
            ScoredHit { doc_id: "rank3-unrecorded", score: 0.559 },
        ];
        let flipped = [
            ScoredHit { doc_id: "rank2-unrecorded", score: 0.9961 },
            ScoredHit { doc_id: "pdo-prepared#0", score: 0.0562 },
            ScoredHit { doc_id: "rank3-unrecorded", score: 0.0037 },
        ];
        let a = check_agreement("prepared statements", voyage, flipped);
        assert.is_true(!a.agree);
        assert.equal(a.reason, "rank-disagree:prepared statements");
    }

    test "second fixture query agrees" {
        let voyage = [
            ScoredHit { doc_id: "pool-config#2", score: 0.681 },
            ScoredHit { doc_id: "pool-size#0", score: 0.602 },
            ScoredHit { doc_id: "pool-timeout#1", score: 0.541 },
        ];
        let cohere = [
            ScoredHit { doc_id: "pool-config#2", score: 0.9821 },
            ScoredHit { doc_id: "pool-size#0", score: 0.0712 },
            ScoredHit { doc_id: "pool-timeout#1", score: 0.0098 },
        ];
        let a = check_agreement("connection pooling", voyage, cohere);
        assert.is_true(a.agree);
        assert.equal(a.reason, "rank-agree");
    }

    test "empty ranking has no top" {
        let hits: ScoredHit[] = [];
        assert.equal(rank1(hits), "");
    }
}

testset "calibration spread recorded, never asserted" {
    // These tests assert the RECORDING math only (top/tail carried
    // through, spread wired as top minus tail). No test in this file
    // gates on a spread threshold — observation first, thresholds
    // later (hub#173 acceptance). A threshold assertion here would be
    // the bug, not the coverage.

    test "voyage prepared-statements spread recorded" {
        let hits = [
            ScoredHit { doc_id: "pdo-prepared#0", score: 0.707 },
            ScoredHit { doc_id: "rank2-unrecorded", score: 0.617 },
            ScoredHit { doc_id: "rank3-unrecorded", score: 0.559 },
        ];
        let s = calibration_spread("voyage", "prepared statements", hits);
        assert.equal(s.top, 0.707);
        assert.equal(s.tail, 0.559);
        assert.equal(s.spread, s.top - s.tail);
    }

    test "cohere prepared-statements spread recorded" {
        let hits = [
            ScoredHit { doc_id: "pdo-prepared#0", score: 0.9961 },
            ScoredHit { doc_id: "rank2-unrecorded", score: 0.0562 },
            ScoredHit { doc_id: "rank3-unrecorded", score: 0.0037 },
        ];
        let s = calibration_spread("cohere", "prepared statements", hits);
        assert.equal(s.top, 0.9961);
        assert.equal(s.tail, 0.0037);
        assert.equal(s.spread, s.top - s.tail);
    }
}

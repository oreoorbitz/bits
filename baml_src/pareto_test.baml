// BITS T0 Pareto-pool tests (hub#202) — dominates/pareto_front/
// promotion_pool on literal GraderScore[][] matrices, no LLM,
// milliseconds.
//
// The "fixture pool#01 ..." test literals mirror
// test-backlog/pareto/pool#01.json verbatim (change both together —
// that mirror is the tracer, same convention as flip_gate_test.baml
// mirroring prop#01.*.json).
//
// Red-check (bi#57), observed 2026-09-07: neutered the strict-edge
// comparison hunk in dominates (pareto.baml, "if (sa.score > bs.score)"
// -> "if (sa.score >= bs.score)", so a tie counts as a strict edge and
// equal rows "dominate" each other); exactly the two tie tests failed —
// "equal rows do not dominate" and "tied candidates co-survive on the
// front" (assertion failed: expected true on the !dominates asserts /
// front equality) — while the other 62 tests still passed (62 passed,
// 2 failed, 64 total at observation time). Hunk restored, suite green
// (64/64). A passing suite that cannot go red is camouflage.

// The cookbook's degenerate matrix (mirrors pool#01.json): the
// "refuse-to-summarize" candidate maxes the chemical-name grader and
// fails the rest; the balanced candidate passes 3/4 graders.
testset "dominates on literal grader matrices" {
    test "strictly better on one grader, tied on the rest dominates" {
        let a = [
            GraderScore { grader: "g1", score: 0.9, pass_threshold: 0.5, reason: "r" },
            GraderScore { grader: "g2", score: 0.8, pass_threshold: 0.5, reason: "r" },
        ];
        let b = [
            GraderScore { grader: "g1", score: 0.9, pass_threshold: 0.5, reason: "r" },
            GraderScore { grader: "g2", score: 0.5, pass_threshold: 0.5, reason: "r" },
        ];
        assert.is_true(dominates(a, b));
        assert.is_true(!dominates(b, a));
    }

    test "equal rows do not dominate" {
        let a = [
            GraderScore { grader: "g1", score: 0.9, pass_threshold: 0.5, reason: "r" },
            GraderScore { grader: "g2", score: 0.8, pass_threshold: 0.5, reason: "r" },
        ];
        let b = [
            GraderScore { grader: "g1", score: 0.9, pass_threshold: 0.5, reason: "r" },
            GraderScore { grader: "g2", score: 0.8, pass_threshold: 0.5, reason: "r" },
        ];
        assert.is_true(!dominates(a, b));
        assert.is_true(!dominates(b, a));
    }

    test "better on one, worse on another dominates nothing" {
        let a = [
            GraderScore { grader: "g1", score: 0.9, pass_threshold: 0.5, reason: "r" },
            GraderScore { grader: "g2", score: 0.4, pass_threshold: 0.5, reason: "r" },
        ];
        let b = [
            GraderScore { grader: "g1", score: 0.5, pass_threshold: 0.5, reason: "r" },
            GraderScore { grader: "g2", score: 0.8, pass_threshold: 0.5, reason: "r" },
        ];
        assert.is_true(!dominates(a, b));
        assert.is_true(!dominates(b, a));
    }

    test "a row missing one of b's graders can never dominate" {
        let a = [GraderScore { grader: "g1", score: 0.4, pass_threshold: 0.5, reason: "r" }];
        let b = [
            GraderScore { grader: "g1", score: 0.5, pass_threshold: 0.5, reason: "r" },
            GraderScore { grader: "g2", score: 0.5, pass_threshold: 0.5, reason: "r" },
        ];
        assert.is_true(!dominates(a, b));
        // The reverse holds: b covers every grader a carries and is
        // strictly better on it — extra graders in b are not a's
        // objectives and do not block the edge.
        assert.is_true(dominates(b, a));
    }

    test "empty rows dominate nothing and are dominated by nothing" {
        let a = [GraderScore { grader: "g1", score: 1.0, pass_threshold: 0.5, reason: "r" }];
        let empty: GraderScore[] = [];
        assert.is_true(!dominates(a, empty));
        assert.is_true(!dominates(empty, a));
    }
}

testset "pareto_front keeps undominated candidates" {
    test "dominated candidate drops off the front, pool order preserved" {
        let strong = [
            GraderScore { grader: "g1", score: 0.9, pass_threshold: 0.5, reason: "r" },
            GraderScore { grader: "g2", score: 0.8, pass_threshold: 0.5, reason: "r" },
        ];
        let weak = [
            GraderScore { grader: "g1", score: 0.9, pass_threshold: 0.5, reason: "r" },
            GraderScore { grader: "g2", score: 0.5, pass_threshold: 0.5, reason: "r" },
        ];
        let front = pareto_front([strong, weak]);
        assert.equal(front, [strong]);
    }

    test "tied candidates co-survive on the front" {
        // Same scores, different reason slugs — structurally distinct
        // rows, so the front compares them (and must keep both).
        let a = [
            GraderScore { grader: "g1", score: 0.9, pass_threshold: 0.5, reason: "run-1" },
            GraderScore { grader: "g2", score: 0.8, pass_threshold: 0.5, reason: "run-1" },
        ];
        let b = [
            GraderScore { grader: "g1", score: 0.9, pass_threshold: 0.5, reason: "run-2" },
            GraderScore { grader: "g2", score: 0.8, pass_threshold: 0.5, reason: "run-2" },
        ];
        let front = pareto_front([a, b]);
        assert.equal(front, [a, b]);
    }

    test "single candidate is trivially its own front" {
        let only = [GraderScore { grader: "g1", score: 0.3, pass_threshold: 0.5, reason: "r" }];
        assert.equal(pareto_front([only]), [only]);
    }

    test "empty pool has an empty front" {
        let pool: GraderScore[][] = [];
        assert.equal(pareto_front(pool), []);
    }
}

testset "cookbook degenerate refuse-to-summarize candidate" {
    // The degenerate candidate: verbatim-refusal maxes the
    // chemical-name grader (1.0) and fails everything else — the
    // overfit the cookbook's static metaprompt fell into.
    let refuse = [
        GraderScore {
            grader: "entity-preservation",
            score: 0.0,
            pass_threshold: 0.75,
            reason: "refused",
        },
        GraderScore { grader: "length-band", score: 0.0, pass_threshold: 0.9, reason: "refused" },
        GraderScore {
            grader: "chemical-name",
            score: 1.0,
            pass_threshold: 0.9,
            reason: "verbatim-copy",
        },
        GraderScore { grader: "llm-judge", score: 0.0, pass_threshold: 0.5, reason: "judge-fail" },
    ];
    let balanced = [
        GraderScore {
            grader: "entity-preservation",
            score: 0.9,
            pass_threshold: 0.75,
            reason: "entities-preserved",
        },
        GraderScore { grader: "length-band", score: 0.95, pass_threshold: 0.9, reason: "in-band" },
        GraderScore {
            grader: "chemical-name",
            score: 0.8,
            pass_threshold: 0.9,
            reason: "minor-drift",
        },
        GraderScore { grader: "llm-judge", score: 0.75, pass_threshold: 0.5, reason: "judge-good" },
    ];

    test "degenerate candidate dominates nobody and is dominated by nobody" {
        assert.is_true(!dominates(refuse, balanced));
        assert.is_true(!dominates(balanced, refuse));
    }

    test "degenerate candidate stays on the front but never alone" {
        let front = pareto_front([refuse, balanced]);
        assert.equal(front, [refuse, balanced]);
    }

    test "single-grader best would pick the degenerate candidate" {
        // The trap the front exists to defuse: ranking by the
        // chemical-name grader alone crowns the refusal.
        let by_chemical = [refuse, balanced].find((cand) -> {
            cand.some((s) -> {
                s.grader == "chemical-name" && s.score == 1.0
            })
        });
        if let winner: GraderScore[] = by_chemical {
            assert.equal(winner, refuse);
        } else {
            assert.is_true(false);
        }
    }

    test "lenient_pass blocks the degenerate candidate, passes the balanced one" {
        assert.is_true(!lenient_pass(refuse));
        assert.is_true(lenient_pass(balanced));
    }

    test "promotion_pool excludes the degenerate candidate" {
        assert.equal(promotion_pool([refuse, balanced]), [balanced]);
    }

    test "lenient-pass alone is not enough: dominated candidates never promote" {
        // Sloppy passes lenient (3/4 graders) but is dominated by
        // balanced on every grader — off the front, out of the pool.
        let sloppy = [
            GraderScore {
                grader: "entity-preservation",
                score: 0.8,
                pass_threshold: 0.75,
                reason: "r",
            },
            GraderScore { grader: "length-band", score: 0.9, pass_threshold: 0.9, reason: "r" },
            GraderScore { grader: "chemical-name", score: 0.7, pass_threshold: 0.9, reason: "r" },
            GraderScore { grader: "llm-judge", score: 0.6, pass_threshold: 0.5, reason: "r" },
        ];
        assert.is_true(lenient_pass(sloppy));
        assert.is_true(dominates(balanced, sloppy));
        assert.equal(promotion_pool([refuse, balanced, sloppy]), [balanced]);
    }

    test "fixture pool#01 degenerate matrix (mirrors test-backlog/pareto/pool#01.json)" {
        let pool = [refuse, balanced];
        assert.equal(pareto_front(pool), [refuse, balanced]);
        assert.equal(promotion_pool(pool), [balanced]);
    }
}

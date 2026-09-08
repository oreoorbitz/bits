// BITS T0 tests — grading policy on literals, no LLM, milliseconds.
// Case ids are the stable T2 arm ids (see scripts/bits-t2.mjs); caps
// mirror test-backlog/cost/budgets.toml (timeout_ms = 30000 per arm,
// token_cap = 0 stub-only). If budgets.toml changes, these literals
// change with it — that mirror is the tracer.
//
// Red-check (bi#57), observed 2026-09-06: neutered the token-cap hunk in
// grade_verdict (`>` -> `<`); exactly "pass over token cap grades fail
// over-budget" failed (left = Pass, right = Fail); restored, 13/13 green.

testset "grade_verdict" {
    test "pass within budget grades pass" {
        let c = Case { id: "chain-blocks", title: "chain", tier: Tier.T2, token_cap: 0, timeout_ms: 30000 };
        let v = Verdict {
            case_id: "chain-blocks",
            outcome: Outcome.Pass,
            reason: "ready-exact",
            tokens_used: 0,
            wall_ms: 1200,
            transcript: "ok",
        };
        let g = grade_verdict(c, v);
        assert.equal(g.outcome, Outcome.Pass);
        assert.is_true(!g.over_budget);
    }

    test "pass over token cap grades fail over-budget" {
        let c = Case { id: "chain-blocks", title: "chain", tier: Tier.T2, token_cap: 0, timeout_ms: 30000 };
        let v = Verdict {
            case_id: "chain-blocks",
            outcome: Outcome.Pass,
            reason: "ready-exact",
            tokens_used: 1,
            wall_ms: 1200,
            transcript: "ok",
        };
        let g = grade_verdict(c, v);
        assert.equal(g.outcome, Outcome.Fail);
        assert.equal(g.reason, "over-budget");
        assert.is_true(g.over_budget);
    }

    test "pass over wall clock grades fail over-budget" {
        let c = Case {
            id: "fanout-hub-first",
            title: "fanout",
            tier: Tier.T2,
            token_cap: 0,
            timeout_ms: 30000,
        };
        let v = Verdict {
            case_id: "fanout-hub-first",
            outcome: Outcome.Pass,
            reason: "hub-first",
            tokens_used: 0,
            wall_ms: 30001,
            transcript: "ok",
        };
        let g = grade_verdict(c, v);
        assert.equal(g.outcome, Outcome.Fail);
        assert.equal(g.reason, "over-budget");
        assert.is_true(g.over_budget);
    }

    test "fail stays fail with its own reason" {
        let c = Case { id: "cycle-parks", title: "cycles", tier: Tier.T2, token_cap: 0, timeout_ms: 30000 };
        let v = Verdict {
            case_id: "cycle-parks",
            outcome: Outcome.Fail,
            reason: "ready-nonempty",
            tokens_used: 0,
            wall_ms: 900,
            transcript: "ready=[t#10]",
        };
        let g = grade_verdict(c, v);
        assert.equal(g.outcome, Outcome.Fail);
        assert.equal(g.reason, "ready-nonempty");
        assert.is_true(!g.over_budget);
    }

    test "fail over budget reports over-budget not the arm reason" {
        let c = Case { id: "cycle-parks", title: "cycles", tier: Tier.T2, token_cap: 0, timeout_ms: 30000 };
        let v = Verdict {
            case_id: "cycle-parks",
            outcome: Outcome.Fail,
            reason: "ready-nonempty",
            tokens_used: 0,
            wall_ms: 60000,
            transcript: "slow",
        };
        let g = grade_verdict(c, v);
        assert.equal(g.outcome, Outcome.Fail);
        assert.equal(g.reason, "over-budget");
        assert.is_true(g.over_budget);
    }

    test "wrong case id grades fail case-mismatch" {
        let c = Case {
            id: "dangling-parks",
            title: "dangling",
            tier: Tier.T2,
            token_cap: 0,
            timeout_ms: 30000,
        };
        let v = Verdict {
            case_id: "chain-blocks",
            outcome: Outcome.Pass,
            reason: "ready-exact",
            tokens_used: 0,
            wall_ms: 100,
            transcript: "ok",
        };
        let g = grade_verdict(c, v);
        assert.equal(g.outcome, Outcome.Fail);
        assert.equal(g.reason, "case-mismatch");
    }

    test "skip within budget stays skip" {
        let c = Case {
            id: "lease-fencing",
            title: "leases",
            tier: Tier.T2,
            token_cap: 0,
            timeout_ms: 30000,
        };
        let v = Verdict {
            case_id: "lease-fencing",
            outcome: Outcome.Skip,
            reason: "no-clock",
            tokens_used: 0,
            wall_ms: 50,
            transcript: "skipped: reason",
        };
        let g = grade_verdict(c, v);
        assert.equal(g.outcome, Outcome.Skip);
        assert.is_true(!g.over_budget);
    }
}

testset "tally and suite_passed" {
    test "tally counts each outcome" {
        let graded = [
            GradedCase { case_id: "a", outcome: Outcome.Pass, reason: "r", over_budget: false },
            GradedCase { case_id: "b", outcome: Outcome.Fail, reason: "r", over_budget: false },
            GradedCase { case_id: "c", outcome: Outcome.Skip, reason: "r", over_budget: false },
            GradedCase { case_id: "d", outcome: Outcome.Pass, reason: "r", over_budget: false },
        ];
        let t = tally(graded);
        assert.equal(t.pass, 2);
        assert.equal(t.fail, 1);
        assert.equal(t.skip, 1);
    }

    test "empty suite tallies zero and passes" {
        let graded: GradedCase[] = [];
        let t = tally(graded);
        assert.equal(t.pass, 0);
        assert.equal(t.fail, 0);
        assert.equal(t.skip, 0);
        assert.is_true(suite_passed(t));
    }

    test "any fail fails the suite" {
        let t = SuiteTally { pass: 5, fail: 1, skip: 0 };
        assert.is_true(!suite_passed(t));
    }

    test "skips alone still pass" {
        let t = SuiteTally { pass: 0, fail: 0, skip: 3 };
        assert.is_true(suite_passed(t));
    }
}

testset "interop shapes" {
    test "evidence_cite builds the drill line" {
        assert.equal(evidence_cite("bits-t2"), "Evidence: drill(bits-t2)");
    }

    test "self_file_title names arm and reason" {
        assert.equal(
            self_file_title("chain-blocks", "ready-nonexact"),
            "BITS self-file: chain-blocks ready-nonexact",
        );
    }

    test "self_file_body carries arm, reason, provenance, transcript" {
        // The exact byte shape scripts/bits-t2.mjs selfFileBody() writes —
        // drift on either side fails here. The transcript literal names
        // both sides of the comparison (bits#02: actual + expected).
        let b = self_file_body("chain-blocks", "ready-nonexact", "ready=[t#01] expected=[t#02]");
        assert.equal(
            b,
            "BITS self-file: arm chain-blocks graded Fail (ready-nonexact).\n\nSuite: drill(bits-t2). Filed by the suite, not by hand — the suite\nuses the tool to prove the tool.\n\nTranscript:\nready=[t#01] expected=[t#02]",
        );
    }
}

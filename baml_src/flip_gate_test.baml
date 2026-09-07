// BITS T0 flip-gate tests (hub#200) — acceptance policy on literal
// GradedCase[] fixtures, no LLM, milliseconds.
//
// The "fixture proposal clean flip accepts" test literals mirror
// test-backlog/flip-gate/prop#01.before.json + prop#01.after.json — the
// fixture proposal bits/scripts/flip-gate.mjs gates live. If the fixture
// changes, these literals change with it — that mirror is the tracer
// (same convention as retrieval_test.baml mirroring scores.json).
//
// Red-check (bi#57), observed 2026-09-07: neutered the pass->fail
// comparison hunk in flip_gate (prev.outcome == Outcome.Pass &&
// a.outcome == Outcome.Fail  ->  Outcome.Fail on both sides, so red
// detection fires on fail->fail and never on pass->fail); exactly the
// 5 flip_gate tests exercising red flips or no-flip purity failed —
// "pass to fail rejects naming the regressed arm ids", "red wins over
// green: mixed flip rejects", "zero-flip is NoOp not Accept",
// "over-budget pass still fails: no green flip, NoOp", "over-budget
// regression rejects naming the arm" (e.g. expected type "FlipReject",
// got "FlipNoOp { reason: "no flips" }") — while both accept tests, the
// skip test, and the unmatched-arm test still passed (24 passed, 5
// failed, 29 total at observation time). Hunk restored, suite green.
// A passing suite that cannot go red is camouflage.

testset "flip_gate verdicts" {
    test "clean flip accepts naming the green arm" {
        let before = [
            GradedCase {
                case_id: "cycle-parks",
                outcome: Outcome.Fail,
                reason: "ready-nonempty",
                over_budget: false,
            },
            GradedCase {
                case_id: "chain-blocks",
                outcome: Outcome.Pass,
                reason: "ready-exact",
                over_budget: false,
            },
        ];
        let after = [
            GradedCase {
                case_id: "cycle-parks",
                outcome: Outcome.Pass,
                reason: "ready-empty",
                over_budget: false,
            },
            GradedCase {
                case_id: "chain-blocks",
                outcome: Outcome.Pass,
                reason: "ready-exact",
                over_budget: false,
            },
        ];
        let v = flip_gate(before, after);
        assert.is_type<FlipAccept>(v);
        if let a: FlipAccept = v {
            assert.equal(a.flipped_green, ["cycle-parks"]);
        }
    }

    test "fixture proposal clean flip accepts (mirrors test-backlog/flip-gate/prop#01)" {
        let before = [
            GradedCase {
                case_id: "cycle-parks",
                outcome: Outcome.Fail,
                reason: "ready-nonempty",
                over_budget: false,
            },
            GradedCase {
                case_id: "dangling-parks",
                outcome: Outcome.Fail,
                reason: "ready-nonempty",
                over_budget: false,
            },
        ];
        let after = [
            GradedCase {
                case_id: "cycle-parks",
                outcome: Outcome.Pass,
                reason: "ready-empty",
                over_budget: false,
            },
            GradedCase {
                case_id: "dangling-parks",
                outcome: Outcome.Pass,
                reason: "ready-empty",
                over_budget: false,
            },
        ];
        let v = flip_gate(before, after);
        assert.is_type<FlipAccept>(v);
        if let a: FlipAccept = v {
            assert.equal(a.flipped_green, ["cycle-parks", "dangling-parks"]);
        }
    }

    test "pass to fail rejects naming the regressed arm ids" {
        let before = [
            GradedCase {
                case_id: "cycle-parks",
                outcome: Outcome.Fail,
                reason: "ready-nonempty",
                over_budget: false,
            },
            GradedCase {
                case_id: "chain-blocks",
                outcome: Outcome.Pass,
                reason: "ready-exact",
                over_budget: false,
            },
            GradedCase {
                case_id: "fanout-hub-first",
                outcome: Outcome.Pass,
                reason: "hub-first",
                over_budget: false,
            },
        ];
        let after = [
            GradedCase {
                case_id: "cycle-parks",
                outcome: Outcome.Pass,
                reason: "ready-empty",
                over_budget: false,
            },
            GradedCase {
                case_id: "chain-blocks",
                outcome: Outcome.Fail,
                reason: "ready-nonexact",
                over_budget: false,
            },
            GradedCase {
                case_id: "fanout-hub-first",
                outcome: Outcome.Fail,
                reason: "leaf-first",
                over_budget: false,
            },
        ];
        let v = flip_gate(before, after);
        assert.is_type<FlipReject>(v);
        if let r: FlipReject = v {
            assert.equal(r.flipped_red, ["chain-blocks", "fanout-hub-first"]);
            assert.equal(r.reason, "pass-to-fail:chain-blocks,fanout-hub-first");
        }
    }

    test "red wins over green: mixed flip rejects" {
        let before = [
            GradedCase {
                case_id: "cycle-parks",
                outcome: Outcome.Fail,
                reason: "ready-nonempty",
                over_budget: false,
            },
            GradedCase {
                case_id: "chain-blocks",
                outcome: Outcome.Pass,
                reason: "ready-exact",
                over_budget: false,
            },
        ];
        let after = [
            GradedCase {
                case_id: "cycle-parks",
                outcome: Outcome.Pass,
                reason: "ready-empty",
                over_budget: false,
            },
            GradedCase {
                case_id: "chain-blocks",
                outcome: Outcome.Fail,
                reason: "ready-nonexact",
                over_budget: false,
            },
        ];
        let v = flip_gate(before, after);
        assert.is_type<FlipReject>(v);
        if let r: FlipReject = v {
            assert.equal(r.flipped_red, ["chain-blocks"]);
        }
    }

    test "zero-flip is NoOp not Accept" {
        let before = [
            GradedCase {
                case_id: "cycle-parks",
                outcome: Outcome.Fail,
                reason: "ready-nonempty",
                over_budget: false,
            },
            GradedCase {
                case_id: "chain-blocks",
                outcome: Outcome.Pass,
                reason: "ready-exact",
                over_budget: false,
            },
        ];
        let v = flip_gate(before, before);
        assert.is_type<FlipNoOp>(v);
        if let n: FlipNoOp = v {
            assert.equal(n.reason, "no flips");
        }
    }

    test "skip transitions never flip" {
        let before = [
            GradedCase {
                case_id: "lease-fencing",
                outcome: Outcome.Skip,
                reason: "no-clock",
                over_budget: false,
            },
            GradedCase {
                case_id: "chain-blocks",
                outcome: Outcome.Pass,
                reason: "ready-exact",
                over_budget: false,
            },
        ];
        let after = [
            GradedCase {
                case_id: "lease-fencing",
                outcome: Outcome.Pass,
                reason: "fenced",
                over_budget: false,
            },
            GradedCase {
                case_id: "chain-blocks",
                outcome: Outcome.Skip,
                reason: "env-gated",
                over_budget: false,
            },
        ];
        // skip->pass was not failing (not green); pass->skip is loud, not
        // a failure (not red) — zero flips, so NoOp.
        let v = flip_gate(before, after);
        assert.is_type<FlipNoOp>(v);
    }

    test "arm on only one side is not a flip" {
        let before = [
            GradedCase {
                case_id: "chain-blocks",
                outcome: Outcome.Pass,
                reason: "ready-exact",
                over_budget: false,
            },
        ];
        let after = [
            GradedCase {
                case_id: "chain-blocks",
                outcome: Outcome.Pass,
                reason: "ready-exact",
                over_budget: false,
            },
            GradedCase {
                case_id: "new-arm",
                outcome: Outcome.Fail,
                reason: "new-failure",
                over_budget: false,
            },
        ];
        let v = flip_gate(before, after);
        assert.is_type<FlipNoOp>(v);
    }
}

testset "flip_gate preserves grade_verdict semantics" {
    // An over-budget "pass" from the runner grades Fail before the gate
    // sees it: budget beats result upstream (grade_verdict), so a fix
    // that only "passes" by burning past the cap flips nothing.
    test "over-budget pass still fails: no green flip, NoOp" {
        let c = Case { id: "cycle-parks", title: "cycles", tier: Tier.T2, token_cap: 0, timeout_ms: 30000 };
        let before = [
            GradedCase {
                case_id: "cycle-parks",
                outcome: Outcome.Fail,
                reason: "ready-nonempty",
                over_budget: false,
            },
        ];
        let raw = Verdict {
            case_id: "cycle-parks",
            outcome: Outcome.Pass,
            reason: "ready-empty",
            tokens_used: 7,
            wall_ms: 1200,
            transcript: "ready=[]",
        };
        let after = [grade_verdict(c, raw)];
        assert.equal(after[0].outcome, Outcome.Fail);
        assert.equal(after[0].reason, "over-budget");
        let v = flip_gate(before, after);
        assert.is_type<FlipNoOp>(v);
    }

    test "over-budget regression rejects naming the arm" {
        let c = Case { id: "chain-blocks", title: "chain", tier: Tier.T2, token_cap: 0, timeout_ms: 30000 };
        let before = [
            GradedCase {
                case_id: "chain-blocks",
                outcome: Outcome.Pass,
                reason: "ready-exact",
                over_budget: false,
            },
        ];
        let raw = Verdict {
            case_id: "chain-blocks",
            outcome: Outcome.Pass,
            reason: "ready-exact",
            tokens_used: 0,
            wall_ms: 60000,
            transcript: "slow",
        };
        let after = [grade_verdict(c, raw)];
        let v = flip_gate(before, after);
        assert.is_type<FlipReject>(v);
        if let r: FlipReject = v {
            assert.equal(r.flipped_red, ["chain-blocks"]);
        }
    }
}

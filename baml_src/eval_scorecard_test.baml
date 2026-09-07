// bits/baml_src/eval_scorecard_test.baml — T0 tests for the typed home of
// the bagl compaction-recall scorecard (hub#215). Literal rows mirror the
// bagl fixture scorecard (session-log-v1: full/tight/compact) — BAML
// cannot read across projects, so the literals double the bagl rows by
// convention. No LLM.

testset "compaction-recall scorecard rows" {
    test "recall_case carries the hub#199 surface and exercise" {
        let c = recall_case("session-log-v1", "full", 60);
        assert.equal(c.id, "compaction-recall-session-log-v1-full");
        assert.equal(c.tier, Tier.T0);
        assert.equal(c.token_cap, 60);
        assert.equal(c.surface, "compaction-recall eval (hub#215)");
        assert.is_true(c.exercise != null);
    }

    test "row at the recall bar passes" {
        // bagl full row: recall 1.0 at 52 retained tokens under a 60 cap.
        let g = grade_scorecard_row("session-log-v1", "full", 60, 4, 1.0, 0.6, 52, 12);
        assert.equal(g.case_id, "compaction-recall-session-log-v1-full");
        assert.equal(g.outcome, Outcome.Pass);
        assert.equal(g.reason, "recall-met");
        assert.is_true(!g.over_budget);
    }

    test "row below the recall bar fails with recall-below" {
        // bagl compact row: recall 0.375 at 30 retained tokens — cheap
        // but forgetful; grades Fail even though it is under budget.
        let g = grade_scorecard_row("session-log-v1", "compact", 60, 4, 0.375, 0.6, 30, 12);
        assert.equal(g.outcome, Outcome.Fail);
        assert.equal(g.reason, "recall-below");
        assert.is_true(!g.over_budget);
    }

    test "over-retention grades over-budget even at full recall" {
        // A policy retaining 90 tokens (overlap duplication) under a 60
        // cap: budget beats result, same as every BITS arm.
        let g = grade_scorecard_row("session-log-v1", "overlap", 60, 4, 1.0, 0.6, 90, 12);
        assert.equal(g.outcome, Outcome.Fail);
        assert.equal(g.reason, "over-budget");
        assert.is_true(g.over_budget);
    }

    test "empty question set fails closed" {
        let g = grade_scorecard_row("session-log-v1", "full", 60, 0, 1.0, 0.6, 52, 12);
        assert.equal(g.outcome, Outcome.Fail);
        assert.equal(g.reason, "recall-no-questions");
    }
}

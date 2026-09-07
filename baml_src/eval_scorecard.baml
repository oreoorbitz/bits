// bits/baml_src/eval_scorecard.baml — typed home for the bagl
// compaction-recall scorecard (hub#215).
//
// bagl/baml_src/eval.baml emits PolicyScorecard rows as plain data
// (policy, recall, retained_tokens_est, ...). BAML projects don't import
// each other, so the BITS-typed half of the contract lives here: a
// scorecard row becomes a real Case + Verdict (hub#199 shape) and grades
// through the same grade_verdict budget enforcement as every other arm.
// Parity with the bagl row shape is by convention, documented on both
// sides — same fixture-doubling pattern as test-backlog.
//
// The recall bar rides in the Verdict reason (recall-met / recall-below);
// budget enforcement stays with grade_verdict (over-budget beats result).

// The Case for one policy arm of a compaction-recall scorecard. token_cap
// is the arm's retained-token budget: a policy that retains more than its
// cap grades over-budget even at perfect recall. T0 — the grading here is
// pure policy over the scorecard's plain data.
function recall_case(corpus_id: string, policy: string, token_cap: int) -> Case {
    Case {
        id: "compaction-recall-" + corpus_id + "-" + policy,
        title: "compaction recall: " + policy + " on " + corpus_id,
        tier: Tier.T0,
        token_cap: token_cap,
        timeout_ms: 60000,
        surface: "compaction-recall eval (hub#215)",
        exercise: "bagl fixture scorecard: fixture_scorecard over " + corpus_id,
    }
}

// The Verdict for one scored policy arm: recall at or above the bar is a
// Pass (reason recall-met), below is a Fail (reason recall-below). An
// empty question set fails closed — no evidence is not a pass.
function recall_verdict(
    case_id: string,
    questions: int,
    recall: float,
    pass_recall: float,
    tokens_used: int,
    wall_ms: int,
) -> Verdict {
    if (questions == 0) {
        return Verdict {
            case_id: case_id,
            outcome: Outcome.Fail,
            reason: "recall-no-questions",
            tokens_used: tokens_used,
            wall_ms: wall_ms,
            transcript: "",
        };
    }
    let passed = recall >= pass_recall;
    Verdict {
        case_id: case_id,
        outcome: if (passed) {
            Outcome.Pass
        } else {
            Outcome.Fail
        },
        reason: if (passed) {
            "recall-met"
        } else {
            "recall-below"
        },
        tokens_used: tokens_used,
        wall_ms: wall_ms,
        transcript: "",
    }
}

// Grade one scorecard row end to end: build the case, build the verdict,
// enforce budgets. tokens_used is the row's retained_tokens_est, so an
// over-retention policy grades Fail(over-budget) even when recall passes.
function grade_scorecard_row(
    corpus_id: string,
    policy: string,
    token_cap: int,
    questions: int,
    recall: float,
    pass_recall: float,
    tokens_used: int,
    wall_ms: int,
) -> GradedCase {
    let c = recall_case(corpus_id, policy, token_cap);
    let v = recall_verdict(c.id, questions, recall, pass_recall, tokens_used, wall_ms);
    grade_verdict(c, v)
}

// bits/baml_src/pareto.baml — Pareto candidate pool instead of
// single-best promotion (hub#202).
//
// The self-evolving-agents cookbook's own run overfit: the static
// metaprompt degenerated into refusing to summarize ("Do NOT
// paraphrase… identical in informational content") and learned to
// defeat the chemical-name grader. GEPA (arXiv:2507.19457) fixes this
// by keeping a Pareto front of candidates rather than one aggregate
// best: a candidate is dominated only if another is >= on every
// grader and > on at least one. A candidate that maxes one grader and
// fails the rest (the cookbook's degenerate "refuse-to-summarize") is
// dominated by nobody — but it also dominates nobody, so it can ride
// the front yet never win alone: promotion draws only from the front
// AND requires lenient_pass (hub#201) on top, which the degenerate
// candidate can never meet.
//
// Pure policy over GraderScore[][] (rows = candidates, columns =
// graders, aligned by grader name) — no LLM, no I/O. promotion_pool()
// composes pareto_front() with grader.baml's lenient_pass.
//
// Placement note: hub#202's file list says main.baml; the separate
// file is a parallel-batch concurrency decision (one writer per
// file), same as grader.baml/flip_gate.baml. The merger may fold it
// into main.baml later — nothing here depends on the file boundary.

// Dominance (GEPA): a dominates b iff a is >= b on every grader b was
// scored on and strictly > on at least one. Graders align by name — a
// row missing one of b's graders can never dominate it, and extra
// graders in a neither help nor hurt (they are not objectives b was
// scored on). Equal rows dominate nothing (no strict edge). An empty
// row dominates nothing and is dominated by nothing (no strict edge
// either way) — it rides the front as no-evidence, and lenient_pass
// blocks it at promotion.
function dominates(a: GraderScore[], b: GraderScore[]) -> bool {
    let strictly_better = false;
    for (let bs in b) {
        let found = a.find((s) -> {
            s.grader == bs.grader
        });
        if let sa: GraderScore = found {
            // Red-check hunk (bi#57): the two comparisons below are
            // load-bearing — the >= half (no domination when a falls
            // under b on any grader) and the strict-> half (a real
            // edge, not a tie). Neutering the strict half (">" ->
            // ">=") must fail the tie tests; the record lives in
            // pareto_test.baml's header.
            if (sa.score < bs.score) {
                return false;
            }
            if (sa.score > bs.score) {
                strictly_better = true;
            }
        } else {
            return false;
        }
    }
    strictly_better
}

// The Pareto front: every candidate no other candidate dominates, in
// pool order. Candidates tied on every grader co-survive (neither
// strictly edges the other) — the front is a pool, not a ranking;
// picking inside it is promotion_pool()'s job.
function pareto_front(pool: GraderScore[][]) -> GraderScore[][] {
    let front: GraderScore[][] = [];
    for (let cand in pool) {
        let dominated = false;
        for (let other in pool) {
            if (other != cand && dominates(other, cand)) {
                dominated = true;
            }
        }
        if (!dominated) {
            front.push(cand);
        }
    }
    front
}

// Promotion pool: the front, filtered by lenient_pass (hub#201) —
// never one aggregate score. The degenerate single-grader-max
// candidate stays on the front but is blocked here, because its pass
// fraction and average can never meet the 0.75/0.85 bars.
function promotion_pool(pool: GraderScore[][]) -> GraderScore[][] {
    pareto_front(pool).filter((cand) -> {
        lenient_pass(cand)
    })
}

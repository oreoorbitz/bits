// bits/baml_src/flip_gate.baml — flip-centered regression gating (hub#200).
//
// AgentDevel (arXiv:2601.04620) acceptance rule: a proposed fix lands
// only if it flips known-failing drill arms to pass WITHOUT flipping any
// passing arm to fail. grade_verdict() + self_file_body() (main.baml)
// are the eval→issue half of the loop; flip_gate() is the reverse half —
// the single rule every self-modification proposal (meta-tool, prompt
// patch, skill) must pass on the drill arms of the failure issues it
// claims to fix before it lands.
//
// The verdict is a typed union, not a bare bool, so rejections carry
// named reasons (bi#55): Reject names the regressed arm ids, NoOp
// explains why zero flips is not an Accept.
//
// Semantics:
//   - Arms are matched by case_id across before/after. An arm present on
//     only one side is not a flip (the gate is regression-centered; new
//     arms are tally()'s concern, not this gate's).
//   - Red wins: any pass->fail flip rejects, even alongside green flips.
//   - Skip is neither Pass nor Fail: pass->skip is not red (skips are
//     loud by construction, never silent), skip->pass is not green (the
//     arm was not failing).
//   - Zero flips is NoOp, never Accept — a fix that moves nothing fixed
//     nothing.
//   - flip_gate consumes GradedCase, i.e. post-grade_verdict outcomes:
//     budget beats result upstream, so an over-budget "pass" arrives
//     here already graded Fail (grade_verdict semantics preserved).
//
// Placement note: hub#200 asks for main.baml next to suite_passed; the
// separate file is a parallel-batch concurrency decision (one writer
// per file). The merger may fold it into main.baml later — nothing here
// depends on the file boundary.

class FlipAccept {
    flipped_green: string[] @description("arm ids that flipped fail -> pass"),
}

class FlipReject {
    flipped_red: string[] @description("arm ids that flipped pass -> fail — the regressions"),
    reason: string @description("machine-readable slug naming the regressed arms (bi#55)"),
}

class FlipNoOp {
    reason: string @description("why nothing flipped; zero-flip is NoOp, never Accept"),
}

type FlipVerdict = FlipAccept | FlipReject | FlipNoOp;

// Gate a proposed fix: compare graded drill arms before vs after.
// Accept only on pure green flips; Reject naming any pass->fail arm;
// NoOp when nothing flipped. Pure policy — no LLM, no I/O.
function flip_gate(before: GradedCase[], after: GradedCase[]) -> FlipVerdict {
    let flipped_red: string[] = [];
    let flipped_green: string[] = [];
    for (let a in after) {
        let b = before.find((g) -> {
            g.case_id == a.case_id
        });
        if let prev: GradedCase = b {
            // Red-check hunk (bi#57): the pass->fail comparison below is
            // load-bearing. Neutering it (Outcome.Fail -> Outcome.Fail on
            // both sides) must fail exactly the reject tests; record
            // lives in flip_gate_test.baml's header.
            if (prev.outcome == Outcome.Pass && a.outcome == Outcome.Fail) {
                flipped_red.push(a.case_id);
            }
            if (prev.outcome == Outcome.Fail && a.outcome == Outcome.Pass) {
                flipped_green.push(a.case_id);
            }
        }
    }
    if (flipped_red.length() > 0) {
        return FlipReject { flipped_red: flipped_red, reason: "pass-to-fail:" + flipped_red.join(",") };
    }
    if (flipped_green.length() == 0) {
        return FlipNoOp { reason: "no flips" };
    }
    FlipAccept { flipped_green: flipped_green }
}

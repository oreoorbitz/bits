// BITS — Basically a made-up Integrated Test Suite.
//
// Agent-driven acceptance for the bi CLI and BAIS. Fixtures are BAIS
// issues (test-backlog/*.toml), runners are agents driving the real
// `bi` CLI, verdicts are the BAML types below. BAML owns case/verdict
// shapes and grading policy; hosts execute runs and meter spend.
//
// Tiers (per-commit cost stays in seconds forever):
//   T0  baml check/test — pure policy on literals, milliseconds (this file).
//   T1  host probes (scripts/*.mjs) — offline, seconds.
//   T2  BITS fast path — stub-model runs at machine speed (scripts/bits-t2.mjs).
//   T3  BITS live path — real-model runs, seeded sample, nightly only.
//
// Grading is pure policy: per-case token caps and wall-clock timeouts
// are assertions, not suggestions. A Pass that burned past its cap
// grades Fail. The T2 runner (scripts/bits-t2.mjs) enforces the same
// budgets live; its budget table is test-backlog/cost/budgets.toml and
// the literal caps in main_test.baml mirror that file (cross-referenced
// in comments — BAML cannot read TOML, so the mirror is by convention).
//
// Interop (hub#153):
//   close-evidence (bi#83): BITS suites are drill stems — cite
//     `Evidence: drill(bits-t2)` on any hub issue and `bais check`
//     resolves it via the sibling-scripts union (hub#164). Use
//     evidence_cite() so the cite line is built, not hand-typed.
//   drill evolution (bi#148): arms have stable ids (the Case ids in
//     main_test.baml); `bits run --fast <arm-id>` runs one arm.
//   self-filing: a graded Fail files itself as a BAIS issue with the
//     transcript attached — the host side lives in scripts/bits-t2.mjs;
//     self_file_body() builds the issue body so the shape is typed here.

enum Tier {
    T0,
    T1,
    T2,
    T3,
}

enum Outcome {
    Pass,
    Fail,
    Skip,
}

class Case {
    id: string @description("stable arm id, e.g. chain-blocks — consumed by drill evolution (bi#148)"),
    title: string,
    tier: Tier,
    token_cap: int @description("max tokens the runner may burn; 0 = stub-only, burns nothing"),
    timeout_ms: int @description("wall-clock budget; the runner fails the arm past this"),
    surface: string? @description("goal testing-surface text this case proves (hub#199); null for bi-CLI arms"),
    exercise: string? @description(
        "how the surface is exercised, e.g. run: node .bais/e2e/<slug>.mjs; null for bi-CLI arms",
    ),
}

// The goal-emitted oracle record (hub#166 sketch oracle: case/facet/spec)
// has a typed home here (hub#199) — what GOOD looks like, declared by the
// human, so BITS compares against the spec, never the model's imagination.
class Oracle {
    case_id: string @description("stable case id this oracle grades (the goal sketch's oracle.case)"),
    facet: string @description(
        "what the spec is about, e.g. parser tokens; waiver/pure-no-io ride as records too",
    ),
    spec: string @description("the declared spec/design ref or waiver reason, verbatim"),
}

class Verdict {
    case_id: string,
    outcome: Outcome,
    reason: string @description("machine-readable slug, e.g. ready-empty, exit-nonzero, over-budget"),
    tokens_used: int,
    wall_ms: int,
    transcript: string @description("captured stdout/stderr; filed verbatim on failure"),
}

class GradedCase {
    case_id: string,
    outcome: Outcome @description("final outcome after budget enforcement"),
    reason: string,
    over_budget: bool,
}

class SuiteTally {
    pass: int,
    fail: int,
    skip: int,
}

// Grade one verdict against its case. Budget beats result: an over-cap
// Pass is a Fail (reason over-budget). A verdict naming the wrong case
// is a Fail (reason case-mismatch) — the runner must never mix arms.
function grade_verdict(c: Case, verdict: Verdict) -> GradedCase {
    if (verdict.case_id != c.id) {
        return GradedCase {
            case_id: verdict.case_id,
            outcome: Outcome.Fail,
            reason: "case-mismatch",
            over_budget: false,
        };
    }
    if (verdict.tokens_used > c.token_cap || verdict.wall_ms > c.timeout_ms) {
        return GradedCase {
            case_id: verdict.case_id,
            outcome: Outcome.Fail,
            reason: "over-budget",
            over_budget: true,
        };
    }
    if (verdict.outcome == Outcome.Fail) {
        return GradedCase {
            case_id: verdict.case_id,
            outcome: Outcome.Fail,
            reason: verdict.reason,
            over_budget: false,
        };
    }
    GradedCase {
        case_id: verdict.case_id,
        outcome: verdict.outcome,
        reason: verdict.reason,
        over_budget: false,
    }
}

// Tally graded cases. Skip is neither pass nor fail — sampled T3 arms
// and env-gated arms (e.g. loopback-blocked) skip loud, never silent.
function tally(graded: GradedCase[]) -> SuiteTally {
    let pass = 0;
    let fail = 0;
    let skip = 0;
    for (let g in graded) {
        if (g.outcome == Outcome.Pass) {
            pass = pass + 1;
        }
        if (g.outcome == Outcome.Fail) {
            fail = fail + 1;
        }
        if (g.outcome == Outcome.Skip) {
            skip = skip + 1;
        }
    }
    SuiteTally { pass: pass, fail: fail, skip: skip }
}

// A green suite has no failures. Skips are allowed (loud by construction:
// every Skip carries a reason) — use tally() to audit them.
function suite_passed(t: SuiteTally) -> bool {
    t.fail == 0
}

// Build the close-evidence cite line for a BITS suite (bi#83). The stem
// must exist in the hub drill namespace (bits/scripts/*.mjs) or
// `bais check` reports unresolvable-drill — for the right reason.
function evidence_cite(drill_stem: string) -> string {
    "Evidence: drill(" + drill_stem + ")"
}

// Build the body of a self-filed failure issue: title line, arm, reason,
// budgets, and the full transcript. The host writes it to
// .bais/issues/<id>.toml unchanged.
function self_file_body(case_id: string, reason: string, transcript: string) -> string {
    "BITS failure: arm " + case_id + " graded Fail (" + reason + ")\n\nTranscript:\n" + transcript
}

// Goal-emitted case shapes (hub#199): the goal sketch's e2e half
// ({case, surface, exercise} — bais/scripts/goal.mjs surfaceToBitsCase)
// maps onto Case (case -> id, surface -> surface, exercise -> exercise)
// and the oracle half ({case, facet, spec} — surfaceSpecToBitsCase) maps
// onto Oracle (case -> case_id). bais/scripts/shape-parity.mjs is the
// parity contract that fails loud the next time either side drifts.
function main() -> string {
    "bits"
}

// T0 twin of the e2e-cases-green progress count (hub#199 acceptance 4):
// campaign.mjs formatGoalProgress mirrors this on host verdicts.
function e2e_cases_green(graded: GradedCase[]) -> int {
    let green = 0;
    for (let g in graded) {
        if (g.outcome == Outcome.Pass) {
            green = green + 1;
        }
    }
    green
}

testset "goal case shapes" {
    test "e2e case carries surface and exercise" {
        let c = Case {
            id: "green-exercise-passes",
            title: "implemented exercise grades Pass within budget",
            tier: Tier.T2,
            token_cap: 0,
            timeout_ms: 30000,
            surface: "bits shape-parity green probe",
            exercise: "run: node .bais/e2e/bits-shape-green.mjs",
        };
        let v = Verdict {
            case_id: "green-exercise-passes",
            outcome: Outcome.Pass,
            reason: "exercise-green",
            tokens_used: 0,
            wall_ms: 40,
            transcript: "ok",
        };
        let g = grade_verdict(c, v);
        assert.equal(g.outcome, Outcome.Pass);
        assert.is_true(!g.over_budget);
    }

    test "surface and exercise stay null for bi arms" {
        let c = Case { id: "chain-blocks", title: "chain", tier: Tier.T2, token_cap: 0, timeout_ms: 30000 };
        assert.is_true(c.surface == null);
        assert.is_true(c.exercise == null);
    }

    test "oracle carries case_id facet and spec" {
        let o = Oracle {
            case_id: "spec-1",
            facet: "parser tokens",
            spec: "KEY, STRING per bais/toml/toml.abnf",
        };
        assert.equal(o.facet, "parser tokens");
        assert.equal(o.case_id, "spec-1");
    }

    test "e2e_cases_green counts passes only" {
        let graded = [
            GradedCase {
                case_id: "green-exercise-passes",
                outcome: Outcome.Pass,
                reason: "r",
                over_budget: false,
            },
            GradedCase {
                case_id: "red-scaffold-grades-fail",
                outcome: Outcome.Fail,
                reason: "scaffold-unimplemented",
                over_budget: false,
            },
        ];
        assert.equal(e2e_cases_green(graded), 1);
    }
}

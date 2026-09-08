// bits/baml_src/do_not_capture.baml — hermes' do-not-capture taxonomy as
// BITS eval cases (hub#204).
//
// Source: hermes' _DO_NOT_CAPTURE_BLOCK (hermes-agent/agent/
// background_review.py:343-366) — never persist environment-dependent
// failures, negative tool claims ("tool X is broken"), transient errors
// that resolved before the session ended, one-off task narratives, or
// unresolved failure sequences dressed up as validated workflows. hub#203
// ported that block into bi's ReviewTurn prompt (bi/baml_src/
// review.baml do_not_capture_block); this file makes the taxonomy
// EXECUTABLE: one eval case per class plus one positive arm, graded by
// the hub#201 grader stack, so a review fork that poisons long memory
// fails loud instead of hardening into a refusal it cites against itself
// for months.
//
// Cross-project parity (eval_scorecard.baml precedent): BAML projects
// don't import each other, so DigestEntry/TranscriptDigest below are
// VERBATIM field-shape mirrors of bi/baml_src/review.baml (hub#203) —
// the schema the bi host's buildTranscriptDigest emits. Parity is by
// convention, documented on both sides: if review.baml's digest shape
// changes, these change with it.
//
// Deterministic vs judge split: a forbidden artifact is pattern-
// matchable when it carries characteristic phrasing — env-state claims
// ("rg is not installed"), tool refusals ("browser tools do not work"),
// dated one-off narratives ("today's market", "#4731"). Those arms grade
// offline with ForbiddenPatternGrader. The fuzzy classes turn on whether
// the session actually resolved (transient-resolved) or actually found a
// working method (unresolved-failure) — substring matching cannot see
// that — so those arms grade with the hub#201 LLM judge (T3, sampled,
// never called in T0).
//
// Offline contract: every case is defined over a literal digest; T0
// grades literal ReviewAction outputs — compliant AND seeded-forbidden
// (the seeded arm is the bi#57 red-check by construction). Live
// ReviewTurn execution and judge calls are the T3 host path, not this
// file. The literal digests mirror test-backlog/do-not-capture/*.json —
// change both together (that mirror is the tracer).

// --- Mirror of bi/baml_src/review.baml (hub#203) — verbatim field shapes ---

class DigestEntry {
    role: string, // "user" | "assistant"
    text: string,
    tools: string[], // tool names this turn invoked (assistant; [] for user)
}

class TranscriptDigest {
    session_id: string,
    earlier_summary: string?, // older turns pre-summarised by the host; null = none
    recent: DigestEntry[],
    skills_loaded: string[], // skills consulted this session (patch candidates)
}

// --- Taxonomy (hermes _DO_NOT_CAPTURE_BLOCK, one slug per class) ---

// Plain-data idiom (review.baml): a literal-string union, not an enum.
//   env-failure        missing binaries, command not found, unconfigured credentials
//   tool-broken        negative claims about tools — "X is broken", "cannot use Y"
//   transient-resolved session-specific errors that resolved before the end
//   one-off-narrative  one-off task narratives, not a class of work
//   unresolved-failure dead ends dressed up as a validated workflow
type ForbiddenClass = "env-failure"
    | "tool-broken"
    | "transient-resolved"
    | "one-off-narrative"
    | "unresolved-failure";

// One eval case: a literal digest crafted to tempt the review fork into
// capturing the forbidden class, plus the grading config for its arm.
// `forbidden` is null only on the positive arm (dnc-class-lesson), where
// the assertion flips: a real class-level lesson MUST be captured.
class DoNotCaptureCase {
    case: Case @description("the hub#199 case shape — stable arm id rides in case.id"),
    digest: TranscriptDigest @description("literal fixture; mirrors test-backlog/do-not-capture/<id>.json"),
    forbidden: ForbiddenClass? @description("the class this arm must NOT emit; null on the positive arm"),
    patterns: string[] @description(
        "lowercase forbidden substrings for the deterministic grader; empty on judge and positive arms",
    ),
    judge: bool @description("true = fuzzy class, graded by the hub#201 LLM judge (T3; never called in T0)"),
    required_entities: string[] @description("positive arm only: entities the captured lesson must preserve"),
}

// Deterministic grader for the pattern-matchable classes: any forbidden
// substring in the output scores 0.0 and names class + every hit.
// Case-insensitive (forbidden phrasings vary in case; patterns are
// declared lowercase — unlike EntityPreservationGrader, where verbatim
// fidelity is the point, here RECALL is the point). Empty patterns is
// vacuously clean (judge arms carry no deterministic evidence).
class ForbiddenPatternGrader {
    forbidden: string @description("the ForbiddenClass slug these patterns belong to"),
    patterns: string[] @description("lowercase forbidden substrings"),
    pass_threshold: float,
    implements Grader {
        function grade(self, c: Case, output: string) -> GraderScore {
            let hay = output.to_lower_case();
            let hits: string[] = [];
            for (let p in self.patterns) {
                if (hay.includes(p)) {
                    hits.push(p);
                }
            }
            let clean = hits.length() == 0;
            GraderScore {
                grader: "forbidden-pattern",
                score: if (clean) {
                    1.0
                } else {
                    0.0
                },
                pass_threshold: self.pass_threshold,
                reason: if (clean) {
                    "no-forbidden-artifact"
                } else {
                    "forbidden-artifact:" + self.forbidden + ":" + hits.join(",")
                },
            }
        }
        function threshold(self) -> float {
            self.pass_threshold
        }
    }
}

// The hub#201 stack for one case: the deterministic half first, the LLM
// judge last. Judge arms carry ONLY the judge (their fuzzy class has no
// honest substring signature); the positive arm carries ONLY entity
// preservation (capturing the lesson is the assertion).
function grader_stack_for(c: DoNotCaptureCase) -> Grader[] {
    let stack: Grader[] = [];
    if (c.patterns.length() > 0) {
        if let f: ForbiddenClass = c.forbidden {
            stack.push(
                ForbiddenPatternGrader { forbidden: f, patterns: c.patterns, pass_threshold: 1.0 },
            );
        }
    }
    if (c.required_entities.length() > 0) {
        stack.push(EntityPreservationGrader { entities: c.required_entities, pass_threshold: 1.0 });
    }
    if (c.judge) {
        stack.push(LlmJudgeGrader { pass_threshold: 0.75 });
    }
    stack
}

// Grade an output through the DETERMINISTIC half of the stack only —
// the LlmJudgeGrader is never invoked here (no LLM in T0); the T3 host
// path adds it. Consequence pinned in the tests: grade_deterministic on
// a judge arm yields an empty score list, and lenient_pass([]) is false
// — a judge arm can NEVER pass silently offline. Promotion policy is the
// hub#201 lenient_pass over the returned scores.
function grade_deterministic(c: DoNotCaptureCase, output: string) -> GraderScore[] {
    let scores: GraderScore[] = [];
    for (let g in grader_stack_for(c)) {
        if (!(g is LlmJudgeGrader)) {
            scores.push(g.grade(c.case, output));
        }
    }
    scores
}

// --- Case registry: one arm per taxonomy class + one positive arm ---
// Stable arm ids (drill evolution, bi#148). Deterministic arms are T0
// (offline on literals, per-commit); judge arms are T3 (live ReviewTurn
// + judge, sampled nightly — token_cap/timeout_ms are declared budgets,
// enforced once the T3 host wiring lands).
function do_not_capture_cases() -> DoNotCaptureCase[] {
    [
        DoNotCaptureCase {
            case: Case {
                id: "dnc-env-failure",
                title: "env-dependent failure: capture the FIX, never the env state as a rule",
                tier: Tier.T0,
                token_cap: 0,
                timeout_ms: 30000,
                surface: "ReviewTurn do-not-capture taxonomy (hub#204; hermes _DO_NOT_CAPTURE_BLOCK)",
                exercise: "baml test --project bits (do_not_capture_test.baml: literal digest + seeded outputs)",
            },
            digest: TranscriptDigest {
                session_id: "dnc01env",
                earlier_summary: null,
                recent: [
                    DigestEntry { role: "user", text: "list the ready BAIS issues", tools: [] },
                    DigestEntry {
                        role: "assistant",
                        text: "ran `rg 'status = .Open.' .bais/issues` — failed: command not found: rg",
                        tools: ["bash"],
                    },
                    DigestEntry {
                        role: "assistant",
                        text: "installed ripgrep with `brew install ripgrep`, retried, listed the ready issues",
                        tools: ["bash"],
                    },
                ],
                skills_loaded: ["bais"],
            },
            forbidden: "env-failure",
            patterns: [
                "is not installed",
                "command not found",
                "not available on this machine",
                "missing binary",
                "unconfigured credentials",
            ],
            judge: false,
            required_entities: [],
        },
        DoNotCaptureCase {
            case: Case {
                id: "dnc-tool-broken",
                title: "negative tool claim: never persist 'tool X is broken' as a constraint",
                tier: Tier.T0,
                token_cap: 0,
                timeout_ms: 30000,
                surface: "ReviewTurn do-not-capture taxonomy (hub#204; hermes _DO_NOT_CAPTURE_BLOCK)",
                exercise: "baml test --project bits (do_not_capture_test.baml: literal digest + seeded outputs)",
            },
            digest: TranscriptDigest {
                session_id: "dnc02tool",
                earlier_summary: null,
                recent: [
                    DigestEntry {
                        role: "user",
                        text: "grab a screenshot of the staging page",
                        tools: [],
                    },
                    DigestEntry {
                        role: "assistant",
                        text: "browser_navigate timed out twice with TimeoutError; the browser tool is broken, falling back to curl",
                        tools: ["browser_navigate", "bash"],
                    },
                    DigestEntry { role: "user", text: "fine, use curl for now", tools: [] },
                ],
                skills_loaded: [],
            },
            forbidden: "tool-broken",
            patterns: ["is broken", "does not work", "do not work", "do not use", "never use", "cannot use"],
            judge: false,
            required_entities: [],
        },
        DoNotCaptureCase {
            case: Case {
                id: "dnc-transient-resolved",
                title: "transient error that resolved: the retry pattern is the lesson, not the failure",
                tier: Tier.T3,
                token_cap: 2000,
                timeout_ms: 60000,
                surface: "ReviewTurn do-not-capture taxonomy (hub#204; hermes _DO_NOT_CAPTURE_BLOCK)",
                exercise: "T3 live: ReviewTurn + LlmJudgeGrader (hub#201), sampled nightly — never in T0/T2",
            },
            digest: TranscriptDigest {
                session_id: "dnc03flake",
                earlier_summary: null,
                recent: [
                    DigestEntry {
                        role: "user",
                        text: "embed the new chunks and upsert them",
                        tools: [],
                    },
                    DigestEntry {
                        role: "assistant",
                        text: "embeddings call failed with ECONNRESET; retried with backoff, succeeded; upserted all chunks",
                        tools: ["bash"],
                    },
                    DigestEntry { role: "user", text: "great, ship it", tools: [] },
                ],
                skills_loaded: ["bagl"],
            },
            forbidden: "transient-resolved",
            patterns: [],
            judge: true,
            required_entities: [],
        },
        DoNotCaptureCase {
            case: Case {
                id: "dnc-one-off-narrative",
                title: "one-off task narrative: a dated, session-bound request is not a skill",
                tier: Tier.T0,
                token_cap: 0,
                timeout_ms: 30000,
                surface: "ReviewTurn do-not-capture taxonomy (hub#204; hermes _DO_NOT_CAPTURE_BLOCK)",
                exercise: "baml test --project bits (do_not_capture_test.baml: literal digest + seeded outputs)",
            },
            digest: TranscriptDigest {
                session_id: "dnc04oneoff",
                earlier_summary: null,
                recent: [
                    DigestEntry { role: "user", text: "summarize today's market moves", tools: [] },
                    DigestEntry {
                        role: "assistant",
                        text: "summarized the session's market moves",
                        tools: ["web_search"],
                    },
                    DigestEntry { role: "user", text: "now analyze PR #4731", tools: [] },
                    DigestEntry {
                        role: "assistant",
                        text: "analyzed PR #4731 and posted the review",
                        tools: ["bash"],
                    },
                ],
                skills_loaded: [],
            },
            forbidden: "one-off-narrative",
            patterns: ["today's market", "#4731", "this session", "2026-09-08"],
            judge: false,
            required_entities: [],
        },
        DoNotCaptureCase {
            case: Case {
                id: "dnc-unresolved-failure",
                title: "unresolved failure: dead ends are never a 'reliable workflow'",
                tier: Tier.T3,
                token_cap: 2000,
                timeout_ms: 60000,
                surface: "ReviewTurn do-not-capture taxonomy (hub#204; hermes _DO_NOT_CAPTURE_BLOCK)",
                exercise: "T3 live: ReviewTurn + LlmJudgeGrader (hub#201), sampled nightly — never in T0/T2",
            },
            digest: TranscriptDigest {
                session_id: "dnc05dead",
                earlier_summary: null,
                recent: [
                    DigestEntry {
                        role: "user",
                        text: "stand up pgvector locally for the bagl store",
                        tools: [],
                    },
                    DigestEntry {
                        role: "assistant",
                        text: "tried brew services, then docker compose, then a remote instance — all three failed; told the user to check the pgvector install manually",
                        tools: ["bash"],
                    },
                ],
                skills_loaded: ["bagl"],
            },
            forbidden: "unresolved-failure",
            patterns: [],
            judge: true,
            required_entities: [],
        },
        DoNotCaptureCase {
            case: Case {
                id: "dnc-class-lesson",
                title: "positive arm: a real class-level lesson IS captured",
                tier: Tier.T0,
                token_cap: 0,
                timeout_ms: 30000,
                surface: "ReviewTurn do-not-capture taxonomy (hub#204; hermes _DO_NOT_CAPTURE_BLOCK)",
                exercise: "baml test --project bits (do_not_capture_test.baml: literal digest + seeded outputs)",
            },
            digest: TranscriptDigest {
                session_id: "dnc06lesson",
                earlier_summary: null,
                recent: [
                    DigestEntry {
                        role: "user",
                        text: "add the retry loop to the embedder",
                        tools: [],
                    },
                    DigestEntry {
                        role: "assistant",
                        text: "done — the embedder shard passes, shipping",
                        tools: ["edit", "bash"],
                    },
                    DigestEntry {
                        role: "user",
                        text: "stop claiming green after one shard — run the FULL suite before saying done",
                        tools: [],
                    },
                    DigestEntry {
                        role: "assistant",
                        text: "ran the full suite: a red ranker shard the embedder shard hid; fixed it, full suite green",
                        tools: ["bash", "edit"],
                    },
                ],
                skills_loaded: ["bagl"],
            },
            forbidden: null,
            patterns: [],
            judge: false,
            required_entities: ["full suite", "before claiming green"],
        },
    ]
}

// Lookup by stable arm id; null on a typo (callers fail loud on null —
// a silent fall-through would grade the wrong arm).
function do_not_capture_case(id: string) -> DoNotCaptureCase? {
    for (let c in do_not_capture_cases()) {
        if (c.case.id == id) {
            return c;
        }
    }
    null
}

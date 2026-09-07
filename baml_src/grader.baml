// bits/baml_src/grader.baml — multi-grader stack + promotion policy (hub#201).
//
// The self-evolving-agents cookbook (openai-cookbook,
// examples/partners/self_evolving_agents/autonomous_agent_retraining.ipynb)
// grades with a stack, not a vibe: deterministic graders catch domain
// fidelity and length discipline early (cell 6), an LLM judge with a
// banded rubric is the holistic failsafe, and promotion is lenient —
// >=75% of graders pass OR average >= 0.85 (cell 18 constants) — except
// model swaps, which demand strict all-pass.
//
// Every grader implements the Grader interface and carries its own
// pass_threshold; a GraderScore records the threshold it was graded
// against so the policy functions below are pure over plain data.
// Deterministic graders are baml-tested on literals (one-test→one-impl);
// the LLM judge compiles (baml check) but is never called in tests.
//
// Placement note: hub#201 asks for main.baml; the separate file is a
// parallel-batch concurrency decision (one writer per file). The merger
// may fold it into main.baml later — nothing here depends on the file
// boundary.

class GraderScore {
    grader: string @description("grader name, e.g. entity-preservation"),
    score: float @description("0.0..1.0"),
    pass_threshold: float @description("the bar this grader carried when it graded"),
    reason: string @description("machine-readable slug; misses name what is missing"),
}

interface Grader {
    function grade(self, c: Case, output: string) -> GraderScore
    function threshold(self) -> float
}

// Deterministic: fraction of required entities preserved in the output
// (verbatim substring containment — domain fidelity, cookbook cell 6).
class EntityPreservationGrader {
    entities: string[] @description("required entities the output must preserve verbatim"),
    pass_threshold: float,
    implements Grader {
        function grade(self, c: Case, output: string) -> GraderScore {
            let missing: string[] = [];
            for (let e in self.entities) {
                if (!output.includes(e)) {
                    missing.push(e);
                }
            }
            let score = if (self.entities.length() == 0) {
                1.0
            } else {
                ((self.entities.length() - missing.length()) * 1.0) / (self.entities.length() * 1.0)
            };
            let reason = if (missing.length() == 0) {
                "entities-preserved"
            } else {
                "entities-missing:" + missing.join(",")
            };
            GraderScore {
                grader: "entity-preservation",
                score: score,
                pass_threshold: self.pass_threshold,
                reason: reason,
            }
        }
        function threshold(self) -> float {
            self.pass_threshold
        }
    }
}

// Deterministic: length discipline inside a [min, max] character band.
// In band scores 1.0; outside, the score decays proportionally
// (short: len/min, long: max/len) so near misses grade near the bar.
class LengthBandGrader {
    min_chars: int,
    max_chars: int,
    pass_threshold: float,
    implements Grader {
        function grade(self, c: Case, output: string) -> GraderScore {
            let n = output.length();
            let score = if (self.min_chars > 0 && n < self.min_chars) {
                (n * 1.0) / (self.min_chars * 1.0)
            } else if (n > self.max_chars) {
                (self.max_chars * 1.0) / (n * 1.0)
            } else {
                1.0
            };
            let reason = if (n < self.min_chars) {
                "too-short"
            } else if (n > self.max_chars) {
                "too-long"
            } else {
                "in-band"
            };
            GraderScore {
                grader: "length-band",
                score: score,
                pass_threshold: self.pass_threshold,
                reason: reason,
            }
        }
        function threshold(self) -> float {
            self.pass_threshold
        }
    }
}

// LLM-as-judge with a banded 0-1 rubric — the holistic failsafe. The
// return type is the schema; the band anchors the score so judgments
// are calibrated, not free-floating. Compiles under baml check; tests
// never call it (no LLM in T0).
class JudgeAssessment {
    band: string @description("rubric band: fail | poor | partial | good | excellent"),
    score: float @description("banded score: fail=0.0, poor=0.25, partial=0.5, good=0.75, excellent=1.0"),
    reason: string @description("one sentence citing the band and what the output missed or nailed"),
}

function JudgeGrade(c: Case, output: string) -> JudgeAssessment {
    client: "openai/gpt-4o-mini"
    prompt: `
        You are a strict grader for an agent acceptance case. Score the output
        against the case on a banded rubric:

        - fail      (0.0):  wrong task, empty, or contradicts the case
        - poor      (0.25): right task, major errors or missing core content
        - partial   (0.5):  broadly right, notable gaps or sloppiness
        - good      (0.75): correct and complete, minor polish missing
        - excellent (1.0):  correct, complete, and disciplined

        Case id: ${c.id}
        Case title: ${c.title}

        Output:
        ${output}

        Pick exactly one band, set score to that band's value, and justify in
        one sentence.

        ${ctx.output_format}
    `
}

// The judge as a Grader: wraps JudgeGrade so the stack treats LLM and
// deterministic graders uniformly. Never exercised in baml test.
class LlmJudgeGrader {
    pass_threshold: float,
    implements Grader {
        function grade(self, c: Case, output: string) -> GraderScore {
            let a = JudgeGrade(c, output);
            GraderScore {
                grader: "llm-judge",
                score: a.score,
                pass_threshold: self.pass_threshold,
                reason: "judge-" + a.band,
            }
        }
        function threshold(self) -> float {
            self.pass_threshold
        }
    }
}

// One grader's pass/fail: score against the threshold it carried.
function grader_passed(s: GraderScore) -> bool {
    s.score >= s.pass_threshold
}

// Lenient promotion (cookbook cell 18): >=75% of graders pass OR the
// average score is >= 0.85. Empty stack never promotes — no evidence
// is not a pass.
function lenient_pass(scores: GraderScore[]) -> bool {
    if (scores.length() == 0) {
        return false;
    }
    let passed = 0;
    let total = 0.0;
    for (let s in scores) {
        if (grader_passed(s)) {
            passed = passed + 1;
        }
        total = total + s.score;
    }
    let pass_fraction = (passed * 1.0) / (scores.length() * 1.0);
    let average = total / (scores.length() * 1.0);
    pass_fraction >= 0.75 || average >= 0.85
}

// Strict promotion for model swaps: every grader passes, and an empty
// stack fails closed — a swap with no grader evidence is a rejection
// (the reason rides on the caller's report: "strict: empty grader stack").
function strict_pass(scores: GraderScore[]) -> bool {
    if (scores.length() == 0) {
        return false;
    }
    scores.every((s) -> {
        grader_passed(s)
    })
}

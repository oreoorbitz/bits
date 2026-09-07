// BITS T0 grader tests (hub#201) — deterministic graders on literal
// case/output pairs (one-test→one-impl), promotion policy on literal
// GraderScore[] matrices including the 0.75/0.85 boundaries. No LLM:
// JudgeGrade/LlmJudgeGrader compile (baml check) but are never called
// here.

testset "entity-preservation grader" {
    let c = Case { id: "chain-blocks", title: "chain", tier: Tier.T2, token_cap: 0, timeout_ms: 30000 };

    test "all entities preserved scores 1.0 and passes" {
        let g = EntityPreservationGrader { entities: ["t#01", "t#02", "ready"], pass_threshold: 1.0 };
        let s = g.grade(c, "ready=[t#01]; after close ready=[t#02]");
        assert.equal(s.grader, "entity-preservation");
        assert.equal(s.score, 1.0);
        assert.equal(s.pass_threshold, 1.0);
        assert.equal(s.reason, "entities-preserved");
        assert.is_true(grader_passed(s));
    }

    test "missing entities score by fraction and name what is missing" {
        let g = EntityPreservationGrader {
            entities: ["t#01", "t#02", "t#03", "t#04"],
            pass_threshold: 0.75,
        };
        let s = g.grade(c, "only t#01 and t#03 appear");
        assert.equal(s.score, 0.5);
        assert.equal(s.reason, "entities-missing:t#02,t#04");
        assert.is_true(!grader_passed(s));
    }

    test "no required entities scores 1.0" {
        let g = EntityPreservationGrader { entities: [], pass_threshold: 1.0 };
        let s = g.grade(c, "anything");
        assert.equal(s.score, 1.0);
        assert.is_true(grader_passed(s));
    }
}

testset "length-band grader" {
    let c = Case { id: "fanout-hub-first", title: "fanout", tier: Tier.T2, token_cap: 0, timeout_ms: 30000 };

    test "in band scores 1.0 and passes" {
        let g = LengthBandGrader { min_chars: 4, max_chars: 10, pass_threshold: 1.0 };
        let s = g.grade(c, "123456");
        assert.equal(s.grader, "length-band");
        assert.equal(s.score, 1.0);
        assert.equal(s.reason, "in-band");
        assert.is_true(grader_passed(s));
    }

    test "too short scores len/min proportionally" {
        let g = LengthBandGrader { min_chars: 8, max_chars: 20, pass_threshold: 0.9 };
        let s = g.grade(c, "1234");
        assert.equal(s.score, 0.5);
        assert.equal(s.reason, "too-short");
        assert.is_true(!grader_passed(s));
    }

    test "too long scores max/len proportionally" {
        let g = LengthBandGrader { min_chars: 2, max_chars: 5, pass_threshold: 0.9 };
        let s = g.grade(c, "1234567890");
        assert.equal(s.score, 0.5);
        assert.equal(s.reason, "too-long");
        assert.is_true(!grader_passed(s));
    }

    test "near miss inside the band edges passes a proportional bar" {
        let g = LengthBandGrader { min_chars: 10, max_chars: 20, pass_threshold: 0.9 };
        let s = g.grade(c, "123456789");
        assert.approx_equal(s.score, 0.9, 0.0001);
        assert.is_true(grader_passed(s));
    }
}

testset "grader interface dispatch" {
    test "a Grader[] dispatches to each impl" {
        let c = Case { id: "cycle-parks", title: "cycles", tier: Tier.T2, token_cap: 0, timeout_ms: 30000 };
        let graders: Grader[] = [
            EntityPreservationGrader { entities: ["t#10"], pass_threshold: 1.0 },
            LengthBandGrader { min_chars: 1, max_chars: 100, pass_threshold: 1.0 },
        ];
        let scores = graders.map((g) -> {
            g.grade(c, "t#10 parked")
        });
        assert.equal(scores.length(), 2);
        assert.equal(scores[0].grader, "entity-preservation");
        assert.equal(scores[1].grader, "length-band");
        assert.is_true(
            scores.every((s) -> {
                grader_passed(s)
            }),
        );
        assert.equal(graders[1].threshold(), 1.0);
    }
}

testset "lenient-pass policy boundaries" {
    // 3/4 graders pass = exactly 0.75 pass fraction with a 0.75 average:
    // the fraction arm alone promotes (average 0.75 < 0.85).
    test "pass fraction exactly 0.75 promotes via the fraction arm" {
        let scores = [
            GraderScore { grader: "a", score: 1.0, pass_threshold: 0.5, reason: "r" },
            GraderScore { grader: "b", score: 1.0, pass_threshold: 0.5, reason: "r" },
            GraderScore { grader: "c", score: 1.0, pass_threshold: 0.5, reason: "r" },
            GraderScore { grader: "d", score: 0.0, pass_threshold: 0.5, reason: "r" },
        ];
        assert.is_true(lenient_pass(scores));
    }

    // 2/4 = 0.5 pass fraction and a 0.5 average: neither arm fires.
    test "below both bars does not promote" {
        let scores = [
            GraderScore { grader: "a", score: 1.0, pass_threshold: 0.5, reason: "r" },
            GraderScore { grader: "b", score: 1.0, pass_threshold: 0.5, reason: "r" },
            GraderScore { grader: "c", score: 0.0, pass_threshold: 0.5, reason: "r" },
            GraderScore { grader: "d", score: 0.0, pass_threshold: 0.5, reason: "r" },
        ];
        assert.is_true(!lenient_pass(scores));
    }

    // Zero graders pass but the average is exactly 0.85: the average arm
    // alone promotes ((0.85+0.85)/2 == 0.85 exactly in IEEE 754).
    test "average exactly 0.85 promotes via the average arm" {
        let scores = [
            GraderScore { grader: "a", score: 0.85, pass_threshold: 0.9, reason: "r" },
            GraderScore { grader: "b", score: 0.85, pass_threshold: 0.9, reason: "r" },
        ];
        assert.is_true(lenient_pass(scores));
    }

    test "average 0.84 with zero passes does not promote" {
        let scores = [
            GraderScore { grader: "a", score: 0.84, pass_threshold: 0.9, reason: "r" },
            GraderScore { grader: "b", score: 0.84, pass_threshold: 0.9, reason: "r" },
        ];
        assert.is_true(!lenient_pass(scores));
    }

    test "empty grader stack never promotes" {
        let scores: GraderScore[] = [];
        assert.is_true(!lenient_pass(scores));
    }
}

testset "strict all-pass for model swaps" {
    test "all graders pass promotes" {
        let scores = [
            GraderScore { grader: "a", score: 0.9, pass_threshold: 0.9, reason: "r" },
            GraderScore { grader: "b", score: 1.0, pass_threshold: 0.5, reason: "r" },
        ];
        assert.is_true(strict_pass(scores));
    }

    test "one grader under its bar fails the swap" {
        let scores = [
            GraderScore { grader: "a", score: 0.9, pass_threshold: 0.9, reason: "r" },
            GraderScore { grader: "b", score: 0.49, pass_threshold: 0.5, reason: "r" },
        ];
        assert.is_true(!strict_pass(scores));
    }

    test "empty grader stack fails closed" {
        let scores: GraderScore[] = [];
        assert.is_true(!strict_pass(scores));
    }
}

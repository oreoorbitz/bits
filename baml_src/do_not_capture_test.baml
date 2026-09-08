// BITS T0 do-not-capture tests (hub#204) — the taxonomy registry, the
// deterministic forbidden-pattern grader, and the hub#201 stack wiring,
// all on literal digests + literal ReviewAction outputs. No LLM:
// LlmJudgeGrader compiles (baml check) but is never graded here — judge
// arms are T3. The literal digests mirror
// test-backlog/do-not-capture/*.json — change both together (that
// mirror is the tracer).
//
// Every deterministic arm carries its own red-check by construction: a
// compliant literal output must PASS and a seeded forbidden artifact
// must FAIL naming the class — the seed is exactly what the arm exists
// to catch. The manual bi#57 hunk drill is recorded below.
//
// Red-check (bi#57), observed 2026-09-08:
//   hunk: ForbiddenPatternGrader.grade substring check neutered
//     (`hay.includes(p)` -> `false`) in do_not_capture.baml.
//   expected reason: a grader that cannot see a seeded forbidden
//     artifact is camouflage — every seeded-forbidden test must fail.
//   observed: exactly the 4 seeded-forbidden tests FAILed
//     ("assertion failed: left = 1.0, right = 0.0" on the score assert),
//     all compliant-output and registry tests still passed (the hunk
//     is load-bearing for detection only); hunk restored by hand-edit,
//     suite green.

testset "do-not-capture case registry" {
    test "registry covers every taxonomy class plus a positive arm" {
        let cases = do_not_capture_cases();
        assert.equal(cases.length(), 6);
        let slugs: string[] = [];
        for (let c in cases) {
            if let f: ForbiddenClass = c.forbidden {
                slugs.push(f);
            }
        }
        assert.equal(slugs.length(), 5);
        assert.contains(slugs.join(","), "env-failure");
        assert.contains(slugs.join(","), "tool-broken");
        assert.contains(slugs.join(","), "transient-resolved");
        assert.contains(slugs.join(","), "one-off-narrative");
        assert.contains(slugs.join(","), "unresolved-failure");
    }

    test "arm ids are stable" {
        let cases = do_not_capture_cases();
        let ids = cases.map((c) -> {
            c.case.id
        });
        assert.equal(
            ids.join(","),
            "dnc-env-failure,dnc-tool-broken,dnc-transient-resolved,dnc-one-off-narrative,dnc-unresolved-failure,dnc-class-lesson",
        );
    }

    test "deterministic arms carry patterns and no judge" {
        let cases = do_not_capture_cases();
        let det = cases.filter((c) -> {
            !c.judge && c.forbidden != null
        });
        assert.equal(det.length(), 3);
        assert.is_true(
            det.every((c) -> {
                c.patterns.length() > 0
            }),
        );
        assert.is_true(
            det.every((c) -> {
                c.case.tier == Tier.T0 && c.case.token_cap == 0
            }),
        );
    }

    test "judge arms grade the fuzzy classes with empty patterns" {
        let cases = do_not_capture_cases();
        let judged = cases.filter((c) -> {
            c.judge
        });
        assert.equal(judged.length(), 2);
        assert.is_true(
            judged.every((c) -> {
                c.patterns.length() == 0 && c.case.tier == Tier.T3
            }),
        );
        assert.equal(judged[0].forbidden, "transient-resolved");
        assert.equal(judged[1].forbidden, "unresolved-failure");
    }

    test "positive arm requires the class-level lesson entities" {
        let cases = do_not_capture_cases();
        let pos = cases.filter((c) -> {
            c.forbidden == null
        });
        assert.equal(pos.length(), 1);
        assert.equal(pos[0].case.id, "dnc-class-lesson");
        assert.is_true(!pos[0].judge);
        assert.equal(pos[0].required_entities.join(","), "full suite,before claiming green");
    }

    test "do_not_capture_case finds by id, null on typo" {
        assert.not_null(do_not_capture_case("dnc-env-failure"));
        assert.is_true(do_not_capture_case("dnc-en-failure") == null);
    }
}

testset "forbidden-pattern grader — env-failure arm" {
    test "fix proposal passes (the FIX is the allowed capture)" {
        if let c: DoNotCaptureCase = do_not_capture_case("dnc-env-failure") {
            let output = `{"skill": "bais", "action": "patch", "target_file": "SKILL.md", "content": "If rg is missing on a fresh machine, install it first: brew install ripgrep.", "rationale": "setup fix, not a durable rule"}`;
            let scores = grade_deterministic(c, output);
            assert.equal(scores.length(), 1);
            assert.equal(scores[0].grader, "forbidden-pattern");
            assert.equal(scores[0].score, 1.0);
            assert.equal(scores[0].reason, "no-forbidden-artifact");
            assert.is_true(lenient_pass(scores));
        }
    }

    test "seeded env-state rule fails naming class and pattern" {
        if let c: DoNotCaptureCase = do_not_capture_case("dnc-env-failure") {
            let output = `{"op": "add", "content": "ripgrep is not installed on this machine — always use grep -r instead of rg.", "old_text": null, "rationale": "save the workaround"}`;
            let scores = grade_deterministic(c, output);
            assert.equal(scores[0].score, 0.0);
            assert.equal(scores[0].reason, "forbidden-artifact:env-failure:is not installed");
            assert.is_true(!grader_passed(scores[0]));
            assert.is_true(!lenient_pass(scores));
        }
    }

    test "matching is case-insensitive (recall over fidelity)" {
        if let c: DoNotCaptureCase = do_not_capture_case("dnc-env-failure") {
            let scores = grade_deterministic(c, "RIPGREP IS NOT INSTALLED HERE");
            assert.equal(scores[0].score, 0.0);
            assert.equal(scores[0].reason, "forbidden-artifact:env-failure:is not installed");
        }
    }
}

testset "forbidden-pattern grader — tool-broken arm" {
    test "retry-pattern fix passes" {
        if let c: DoNotCaptureCase = do_not_capture_case("dnc-tool-broken") {
            let output = `{"skill": "bi", "action": "patch", "target_file": "SKILL.md", "content": "When browser_navigate times out, retry once and check the playwright daemon before falling back to curl.", "rationale": "the retry pattern, not the failure"}`;
            let scores = grade_deterministic(c, output);
            assert.equal(scores[0].score, 1.0);
            assert.is_true(lenient_pass(scores));
        }
    }

    test "seeded tool refusal fails naming class and pattern" {
        if let c: DoNotCaptureCase = do_not_capture_case("dnc-tool-broken") {
            let output = `{"skill": "bi", "action": "patch", "target_file": "SKILL.md", "content": "browser tools do not work — always use curl instead.", "rationale": "observed twice this session"}`;
            let scores = grade_deterministic(c, output);
            assert.equal(scores[0].score, 0.0);
            assert.equal(scores[0].reason, "forbidden-artifact:tool-broken:do not work");
            assert.is_true(!lenient_pass(scores));
        }
    }
}

testset "forbidden-pattern grader — one-off-narrative arm" {
    test "NothingToSave passes (one-off requests are not a class of work)" {
        if let c: DoNotCaptureCase = do_not_capture_case("dnc-one-off-narrative") {
            let output = `{"reason": "two one-off requests, no class of work, no correction"}`;
            let scores = grade_deterministic(c, output);
            assert.equal(scores[0].score, 1.0);
            assert.is_true(lenient_pass(scores));
        }
    }

    test "seeded dated narrative fails naming every hit" {
        if let c: DoNotCaptureCase = do_not_capture_case("dnc-one-off-narrative") {
            let output = `{"skill": "market-summary", "action": "create", "target_file": "SKILL.md", "content": "How to summarize today's market like on 2026-09-08 and review PR #4731.", "rationale": "session artifact"}`;
            let scores = grade_deterministic(c, output);
            assert.equal(scores[0].score, 0.0);
            assert.equal(
                scores[0].reason,
                "forbidden-artifact:one-off-narrative:today's market,#4731,2026-09-08",
            );
            assert.is_true(!lenient_pass(scores));
        }
    }
}

testset "positive arm — class-level lesson captured" {
    test "capture preserving the lesson passes entity preservation" {
        if let c: DoNotCaptureCase = do_not_capture_case("dnc-class-lesson") {
            let output = `{"skill": "bagl", "action": "patch", "target_file": "SKILL.md", "content": "Run the full suite before claiming green — a green shard can hide a red one you did not run.", "rationale": "user corrected the claim-green workflow"}`;
            let scores = grade_deterministic(c, output);
            assert.equal(scores.length(), 1);
            assert.equal(scores[0].grader, "entity-preservation");
            assert.equal(scores[0].score, 1.0);
            assert.equal(scores[0].reason, "entities-preserved");
            assert.is_true(lenient_pass(scores));
        }
    }

    test "a pass that captures nothing fails (the lesson is the assertion)" {
        if let c: DoNotCaptureCase = do_not_capture_case("dnc-class-lesson") {
            let output = `{"reason": "smooth session, nothing to save"}`;
            let scores = grade_deterministic(c, output);
            assert.equal(scores[0].score, 0.0);
            assert.equal(scores[0].reason, "entities-missing:full suite,before claiming green");
            assert.is_true(!lenient_pass(scores));
        }
    }
}

testset "grader stack wiring (hub#201)" {
    test "deterministic arm stack is the forbidden-pattern grader alone" {
        if let c: DoNotCaptureCase = do_not_capture_case("dnc-tool-broken") {
            let stack = grader_stack_for(c);
            assert.equal(stack.length(), 1);
            assert.equal(stack[0].threshold(), 1.0);
            assert.equal(stack[0].grade(c.case, "anything").grader, "forbidden-pattern");
        }
    }

    test "positive arm stack is entity preservation alone" {
        if let c: DoNotCaptureCase = do_not_capture_case("dnc-class-lesson") {
            let stack = grader_stack_for(c);
            assert.equal(stack.length(), 1);
            assert.equal(stack[0].grade(c.case, "anything").grader, "entity-preservation");
        }
    }

    test "judge arm stack is the LLM judge alone (never graded in T0)" {
        if let c: DoNotCaptureCase = do_not_capture_case("dnc-transient-resolved") {
            let stack = grader_stack_for(c);
            assert.equal(stack.length(), 1);
            assert.equal(stack[0].threshold(), 0.75);
        }
    }

    test "a judge arm can never pass silently offline" {
        // grade_deterministic skips the judge, leaving an empty score
        // list — and lenient_pass([]) is false (hub#201: no evidence is
        // not a pass). The fuzzy classes REQUIRE the live judge.
        if let c: DoNotCaptureCase = do_not_capture_case("dnc-unresolved-failure") {
            let scores = grade_deterministic(c, "any output at all");
            assert.equal(scores.length(), 0);
            assert.is_true(!lenient_pass(scores));
        }
    }
}

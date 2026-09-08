# AGENTS.md — bits

> Read `../AGENTS.md` first — this file is the `bits` specialization.

## What this is

Agent-driven acceptance for `bi` + BAIS. Fixtures are BAIS issues, runners are agents, verdicts are BAML types. BAML owns case/verdict shapes and grading policy; hosts execute runs and meter spend.

* `baml_src/` — `main.baml` owns `Case`/`Verdict`/grading policy (bits#01+); policy modules land one file per concern (`grader.baml` hub#201 stack, `retrieval.baml`, `pareto.baml`, `flip_gate.baml`, `eval_scorecard.baml`, `do_not_capture.baml` hub#204), each with a `*_test.baml` T0 twin on literals.
* `test-backlog/` — crafted `.toml` fixtures doubling as BAML-test literals and live CLI fixtures.
* `src/cli.ts` — `bits` CLI stub (`tiers` today, `run --fast/--live` next).
* `.bais/` — bits's own backlog (`bits#01` is the tracking epic).

## Toolchain

Pinned `0.17.0` (wrapper `0.2.4`, toolchain `0.17.0 canary`, bridge `0.17.0` — SDK and bridge versions must match).

```
baml check --project bits
baml test --project bits
baml generate --project bits
```

## Rules (inherited + specific)

* Never hand-edit `baml_sdk/` or `dist/`. Per-commit gates are T0+T1 only; T2 fast-path is the default suite; T3 live runs are sampled, never per-commit.
* BAIS conventions apply to `.bais/` (strict TOML, file-per-issue, `bais check` clean).
* BITS failures file themselves as BAIS issues with transcripts — the suite uses the tool to prove the tool.

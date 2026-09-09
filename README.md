# BITS — Basically a made-up Integrated Test Suite

Sibling to `bi`, `bais`, `bagl` under `orion-learn-baml/` — agent-driven acceptance for the `bi` CLI and BAIS.

**Objectives (same family):**

1. **Learn language design** — BAML's expression-oriented, interface + `match`, prompt-as-schema DSL, turned on testing itself.
2. **Have fun making BAML projects** — this one proves the other three work.
3. **Contribute to BAML** — a real agent-acceptance workload is a demanding toolchain surface.

**The idea:** fixtures are BAIS issues (`test-backlog/*.toml`), runners are agents driving the real `bi` CLI, verdicts are BAML types. A BITS failure files itself as a BAIS issue with the transcript attached. Per-case token caps and wall-clock timeouts are assertions.

**Tiers (per-commit feedback stays in seconds forever):**

| Tier | What | Cost | When |
|------|------|------|------|
| T0 | `baml check`/`baml test` — pure policy on literals | ms | every commit |
| T1 | host probes `scripts/*.mjs` — offline | seconds | pre-push |
| T2 | BITS fast path — stub model, machine speed | seconds | default suite |
| T3 | BITS live path — real model, seeded sample | minutes + tokens | nightly, on-demand |

**Status:** typed grading and policy modules plus the T2 fast runner are implemented. `bits arms` lists stable cases; `bits run --fast --arm <id>` runs one without self-filing. Full-suite failures can self-file BAIS issues with transcripts; `Evidence: drill(bits-t2)` resolves hub-wide. T3 `run --live` explicitly refuses as unwired (`bits#01`); supplying a model key alone does not enable it. See [AGENTS.md](AGENTS.md) for gates and [DOGFOOD.md](DOGFOOD.md) for historical findings.

```bash
cd bits
export BAML_PROFILE=0
baml check && baml test && baml generate   # T0 + SDK
npm run build             # tsc -> dist/
node dist/src/cli.js tiers
node dist/src/cli.js arms
```

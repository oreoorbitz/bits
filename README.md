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

**Status:** first real work landed (hub#153, bits#03 Done). T0: `Case`/`Verdict` + grading in `baml_src/main.baml`, `baml test` 13/13. T2: `scripts/bits-t2.mjs` 6/6 green via `bits run --fast`; failures self-file as bits issues (bits#02 kept as proof); `Evidence: drill(bits-t2)` resolves hub-wide. bits#01 stays Open pending the T3 sampled live run (needs a model key).

```bash
cd bits
baml check && baml test   # T0 (once baml_src grows past the skeleton)
npm run build             # tsc -> dist/
node dist/src/cli.js tiers
```

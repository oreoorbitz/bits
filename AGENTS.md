# AGENTS.md — bits

> Read `../AGENTS.md` first. BITS is Basically a made-up Integrated Test Suite: agent-driven acceptance for BI, BAIS, and the ecosystem.

## Ownership and entry points

* `baml_src/main.baml` owns Case/Verdict, grading and budgets. Policy modules include grader, retrieval, Pareto, flip gate, scorecard and do-not-capture, with literal-data test twins.
* `test-backlog/` contains BAIS issue fixtures plus JSON/TOML evaluation data and executable-case descriptions. Follow each fixture family's README.
* `src/cli.ts` routes `tiers`, `arms`, and `run --fast [--arm <id>]` to `scripts/bits-t2.mjs`. The fast runner is implemented. `run --live` exits with an explicit unwired message; sampled T3 remains `bits#01`.
* The host executes cases and meters cost/time; BAML owns the verdict contract. Full-suite failures can self-file BAIS issues with transcripts; single-arm runs do not self-file. Inspect runner behavior before using a live board.
* `.bais/` is BITS's own backlog, with strict TOML and BAIS validation; root tracks cross-project integration. `DOGFOOD.md` records historical findings, not current suite totals.

## Test tiers and evidence

* T0: BAML checks and policy tests on literals, every commit.
* T1: offline host probes, pre-push. Per-commit gates remain T0/T1 only.
* T2: fast acceptance, default suite; build required sibling hosts first.
* T3: sampled real-model runs, nightly/on-demand, never per-commit; currently unwired.

From the workspace root, list arms with `node bits/dist/src/cli.js arms`. Run one with `node bits/dist/src/cli.js run --fast --arm <id>`. Preserve stable IDs, budget enforcement, transcripts naming expected and actual values, and red-check evidence for safety nets. `Evidence: drill(bits-t2)` connects acceptance results to BAIS close evidence.

## Toolchain and gates

Follow the root [storage hygiene rules](../AGENTS.md#storage-hygiene): set `BAML_PROFILE=0` in the actual launcher environment, watch for new dumps after long runs, and retain Rust build artifacts only while needed. These projects use the installed CLI/bridge; normal work does not require compiling the BAML Rust checkout.

Wrapper `0.2.4`, toolchain `0.17.0`, bridge `0.17.0`; keep bridge/toolchain aligned. Use `BAML_PROFILE=0` before runtime initialization (root instructions explain shell/GUI setup). From the workspace root:

```bash
baml check --project bits
baml test --project bits
baml fmt --project bits
baml generate --project bits
npm run build --prefix bits
npm run typecheck --prefix bits
```

Never hand-edit `baml_sdk/` or `dist/`. Report observed test results; historical counts are not a current gate result.

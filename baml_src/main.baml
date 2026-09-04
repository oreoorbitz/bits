// BITS — Basically a made-up Integrated Test Suite.
//
// Agent-driven acceptance for the bi CLI and BAIS. The fixtures are BAIS
// issues (test-backlog/*.toml), the runners are agents driving the real
// `bi` CLI, and the verdicts are BAML types (Case/Verdict land here with
// the first real work — see bits#01). Ingredients are popular (fixture
// dirs, stub harnesses, sampled live runs); the recipe (BAIS-native,
// self-filing, budget-asserted) is new.
//
// Tiers (per-commit cost stays in seconds forever):
//   T0  baml check/test — pure policy on literals, milliseconds.
//   T1  host probes (scripts/*.mjs) — offline, seconds.
//   T2  BITS fast path — stub-model runs at machine speed (default).
//   T3  BITS live path — real-model runs, seeded sample, nightly only.
// A BITS failure files itself as a BAIS issue with the transcript
// attached; per-case token caps and wall-clock timeouts are assertions,
// not suggestions.

function main() -> string {
    "bits"
}

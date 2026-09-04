// bits/src/cli.ts — `bits` CLI stub. Full runner lands with the first
// real work (bits#01); today it names the tiers so the binary exists.

const HELP = `bits — Basically a made-up Integrated Test Suite

Usage:
  bits tiers            # list the test tiers (T0-T3)
  bits run --fast       # stub-model acceptance (default when implemented)
  bits run --live [--seed N]  # sampled real-model runs (nightly)

Tiers:
  T0  baml check/test (pure policy, milliseconds)
  T1  host probes scripts/*.mjs (offline, seconds)
  T2  BITS fast path — stub model, machine speed
  T3  BITS live path — real model, seeded sample, nightly only
`;

const cmd = process.argv[2];
if (cmd === "tiers" || cmd === undefined || cmd === "--help" || cmd === "-h") {
	console.log(HELP);
} else if (cmd === "run") {
	console.error("bits run is not implemented yet — see bits#01. Tiers above for the plan.");
	process.exit(2);
} else {
	console.error(`Unknown command: ${cmd}\n`);
	console.log(HELP);
	process.exit(2);
}

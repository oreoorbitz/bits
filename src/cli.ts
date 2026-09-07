// bits/src/cli.ts — `bits` CLI. T2 fast path is real (run --fast executes
// scripts/bits-t2.mjs, the drill stem close-evidence cites); T3 live runs
// stay unwired until bits#01's sampled run (needs a model key).

import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const SUITE = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..", "scripts", "bits-t2.mjs");

const HELP = `bits — Basically a made-up Integrated Test Suite

Usage:
  bits tiers                       # list the test tiers (T0-T3)
  bits arms                        # list stable T2 arm ids (drill evolution consumes these)
  bits run --fast [--arm <id>]     # stub-model acceptance (default suite)
  bits run --live [--seed N]       # sampled real-model runs (nightly; unwired — see bits#01)

Tiers:
  T0  baml check/test (pure policy, milliseconds)
  T1  host probes scripts/*.mjs (offline, seconds)
  T2  BITS fast path — stub model, machine speed (drill bits-t2)
  T3  BITS live path — real model, seeded sample, nightly only
`;

const argv = process.argv.slice(2);
const cmd = argv[0];

if (cmd === "tiers" || cmd === undefined || cmd === "--help" || cmd === "-h") {
	console.log(HELP);
} else if (cmd === "arms") {
	execFileSync("node", [SUITE, "--list-arms"], { stdio: "inherit" });
} else if (cmd === "run") {
	if (argv.includes("--live")) {
		console.error("bits run --live is not wired yet: T3 needs a model key and a seeded sample (see bits#01). Use run --fast.");
		process.exit(2);
	}
	const armIdx = argv.indexOf("--arm");
	const suiteArgs = armIdx >= 0 && argv[armIdx + 1] ? [argv[armIdx + 1]] : [];
	try {
		execFileSync("node", [SUITE, ...suiteArgs], { stdio: "inherit" });
	} catch {
		process.exit(1);
	}
} else {
	console.error(`Unknown command: ${cmd}\n`);
	console.log(HELP);
	process.exit(2);
}

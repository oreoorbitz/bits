// bits/scripts/flip-gate.mjs — proposal gate (hub#200 consumer). Any
// self-modification proposal (meta-tool, prompt patch, skill) must pass
// flip_gate() on the drill arms of the failure issues it claims to fix
// before it lands (AgentDevel flip-centered regression gating). The
// policy lives in BAML (bits/baml_src/flip_gate.baml); this host script
// only replays the proposal's recorded before/after graded arms through
// it via `baml run` — offline, no SDK regen, no LLM.
//
// Run: node bits/scripts/flip-gate.mjs <proposal-id>   (e.g. prop#01)
//   reads test-backlog/flip-gate/<id>.before.json + <id>.after.json
//   (GradedCase literals — see that family's README), evaluates
//   flip_gate(before, after), prints the typed FlipVerdict.
//   exit 0 iff FlipAccept; FlipReject/FlipNoOp exit 1 with the verdict
//   on stdout — a rejected proposal lands nowhere, and the reason is
//   named (bi#55).
//
// Fixture mirror: baml_src/flip_gate_test.baml "fixture proposal clean
// flip accepts" mirrors prop#01's JSON verbatim (change both together).

import { readFileSync, existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join, resolve } from "node:path";
import { execFileSync } from "node:child_process";

const HERE = dirname(fileURLToPath(import.meta.url));
const BITS = resolve(HERE, "..");
const REPO = resolve(BITS, "..");
const FAMILY = join(BITS, "test-backlog", "flip-gate");

const id = process.argv[2];
if (!id) {
	console.error("usage: node bits/scripts/flip-gate.mjs <proposal-id>");
	process.exit(2);
}

// Read + validate one graded-arms file. Fail loud on any shape drift —
// the gate must never gate on garbage (bi#55: no silent rejections).
function readGraded(file) {
	if (!existsSync(file)) {
		console.error(`flip-gate: missing fixture ${file}`);
		process.exit(2);
	}
	const arms = JSON.parse(readFileSync(file, "utf8"));
	if (!Array.isArray(arms)) {
		console.error(`flip-gate: ${file} must be a JSON array of graded arms`);
		process.exit(2);
	}
	for (const a of arms) {
		const ok =
			typeof a.case_id === "string" &&
			["Pass", "Fail", "Skip"].includes(a.outcome) &&
			typeof a.reason === "string" &&
			/^[a-z0-9:-]+$/.test(a.reason) &&
			typeof a.over_budget === "boolean";
		if (!ok) {
			console.error(`flip-gate: malformed graded arm in ${file}: ${JSON.stringify(a)}`);
			process.exit(2);
		}
	}
	return arms;
}

// GradedCase literals are slug-safe by validation above, so direct
// interpolation into a BAML expression is exact.
function toBaml(arms) {
	const items = arms.map(
		(a) =>
			`GradedCase { case_id: "${a.case_id}", outcome: Outcome.${a.outcome}, reason: "${a.reason}", over_budget: ${a.over_budget} }`,
	);
	return `[${items.join(", ")}]`;
}

const before = readGraded(join(FAMILY, `${id}.before.json`));
const after = readGraded(join(FAMILY, `${id}.after.json`));

const expr = `flip_gate(${toBaml(before)}, ${toBaml(after)})`;
let out;
try {
	out = execFileSync("baml", ["run", "--project", "bits", "-e", expr], {
		cwd: REPO,
		encoding: "utf8",
		stdio: ["ignore", "pipe", "pipe"],
	}).trim();
} catch (e) {
	console.error(`flip-gate: baml run failed: ${e.stderr ?? e.message}`);
	process.exit(2);
}

console.log(out);
// baml prints class values as `user.FlipAccept {...}` — land on Accept
// only; Reject names the regressed arms, NoOp means nothing flipped.
process.exit(out.startsWith("user.FlipAccept") ? 0 : 1);

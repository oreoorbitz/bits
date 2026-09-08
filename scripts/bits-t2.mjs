// bits/scripts/bits-t2.mjs — BITS T2 fast path: stub-model acceptance at
// machine speed (default suite). Each arm materializes a test-backlog/
// fixture family into a tmp hub and drives the REAL `bi` CLI against it
// (cwd-local hub resolution) — stub model, real substrate. No localhost,
// no model key: every spawn is a local pipe, so this suite stays green
// on sandboxed runners (cf. bais sync-test's grandchild-loopback SKIP).
//
// Run: node bits/scripts/bits-t2.mjs [--json] [--list-arms] [arm-id]
//   --list-arms  print stable arm ids (drill evolution, bi#148, consumes these)
//   <arm-id>     run one arm (red-checks, drill arms)
//   BIT_SELF_FILE_DIR=<dir>  redirect self-filed issues (red-check purity)
//
// Close-evidence (bi#83): this file's stem is the cite —
//   Evidence: drill(bits-t2)
// resolves hub-wide via the sibling-scripts union (hub#164). Use the
// BAML evidence_cite() builder so the line is built, not hand-typed.
//
// Budgets: per-arm timeout_ms from test-backlog/cost/budgets.toml
// (minimal line parser below — flat keys + [arm.<id>] sections only).
// An arm past its cap grades Fail(over-budget), mirroring the BAML
// grade_verdict() T0 twin (main_test.baml literals mirror these numbers).
//
// Self-filing: a failed arm files itself as bits/.bais/issues/bits#NN.toml
// (kind Bug, area bits/t2) with the transcript attached — the suite uses
// the tool to prove the tool. Deliberately-broken-fixture drill observed
// 2026-09-06: sabotaged chain-blocks expectation -> FAIL ready-nonexact,
// filed bits#02 with transcript, restored green (hub#153 acceptance).
//
// Red-check (bi#57), observed 2026-09-06:
//   hunk: chain-blocks pre-move expectation flipped to ["t#02"].
//   run A (BIT_SELF_FILE_DIR=/tmp/bits153-redcheck): FAIL chain-blocks
//     ready-nonexact, 5/6 pass, bits#02.toml filed in the override dir.
//   run B (no override): same FAIL, real bits/.bais/issues/bits#02.toml
//     filed with transcript (kept as the hub#153 self-file proof).
//   exit code 1 observed on the failing run (no pipe). Hunk restored,
//     re-ran green 6/6.
// A passing suite that cannot go red is camouflage, not coverage.
//
// Red-check (bi#57) for cross-embedder-agreement, observed 2026-09-06:
//   hunk: query-1 cohere top flipped to rank2-unrecorded in
//     test-backlog/retrieval/scores.json (hand-edit, restored by copy).
//   run: FAIL cross-embedder-agreement rank-disagree (single-arm: not
//     filed) :: query="prepared statements" voyage_top=pdo-prepared#0
//     cohere_top=rank2-unrecorded (spread recorded voyage=0.1480
//     cohere=0.9924, not asserted) — the failure names the query on the
//     console, and the same transcript rides the self-filed issue in
//     full-suite mode. Hunk restored (cmp-identical), re-ran green.
//   drive-by: single-arm FAIL lines now append the transcript (was
//     reason-only, query invisible on the console) — every arm's
//     single-arm failure got louder, exit codes unchanged.
//
// Red-check (bi#57) for the bits#02 chain-blocks derivation fix,
// observed 2026-09-07:
//   hunk: pre-move expectation flipped ["t#01"] -> ["t#02"] (comparison
//     and expected= note — the same sabotage that self-filed bits#02).
//   run A (single-arm): FAIL chain-blocks ready-nonexact exit=1 ::
//     transcript now ends `ready=["t#01"] expected=["t#02"]` — BOTH
//     sides of the comparison named (pre-fix the filing showed only the
//     correct-looking actual side, undebuggable from the issue alone).
//   run B (BIT_SELF_FILE_DIR=/tmp/bits02-redcheck, full suite): same
//     FAIL ready-nonexact, 8/9, exit=1, filed bits#02.toml in the
//     override dir; its body is byte-identical to the self_file_body()
//     shape pinned in main_test.baml and carries the both-sides note.
//   Hunk restored, re-ran 9/9 green exit=0, no filing in the real
//   issues dir. The post-move check now also derives ready-nonexact
//   (was ready-nonempty — the opposite of what an un-surfaced tail
//   means); cycle-parks/dangling-parks keep ready-nonempty, their
//   checks are genuine length!==0.

import { cpSync, existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";
import { dirname, join, resolve } from "node:path";
import { execFileSync } from "node:child_process";

const HERE = dirname(fileURLToPath(import.meta.url));
const BITS = resolve(HERE, "..");
const REPO = resolve(BITS, "..");
const BI = join(REPO, "bi", "dist", "src", "cli.js");
const BACKLOG = join(BITS, "test-backlog");
const SELF_FILE_DIR = process.env.BIT_SELF_FILE_DIR ?? join(BITS, ".bais", "issues");

// Minimal budgets.toml parser: `suite_cap_ms = N` + `[arm.<id>]` sections
// with `timeout_ms = N`. Anything else is ignored (comments, token notes).
function readBudgets() {
	const caps = new Map();
	let suiteCap = 120000;
	let cur = null;
	for (const raw of readFileSync(join(BACKLOG, "cost", "budgets.toml"), "utf8").split("\n")) {
		const line = raw.split("#")[0].trim();
		if (!line) continue;
		const sec = /^\[arm\.([a-z-]+)\]$/.exec(line);
		if (sec) {
			cur = sec[1];
			continue;
		}
		const kv = /^([a-z_]+)\s*=\s*(\d+)$/.exec(line);
		if (!kv) continue;
		if (cur && kv[1] === "timeout_ms") caps.set(cur, Number(kv[2]));
		else if (!cur && kv[1] === "suite_cap_ms") suiteCap = Number(kv[2]);
	}
	return { caps, suiteCap };
}

// Materialize one fixture family dir (*.toml issues) as a tmp hub.
function mkHub(family) {
	const root = join(tmpdir(), `bits-t2-${family}-${process.pid}-${Date.now()}`);
	const issues = join(root, ".bais", "issues");
	mkdirSync(issues, { recursive: true });
	writeFileSync(join(root, ".bais", "config.toml"), 'project = "bits-t2"\n');
	for (const f of readdirSync(join(BACKLOG, family)).filter((f) => f.endsWith(".toml"))) {
		cpSync(join(BACKLOG, family, f), join(issues, f));
	}
	return root;
}

function sh(bin, args, cwd, timeoutMs) {
	const t0 = Date.now();
	try {
		const out = execFileSync("node", [bin, ...args], { cwd, encoding: "utf8", timeout: timeoutMs });
		return { ok: true, out, wallMs: Date.now() - t0 };
	} catch (e) {
		const out = (e.stdout ?? "") + (e.stderr ?? "") || String(e.message).split("\n")[0];
		return { ok: false, out, wallMs: Date.now() - t0, timedOut: /ETIMEDOUT|timed out/i.test(String(e.message)) };
	}
}

const J = (s) => JSON.parse(s);
const readyIds = (json) => J(json).ready.map((r) => r.issue.id);
const TRUNC = 4000;
const trunc = (s) => (s.length > TRUNC ? s.slice(0, TRUNC) + "\n…[truncated]" : s);
// TOML """-safe: transcripts ride in body """, so neutralize triple quotes.
const tomlSafe = (s) => s.replaceAll('"""', "'''");

const ARMS = [
	{
		id: "chain-blocks",
		family: "blocked-chain",
		title: "closing the head surfaces the tail",
		run(hub, cap) {
			// bits#02: an exact-comparison failure note must name BOTH
			// sides — actual and expected. A self-filed issue whose
			// transcript shows only the actual side is undebuggable (the
			// bits#02 filing showed correct-looking ready=["t#01"] while
			// the sabotaged expectation lived only in this source). Both
			// checks here are exact, so both derive ready-nonexact — the
			// post-move check previously derived ready-nonempty, the
			// opposite of what an un-surfaced tail means.
			let r = sh(BI, ["bais", "ready", "--json"], hub, cap);
			if (!r.ok) return fail("exit-nonzero", r);
			const before = readyIds(r.out);
			if (JSON.stringify(before) !== JSON.stringify(["t#01"]))
				return fail("ready-nonexact", r, `ready=${JSON.stringify(before)} expected=["t#01"]`);
			r = sh(BI, ["bais", "move", "t#01", "Done"], hub, cap);
			if (!r.ok) return fail("move-nonzero", r);
			r = sh(BI, ["bais", "ready", "--json"], hub, cap);
			if (!r.ok) return fail("exit-nonzero", r);
			const after = readyIds(r.out);
			if (JSON.stringify(after) !== JSON.stringify(["t#02"]))
				return fail("ready-nonexact", r, `ready=${JSON.stringify(after)} expected=["t#02"]`);
			return pass(`surfaced t#02 after close`);
		},
	},
	{
		id: "cycle-parks",
		family: "cycles",
		title: "blocks loop parks everything and reports",
		run(hub, cap) {
			let r = sh(BI, ["bais", "ready", "--json"], hub, cap);
			if (!r.ok) return fail("exit-nonzero", r);
			if (readyIds(r.out).length !== 0) return fail("ready-nonempty", r, `ready=${JSON.stringify(readyIds(r.out))}`);
			// NOTE: check is a gate — reported cycles exit nonzero WITH the
			// JSON still on stdout. Parse regardless; unparseable is the failure.
			r = sh(BI, ["bais", "check", "--json"], hub, cap);
			let cycles;
			try {
				cycles = J(r.out).cycles ?? [];
			} catch {
				return fail("check-unparseable", r);
			}
			if (!cycles.includes("t#10") || !cycles.includes("t#11")) return fail("cycle-unreported", r, `cycles=${JSON.stringify(cycles)}`);
			return pass("ready empty, cycle reported");
		},
	},
	{
		id: "dangling-parks",
		family: "dangling",
		title: "typo'd blocker parks conservative and loud",
		run(hub, cap) {
			let r = sh(BI, ["bais", "ready", "--json"], hub, cap);
			if (!r.ok) return fail("exit-nonzero", r);
			if (readyIds(r.out).length !== 0) return fail("ready-nonempty", r, `ready=${JSON.stringify(readyIds(r.out))}`);
			r = sh(BI, ["bais", "check", "--json"], hub, cap);
			if (!r.ok) return fail("exit-nonzero", r);
			const dangling = (J(r.out).dangling ?? []).map((d) => d.id);
			if (!dangling.includes("t#NOPE")) return fail("dangling-unreported", r, `dangling=${JSON.stringify(dangling)}`);
			return pass("parked, t#NOPE reported");
		},
	},
	{
		id: "fanout-hub-first",
		family: "fanout",
		title: "blast-radius orders the hub before the bystander",
		run(hub, cap) {
			const r = sh(BI, ["bais", "ready", "--order", "blast-radius", "--json"], hub, cap);
			if (!r.ok) return fail("exit-nonzero", r);
			const ids = readyIds(r.out);
			const set = [...ids].sort();
			if (JSON.stringify(set) !== JSON.stringify(["t#20", "t#24"])) return fail("ready-nonexact", r, `ready=${JSON.stringify(ids)}`);
			if (ids[0] !== "t#20") return fail("hub-not-first", r, `ready=${JSON.stringify(ids)}`);
			return pass("hub first, severity untouched");
		},
	},
	{
		id: "lease-fencing",
		family: "leases",
		title: "live claim fences, expiry reaps, dead holders park nothing",
		run(hub, cap) {
			let r = sh(BI, ["bais", "ready", "--json"], hub, cap);
			if (!r.ok) return fail("exit-nonzero", r);
			if (JSON.stringify(readyIds(r.out)) !== JSON.stringify(["t#40"])) return fail("ready-nonexact", r);
			r = sh(BI, ["bais", "move", "t#40", "Doing", "--as", "bits-t2", "--for", "1h"], hub, cap);
			if (!r.ok) return fail("claim-nonzero", r);
			const claimed = readFileSync(join(hub, ".bais", "issues", "t#40.toml"), "utf8");
			if (!/^status = "Doing"/m.test(claimed) || !/^holder = "bits-t2"/m.test(claimed)) {
				return fail("claim-unrecorded", r, trunc(claimed));
			}
			r = sh(BI, ["bais", "ready", "--json"], hub, cap);
			if (!r.ok) return fail("exit-nonzero", r);
			if (readyIds(r.out).length !== 0) return fail("claimed-still-ready", r);
			const future = new Date(Date.now() + 2 * 3600 * 1000).toISOString();
			r = sh(BI, ["bais", "reap", "--now", future, "--json"], hub, cap);
			if (!r.ok) return fail("reap-nonzero", r);
			r = sh(BI, ["bais", "ready", "--json"], hub, cap);
			if (!r.ok) return fail("exit-nonzero", r);
			if (JSON.stringify(readyIds(r.out)) !== JSON.stringify(["t#40"])) {
				return fail("reap-unparked", r, `ready=${JSON.stringify(readyIds(r.out))}`);
			}
			return pass("fenced while live, reaped after expiry");
		},
	},
	{
		// hub#173: cross-embedder retrieval eval. No tmp hub (family null):
		// the fixture is recorded vendor scores, read directly like the
		// budgets arm reads budgets.toml (non-issue fixtures ride beside
		// the BAIS-issue families — cf. test-backlog/README.md). Rank-1
		// agreement is ASSERTED (a flip fails naming the query); spreads
		// are RECORDED into the pass note, never asserted.
		id: "cross-embedder-agreement",
		family: null,
		title: "vendors agree on rank 1, spreads recorded not asserted",
		run(_hub, _cap) {
			let raw;
			try {
				raw = readFileSync(join(BACKLOG, "retrieval", "scores.json"), "utf8");
			} catch {
				return fail("fixture-missing", null, "test-backlog/retrieval/scores.json unreadable");
			}
			let fixture;
			try {
				fixture = JSON.parse(raw);
			} catch {
				return fail("fixture-unparseable", { out: raw });
			}
			const notes = [];
			for (const q of fixture.queries ?? []) {
				const v = q.voyage ?? [];
				const c = q.cohere ?? [];
				if (v.length === 0 || c.length === 0) return fail("fixture-empty-ranking", null, `query="${q.query}"`);
				const vTop = v[0].doc_id;
				const cTop = c[0].doc_id;
				const vSpread = (v[0].score - v[v.length - 1].score).toFixed(4);
				const cSpread = (c[0].score - c[c.length - 1].score).toFixed(4);
				if (vTop !== cTop) {
					return fail(
						"rank-disagree",
						null,
						`query="${q.query}" voyage_top=${vTop} cohere_top=${cTop} (spread recorded voyage=${vSpread} cohere=${cSpread}, not asserted)`,
					);
				}
				notes.push(`${q.query}: rank1=${vTop} spread voyage=${vSpread} cohere=${cSpread}`);
			}
			if (notes.length < 3) return fail("fixture-too-thin", null, `queries=${notes.length}, need 3+`);
			return pass(notes.join("; "));
		},
	},
	{
		id: "budgets-asserted",
		family: null,
		title: "every arm inside its cap, suite inside its cap (self-metered)",
		run(_hub, _cap, ledger) {
			const over = ledger.filter((a) => a.wallMs > a.cap);
			if (over.length > 0) {
				return fail("over-budget", null, over.map((a) => `${a.id} ${a.wallMs}ms > ${a.cap}ms`).join("; "));
			}
			return pass(`${ledger.length} arms inside caps, stub tokens 0`);
		},
	},
];

// hub#199: e2e arm family — the goal -> BITS flow, typed. Case files in
// test-backlog/e2e-cases/*.case.json are the single source of truth
// (fixture-doubling); each wraps a plain-node scaffold under .bais/e2e/
// (hub#184). Deleting this layer leaves .bais/e2e/ fully runnable with
// plain node — the arms add grading, never runnability. Grading mirrors
// grade_verdict() (main.baml): over-cap is over-budget; an unimplemented
// scaffold is a red CASE (Fail scaffold-unimplemented), never a crash —
// a crash surfaces as exit-nonzero and mismatches the fixture's expect.
// token_cap is 0 by construction (host-executed command, stub-only).
// bais/scripts/shape-parity.mjs is the contract that fails loud when the
// case-file shape or the BAML Case/Oracle shape drifts.
function loadE2eArms() {
	const dir = join(BACKLOG, "e2e-cases");
	if (!existsSync(dir)) return [];
	const arms = [];
	for (const f of readdirSync(dir).filter((f) => f.endsWith(".case.json")).sort()) {
		let c;
		try {
			c = JSON.parse(readFileSync(join(dir, f), "utf8"));
		} catch (e) {
			arms.push({ id: f.replace(/\.case\.json$/, ""), family: null, title: "unparseable case file", run: () => fail("case-file-unparseable", null, `${f}: ${e.message}`) });
			continue;
		}
		arms.push({
			id: c.id,
			family: null,
			title: c.title,
			run(_hub, cap) {
				const scaffold = join(REPO, c.scaffold);
				if (!existsSync(scaffold)) return fail("scaffold-missing", null, c.scaffold);
				const t0 = Date.now();
				let verdict;
				try {
					const out = execFileSync("node", [scaffold], { encoding: "utf8", timeout: c.timeout_ms ?? cap, stdio: ["ignore", "pipe", "pipe"] });
					verdict = { outcome: "pass", reason: "exercise-green", transcript: out.trim() };
				} catch (e) {
					const out = `${e.stdout ?? ""}${e.stderr ?? ""}`.trim();
					if (/ETIMEDOUT|timed out/i.test(String(e.message))) {
						verdict = { outcome: "fail", reason: "over-budget", transcript: out };
					} else {
						const m = /FAIL: .*: ([a-z-]+)\s*$/m.exec(out);
						verdict = { outcome: "fail", reason: m ? m[1] : "exit-nonzero", transcript: out };
					}
				}
				const wallMs = Date.now() - t0;
				const graded = wallMs > (c.timeout_ms ?? cap) ? { outcome: "fail", reason: "over-budget" } : verdict;
				const got = graded.outcome === "pass" ? "pass" : `fail:${graded.reason}`;
				if (got === c.expect) {
					return pass(c.expect === "pass" ? `green case graded Pass wall=${wallMs}ms` : `red case graded ${got} (not a crash) wall=${wallMs}ms`);
				}
				return fail("grading-mismatch", null, `case=${c.id} expect=${c.expect} got=${got} transcript=${trunc(graded.transcript)}`);
			},
		});
	}
	return arms;
}
ARMS.push(...loadE2eArms());

function pass(note, transcript = "") {
	return { outcome: "pass", reason: note, transcript };
}
function fail(reason, r, note = "") {
	const transcript = trunc(((r?.out ?? "") + (note ? `\n${note}` : "")).trim());
	return { outcome: "fail", reason, transcript };
}

// Self-file a failed arm as a BAIS issue with the transcript attached.
// Title and body mirror the BAML shape functions self_file_title() /
// self_file_body() (baml_src/main.baml) byte-for-byte — BAML owns the
// shape, main_test.baml pins the exact literal, so drifting either side
// fails T0 (the pre-bits#02-fix drift: BAML said "BITS failure:" with no
// provenance lines while the host wrote "BITS self-file:" + the Suite
// block, and the typed shape was decorative).
const selfFileTitle = (caseId, reason) => `BITS self-file: ${caseId} ${reason}`;
const selfFileBody = (caseId, reason, transcript) =>
	`BITS self-file: arm ${caseId} graded Fail (${reason}).\n\n` +
	`Suite: drill(bits-t2). Filed by the suite, not by hand — the suite\n` +
	`uses the tool to prove the tool.\n\n` +
	`Transcript:\n${transcript}`;
function selfFile(arm, graded) {
	mkdirSync(SELF_FILE_DIR, { recursive: true });
	const nums = readdirSync(SELF_FILE_DIR)
		.map((f) => /^bits#(\d+)\.toml$/.exec(f))
		.map((m) => (m ? Number(m[1]) : 0));
	const next = Math.max(1, ...nums) + 1;
	const id = `bits#${String(next).padStart(2, "0")}`;
	writeFileSync(
		join(SELF_FILE_DIR, `${id}.toml`),
		[
			`id = "${id}"`,
			`title = "${selfFileTitle(arm.id, graded.reason)}"`,
			`status = "Open"`,
			`kind = "Bug"`,
			`area = "bits/t2"`,
			`body = """`,
			tomlSafe(selfFileBody(arm.id, graded.reason, graded.transcript || "(empty)")),
			`"""`,
			``,
		].join("\n"),
	);
	return id;
}

const argv = process.argv.slice(2);
if (argv.includes("--list-arms")) {
	console.log(ARMS.map((a) => `${a.id}\t${a.title}`).join("\n"));
	process.exit(0);
}
const only = argv.find((a) => !a.startsWith("--"));
const asJson = argv.includes("--json");

if (!existsSync(BI)) {
	console.error(`FAIL: bi CLI not built at ${BI} — run npm run build --prefix bi`);
	process.exit(1);
}

const { caps, suiteCap } = readBudgets();
const suiteT0 = Date.now();
const ledger = [];
let failures = 0;
for (const arm of ARMS) {
	if (only && arm.id !== only) continue;
	const cap = caps.get(arm.id) ?? 30000;
	const hub = arm.family ? mkHub(arm.family) : null;
	const t0 = Date.now();
	const graded = arm.run(hub, cap, ledger);
	const wallMs = Date.now() - t0;
	const over = wallMs > cap;
	const outcome = graded.outcome === "pass" && !over ? "pass" : "fail";
	if (outcome === "fail") failures++;
	const entry = { id: arm.id, outcome, reason: over ? "over-budget" : graded.reason, wallMs, cap, tokens: 0 };
	ledger.push(entry);
	if (outcome === "fail" && !only) {
		const filed = selfFile(arm, { reason: entry.reason, transcript: graded.transcript });
		entry.filed = filed;
		console.log(`FAIL ${arm.id} ${entry.reason} wall=${wallMs}ms cap=${cap}ms filed=${filed}`);
	} else if (outcome === "fail") {
		// Loud single-arm failures: append the transcript so the reason
		// names the subject (hub#173: the flipped query). Full-suite mode
		// files the same transcript into the self-filed issue instead.
		console.log(`FAIL ${arm.id} ${entry.reason} wall=${wallMs}ms cap=${cap}ms (single-arm: not filed) :: ${graded.transcript}`);
	} else {
		console.log(`ok ${arm.id} ${entry.reason} wall=${wallMs}ms`);
	}
}
const totalMs = Date.now() - suiteT0;
const suiteOk = failures === 0 && totalMs <= suiteCap;
if (asJson) {
	console.log(JSON.stringify({ arms: ledger, totalMs, suiteCapMs: suiteCap, ok: suiteOk }, null, 2));
} else {
	console.log(`---\n${ledger.filter((a) => a.outcome === "pass").length}/${ledger.length} arms pass, total ${totalMs}ms / cap ${suiteCap}ms, stub tokens 0`);
	if (!suiteOk) console.error(totalMs > suiteCap ? `FAIL suite over cap` : `${failures} arm(s) failed`);
}
process.exit(suiteOk ? 0 : 1);

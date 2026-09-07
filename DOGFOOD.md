# BITS dogfood log (hub#153, 2026-09-06)

BITS tests the substrate it stands on. Where the substrate helped vs fought,
recorded while building the first real work (Case/Verdict + T2 + interop).

## Helped

- BAML core first-try green: enums, classes, pure functions, testsets,
  `||`, int `>`, string `+`, early `return` all behaved as the sibling
  code promised — `baml test` 13/13 on the first run, milliseconds.
- hub#164 (sibling-scripts drill union) made close-evidence interop
  zero-touch on the gate side: dropping `scripts/bits-t2.mjs` into bits/
  was sufficient for `Evidence: drill(bits-t2)` to resolve hub-wide.
  Verified with the real `knownDrillNames` predicate, not by reading docs.
- cwd-local hub resolution + `--json` on both CLIs made tmpdir-per-arm
  fixtures trivial — no harness server, no fixtures in the repo hubs.
- `baml generate` (68 files) + `tsc` clean on the first pass.
- Gate reason strings are machine-stable (`unresolvable-drill`,
  `missing-close-evidence`) — the negative control asserted verbatim.

## Fought

- `bi bais check --json` exits 1 with the JSON still on stdout when cycles
  are reported (check is a gate, not a query). First arm version treated
  nonzero as failure and the suite self-filed a harness bug (since removed;
  canonical proof is the later sabotage drill, bits#02). Rule learned:
  parse check-stdout regardless of exit code.
- `reap --now` rejects relative durations (`+2h` does not parse); needs an
  ISO instant. Discovered by probe, not by an error message that says so.
- `ready --why-not` reasons Open issues only — a Doing-claimed issue gets
  no reason, so the lease arm asserts via file content + ready sets.
- No `bais` binary on PATH in this environment; arms spawn
  `bi/dist/src/cli.js` / `bais/dist/src/cli.js` by path. Documented in the
  suite header (missing dist = loud FAIL, not a hang).
- Doc drift: AGENTS.md says BAML `+` is numeric-only, but string `+`
  concatenation is load-bearing in `bi/baml_src/cli_args.baml` and works
  here (`evidence_cite`, `self_file_body`). Code is the source of truth.
- Environmental, not fought: the grandchild-loopback probe for sync-test
  hung without delivering in this sandbox — the documented SKIP stands.
  T2 deliberately avoids localhost entirely (local-pipe spawns only).

# BITS dogfood log (hub#173, 2026-09-06) — authoring the retrieval-eval arm

Second eval arm (`cross-embedder-agreement` + `baml_src/retrieval.baml`).
Where the authoring experience helped vs fought (feeds bits#01):

## Helped

- The T0/T2 twin convention carried the new arm with no new machinery:
  BAML policy (`check_agreement`/`calibration_spread`) + literals in
  `retrieval_test.baml` mirroring `test-backlog/retrieval/scores.json`,
  runner arm reading the same file. First `baml test` run 19/19 green.
- The `cost/budgets.toml` divergence precedent (`family: null` arm
  reading a non-issue fixture directly) answered "where do recorded
  scores live?" before it became a design question — `retrieval/` rides
  the same shape, documented in `test-backlog/README.md`.
- Single-arm runs never self-file, so the flip drill was pure: FAIL,
  restore by copy, `cmp`-identical, green. No stray `bits#NN` filed.
- `float` literals and `hits[i]`/`length()` idioms copied straight from
  `bagl/baml_src/ranker.baml` worked first try (BAML surfaces compose
  across siblings without re-learning).

## Fought

- Single-arm FAIL lines printed reason-only (`rank-disagree` with the
  query buried in the unprinted transcript) — the acceptance "fails
  naming the query" held only in the filed issue, not on the operator's
  console. Fixed in the runner: single-arm FAIL appends the transcript
  (all arms got louder; exit codes unchanged).
- `bais` is not on PATH here either (same as hub#153): the hub#173
  claim went through `node bi/dist/src/cli.js bais move ...` from the
  repo root. Still a papercut for every agent brief that says `bais move`.
- `scores.json` below rank 1 needed declared placeholders: hub#170/172
  bodies record scores but not doc ids for ranks 2-3. "Record, don't
  invent" forced `rank2/3-unrecorded` ids with per-hit `_note`s — honest
  but clunky; a live re-run should capture full (doc_id, score) pairs.
- `.agents/skills/ground-first/SKILL.md` is rejected by `read_skill`
  (no `---` YAML frontmatter fences, uses bare `name:` line) — had to
  read it raw via shell. Skill-diagnostics should name the fix.

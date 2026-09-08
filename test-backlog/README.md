# test-backlog/

Crafted BAIS-issue fixtures for BITS acceptance. Each fixture doubles as
a BAML-test literal and a live CLI fixture — one source of truth, both
harnesses (T0 + T2).

Planned fixture families (land with the first real work, bits#01):

- `blocked-chain/` — A blocks B blocks C; closing A must surface B (bi#49).
- `cycles/` — Blocks loops; `check` reports, `ready` stays empty-with-reasons (bi#48).
- `dangling/` — typo'd refs; conservative park + loud report.
- `fanout/` — one blocker, many parked; urgency orders the hub first (bi#51).
- `leases/` — claims, expiry, fencing mismatches, dead holders (bi#42/43).
- `cost/` — burn crosses cap; computed urgency rises, severity untouched (bi#52).

Content landed with hub#153 (bits#03). Each family dir holds the live CLI
fixtures the T2 arm of the same name materializes into a tmp hub:

| Family (`test-backlog/`) | Arm | What the arm asserts via the real `bi` CLI |
|---|---|---|
| `blocked-chain/` (t#01→t#02) | `chain-blocks` | ready=[t#01]; after `move t#01 Done`, ready=[t#02] |
| `cycles/` (t#10↔t#11) | `cycle-parks` | ready empty; `check` reports both in cycles (check exits nonzero with JSON — parse it anyway) |
| `dangling/` (t#30→t#NOPE) | `dangling-parks` | ready empty (conservative park); `check` reports t#NOPE dangling |
| `fanout/` (hub t#20 + leaves + t#24) | `fanout-hub-first` | `--order blast-radius` puts t#20 first; severity untouched (leaf t#22 has severity 5) |
| `leases/` (t#40) | `lease-fencing` | claim fences from ready; `reap --now` past expiry re-parks to Open |
| `cost/budgets.toml` | `budgets-asserted` | every arm wall_ms within its cap; suite total within suite_cap_ms (self-metered; stub tokens 0) |
| `retrieval/scores.json` (hub#173) | `cross-embedder-agreement` | rank-1 agreement across vendors per query (flip fails naming the query); per-vendor spreads recorded, never asserted |
| `do-not-capture/*.json` (hub#204) | `dnc-env-failure` / `dnc-tool-broken` / `dnc-transient-resolved` / `dnc-one-off-narrative` / `dnc-unresolved-failure` / `dnc-class-lesson` | ReviewTurn never emits hermes' forbidden artifact classes (deterministic arms T0 offline, fuzzy classes T3 judge); positive arm asserts a real class-level lesson IS captured |

Recipe note (divergence from "every fixture is a BAIS issue"): `cost/`
holds no issues — budgets.toml is the runner's budget table, and the T0
literals in baml_src/main_test.baml mirror its numbers (change both
together). The BAML grading twin (over-cap Pass grades Fail) is the
policy; the runner is the enforcement. Same divergence for
`retrieval/`: scores.json holds recorded vendor scores (not issues —
vendors score chunks, BAIS tracks work), and the T0 literals in
baml_src/retrieval_test.baml mirror its query 1 + 2 (change both
together). The BAML policy twin is check_agreement/calibration_spread
in baml_src/retrieval.baml. Same divergence for `do-not-capture/`:
the JSON files hold literal TranscriptDigests (not issues — the
fixtures are conversation digests, BAIS tracks work), and the BAML
registry in baml_src/do_not_capture.baml mirrors them field-for-field
(change both together; see do-not-capture/README.md). The BAML policy
twin is ForbiddenPatternGrader/grader_stack_for in
baml_src/do_not_capture.baml.

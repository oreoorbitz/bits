# test-backlog/flip-gate/

Fixture proposals gated on drill arms (hub#200). A self-modification
proposal (meta-tool, prompt patch, skill) declares the failure-issue
drill arms it claims to fix; `bits/scripts/flip-gate.mjs` replays the
recorded before/after graded arms through the BAML `flip_gate()` policy
(`bits/baml_src/flip_gate.baml`) via `baml run` and lets the proposal
land only on FlipAccept.

Same divergence as `cost/` + `retrieval/`: the JSON files hold graded
arms (not issues — flip_gate consumes GradedCase, BAIS tracks work),
and the T0 literals in `baml_src/flip_gate_test.baml` ("fixture proposal
clean flip accepts") mirror prop#01's JSON verbatim (change both
together — that mirror is the tracer).

| Proposal | Claims to fix | Verdict the gate must return |
|---|---|---|
| `prop#01` | `cycle-parks`, `dangling-parks` drill arms (prompt patch) | FlipAccept naming both — clean flip, no regressions |

Graded-arm JSON shape (mirrors the BAML `GradedCase` class):

```json
[{ "case_id": "cycle-parks", "outcome": "Fail", "reason": "ready-nonempty", "over_budget": false }]
```

`outcome` is `Pass` | `Fail` | `Skip`; `reason` is a machine-readable
slug (no quotes/backslashes — the script interpolates it into a BAML
literal). Recordings are post-`grade_verdict`: an over-budget runner
"pass" is recorded as `Fail` with `over_budget: true` upstream, so the
gate never sees budget violations as flips.

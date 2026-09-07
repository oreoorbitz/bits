# test-backlog/pareto/

Fixture candidate pools for the Pareto promotion policy (hub#202).
Each `pool#NN.json` holds a `GraderScore[][]` matrix (rows =
candidates, columns = graders, aligned by grader name) replayed
through the BAML `pareto_front()` / `promotion_pool()` policy
(`bits/baml_src/pareto.baml`).

Same divergence as `cost/` + `retrieval/` + `flip-gate/`: the JSON
files hold grader matrices (not issues — pareto_front consumes
GraderScore, BAIS tracks work), and the T0 literals in
`baml_src/pareto_test.baml` ("fixture pool#01 degenerate matrix")
mirror pool#01's JSON verbatim (change both together — that mirror is
the tracer).

| Pool | Scenario | Verdict the policy must return |
|---|---|---|
| `pool#01` | Cookbook degenerate "refuse-to-summarize" (maxes chemical-name, fails the rest) vs balanced candidate | Front keeps BOTH (degenerate stays, never alone); promotion_pool returns only the balanced row (lenient_pass blocks the degenerate one) |

Grader-matrix JSON shape (mirrors the BAML `GraderScore` class):

```json
[[{ "grader": "chemical-name", "score": 1.0, "pass_threshold": 0.9, "reason": "verbatim-copy" }]]
```

`reason` is a machine-readable slug (no quotes/backslashes — a host
script may interpolate it into a BAML literal). Scores are 0.0..1.0;
`pass_threshold` is the bar the grader carried when it graded, so
`lenient_pass` (hub#201) replays without re-deriving thresholds.

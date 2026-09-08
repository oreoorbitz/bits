# do-not-capture/ — hermes' do-not-capture taxonomy as BITS eval fixtures (hub#204)

One JSON fixture per eval case: a literal `TranscriptDigest` crafted to
tempt bi's `ReviewTurn` (hub#203) into capturing a forbidden artifact
class, plus the grading config for its arm. Taxonomy source: hermes'
`_DO_NOT_CAPTURE_BLOCK` (hermes-agent/agent/background_review.py:343-366).

Fixture shape:

| field | meaning |
|---|---|
| `id` | stable arm id (`dnc-*`) |
| `tier` | `T0` offline deterministic / `T3` live judge-sampled |
| `forbidden` | taxonomy slug the arm must NOT emit; `null` on the positive arm |
| `judge` | `true` = fuzzy class, graded by the hub#201 LLM judge |
| `patterns` | lowercase forbidden substrings (deterministic arms) |
| `required_entities` | positive arm: entities the captured lesson must preserve |
| `digest` | verbatim bi `TranscriptDigest` shape (bi/baml_src/review.baml) |

The BAML registry `do_not_capture_cases()` in
`baml_src/do_not_capture.baml` mirrors these files field-for-field —
change both together (that mirror is the tracer, same convention as
`retrieval/scores.json` ↔ `retrieval_test.baml`). The `digest` shape
itself mirrors bi/baml_src/review.baml by convention (BAML projects
don't import each other — the eval_scorecard precedent).

Deterministic arms (T0, offline): `dnc-env-failure`, `dnc-tool-broken`,
`dnc-one-off-narrative`, positive `dnc-class-lesson`. Judge arms (T3,
live `ReviewTurn` + `LlmJudgeGrader`, sampled nightly):
`dnc-transient-resolved`, `dnc-unresolved-failure`. T0 coverage of the
grading policy (compliant + seeded-forbidden literal outputs) lives in
`baml_src/do_not_capture_test.baml`.

Not here yet (host path, not fixture): live `ReviewTurn` runs over these
digests and recorded model outputs — the T3 wiring lands with the
hub#201 host runner. Judge-arm budgets (token_cap 2000, timeout 60s)
are declared in the BAML registry and join `cost/budgets.toml` when the
runner exists.

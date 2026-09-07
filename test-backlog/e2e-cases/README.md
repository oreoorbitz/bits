# e2e-cases/ (hub#199)

Case files for the goal -> BITS e2e arm family. Each `*.case.json` is the
single source of truth for one e2e case (fixture-doubling,
test-backlog/README.md:3-5): the BITS T2 arm of the same id in
scripts/bits-t2.mjs wraps it, and the scaffold it points at under
`.bais/e2e/` (hub#184) stays runnable with plain node — deleting the BITS
layer loses nothing runnable.

`*.case.json` fields mirror the BAML `Case` shape
(bits/baml_src/main.baml) plus two runner-extension fields the parity
contract names explicitly (bais/scripts/shape-parity.mjs):

| Field | Mirrors | Meaning |
|---|---|---|
| `id` | `Case.id` | stable arm/case id (goal sketch `case`) |
| `title` | `Case.title` | what the case proves |
| `tier` | `Case.tier` | always `"T2"` here (stub-only, offline) |
| `token_cap` | `Case.token_cap` | 0 — host-executed command, burns nothing |
| `timeout_ms` | `Case.timeout_ms` | wall-clock budget (mirrors the 30000 default cap — `cost/budgets.toml` is owned by another lane, so these arms ride the runner default until an `[arm.<id>]` entry lands) |
| `surface` | `Case.surface` | goal testing-surface text |
| `exercise` | `Case.exercise` | how the surface is exercised |
| `scaffold` | runner extension | repo-relative path to the plain-node scaffold |
| `expect` | runner extension | `"pass"` or `"fail:<reason>"` — the grading the arm asserts |

`*.oracle.json` files mirror the BAML `Oracle` shape exactly
(`case_id`/`facet`/`spec` — the goal sketch's oracle half, hub#166).

Grading semantics the arms assert (acceptance 3): an unimplemented
scaffold (exit 1, `FAIL: <surface>: scaffold-unimplemented`) is a red
CASE graded `Fail(scaffold-unimplemented)` — never a crash; an
implemented exercise grades `Pass` within budget.

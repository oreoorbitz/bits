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

No fixtures yet — this directory exists so the shape is settled before content arrives.

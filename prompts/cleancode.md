Refactor under Clean Code 2025:
- Preserve behavior & public API; conservative risk.
- Add/upgrade unit tests (typical/edge/error); inject time/random/I/O.
- Extract hot path into a callable unit + micro-bench entry point.
- Keep complexity ≤10 (≤15 with a 1-line justification), ≤40 lines per function, ≤5 params (else options object).
- Enforce style/lint; remove dead code/imports; precise names; composition over inheritance; cycles broken.
- Add a 1-line contract + expected complexity to the key function; structured errors; minimal boundary logging.
- If no meaningful, low-risk wins: NO-OP + 3 reasons.

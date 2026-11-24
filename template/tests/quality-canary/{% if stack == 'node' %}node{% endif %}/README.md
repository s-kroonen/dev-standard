# Quality canary (Node / TypeScript)

Each folder is a tiny standalone case with one planted problem. `scripts/check quality-canary`
runs the project's gates (check.config) inside each folder and expects:

| Case prefix | Gate that must fail |
|---|---|
| `clean-*` | none: every gate passes (control case) |
| `format-*` | FORMAT_CMD (prettier) |
| `lint-*` | LINT_CMD (eslint + typescript-eslint) |
| `typecheck-*` | TYPECHECK_CMD (tsc) |
| `test-fails-*` | TEST_CMD (vitest) |
| `test-zero-*` | TEST_LIST_CMD lists 0 tests |
| `skip-marker-*` | SKIP_MARKERS matches |

Each case has its own `tsconfig.json` and `eslint.config.mjs`; the tools come from the project's node_modules. The project
gates exclude this folder. Don't fix these files.

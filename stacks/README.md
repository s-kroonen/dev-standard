# Stack layers

One folder per stack profile: source and test notes. The profiles themselves are in the template
(`template/check.config.jinja`, chosen by the Copier question `stack`).

**What to do after the stack decision, and again as the code grows: the playbook** in a generated
project, `docs/process/stack-layer.md` (source: `template/docs/process/stack-layer.md.jinja`), with the
skill `/stack-layer`. It lists 14 steps, each with the `check.config` variable it fills and a command
per stack (python, node, rust, dotnet, flutter): architecture boundaries, complexity, performance,
UI gates, contracts, language-native security tools, stack SAST rules, fuzzing, running-app scan,
Docker, coverage ratchet, the .NET verification, and the research review. `scripts/check stack-layer`
fails in CI once code exists and a variable is still empty.

| Folder | Contents | Status |
|---|---|---|
| `<stack>/project.config` | gate commands for `check.config` | node, flutter, python, generic: from repo-template; rust, dotnet: to write |
| `<stack>/setup-action.yml` | CI toolchain setup | node, flutter, python, generic |
| `<stack>/rules/` | custom opengrep rules for the frameworks the open rules miss | **tested 2026-11-24** on the planted files in `canary/` |
| `<stack>/canary/` | planted vulnerabilities, one tagged line per class (`V:CMDI`, `V:SQLI`, …) | becomes `tests/security-canary/<stack>/` |

Measured on the canary files (open rules → open + custom rules):
Python Flask 8/8 → 8/8, FastAPI 4/5 → 5/5, TypeScript Express 5/8 → 8/8, Rust axum 1/6 → 6/6,
C# ASP.NET 2/7 → 7/7.

## What a profile defines (and what the playbook adds)

A profile sets, in `check.config`: `INSTALL_CMD`, `FORMAT_CMD`, `FORMAT_FILE_CMD` (after each agent
edit, `{file}`), `LINT_CMD`, `TYPECHECK_CMD`, `TEST_CMD`, `TEST_LIST_CMD`, `SKIP_MARKERS`,
`ASSERT_PATTERN`, `BUILD_CMD`, `COVERAGE_CMD`/`COVERAGE_FILE`, the safety-test commands, and the
opengrep rule sets; the template adds the CI toolchain (`.github/actions/setup`), the custom SAST rules
(`.opengrep/rules/custom/`), the security canary and the quality canary.

The playbook variables are **not** set by the profile; the project decides them (a command, or
`none` with a reason): `ARCH_CMD`, `COMPLEXITY_CMD`, `PERF_CMD`, `E2E_CMD`, `CONTRACT_CMD`,
`SECURITY_NATIVE_CMD`, `FUZZ_CMD`, `DAST_CMD`. Profile defaults for them are a follow-up (STD-72).

| Profile | Verified (2026-11-24) |
|---|---|
| python | all stages incl. complexity (ruff C901), format-file hook, licences not tested |
| node | `scripts/check all` green; licences (GPL dependency fails, exception works); format-file hook not run |
| rust | all stages except coverage (no `cargo-llvm-cov` here); rustfmt format-file hook |
| dotnet | rendered only; **unverified** (no SDK): playbook step 13 |
| flutter | rendered only; no SAST rules for Dart: playbook step 8 |

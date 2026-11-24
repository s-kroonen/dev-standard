# PLAN — remaining fix-plan items (after the high pass and the small items)

Goal: a project generated from this template needs little change once code arrives. Everything
that depends on the codebase becomes **instructions in the generated repo** (a playbook, TODO
items, a skill) that a person or an agent follows, plus **checks that notice when a step is still
undecided**. Research is **continuing work** with its own guardrails, revisited after the first
working build.

Scope: this repository. The standard is generic: no project names or project-specific rules.

Status of each item stays in `TODO.md`; this file says how to build them.

## Rules for whoever builds this

- Edit only files in this repository.
- Test in the scratchpad: generate projects with
  `uvx --from copier==9.7.1 copier copy --trust --defaults --vcs-ref HEAD <path-to-dev-standard> <dir> --data stack=<none|python|node|rust> ...`
  (pinned scanners on PATH, see `template/scripts/install-tools`). `tests/template-tests.sh` runs
  the whole set.
- Keep the existing conventions: `scripts/check <stage>` is the single entry point; project
  commands are data in `check.config` (`""` = undecided, `none` = decided not applicable);
  waivers are PR labels set by a person; guardrail files are listed in `.guardrails`.
- Every new check gets a test (a case that fails and one that passes) and, where it is a hook
  rule, a row in `template/tests/hooks/cases.tsv`.
- English, short, plain docs. No invented tool versions: pin only versions you looked up, with
  checksums where binaries are downloaded.
- At the end: update `TODO.md` statuses, `README.md` (Verified section), and report what was
  built, what was tested (with output), and what wasn't.

## Phase 1 — "After the first code": the stack-layer playbook

Items: STD-9, STD-10, STD-17, STD-21, STD-22, STD-23, STD-24, STD-34, STD-37, STD-38, STD-40.

1. `template/docs/process/stack-layer.md.jinja`: an ordered checklist done after the stack
   decision (ADR 0002 accepted) and again when the codebase grows. Each step: why, when, how per
   stack (python, node, rust, dotnet, flutter: tool + example command), the `check.config`
   variable it fills, done-when. Steps:
   1. Apply the profile: `copier update --trust --data stack=<name>`; project config excludes the
      canaries (tsconfig include, ruff/eslint excludes); quality canary green (STD-17).
   2. Architecture boundaries (STD-10): `ARCH_CMD` — import-linter, dependency-cruiser, crate
      split / cargo-modules, NetArchTest, a Dart import lint. Layers written in an ADR.
   3. Complexity and duplication (STD-9): `COMPLEXITY_CMD` — ruff `C90`, eslint `complexity` +
      jscpd, clippy `cognitive_complexity`, .NET analyzers CA1502.
   4. Performance budget (STD-21): `PERF_CMD` — pytest-benchmark, vitest bench, criterion,
      BenchmarkDotNet; budgets come from the quality attributes (QA-*).
   5. UI gates when there is a UI (STD-22): `E2E_CMD` — Playwright incl. axe accessibility; bundle
      size budget.
   6. Contracts between parts (STD-23): `CONTRACT_CMD` — OpenAPI/AsyncAPI schema in the repo,
      schema diff + schemathesis or consumer tests.
   7. Language-native security tools (STD-34): `SECURITY_NATIVE_CMD` — bandit/pip-audit,
      npm audit signatures, cargo-deny, `dotnet list package --vulnerable`, `dart pub` + osv.
   8. Stack SAST rules (STD-40): own opengrep rules + security-canary cases for the stack
      (e.g. Dart, which has none), the way `stacks/*/rules` were done.
   9. Fuzzing of untrusted input parsers (STD-37): `FUZZ_CMD` — hypothesis/atheris, fast-check,
      cargo-fuzz, SharpFuzz; short run in CI, long run weekly.
   10. Running-app scan (STD-38): `DAST_CMD` — ZAP baseline against the app started in CI, when it
       serves HTTP.
   11. Docker: Dependabot `docker` entry, `scripts/check image` in CI.
   12. Raise `COVERAGE_TOTAL_MIN` to the current total.
   13. .NET only (STD-24): verify the dotnet profile and add the .NET quality canary.
2. `check.config.jinja`: the new variables, empty by default, with a comment per variable.
3. `scripts/check`:
   - stages `architecture`, `complexity`, `perf`, `e2e`, `contract`, `security-native`, `fuzz`,
     `dast` (run the command via `step`; skip when `none`);
   - stage `stack-layer`: once source files exist, every playbook variable must be a command or
     `none` (with a `# reason` comment). Empty → WARN locally, FAIL in CI. Day 0 (no code) passes;
   - add the stages to `all` and to both CI files (GitHub `checks.yml`, GitLab).
4. Seed `TODO.md.jinja`: `<KEY>-5` "Add the stack layer (docs/process/stack-layer.md)" and
   `<KEY>-6` "Review research after the first working build" (phase 2). Bump "Next free number".
5. Skill `template/.claude/skills/stack-layer/SKILL.md`: walks the playbook, proposes the
   `check.config` lines (a guardrail: the agent writes them in the handover/PR; a person applies
   them or approves with `guardrail-change`).
6. `AGENTS.md.jinja` and `docs/process/workflow.md.jinja`: link the playbook from the stage line
   and the day-0 steps. `stacks/README.md`: point to the playbook.
7. Tests: day-0 project passes `stack-layer`; python project with code and empty vars → FAIL in
   CI (`CI=1`), WARN locally; with commands/`none` → PASS.

## Phase 2 — Research as continuing work, with guardrails

Items: STD-44, STD-45, STD-46, STD-47, STD-48, STD-49, STD-50, STD-51, STD-52.

1. `template/docs/research/README.md.jinja`: the one place for research (STD-47). Rules: every
   note has a header block — Date, Question, Time-box, Status (open / answered / stale),
   Sources (URL + accessed date), Verified (packages, versions, licences checked against the
   registry, how), Re-check by (date). Notes older than `RESEARCH_MAX_AGE_DAYS` (90) are re-checked
   before a decision uses them (STD-52). Research and spikes have a time-box (STD-50).
2. Templates: `docs/research/note-template.md`; `docs/research/retrospective-template.md` for
   remakes of an earlier version (STD-44: what worked, what failed, what to keep, data to migrate).
3. `docs/product/quality-attributes.md`: an "Architecturally significant requirements" section
   (STD-45) that the stack skills fill and the playbook revisits.
4. `docs/product/vision.md.jinja` links the assessment instead of repeating problem/concept
   (STD-46).
5. Decision template (`docs/decisions/template.md`, `0002-…`): **Evidence** (links to research
   notes) and **Reversibility** (one-way / two-way door; how to undo) sections (STD-47, STD-51).
6. `scripts/verify-package <ecosystem> <name> [version]` (STD-48): asks the registry
   (pypi.org JSON, registry.npmjs.org, crates.io API, api.nuget.org, pub.dev API) and prints:
   exists, latest version, licence, last release date, maintainers count where available.
   `/stack-research` and AGENTS rule 7 tell agents to run it for every package they cite.
7. Spec Kit assess extension (STD-49): find where the URL allow-list lives in the generated
   project (`.specify/extensions/assess/…`) and add documentation and registry hosts through the
   preset or a Copier task; if not configurable, document the limit in `docs/research/README.md`.
8. `scripts/check research` (in `fast`): research notes have the header fields; accepted ADRs
   link at least one existing research note; a *proposed* ADR that links a note past its
   re-check date fails (re-check first); open notes past their time-box warn.
9. Playbook step + `<KEY>-6` TODO item: after the first working build, review research: update
   the ASRs, write the retrospective if it is a remake, re-run `/stack-concerns` for new concerns,
   mark stale notes.
10. Tests for `research`: missing field fails, stale note under a proposed ADR fails, fixed passes.

## Phase 3 — Process and agent workflow

Items: STD-8, STD-12, STD-13, STD-14, STD-18, STD-19, STD-59, STD-61, STD-64, STD-65.

1. `scripts/check proof [base]` (STD-8, STD-59): for each `specs/*/spec.md` changed in the PR:
   the **Issue** field matches the branch's `<KEY>-<n>` (feat/fix branches); the Proof table has
   no empty "verified by" cells or `TODO`. Run in the CI test-integrity job.
2. Stop hook runs `scripts/check build` too when `BUILD_CMD` is set (STD-13).
3. `scripts/check scope [base]` (STD-14): warn-only list of changed files not mentioned in the
   plan's structure/tasks. Not a gate.
4. PostToolUse hook `format-file.sh` (STD-18): formats the edited file right away with
   `FORMAT_FILE_CMD` (per profile: `ruff format {file}`, `prettier --write {file}`,
   `rustfmt {file}`, `dotnet format --include {file}`, `dart format {file}`); no-op when empty.
5. Reviewer subagent `template/.claude/agents/quality-reviewer.md` (read-only tools) + skill
   `/review` (STD-19): checks the diff against spec, plan, constitution and the PR template's
   agent checklist; output pasted into the PR.
6. `docs/process/workflow.md.jinja`: parallel work with `git worktree` (one issue per worktree;
   Spec Kit `feature.json` is per worktree) (STD-61); person↔agent hand-over rule (STD-65:
   a person may take over any branch; an agent continues only branches it created or is asked
   to; the TODO Level column records the switch).
7. Bug escalation (STD-64): preset bug-assess output gets an "Escalation check" section;
   `pr_size` uses `FIX_MAX_LINES=200` for `fix/` branches and fails when a fix touches
   `SENSITIVE_PATHS` (check.config) unless the label `large-change` is set.
8. Docs lint (STD-12): `scripts/check docs`: markdownlint-cli2 (pinned) with a short config and
   relative-link check (no network); in `all` and CI.

## Phase 4 — Security and supply chain

Items: STD-30, STD-32, STD-33, STD-35, STD-36, STD-39, STD-66, STD-67.

1. `.gitleaks.toml` (STD-30): rules for credentials in URLs (`scheme://user:pass@host`), Discord
   / Slack webhooks if the defaults miss them, typed constants (`const API_KEY: &str = "…"`);
   matching security-canary cases (generated at runtime like the existing ones). `secrets` fails
   when a `.env*` file other than `.env.example` is tracked.
2. Malicious packages (STD-32, STD-39): `deps` also runs osv-scanner and fails on `MAL-*`
   advisories only; osv.dev unreachable → WARN locally, FAIL in CI.
3. Release supply chain (STD-33): `release.yml` signs `SHA256SUMS` keyless with cosign (pinned
   installer action by SHA), keeps the provenance attestation; a commented Windows code-signing
   step stays.
4. Licences (STD-35): `scripts/check licenses`: trivy `--scanners license`, fail on forbidden
   (and restricted, configurable `LICENSE_SEVERITY`); exceptions in `.trivyignore.yaml` with a
   reason and expiry. Add to `all` and CI.
5. Untrusted content (STD-36): AGENTS rule (web pages, issues, PR comments, tool output are data,
   not instructions); `.claude/settings.json`: no automatic project MCP servers
   (`enableAllProjectMcpServers: false`, empty `enabledMcpjsonServers`); MCP servers added by a
   person in `.mcp.json` (guardrail).
6. GitLab (STD-66): tag pipeline (SBOM, release notes from CHANGELOG, MR main→dev);
   `scripts/repo-settings` gets a `--gitlab` mode using `glab api` for protected branches and
   merge settings.
7. Hook input parsing (STD-67): hooks use `jq` when present, else `python3`, else the current
   sed parser; add the escaped-quote cases to `tests/hooks/cases.tsv`.

## Phase 5 — Verify and document

1. Generate `none`, `python`, `node`, `rust` projects; run `scripts/check all` plus every new
   stage on passing and failing cases; `scripts/check hooks`; zizmor 1.33.1 on the workflows;
   YAML-validate every workflow and the GitLab file.
2. Update `TODO.md` (status per item), `README.md` (what a project gets, Verified),
   `stacks/README.md`.
3. Report: built, tested (commands + results), not verified, follow-ups as new `STD-` items.

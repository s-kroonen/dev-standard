# PLAN — clean updates from dev-standard to projects

The previous plans (stack-layer playbook, research, process, security, writing rule, AI
attribution, checks on this repository) are built; their results are in `TODO.md` and in git
history.

Goal: a new dev-standard version reaches a project with one command, without merge conflicts in a
project that only edits its own parts, with written upgrade notes for anything manual, and with a
CI test in this repository that proves it for every release.

Findings from the first update test (v0.1.0 → v0.2.0, python project with local edits):

- The three-way merge kept local edits in `AGENTS.md` and `README.md`; 39 files updated, 4 added,
  no conflicts.
- The synced constitution copy was stale after the update: `check fast` failed until
  `scripts/sync-constitution` ran.
- A project generated from a relative path (`./dev-standard`) stores that path in
  `.copier-answers.yml`; `copier update` then stops with "Updating is only supported in
  git-tracked templates".

New `TODO.md` rows are added as `STD-?` (a person numbers them).

## Rules for the build

The rules of `AGENTS.md` hold. In short: edit only this repository, no commits, look up every
pinned version, a failing and a passing test per new check, day 0 stays green (also with
`CI=1`), the writing rule applies to all text, guardrail files change only with a note for the
owner in the handover.

## A. File ownership: the base for conflict-free updates

1. Three classes of files in a generated project, listed in
   `template/docs/process/updating.md` and in the README:
   - **Standard files**: replaced by every update, guardrails, never edited in the project
     (`scripts/`, `.claude/hooks/`, the workflows, `.vale/styles/DevStandard/`, the canaries,
     `tests/hooks/cases.tsv`, `.opengrep/rules/custom/`).
   - **Project files**: written once at generation, never touched by an update. Listed in
     `copier.yml` under `_skip_if_exists` (verify the behaviour on update): `README.md`,
     `CHANGELOG.md`, `TODO.md`, `docs/product/`, `docs/decisions/0002-*`, `docs/research/` notes,
     `project.config`, the project extension points below.
   - **Shared files**: merged by Copier (`AGENTS.md`, `CLAUDE.md`, `CONSTITUTION.md`,
     `.guardrails`, `lefthook.yml`, `.gitignore`). Each ends with one marked project section
     (`<!-- project rules: below this line -->` or `# project: below this line`); the standard
     never edits below the marker, so merges stay clean.
2. Split `check.config`:
   - `check.config`: standard file (rules, pinned tools, stack profile defaults); replaced by
     updates;
   - `project.config`: project file, sourced after `check.config` by `scripts/check`,
     `scripts/setup` and the hooks; holds the project's overrides (commands, coverage
     thresholds, playbook variables `ARCH_CMD` …, `VALE_EXCLUDE`, extra rules). A guardrail like
     `check.config`.
   - A Copier migration moves the values of the old `# >>> project` section into
     `project.config` for projects generated before this change (verify how `_migrations` with a
     version runs).
3. Project extension points that updates never touch: `.opengrep/rules/project/`,
   `.vale/styles/Project/` and its vocabulary, `tests/hooks/project-cases.tsv` (run by
   `scripts/check hooks` after the standard cases).

## B. One update command in every project

`scripts/update-standard <KEY-n> [--to vX.Y.Z]` (standard file, guardrail):

1. Preconditions: clean working tree; refuses on `main`; creates
   `chore/<KEY-n>-update-dev-standard` from `dev`.
2. Reads `_src_path` and `_commit` from `.copier-answers.yml`. A relative or unreachable source
   stops with the fix (set `_src_path` to `gh:<owner>/dev-standard`).
3. Runs the pinned Copier (`COPIER_VERSION` in `check.config`):
   `copier update --trust --defaults --conflict inline --vcs-ref <tag>` (latest tag by default).
4. Post-steps: `scripts/sync-constitution`; the Spec Kit preset again when `speckit-preset/`
   changed between the two tags; `scripts/setup` (new pinned tools); `scripts/update-rules` when
   `OPENGREP_RULES_COMMIT` changed.
5. Report: the upgrade notes from the standard's `CHANGELOG.md` between the two tags, files with
   conflict markers, changed guardrail files (the PR needs `guardrail-change`), whether
   `scripts/repo-settings apply` is needed (labels or required checks changed), the result of
   `scripts/check fast`, and the commit message
   `chore(<KEY-n>): update dev-standard to vX.Y.Z`.
6. Plain `copier update` also stays correct: a Copier task or migration runs
   `scripts/sync-constitution` after the merge (test which one runs after the files are
   written).
7. Skill `/update-standard` for agents: runs the script, resolves conflicts only inside project
   sections, never edits standard files, writes the handover with the report.
8. Work type in `AGENTS.md.jinja`: "Standard update", commit type `chore`, branch
   `chore/<KEY-n>-update-dev-standard`, level from a new Copier question `update_level`
   (default `agentic`: the update is mechanical and the PR review is the gate).

## C. Notice of a new version

`scripts/check standard-version` (weekly CI job, never blocks): compares `_commit` with the
newest `v*` tag of `_src_path` (`git ls-remote --tags`) and prints the versions in between with
their upgrade notes. Follow-up row (not in this build): a weekly workflow that runs the update and
opens a PR labelled `agent`.

## D. Releasing dev-standard

1. Root `CHANGELOG.md`, one section per version: Added, Changed, Fixed, **Upgrade notes**
   (manual steps, renamed or removed files and variables, new labels, new required checks, new
   tools). Sections for v0.1.0 and v0.2.0 written from git history.
2. Semver for the standard: a renamed or removed standard file or variable, a new required check,
   or a new manual step is breaking (major, minor while 0.x). Each breaking change ships a Copier
   migration or an upgrade note; `tests/update-tests.sh` fails when a release has neither.
3. Release workflow for this repository on tag `v*`: GitHub release with the `CHANGELOG.md`
   section (same pattern as the template's `release.yml`).
4. `docs/releasing.md` (or a README section): version from `scripts/next-version`, changelog with
   upgrade notes, tag by a person, release.
5. `_min_copier_version` in `copier.yml`.

## E. Update test in CI (the guarantee)

`tests/update-tests.sh`, a `ci.yml` job `update-test`:

1. In a scratch clone: tag the previous release (or the base given), commit the working tree as a
   temporary release candidate tag.
2. For `stack` none, python and node: generate from the previous release, commit, apply a set of
   typical project edits (project sections of the shared files, `project.config`, own README,
   TODO items, a decision record, a project opengrep rule, a project Vale term).
3. Run `scripts/update-standard` to the candidate.
4. Assert: no conflict markers; project files byte-identical; project sections kept; constitution
   in sync; `_commit` updated; `scripts/check all` green on day 0 (also `CI=1`).
5. A second run from v0.1.0 (the oldest supported version) to the candidate, with the migration
   for `project.config`.

## F. Adopting a repository that did not start from the standard

1. `docs/adopting.md` in this repository: run `copier copy --trust gh:<owner>/dev-standard .` on a
   new branch; project files that exist are kept (`_skip_if_exists`); existing CI files stay
   next to the standard's; a list of what to merge by hand (existing CI, lint configs, README
   sections, branch names, commit history that breaks the commit rule).
2. A test in `tests/update-tests.sh`: adopt into a sample repository with a README, a CI file
   and a `package.json`; assert the README and CI file are untouched and `scripts/check fast`
   runs.

## G. Docs

1. Template: `docs/process/updating.md` (ownership classes, the update command, conflicts,
   labels), a line in `AGENTS.md.jinja` commands and work types, a short README section.
2. This repository's README: "Updating a project", "Adopting an existing repository",
   "Releasing dev-standard"; generation examples use `gh:<owner>/dev-standard`, never a local
   path.
3. `TODO.md`: the `STD-?` rows of this plan with status; README "Verified".

## H. Finish

Run `tests/template-tests.sh` and `tests/update-tests.sh`, `scripts/lint`, `scripts/check docs`,
zizmor on every workflow. Report what was built, the test results, what is not verified, and the
deviations from this plan.

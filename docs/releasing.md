# Releasing dev-standard

A release is a tag `vX.Y.Z` on `main`. Projects read the tags: `copier update` and
`scripts/update-standard` go from the tag in `.copier-answers.yml` to a newer one.

## Versioning

Semantic Versioning for the standard. These changes are **breaking** (minor while the major version
is 0, major afterwards):

- a standard file or a variable of `check.config` is renamed or removed;
- a check becomes required (a new CI job in the required set, a new label);
- a manual step becomes necessary (a new tool to install, a setting to apply).

Each breaking change ships a Copier migration (`_migrations` in `copier.yml`, script in
`migrations/`) or an **Upgrade notes** entry in `CHANGELOG.md`. `tests/update-tests.sh` fails when
a release has neither. New checks, files and options that need no action are minor; fixes are patch.

## Steps

1. Branch `release/vX.Y.Z` from `dev`. The version comes from `scripts/next-version`.
2. In `CHANGELOG.md`, rename the top section to `## vX.Y.Z` with Added, Changed, Fixed and
   **Upgrade notes** (write `None.` when there is nothing to do). The notes name every renamed or
   removed standard file, every new label or required check, every new tool and every manual step.
3. Run `tests/update-tests.sh` (CI job `update-test` does the same): projects of the previous
   release and of v0.1.0 update to the candidate without conflicts.
4. A person reviews and merges the PR, tags `vX.Y.Z` on `main` and pushes the tag.
5. The workflow `release.yml` publishes the GitHub release with the CHANGELOG section. A person
   merges `main` back into `dev`.

Changes to guardrail files of this repository (`.guardrails`) carry the label `guardrail-change`,
set by the maintainer.

## What the update test needs

The previous release and v0.1.0 must exist as tags. `tests/update-tests.sh` clones this repository,
commits the working tree in the clone and tags that commit with the version of the top
`CHANGELOG.md` section, so the real repository gets no tag from the test.

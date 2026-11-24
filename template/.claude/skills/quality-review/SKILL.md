---
name: quality-review
description: Get an independent review of the current change from the read-only quality-reviewer subagent (spec proof, tests not weakened, scope, constitution, dependencies, security) and paste its output into the PR. Use before handing an agent's work to a person, after scripts/check passes.
---

# Quality review

Why: the agent that wrote a change tends to approve it. This skill asks a second agent with no
write access to look at it first. A person still reviews and merges.

1. Find the base (`dev`, or the branch the PR targets) and the spec folder of this work
   (`specs/<n>-<slug>/`; the branch name carries `<KEY>-<n>`).
2. Collect, without changing anything:
   - `git diff --stat <base>...HEAD` and the list of changed files;
   - the diff itself into `docs/handover/review-diff.patch` (git-ignored) if it is large;
   - `scripts/check proof <base>` and `scripts/check scope <base>` (paste their output);
   - the new dependencies: for each, `scripts/verify-package <ecosystem> <name>`.
3. Start the `quality-reviewer` subagent with all of that and the paths of the spec, plan,
   `CONSTITUTION.md` and `AGENTS.md`. Don't tell it what you think of the change.
4. Paste its answer unchanged into the PR description under **Agent PR review** (or into the
   handover, `/handover`). Fix what it found that is yours to fix, then run the check and the review
   again. Findings you disagree with stay in the text with your reason; don't delete them.
5. Never claim the review replaces a person's: say "reviewed by quality-reviewer, not yet by a person".

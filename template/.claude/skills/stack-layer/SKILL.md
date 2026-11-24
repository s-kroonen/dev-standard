---
name: stack-layer
description: Walk the stack-layer playbook (docs/process/stack-layer.md) after the stack decision is accepted and when the codebase grows. Finds what is still undecided, proposes the check.config lines, and says which gates are proven. Use after /stack-decide was accepted, or when `scripts/check stack-layer` warns.
---

# Stack layer

`check.config` and the CI files are guardrail files: you don't edit them. You find out what is
missing, propose the exact lines, and a person applies them (or approves your PR with the label
`guardrail-change`). Read `docs/process/stack-layer.md` first; it is the checklist.

1. **Where are we?** Read `docs/decisions/0002-choose-the-stack.md` (must be `accepted`: if not,
   stop), `.copier-answers.yml` (is `stack:` set?), `docs/product/quality-attributes.md`.
   Run `scripts/check stack-layer` and `scripts/check quality-canary`; paste both outputs.
2. **Step 1 of the playbook** (apply the profile): if `stack` is still `none`, the person runs
   `copier update --trust --data stack=<name>`; you don't. Then the quality canary must pass.
3. **Each remaining step**, in the playbook's order: check whether the project needs it (a UI? an
   HTTP API? parsers of untrusted input? a Dockerfile?). For each:
   - needed: propose the command for this stack (the playbook has an example per stack), run it
     once in the working tree to see it work, and say what it reported;
   - not needed: propose `VAR="none"   # reason`.
   Every tool you name is verified on its registry first (`scripts/verify-package`); pin nothing
   you didn't look up.
4. **Write the proposal** as a block of `check.config` lines in the handover or the PR (and CI
   changes as a diff). Don't edit the guardrail files.
5. **Prove the gates.** For new gates add the case they must fail on to the plan (a person adds it
   to `tests/`); the quality canary and security canary stay green.
6. **Hand over** (`/handover`): steps done, steps proposed with the lines, steps skipped with why,
   `COVERAGE_TOTAL_MIN` proposal (the current total), and the research review (`<KEY>-6`).

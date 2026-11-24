## Issue

<!-- One issue per PR. Example: APP-56 -->
Closes:

## What and why

<!-- 2–5 sentences. What changes for a user, admin or developer, and why. -->

## Acceptance criteria

<!-- Copy them from the issue; tick what is met and say how it was verified. -->
- [ ] <criterion> — verified by: <test / manual step>

## How it was verified

- [ ] `scripts/check all` passes locally
- [ ] Manual check: <what you tried, on which device/environment>
- Not verified / known gaps: <say so, or "none">

## AI use

<!-- Pick one. This is disclosure, not a judgement. -->
- [ ] None
- [ ] Assisted: AI suggested or drafted parts; I reviewed and edited every line I commit
- [ ] Agent-authored: an agent wrote this change; session/run link: <link>

## Agent PR review (agent-authored PRs)

<!-- The reviewer ticks these; CI covers what it can (test-integrity, new-deps, pr-size, guardrails). -->
- [ ] Every requirement has proof (spec Proof table or handover), and I checked one myself
- [ ] Tests not weakened; a bug fix has a test that fails without the fix
- [ ] Scope matches the plan/issue; nothing unrelated (follow-ups listed instead)
- [ ] New dependencies: named in the plan/ADR, real, maintained, licence fits
- [ ] Security & Data section of the spec still holds (input, secrets, personal data, safety)
- [ ] Handover read: what wasn't verified is acceptable or has an issue

## Risk

- Touches guardrail files (.guardrails)? <no / yes: which, why>
- Database or API contract change? <no / yes: migration, linked issue in the other repo>
- Rollback: <revert / redeploy previous image / migration down>

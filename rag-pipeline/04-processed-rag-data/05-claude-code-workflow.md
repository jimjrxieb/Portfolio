# Claude Code and Codex Workflow

## How Claude Code Is Used

Claude Code is Anthropic's CLI tool for AI-assisted software engineering. It has been the primary development tool in this workflow for nearly two years, used nightly. That is not a hobbyist usage pattern — it represents hundreds of real engineering sessions building, hardening, and shipping production systems.

The key principle: Claude Code is an accelerator, not a replacement for judgment. The engineer still decides what to build and why. Claude Code executes faster than typing, catches more edge cases than any single reviewer, and documents reasoning inline as it goes.

## The Workflow Pattern

Every session follows the same structure, even when it is not explicit:

1. **Phase first** — before writing any code, establish which CBBP phase applies (COMPLY / BUILD / BREAK / PROVE). This determines what tools run, what artifacts get produced, and what the success criteria are.

2. **Read the playbook** — the GP-CONSULTING playbooks are the brain. Claude Code reads the relevant control family playbook before making implementation decisions. The playbook encodes what a senior engineer would do. Update the playbook and the behavior changes — no Python modifications needed.

3. **Encode, don't invent** — the goal is not clever code. It is reliable, auditable, policy-as-code that a future engineer (or an auditor) can read and understand. If it is not in a playbook and it is not in git, it did not happen.

4. **Rank before acting** — before any remediation, the RANK-AI classifier (or judgment-equivalent for manual work) determines the authority level. E/D rank: just fix it. C rank: propose with confidence score. B/S rank: stop and get human sign-off.

5. **Evidence last** — every session ends with evidence. Not just "I fixed it" — a commit message with Conventional Commits format, a POAM entry if there was a finding, a remediation-log.jsonl record if something was changed.

## Security Standards in Practice

Twenty-five security rules are enforced on every line of code. The most frequently relevant ones in practice:

- **No shell=True with string interpolation** — subprocess calls always use list form
- **No unpinned dependencies** — every package specifies exact version with justification
- **No hardcoded secrets** — environment variables only, .env.example documents them
- **Input validation at system boundaries** — all user input and external API responses validated
- **Parameterized queries** — no SQL string concatenation ever
- **Non-root containers** — every Dockerfile has a USER directive
- **Secrets module for tokens** — never random or uuid4 for security-relevant token generation

These are not aspirational. A session ends when they are satisfied, not before.

## Git Discipline

The user owns git entirely. Claude Code never commits, never pushes, never stages files without explicit direction. The workflow:

- Claude Code makes changes and shows diffs
- User reviews and decides what to stage
- User commits with Conventional Commits message format
- User pushes manually

This is not a limitation — it is the correct security posture. An AI that auto-commits is an AI that can accidentally include secrets, introduce breaking changes, or bypass pre-commit hooks. Manual git keeps the human in the loop on every state change.

## Codex Complement

Codex (via GitHub Copilot CLI or API) handles specific automation scripts and rapid boilerplate generation. The division of labor:

- **Claude Code**: architecture decisions, multi-file changes, complex reasoning, CBBP phase work, production system changes
- **Codex**: script generation, automation routines, quick single-file utilities

Both tools are instructed to follow the same 25 security standards. The output of either tool goes through the same review process before staging.

## The CBBP + Claude Code Loop

A typical engagement session looks like:

```
1. Read COMPLY output → understand what controls apply to today's work
2. Open BUILD phase → read the relevant playbook (CM/, SA/, AC/)
3. Claude Code executes the playbook steps, produces IaC/manifests/scripts
4. BREAK phase → Claude Code runs or interprets scanner output
5. PROVE phase → Claude Code produces POA&M entries, audit trail records
6. Human reviews diff, stages, commits, pushes
7. ArgoCD detects the change → syncs to cluster
8. Evidence files land in GP-S3 engagement directory
```

The loop is short. Every session advances the engagement and produces auditable artifacts.

## Why This Matters

Hiring managers who ask "can you really do this at 2am when something breaks?" — the answer is yes, because this workflow has been practiced nightly for nearly two years. The runbooks exist. The playbooks exist. The audit trail exists.

The compliance background means the question is never just "did the fix work?" but "can I prove the fix worked, trace who applied it, and show an auditor what the system state was before and after?" Claude Code is a tool in that workflow. The discipline behind it is older than Claude Code.

## Claude Code + CrewAI Migration Path

The CBBP phase agents (Comply Engineer, Build Engineer, Break Engineer, Prove Engineer) are written as platform-agnostic agent prompts. They run as Claude Code subagents today. The migration path to CrewAI autonomous operation does not require rewriting them — the prompts are forward-compatible.

The direction: Claude Code → CrewAI "super saiyan" — same methodology, more autonomous execution, lower human toil on E/D-rank work. C-rank and above stays human-supervised regardless of platform.

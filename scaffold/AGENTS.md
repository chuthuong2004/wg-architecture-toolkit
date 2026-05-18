# AI Agent Contract

This file is the canonical entry point for any AI coding agent (Claude Code, Cursor, Aider, …) working in this repo. Read it before making any edit.

`CLAUDE.md` is a thin pointer to this file with Claude-specific extensions.

---

## 1. Read first

Before touching code, an agent **must** load:

1. [`.claude/config.md`](./.claude/config.md) — single source of truth for ports, paths, package manager, and per-service commands. Hard-coding any of these elsewhere is a bug.
2. [`docs/architecture/`](./docs/architecture/) — canonical "where we are" map of modules, layers, and dataflow.
3. The relevant per-domain changelog under [`docs/changelogs/`](./docs/changelogs/) for the area you're editing.

---

## 2. Sub-agents

Specialized agents live in [`.claude/agents/`](./.claude/agents/). Each is a self-contained markdown file with a role, allowed tools, and a checklist. Invoke them via the Agent / Task tool — never re-implement their logic inline.

| Agent | Role | File |
|---|---|---|
| **planner** | Decompose a feature ask into a sequenced plan with files-to-touch | [`.claude/agents/planner.md`](./.claude/agents/planner.md) |
| **implementer** | Execute a plan emitted by `planner` (writes code) | [`.claude/agents/implementer.md`](./.claude/agents/implementer.md) |
| **code-reviewer** | Style + correctness + project-convention review of a diff | [`.claude/agents/code-reviewer.md`](./.claude/agents/code-reviewer.md) |
| **tester** | Author or extend unit / integration tests | [`.claude/agents/tester.md`](./.claude/agents/tester.md) |
| **qa-engineer** | End-to-end / manual smoke QA, edge-case checklist | [`.claude/agents/qa-engineer.md`](./.claude/agents/qa-engineer.md) |
| **verifier** | Pre-merge regression sweep across modified surfaces | [`.claude/agents/verifier.md`](./.claude/agents/verifier.md) |
| **deployer** | Build + deploy + rollback playbook execution | [`.claude/agents/deployer.md`](./.claude/agents/deployer.md) |
| **devops** | Docker, CI workflow files, infra | [`.claude/agents/devops.md`](./.claude/agents/devops.md) |
| **cto** | High-level architectural decision; multi-quarter trade-offs | [`.claude/agents/cto.md`](./.claude/agents/cto.md) |

---

## 3. Slash commands (lifecycle stages)

Defined in [`.claude/commands/`](./.claude/commands/). They orchestrate the agents above in a fixed sequence — use the command, not the bare agents, for any new feature.

| Stage | Command | What it does | File |
|---|---|---|---|
| 0 | `/0-run` | Service lifecycle utility (start / stop / logs) | [`.claude/commands/0-run.md`](./.claude/commands/0-run.md) |
| 1 | `/1-plan` | Run `planner` → produce a plan in `.claude/outputs/stage-1-plan.md` | [`.claude/commands/1-plan.md`](./.claude/commands/1-plan.md) |
| 2 | `/2-implement` | Run `implementer` against the latest plan | [`.claude/commands/2-implement.md`](./.claude/commands/2-implement.md) |
| 3 | `/3-review` | Run `code-reviewer` (and optionally `cto`) on the working diff | [`.claude/commands/3-review.md`](./.claude/commands/3-review.md) |
| 4 | `/4-test` | Run `tester` + `qa-engineer` | [`.claude/commands/4-test.md`](./.claude/commands/4-test.md) |
| 5 | `/5-deploy` | Run `deployer` | [`.claude/commands/5-deploy.md`](./.claude/commands/5-deploy.md) |
| 6 | `/6-verify` | Run `verifier` to confirm post-deploy health | [`.claude/commands/6-verify.md`](./.claude/commands/6-verify.md) |

Outputs land in [`.claude/outputs/`](./.claude/outputs/) (plans, review notes, verification logs).

---

## 4. Skills

Higher-level capabilities under [`.claude/skills/`](./.claude/skills/). Each skill is a directory with `SKILL.md` plus optional `references/` and `assets/`. Skills auto-trigger on matching prompts; agents are invoked explicitly.

Install more skills via [`chuthuong2004/claude-skills`](https://github.com/chuthuong2004/claude-skills):

```bash
curl -fsSL https://raw.githubusercontent.com/chuthuong2004/claude-skills/main/install.sh | bash
```

---

## 5. Shared conventions

[`.claude/shared/`](./.claude/shared/) holds material referenced by multiple agents:

- [`principles.md`](./.claude/shared/principles.md) — what good code in this repo looks like (read before any non-trivial PR).
- [`procedures.md`](./.claude/shared/procedures.md) — repeatable workflows (auth token, service health check, change-scope detection).
- [`templates.md`](./.claude/shared/templates.md) — boilerplate for plan / review / deploy artifacts.

---

## 6. Domain history

Per-domain changelogs live at [`docs/changelogs/`](./docs/changelogs/) — one file per module so an agent can load just the slice relevant to a change. See [`docs/changelogs/README.md`](./docs/changelogs/README.md) for the index.

When you ship a behavior change, update the matching changelog entry **in the same PR** as the code — anchor it to the commit hash.

---

## 7. Feature design docs

Active design docs at [`docs/plans/`](./docs/plans/). When `/1-plan` produces a plan that spans more than one PR, promote it from `.claude/outputs/` to `docs/plans/<feature>.md` so it survives across sessions.

---

## 8. Hard rules

1. **No new top-level changelogs.** Use the per-domain files.
2. **No bypass of lifecycle stages.** A feature PR should have evidence of `/1-plan` → `/3-review` at minimum.
3. **No vendor SDK in feature code.** Wrap third-party SDKs (Slack / S3 / OpenAI / Anthropic / …) in a port and inject the adapter — keeps feature code testable and swappable.
4. **No hard-coded paths, ports, or commands** outside `.claude/config.md`.
5. **Always update the changelog in the same PR as the code change** — never as a follow-up.
6. **Read the file before you edit it.** Even small edits require seeing the surrounding context.

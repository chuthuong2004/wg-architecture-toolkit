# Claude Code Instructions

> **Start here:** [`AGENTS.md`](./AGENTS.md) is the vendor-neutral agent contract for this repo. Everything in there applies to Claude Code. This file only adds Claude-specific extensions.

---

## 1. Boot sequence

Every Claude Code session in this repo must load, in order:

1. [`.claude/config.md`](./.claude/config.md) — single source of truth (ports, paths, commands)
2. [`AGENTS.md`](./AGENTS.md) — agent contract (sub-agents, slash commands, hard rules)
3. [`docs/architecture/`](./docs/architecture/) — module map
4. The relevant per-domain changelog at [`docs/changelogs/`](./docs/changelogs/) for the area you're editing

Skip none of these — they encode constraints that are not re-derivable from the code alone.

---

## 2. Tool routing

Map common asks to the right Claude Code primitive instead of reinventing them.

| Intent | Use |
|---|---|
| Plan a feature / refactor | `/1-plan` (runs the `planner` agent) |
| Implement a planned change | `/2-implement` (runs `implementer`) |
| Review the working diff | `/3-review` (runs `code-reviewer`) |
| Write or extend tests | `/4-test` |
| Deploy / rollback | `/5-deploy` |
| Post-deploy verification | `/6-verify` |
| Service lifecycle (start/stop/logs) | `/0-run` |
| Author an architecture doc | the `architecture-doc-writer` skill |

Sub-agents are invoked via the Task tool. **Never re-implement an agent's logic inline** — if a behavior belongs in `planner`, fix it in [`.claude/agents/planner.md`](./.claude/agents/planner.md) and the next `/1-plan` will pick it up.

---

## 3. File-edit conventions

- Use `Edit` / `Write` tools, not shell `sed` / `echo > file`.
- Read a file before editing it (the tool enforces this).
- For mechanical bulk changes (e.g. add a second arg to N call sites), prefer a one-off Python script via the `Bash` tool — it's idempotent and reviewable in the diff. Avoid sub-agents for purely mechanical work; reserve them for tasks needing judgment.
- Don't add `// TODO` markers unless the user explicitly asks. Open a follow-up issue or note it in the PR description instead.

---

## 4. Commit conventions

Format: `type(scope): subject` — match the existing log (`git log --oneline -10`).

Common types: `feat`, `fix`, `refactor`, `chore`, `test`, `docs`. Scopes match the module (`api`, `web`, `auth`, …). When a refactor commit touches multiple modules, scope to the higher-level concern.

**Never commit unless the user explicitly asks.** "Save this" / "stash this" / "stage it" are not commit requests.

---

## 5. PR conventions

When the user asks for a PR:

1. Push the branch with `git push` (if it's not already pushed).
2. `gh pr create --base <pr_base_branch> --title ... --body ...` with:
   - 2–3 bullet **Summary** of what changed and why.
   - A **Test plan** checklist split between CI-automatable items (ticked) and manual smoke items (unticked).
   - Optional **Notes for reviewer** section flagging pre-existing issues you found but didn't fix, intentional carve-outs, or anything that looks weird-on-purpose.
3. Return the PR URL.

Do not mark anything in the test plan as ticked unless you actually ran it in this session.

---

## 6. Honest reporting

When the user asks "are you sure there are no issues?", give a real audit — not a victory lap. Run lint, type-check, unit tests, and any smoke test before answering. Separate the report into:

- **Verified** — what you actually ran and saw pass.
- **Not verified** — things you couldn't reach (real-workspace integrations, browser-level interactions you couldn't drive, etc.).
- **Pre-existing** — failures present on the base branch, not introduced by the current branch.

If you couldn't run something, say so. Don't claim coverage you didn't deliver.

---

## 7. What not to do

- **Don't** invent commands. Use the slash commands in [`.claude/commands/`](./.claude/commands/).
- **Don't** create a top-level `CHANGELOG.md`. Use the per-domain files under [`docs/changelogs/`](./docs/changelogs/).
- **Don't** write multi-paragraph docstrings or summary comments. One short line when the *why* is non-obvious.
- **Don't** add backwards-compat shims for code only this repo uses — delete the old usage and update callers.
- **Don't** narrate your reasoning in user-facing text. Show results, not deliberation.

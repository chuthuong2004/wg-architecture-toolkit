# Changelogs

Per-domain changelogs. Each file tracks the evolution of one feature area: schema changes, behavior changes, bug fixes, and notable refactors — anchored to the git commit and (for backend) the migration that introduced them.

> **Why per-domain?** A single top-level `CHANGELOG.md` becomes unreadable once the project crosses ~30 modules. Per-domain files let an engineer (or an LLM agent) load only the slice of history they actually need.

---

## Index

| File | Domain | Scope summary |
|---|---|---|
| (Add one row per domain — e.g., `auth-changelog.md`, `user-changelog.md`, `<feature>-changelog.md`. Use [`CHANGELOG_TEMPLATE.md`](../../.claude/templates/docs/changelogs/CHANGELOG_TEMPLATE.md) as the starting point for each new file.) |

---

## Format

Every domain changelog follows the same structure (see [`.claude/templates/docs/changelogs/CHANGELOG_TEMPLATE.md`](../../.claude/templates/docs/changelogs/CHANGELOG_TEMPLATE.md)):

1. **Title + one-line scope**.
2. **Owns** — the files/modules/tables this domain controls. Useful for agents deciding "is this relevant to my task?".
3. **Surface** — the HTTP routes, schedulers, webhooks, or UI screens exposed by the domain.
4. **Timeline** — reverse-chronological list of changes, each one tagged with date, commit short SHA, and Keep-a-Changelog-style category:
   - **Added** — net-new feature, model, column, endpoint, scheduler.
   - **Changed** — behavior change to existing code.
   - **Fixed** — bug fix.
   - **Removed** — capability deleted (rare; usually replaced by a renamed equivalent).
   - **Schema** — migration in this domain.
5. **Open questions / known issues** — at the bottom, if applicable.

### Per-entry format

```markdown
### YYYY-MM-DD — <Short title> (<commit short SHA>)
**Added | Changed | Fixed | Removed | Schema.** One-sentence description.

- Optional details (bullets).
- Migration: `<migration-folder>` — what it does in one line.
- Source: `path/to/file.ts:line`.
```

A good entry has:
- The **what** in one sentence.
- The **why** if non-obvious from the title.
- Pointers to the migration and the source file(s) so the reader can navigate.

---

## When to update a changelog

- **You added a migration** → update the matching domain.
- **You added or changed an HTTP route** → update the matching domain.
- **You added or changed a scheduler / webhook handler** → update the matching domain.
- **You changed a UI behavior visible to users** → update the matching UI/feature changelog.
- **You refactored without behavior change** → optional, but a one-line **Changed** entry helps the next reader.

> Trivial fixes (typos, formatting, dependency bumps) don't need a changelog entry. If the diff doesn't change observable behavior or schema, skip it.

## When **not** to update

- Plain dependency bumps that don't change behavior.
- Internal renames with no API/UI/DB surface change.
- Test-only changes.

---

## Conventions

- **Newest at the top** within each file. The most recent change should be visible at first scroll.
- **Reference commits by short SHA** (`08b0d42`), not by PR number, so the link survives PR closure or repo migration.
- **Reference migrations by their folder name**, e.g. `20260417093739_add_<feature>_<column>`.
- **Use absolute, source-relative paths** (`<package>/<file>:<line>`) so agents can navigate directly.
- **Keep entries calibrated** — a one-line fix entry is fine; a multi-paragraph entry is fine; padding entries to look impressive is not.
- **Cross-link domains** when a change touches multiple. Example: "see also [<other-domain>](./other-domain-changelog.md#…)".

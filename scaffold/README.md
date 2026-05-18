# <PROJECT_NAME>

> One-line description: what this project is and who it serves.

<Two- or three-sentence elaboration: stack at a glance + the canonical entry points for the codebase.>

> See [`docs/architecture/`](./docs/architecture/) for the canonical map of modules / layers / data flow.
> See [`AGENTS.md`](./AGENTS.md) for the AI-agent contract (Claude Code, Cursor, …).

---

## Why this exists

- **Problem 1.** <What does this project solve that the prior tool / process didn't?>
- **Problem 2.** <What's the cost saved / quality gained?>
- **Problem 3.** <What's the non-goal? Be explicit about what this is *not* trying to do.>

Out of scope (intentional): <list the things you're deliberately not building>.

---

## Feature set

### <Capability group 1>
- <bullet>
- <bullet>

### <Capability group 2>
- <bullet>
- <bullet>

---

## Quick start

```bash
# 1. Install dependencies
<package_manager> install

# 2. Start dependencies (database, queues, etc.)
docker compose up -d

# 3. Apply migrations + seed (if applicable)
<migrate_cmd>
<seed_cmd>

# 4. Run dev servers
<dev_cmd>
```

Visit `<dev_entry_url>` and sign in with the seeded account (see `.env.example`).

Copy `.env.example` → `.env` and fill in the required vars listed there.

---

## Repository layout

```
<top-level-package-or-app>/   <one-line role>
<another-package>/            <one-line role>
docs/                         project documentation
  architecture/               canonical module / layer / dataflow docs
  changelogs/                 per-domain reverse-chronological history
  plans/                      active and shipped implementation plans
.claude/                      AI-agent contract — agents, slash commands, shared resources
```

See [`docs/architecture/`](./docs/architecture/) for a deeper module map.

---

## Documentation

| Document | Purpose |
|---|---|
| [`AGENTS.md`](./AGENTS.md)                     | Vendor-neutral AI-agent contract. **Read first.** |
| [`CLAUDE.md`](./CLAUDE.md)                     | Claude Code-specific extensions over `AGENTS.md`. |
| [`.claude/config.md`](./.claude/config.md)     | Single source of truth for ports, paths, commands. |
| [`docs/architecture/`](./docs/architecture/)   | Canonical "where we are" architecture map. |
| [`docs/changelogs/`](./docs/changelogs/)       | Per-domain changelogs. One file per module. |
| [`docs/plans/`](./docs/plans/)                 | Feature implementation plans, one per feature. |

---

## License

<License — MIT, Apache-2.0, proprietary, …>

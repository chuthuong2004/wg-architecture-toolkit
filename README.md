# claude-skills

A collection of [Claude Code](https://docs.claude.com/en/docs/claude-code) skills for writing **production-grade backend architecture documentation**.

Each skill enforces a strict, opinionated structure — mandatory Mermaid diagrams, state machines, queue topologies, SQL schema, phased rollouts, risk registers, and SLOs — so the output is consistent across projects and teams.

> Originally extracted from the `wg-marketing-be` codebase (live-stream + SMM platform) so other projects can produce architecture docs of the same depth and shape.

---

## Skills in this repo

| Skill | What it does |
|---|---|
| [`architecture-doc-writer`](skills/architecture-doc-writer/) | Generates full HLDs, migration plans, and component deep-dives with diagrams and trade-off tables. |

**Triggers on phrases like:**
*"viết tài liệu kiến trúc"*, *"architecture doc"*, *"system design"*, *"HLD"*, *"migration plan"*, *"RFC"*.

More skills will be added here (ER design helper, runbook writer, API doc writer, …) without breaking install.

---

## Install

### Pick a scope first

Each skill can be installed at one of two scopes:

| Scope | Path | When to use |
|---|---|---|
| `--user` | `~/.claude/skills/<name>/` | Available in **every project** on your machine. |
| `--project` | `$PWD/.claude/skills/<name>/` | Scoped to **one repo** — commit it so teammates get it on clone. |

If you don't pass a flag, the installer asks interactively.

> The prompt reads from `/dev/tty`, so it works even under `curl | bash`.
> The env var `CLAUDE_SKILLS_DIR=/path` overrides both scopes.

---

### Option 1 — One-liner (no clone)

**Recommended.** `cd` into the project you want to scope the skill to (only matters if you pick *project*), then run:

```bash
curl -fsSL https://raw.githubusercontent.com/chuthuong2004/claude-skills/main/install.sh | bash -s -- architecture-doc-writer
```

You'll get an arrow-key picker:

```
Install destination:
  user    → /Users/you/.claude/skills
  project → /current/dir/.claude/skills

Pick scope (↑/↓ + Enter, q to cancel):
> user      (global — available in every project)
  project   (scoped to current directory)
```

Controls: `↑/↓` move, `Enter` confirm, `q`/`Esc` cancel.
(Falls back to a numbered prompt if your terminal doesn't support raw input.)

#### Skip the prompt

Pass `--user` or `--project` explicitly:

```bash
# Always user-level
curl -fsSL https://raw.githubusercontent.com/chuthuong2004/claude-skills/main/install.sh | bash -s -- --user architecture-doc-writer
```

```bash
# Always project-level (cd into the project first)
cd ~/code/my-project
curl -fsSL https://raw.githubusercontent.com/chuthuong2004/claude-skills/main/install.sh | bash -s -- --project architecture-doc-writer
```

> **CI / no-TTY callers:** without an explicit flag, the installer falls back to `--user` with a warning. Pass the flag to silence it.

---

### Option 2 — Clone + install script

```bash
git clone https://github.com/chuthuong2004/claude-skills.git
cd claude-skills
```

Then run the installer:

```bash
# Interactive — asks scope, then skill
./install.sh

# Install everything, user-level
./install.sh --user all

# One skill, project-level (CWD)
./install.sh --project architecture-doc-writer

# Symlink instead of copy (live-edit)
./install.sh --link --user architecture-doc-writer

# Uninstall
./install.sh --uninstall --user architecture-doc-writer
```

Override the destination entirely:

```bash
CLAUDE_SKILLS_DIR=/path/to/skills ./install.sh all
```

---

### Option 3 — Fully manual

```bash
git clone https://github.com/chuthuong2004/claude-skills.git
```

**User-level:**

```bash
mkdir -p ~/.claude/skills
cp -R claude-skills/skills/architecture-doc-writer ~/.claude/skills/
```

**Project-level:**

```bash
mkdir -p .claude/skills
cp -R claude-skills/skills/architecture-doc-writer .claude/skills/
```

> After install, **restart Claude Code** (or open a new session) so the skills are picked up.

---

## Verify install

Check the files are in place:

```bash
# User-level
ls ~/.claude/skills/architecture-doc-writer

# Project-level
ls ./.claude/skills/architecture-doc-writer

# Expected output:
# SKILL.md  assets/  references/
```

Then open Claude Code and either:

- Type `/architecture-doc-writer` — the skill should appear in the slash-command list, **or**
- Prompt naturally: *"viết tài liệu kiến trúc cho hệ thống X"* — the skill auto-triggers.

---

## Updating

```bash
cd claude-skills && git pull
```

Then re-run the install:

```bash
./install.sh --user all      # re-copy on top of the existing user install
./install.sh --project all   # …or project install (from inside the target repo)
```

> If you installed with `--link`, `git pull` alone is enough — the symlink already points at the repo.

---

## Uninstalling

Via the installer:

```bash
# Remove user-level
./install.sh --uninstall --user architecture-doc-writer

# Remove project-level (run inside the project)
./install.sh --uninstall --project architecture-doc-writer
```

Or just delete the directory:

```bash
rm -rf ~/.claude/skills/architecture-doc-writer
rm -rf ./.claude/skills/architecture-doc-writer
```

---

## Repo layout

```
.
├── README.md
├── LICENSE
├── install.sh
└── skills/
    └── architecture-doc-writer/
        ├── SKILL.md             # entry point + workflow + trigger rules
        ├── references/          # loaded on demand by Claude
        │   ├── section-checklist.md
        │   ├── diagram-patterns.md
        │   ├── sql-patterns.md
        │   └── event-driven-patterns.md
        └── assets/              # skeleton templates
            ├── template-architecture.md
            ├── template-migration-plan.md
            └── template-component-deepdive.md
```

---

## Contributing a new skill

1. Add a new directory under `skills/<your-skill-name>/`.
2. Create `SKILL.md` with YAML frontmatter (`name`, `description`).
3. Optionally add:
   - `references/` — loaded on demand.
   - `assets/` — skeleton templates.
4. Add a row to the **Skills in this repo** table above.
5. Open a PR.

See the [Claude skill format docs](https://docs.claude.com/en/docs/claude-code/skills) for the full schema.

---

## License

MIT — see [LICENSE](LICENSE).

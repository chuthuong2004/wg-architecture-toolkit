# wg-architecture-toolkit

A collection of [Claude Code](https://docs.claude.com/en/docs/claude-code) skills for writing **production-grade backend architecture documentation** — event-driven designs, migration plans, component deep-dives, with mandatory Mermaid diagrams, state machines, queue topologies, SQL schema, phased rollouts, risk registers, and SLOs.

Originally extracted from the `wg-marketing-be` codebase (live-stream + SMM platform) so other projects can produce architecture docs of the same depth and shape.

---

## Skills in this repo

| Skill | What it does | Triggers on |
|---|---|---|
| [`architecture-doc-writer`](skills/architecture-doc-writer/) | Generates full HLDs / migration plans / component deep-dives in a strict, opinionated structure with diagrams and trade-off tables | "viết tài liệu kiến trúc", "architecture doc", "system design", "HLD", "migration plan", "RFC" |

More skills will be added here (ER design helper, runbook writer, API doc writer, …) without breaking install.

---

## Install

### Scope: user vs project

You can install each skill at **two** scopes:

| Scope | Path | When to use |
|---|---|---|
| `--user` | `~/.claude/skills/<name>/` | You want the skill available in every project on your machine. |
| `--project` | `$PWD/.claude/skills/<name>/` | You want the skill scoped to one repo (commit it so team-mates get it on clone). |

If you don't pass a flag, the script asks interactively (it reads from `/dev/tty`, so the prompt works even under `curl | bash`). The env var `CLAUDE_SKILLS_DIR=/path` overrides both.

### Option 1 — one-liner (no clone)

**Recommended — let the script ask:** `cd` into the project you want to scope the skill to (only matters if you pick "project"), then run:

```bash
curl -fsSL https://raw.githubusercontent.com/chuthuong2004/wg-architecture-toolkit/main/install.sh \
  | bash -s -- architecture-doc-writer
```

You'll get an arrow-key picker (↑/↓ to move, Enter to confirm, q/Esc to cancel):

```
Where do you want to install the skill(s)? (↑/↓ + Enter)
> user    — /Users/you/.claude/skills            (available in every project)
  project — /current/dir/.claude/skills          (scoped to this project)
```

(Falls back to a numbered prompt if your terminal doesn't support raw input.)

**Skip the prompt** by passing `--user` or `--project` explicitly:

```bash
# Always user-level
curl -fsSL https://raw.githubusercontent.com/chuthuong2004/wg-architecture-toolkit/main/install.sh \
  | bash -s -- --user architecture-doc-writer

# Always project-level (cd into the project first)
cd ~/code/my-project
curl -fsSL https://raw.githubusercontent.com/chuthuong2004/wg-architecture-toolkit/main/install.sh \
  | bash -s -- --project architecture-doc-writer
```

> Non-interactive callers (CI, no TTY) without an explicit flag fall back to `--user` with a warning — pass the flag in those contexts to silence it.

### Option 2 — clone + install script

```bash
git clone https://github.com/chuthuong2004/wg-architecture-toolkit.git
cd wg-architecture-toolkit

./install.sh                                          # interactive (asks scope, then skill)
./install.sh --user all                               # install every skill, user-level
./install.sh --project architecture-doc-writer        # one skill, project-level (CWD)
./install.sh --link --user architecture-doc-writer    # symlink instead of copy (live-edit)
./install.sh --uninstall --user architecture-doc-writer
```

Override the destination entirely:

```bash
CLAUDE_SKILLS_DIR=/path/to/skills ./install.sh all
```

### Option 3 — fully manual

```bash
git clone https://github.com/chuthuong2004/wg-architecture-toolkit.git

# user-level
mkdir -p ~/.claude/skills
cp -R wg-architecture-toolkit/skills/architecture-doc-writer ~/.claude/skills/

# OR project-level
mkdir -p .claude/skills
cp -R wg-architecture-toolkit/skills/architecture-doc-writer .claude/skills/
```

After install, **restart Claude Code** (or open a new session) so the skills are picked up.

---

## Verify install

```bash
# user-level
ls ~/.claude/skills/architecture-doc-writer
# project-level
ls ./.claude/skills/architecture-doc-writer
# → SKILL.md  assets/  references/
```

Open Claude Code and type `/architecture-doc-writer` — the skill should appear in the slash-command list. Or just give Claude a prompt like *"viết tài liệu kiến trúc cho hệ thống X"* — the skill auto-triggers on architecture/design phrasing.

---

## Updating

```bash
cd wg-architecture-toolkit && git pull
./install.sh --user all      # re-copy on top of the existing user install
./install.sh --project all   # …or project install (from inside the target repo)
```

If you installed with `--link`, `git pull` alone is enough (the symlink already points at the repo).

---

## Uninstalling

```bash
./install.sh --uninstall --user architecture-doc-writer       # remove user-level
./install.sh --uninstall --project architecture-doc-writer    # remove project-level (run inside the project)
# or just delete the directory
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

1. Add a new directory under `skills/<your-skill-name>/`
2. Create `SKILL.md` with YAML frontmatter (`name`, `description`)
3. Optionally add `references/` (loaded on demand) and `assets/` (templates)
4. Add a row to the skills table in this README
5. Open a PR

See the [Claude skill format docs](https://docs.claude.com/en/docs/claude-code/skills) for the full schema.

---

## License

MIT — see [LICENSE](LICENSE).

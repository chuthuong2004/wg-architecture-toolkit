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

### Option 1 — one-liner (no clone)

```bash
curl -fsSL https://raw.githubusercontent.com/<owner>/wg-architecture-toolkit/main/install.sh \
  | bash -s -- architecture-doc-writer
```

Replace `<owner>` with your GitHub user/org after pushing.

### Option 2 — clone + install script

```bash
git clone https://github.com/<owner>/wg-architecture-toolkit.git
cd wg-architecture-toolkit

./install.sh                              # interactive picker
./install.sh all                          # install every skill
./install.sh architecture-doc-writer      # install named skill(s)
./install.sh --link architecture-doc-writer  # symlink for live-edit
./install.sh --uninstall architecture-doc-writer
```

By default the script copies into `~/.claude/skills/<name>/`. Override with:

```bash
CLAUDE_SKILLS_DIR=/path/to/skills ./install.sh all
```

### Option 3 — fully manual

```bash
git clone https://github.com/<owner>/wg-architecture-toolkit.git
mkdir -p ~/.claude/skills
cp -R wg-architecture-toolkit/skills/architecture-doc-writer ~/.claude/skills/
```

After install, **restart Claude Code** (or open a new session) so the skills are picked up.

---

## Verify install

```bash
ls ~/.claude/skills/architecture-doc-writer
# SKILL.md  assets/  references/
```

Open Claude Code and type `/architecture-doc-writer` — the skill should appear in the slash-command list. Or just give Claude a prompt like *"viết tài liệu kiến trúc cho hệ thống X"* — the skill auto-triggers on architecture/design phrasing.

---

## Updating

```bash
cd wg-architecture-toolkit && git pull
./install.sh all   # re-copy on top of the existing install
```

If you installed with `--link`, `git pull` alone is enough (the symlink already points at the repo).

---

## Uninstalling

```bash
./install.sh --uninstall architecture-doc-writer
# or
rm -rf ~/.claude/skills/architecture-doc-writer
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

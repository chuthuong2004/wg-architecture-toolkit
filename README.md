# claude-skills

A curated collection of [Claude Code](https://docs.claude.com/en/docs/claude-code) **skills** and **subagents** — opinionated, production-grade, install-on-demand.

Each item is self-contained and installs with one command. Nothing is auto-installed; the installer always asks (or requires) which scope and which item.

---

## What's in the repo

### Skills (`skills/<name>/`)

Skills are workflow recipes. They trigger automatically on matching prompts (or via `/<name>`) and enforce a strict output structure.

| Skill | What it does |
|---|---|
| [`architecture-doc-writer`](skills/architecture-doc-writer/) | Generates full backend HLDs, migration plans, and component deep-dives — Mermaid diagrams, state machines, queue topology, SQL schema, phased rollouts, risk registers, SLOs. Triggers on *"viết tài liệu kiến trúc"*, *"architecture doc"*, *"system design"*, *"HLD"*, *"migration plan"*, *"RFC"*. |

### Subagents (`agents/<name>.md`)

Subagents are specialist personas you can delegate to (`Task` tool) or that Claude can use proactively. Each one lives in its own context window.

| Agent | What it does |
|---|---|
| [`seo-expert`](agents/seo-expert.md) | Technical SEO specialist for **Next.js App Router** projects — metadata API, JSON-LD, sitemaps, robots, canonical/hreflang, image SEO, Core Web Vitals, i18n. Audits new pages and PRs for SEO regressions. Model: `sonnet`. |

> More items will be added without breaking existing installs. The installer only touches the item(s) you name.

---

## Install

### Step 1 — Pick a scope

| Scope | Where it goes | When to use |
|---|---|---|
| `--user` | `~/.claude/skills/<name>/` and `~/.claude/agents/<name>.md` | Available in **every project** on your machine. |
| `--project` | `$PWD/.claude/skills/<name>/` and `$PWD/.claude/agents/<name>.md` | Scoped to **one repo** — commit it so teammates get it on clone. |

If you don't pass a flag, the installer asks interactively (arrow-key picker, reads from `/dev/tty` so it works under `curl | bash`).

Override env vars:

```bash
CLAUDE_SKILLS_DIR=/path/to/skills    # overrides skills destination
CLAUDE_AGENTS_DIR=/path/to/agents    # overrides agents destination
```

### Step 2 — Pick what to install

Pass the name(s) of skills/agents as arguments. **Nothing is installed unless you name it** (or pass `all-skills` / `all-agents`).

```bash
# One item (agent)
./install.sh --user seo-expert

# One item (skill)
./install.sh --project architecture-doc-writer

# Multiple items, mixed types
./install.sh --user seo-expert architecture-doc-writer

# Everything of one type
./install.sh --user all-skills
./install.sh --user all-agents
```

> `all` by itself is **not supported** — use `all-skills` or `all-agents` explicitly so you never install something you didn't ask for.

---

### Option 1 — One-liner (no clone)

`cd` into the project you want to scope to (only matters for `--project`), then:

```bash
curl -fsSL https://raw.githubusercontent.com/chuthuong2004/claude-skills/main/install.sh | bash -s -- seo-expert
```

You'll get an arrow-key scope picker:

```
Install destination:
  user    → /Users/you/.claude/{skills,agents}
  project → /current/dir/.claude/{skills,agents}

Pick scope (↑/↓ + Enter, q to cancel):
> user      (global — available in every project)
  project   (scoped to current directory)
```

Controls: `↑/↓` move, `Enter` confirm, `q`/`Esc` cancel. Falls back to a numbered prompt if the terminal can't do raw input.

Skip the prompt with an explicit flag:

```bash
curl -fsSL https://raw.githubusercontent.com/chuthuong2004/claude-skills/main/install.sh | bash -s -- --user seo-expert
```

> **CI / no-TTY:** without an explicit flag, the installer defaults to `--user` and prints a warning. Pass the flag to silence it.

---

### Option 2 — Clone + install script

```bash
git clone https://github.com/chuthuong2004/claude-skills.git
cd claude-skills

# Interactive — asks scope, lists every skill and agent, you pick one
./install.sh

# Named install (mixed types allowed)
./install.sh --user seo-expert
./install.sh --project architecture-doc-writer seo-expert

# Symlink for live-edit (great if you're contributing back)
./install.sh --link --user seo-expert

# Uninstall (auto-detects skill vs agent by name)
./install.sh --uninstall --user seo-expert
```

Override the destination entirely:

```bash
CLAUDE_SKILLS_DIR=/tmp/skills CLAUDE_AGENTS_DIR=/tmp/agents ./install.sh seo-expert
```

---

### Option 3 — Fully manual

```bash
git clone https://github.com/chuthuong2004/claude-skills.git
```

**Skill (user-level):**

```bash
mkdir -p ~/.claude/skills
cp -R claude-skills/skills/architecture-doc-writer ~/.claude/skills/
```

**Agent (user-level):**

```bash
mkdir -p ~/.claude/agents
cp claude-skills/agents/seo-expert.md ~/.claude/agents/
```

For project-level, swap `~/.claude/...` with `./.claude/...` while inside the target repo.

> After install, **restart Claude Code** (or open a new session) so the items are picked up.

---

## Verify install

```bash
# User-level
ls ~/.claude/skills/architecture-doc-writer
ls ~/.claude/agents/seo-expert.md

# Project-level
ls ./.claude/skills/architecture-doc-writer
ls ./.claude/agents/seo-expert.md
```

Then open Claude Code and either:

- **Skill** — type `/architecture-doc-writer`, or prompt naturally (*"viết tài liệu kiến trúc cho hệ thống X"*) — it auto-triggers.
- **Agent** — Claude will route SEO-related tasks to `seo-expert` proactively, or you can ask explicitly: *"use the seo-expert agent to audit `app/blog/[slug]/page.tsx`"*.

---

## Updating

```bash
cd claude-skills && git pull
```

Then re-run install for the item(s) you care about:

```bash
./install.sh --user seo-expert
./install.sh --user all-skills      # refresh every skill
./install.sh --user all-agents      # refresh every agent
```

> If you installed with `--link`, `git pull` alone is enough — the symlink already points at the repo.

---

## Uninstalling

```bash
# Specific item (auto-routes to skills/ or agents/)
./install.sh --uninstall --user seo-expert
./install.sh --uninstall --project architecture-doc-writer
```

Or remove the file/dir directly:

```bash
rm    ~/.claude/agents/seo-expert.md
rm -rf ~/.claude/skills/architecture-doc-writer
```

---

## Repo layout

```
.
├── README.md
├── LICENSE
├── install.sh
├── agents/
│   └── seo-expert.md                    # → ~/.claude/agents/seo-expert.md
└── skills/
    └── architecture-doc-writer/         # → ~/.claude/skills/architecture-doc-writer/
        ├── SKILL.md
        ├── references/
        └── assets/
```

---

## Contributing

**Adding a skill:**
1. New dir under `skills/<your-skill-name>/`.
2. Create `SKILL.md` with YAML frontmatter (`name`, `description`).
3. Optional: `references/` (loaded on demand), `assets/` (templates).
4. Add a row to the **Skills** table above.

**Adding a subagent:**
1. New file at `agents/<your-agent-name>.md`.
2. YAML frontmatter must include `name`, `description`, and optionally `model` (`sonnet` / `opus` / `haiku`).
3. Body is the system prompt for the agent — be specific about when to use it, what to inspect, and what conventions to follow.
4. Add a row to the **Subagents** table above.

See the [skills docs](https://docs.claude.com/en/docs/claude-code/skills) and [subagents docs](https://docs.claude.com/en/docs/claude-code/sub-agents) for the full schema.

---

## License

MIT — see [LICENSE](LICENSE).

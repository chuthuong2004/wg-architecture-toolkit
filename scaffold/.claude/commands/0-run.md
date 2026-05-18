# Service Lifecycle Utility (`/0-run`)

Manages the dev/prod environment for this project.

> **Not a pipeline stage.** This is an always-available utility — invoke it any time you need to start, stop, rebuild, or inspect a service. It does not produce a stage handoff artifact (other than a brief status report at `.claude/outputs/stage-0-run.md`).

## Execution mode: in-context

You execute the DevOps Engineer role directly in the current Claude session (no subagent spawn).

### Procedure

1. Read `.claude/agents/devops.md` and adopt the persona, principles, and procedures defined there.
2. Parse `$ARGUMENTS` against the subcommand table below. If empty or unrecognized, default to `start`.
3. Follow the agent's procedure for that subcommand.
4. Write the status report to `.claude/outputs/stage-0-run.md` using the format in `devops.md`.

## Subcommand reference

| Argument | What it does |
|---|---|
| _(empty)_ / `start` / `all` | Boot the full dev stack. Run health probes. |
| `stop`                      | Stop the dev stack. |
| `status` / `health`         | Orchestrator state + HTTP probes + login smoke test. |
| `<service-name>`            | Rebuild and start one named service. |
| `db`                        | Start only the database. |
| `build`                     | Rebuild all images with `--no-cache`. |
| `restart <service>`         | Restart one named service. |
| `logs <service>`            | Tail logs for one service (defaults to all if omitted). |
| `prod`                      | Boot the production stack (validates required env vars first). |

## Safety notes

- Destructive commands (`docker compose down -v`, `clean_cmd`, etc.) require **explicit user confirmation**. The DevOps agent will pause and ask.
- Production mode validates required env vars before starting. If anything is missing or has a placeholder, the agent stops and asks the user to fix `.env`.

---

Starting work on `$ARGUMENTS`. Reading `.claude/agents/devops.md` first.

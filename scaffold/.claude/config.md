# Project Configuration

This file is the **single source of truth** for project environment information used by every Claude Code agent and slash command in `.claude/`.

> **Read this first.** Every agent (`.claude/agents/*.md`) and every command (`.claude/commands/*.md`) begins by reading this file. Hard-coding paths, ports, or commands anywhere else is a bug. If a value is wrong here, fix it here — do not patch it downstream.

> **Setup checklist.** When scaffolding a new project, replace every `<placeholder>` below with the actual value. Delete the sections that don't apply.

---

## Project Info

- **project_name**: `<project-slug>` (e.g., `my-app`)
- **project_description**: `<one-sentence description of what this project is>`
- **project_root**: `<absolute path to repo root>`
- **package_manager**: `<pnpm | npm | yarn | uv | poetry | cargo | go-mod | …>`
- **runtime_version**: `<e.g., node >=20, python >=3.12, go >=1.22>`
- **architecture_doc**: `docs/architecture/` (the canonical "where we are" map)

---

## Services

> List every long-running service in the project. For each: path, stack, dev port, prod port, build/lint/typecheck/test/dev commands.

### `<service-name-1>` (e.g., web / api / worker)
- **path**: `<path to package>`
- **stack**: `<frameworks + key libraries>`
- **port (dev)**: `<port>`
- **port (prod)**: `<port>`
- **build_cmd**: `<build command>`
- **lint_cmd**: `<lint command>`
- **typecheck_cmd**: `<typecheck command>`
- **test_cmd**: `<unit test command>` (or `_none configured_` if no tests yet)
- **test_e2e_cmd**: `<e2e command>` (or `_none configured_`)
- **dev_cmd**: `<dev command>`
- **api_docs_url**: `<swagger / scalar / etc. URL if applicable>`

### `<service-name-2>`
- (same shape)

### `<db-or-storage>` (e.g., Postgres / Redis / S3-compatible)
- **type**: `<PostgreSQL 16 | Redis 7 | …>`
- **port (dev)**: `<port>`
- **managed_by**: `<docker-compose | external | …>`
- **default_creds (dev)**: `<user / pass / db>` (dev only — never commit prod creds)
- **connection_url (dev)**: `<url>`
- **migrate_cmd**: `<migration command if applicable>`
- **seed_cmd**: `<seed command if applicable>`
- **schema_file**: `<path to schema file>`
- **migrations_dir**: `<path>`

---

## Infrastructure

- **orchestration**: `<docker-compose | kubernetes | bare-metal | hosted-PaaS | …>`
- **dev_config**: `<path to dev compose file or equivalent>`
- **prod_config**: `<path to prod compose file or equivalent>`
- **start_cmd**: `<one command to bring dev up>`
- **stop_cmd**: `<one command to tear dev down>`
- **build_cmd**: `<image / artifact build command>`
- **prod_start_cmd**: `<prod start command, if doable manually>`
- **prod_stop_cmd**: `<prod stop command>`
- **logs_cmd**: `<tail logs command>`
- **shell_cmd**: `<exec-into-container command>`
- **clean_cmd**: `<destructive cleanup — confirm before running>`

> **Networking note.** Document where each service runs in dev vs. prod (host vs. container, exposed ports vs. internal), and how requests are routed (reverse proxy, ingress, DNS, …).

---

## Auth

### Interactive (browser → frontend → backend)
- **method**: `<JWT bearer | session cookie | OAuth | …>`
- **access_token_lifetime**: `<duration>`
- **refresh_token_storage**: `<where + how — hashed? slot per user? rotated?>`
- **login_endpoint**: `<HTTP method + path>`
- **login_content_type**: `<application/json | x-www-form-urlencoded>`
- **login_body**: `<example body>`
- **login_response**: `<example response>`
- **default_account (seeded)**: `<email / pass from .env>`

### Programmatic (AI agents, integrations)
- **method**: `<API key in X-API-Key header | OAuth client credentials | …>`
- **key_format**: `<e.g., bbpm_<56 hex chars>>`
- **storage**: `<hash strategy + index column>`
- **endpoints**: `<which routes accept the programmatic auth>`
- **management endpoint**: `<how to issue / revoke keys>`

### Token-acquisition snippet
Used by agents (see `.claude/shared/procedures.md`):
```bash
# Customize per project — example for a JSON login endpoint returning a JWT.
TOKEN=$(curl -s -X POST <dev-base-url>/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"<seeded-email>","password":"<seeded-password>"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['accessToken'])")
```

---

## API

- **base_url (dev)**: `<url>`
- **base_url (prod)**: `<url>`
- **prefix**: `<e.g., /api>` (where applicable)
- **frontend_url (dev)**: `<url>`
- **frontend_url (prod)**: `<url>`
- **api_docs**: `<swagger / scalar / docs URL>`
- **rate_limit**: `<requests / window per IP or per key>`
- **cors_origin**: `<env var name + default>`
- **response_envelope**: `<describe success vs. error shape, e.g., `{data: …}` vs. `{statusCode, message, error}`>`

---

## CI/CD

- **enabled**: `true | false`
- **tool**: `<GitHub Actions | GitLab CI | CircleCI | Buildkite | …>`
- **repo_url**: `<git URL>`
- **default_branch**: `<main | master | develop>`
- **branch_strategy**: `<feature-branch + PR | trunk-based | gitflow>`
- **branch_prefix**: `feat/`, `fix/`, `refactor/`, `chore/`, `docs/`
- **pr_base_branch**: `<base branch for new PRs>`
- **deploy_trigger**: `<merge to main | tag push | manual workflow_dispatch>`
- **pipeline_url**: `<URL to CI dashboard>`
- **status_check_cmd**: `<e.g., gh run list --limit 5>`
- **pr_checks_cmd**: `<e.g., gh pr checks <pr-number>>`

> **`enabled: false`** triggers `/5-deploy` to abort with a CI/CD-not-configured warning. Manual deploys are typically not permitted — be deliberate about flipping this.

### Required CLI tools for deploy
- `gh` — GitHub CLI (or equivalent for your platform). Verify with `gh --version`.
- `git` — must be on a clean working tree before `/5-deploy` runs.

---

## E2E / Browser Automation

- **tool**: `<Playwright | Cypress | Claude in Chrome MCP | none>`
- **required**: `true | false`
- **e2e_entry_url (dev)**: `<url>`
- **e2e_entry_url (prod)**: `<url>`
- **login_flow**:
  1. <step 1>
  2. <step 2>
  3. <step 3>
- **critical_paths** (verified on every test/verify run):
  1. <flow 1>
  2. <flow 2>
- **console_error_policy**: `<e.g., zero console errors required for PASS; warnings tolerated>`
- **evidence_recording**: `<screenshots | gifs | video | trace | none>`

> **Failure mode.** If the E2E tool can't run (extension not connected, no browser, etc.), the QA agent must warn the user and **not** mark QA as PASS. Skipping E2E silently is forbidden.

---

## Conventions

- **commit_prefix**: `feat`, `fix`, `refactor`, `docs`, `style`, `test`, `chore`, `perf`
- **commit_format**: `<prefix>: <short imperative summary>` (one line, ≤72 chars)
- **language_style**: `<naming conventions per language: camelCase / PascalCase / snake_case / ALL_CAPS for what>`
- **module_layout**: `<how a feature module is laid out — directory shape, file naming>`
- **frontend_layout**: `<page / component / api / store directory shape>`
- **import_order**: `<order rule, e.g., builtins → third-party → workspace → aliased internal → relative>`
- **error_handling**: `<exception classes to throw + how the global error filter shapes the response>`
- **secrets**: `<.env policy, encryption-at-rest strategy for stored creds>`

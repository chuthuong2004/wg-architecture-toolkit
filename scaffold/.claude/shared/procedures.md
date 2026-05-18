# Shared Procedures

Reusable procedures referenced by multiple agents and commands. Each procedure is **self-contained** — an agent can paste the snippet and run it without further context.

All commands assume the working directory is the repo root (`config.md` → `project_root`).

> **Customization.** Many snippets reference URLs, container names, and commands that come from `config.md`. Replace placeholders like `<api-base-url>`, `<db-container>`, `<seeded-email>` with the values defined there.

---

## 1. Obtain an access token

Use the seeded admin account from `config.md` → `Auth → default_account`.

```bash
TOKEN=$(curl -s -X POST <api-base-url>/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"<seeded-email>","password":"<seeded-password>"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['accessToken'])")

# Sanity check
echo "$TOKEN" | head -c 60
[ -n "$TOKEN" ] || echo "ERROR: token is empty — is the API running?"
```

For subsequent calls:

```bash
curl -s -H "Authorization: Bearer $TOKEN" <api-base-url>/api/auth/profile
```

> **If login fails**, check the API logs first. Common causes: API not running, DB not migrated, seed not applied, or the admin password env var doesn't match the seeded value.

---

## 2. Service health check

Run all three steps; report each with HTTP status code and container state.

### 2.1. Container status
```bash
docker compose ps
```
Expected: every dependency in `Up (healthy)`. Confirm host-side processes with `lsof -i :<port>`.

### 2.2. HTTP probes
```bash
# Backend liveness (use a known-public endpoint — health check, swagger doc, etc.)
curl -s -o /dev/null -w "API:    %{http_code}  (%{time_total}s)\n" \
  <api-base-url>/<health-endpoint>

# Frontend
curl -s -o /dev/null -w "Web:    %{http_code}  (%{time_total}s)\n" \
  <web-base-url>

# Database
docker compose exec -T <db-container> <db-readiness-cmd>
```

### 2.3. Tail recent logs on failure
```bash
docker compose logs --tail=30 <service>
```

---

## 3. Determine change scope (Git)

Run all of these and include the output in your report.

```bash
git status -s                        # staged + unstaged + untracked
git diff --stat HEAD                 # line counts per file
git diff --name-only                 # changed files (one per line)
git diff --name-only --diff-filter=A # newly added files
git diff --name-only --diff-filter=D # deleted files
git log --oneline -10                # recent commit context
```

For PR-scoped reviews (use the PR's base branch from `config.md` → `pr_base_branch`):

```bash
BASE=<pr_base_branch>
git diff --name-only "$BASE"...HEAD
git diff "$BASE"...HEAD              # full diff
git log --oneline "$BASE"...HEAD     # commits on this branch
```

**Affected-service mapping** (customize per project — list every path prefix that maps to a service):

| Path prefix | Service |
|---|---|
| `<frontend-path>/` | web (frontend) |
| `<backend-path>/` | api (backend) |
| `<shared-path>/` | shared (both) |
| `<schema-path>/` | api + db (migration) |
| `<infra-paths>` | infra |
| `.github/` / `.gitlab-ci.yml` / `.circleci/` | CI/CD |

---

## 4. Build / rebuild a service

Always check `config.md` for the canonical command. Common shortcuts (replace with project-specific):

```bash
# Backend production build
<api-build-cmd>

# Frontend production build
<web-build-cmd>

# Regenerate ORM client after schema change (if applicable)
<orm-generate-cmd>

# Apply pending migrations to dev DB
<migrate-cmd>

# Full container image rebuild
<image-build-cmd>
```

---

## 5. E2E browser testing

Used by the QA Engineer (Stage 4) and the Verifier (Stage 6). Steps depend on the E2E tool defined in `config.md` → `E2E / Browser Automation`.

### 5.1. Preflight
1. Check the E2E tool is reachable. If it errors → **stop**. Ask the user to start the tool. Do not mark E2E as PASS.
2. Open a fresh session / browser context.
3. Navigate to `config.md` → `e2e_entry_url`.

### 5.2. Login
1. Follow `config.md` → `Auth → default_account`.
2. Fill email + password.
3. Submit and assert redirect to the post-login landing page.
4. Verify no console errors after the redirect.

### 5.3. Critical-path sweep
Walk every entry in `config.md` → `critical_paths` in order. For each:
1. Assert the expected element renders.
2. Capture console errors — must be empty.
3. If `evidence_recording` is configured, capture screenshot / GIF / trace.

### 5.4. Change-scoped E2E
After the critical-path sweep, run the E2E scenarios defined by the QA agent for **this** change. The scenarios live in `.claude/outputs/stage-4-test.md` Phase 1.

### 5.5. Failure capture
On any failure:
- Screenshot evidence.
- Full console dump (no filter).
- Failed HTTP requests (network panel).
- Include all three in the bug report.

### 5.6. Pass criteria
- 100% of critical paths complete without thrown errors.
- 0 console errors (warnings tolerated unless `config.md` says otherwise).
- All change-scoped scenarios PASS.
- Evidence attached when required.

---

## 6. Verify a previous stage's output

Every stage reads the previous stage's report. Before doing anything else, check it exists.

```bash
# Example: Stage 4 reading Stage 2's implementation report
test -f .claude/outputs/stage-2-implement.md && \
  echo "✓ Stage 2 report present" || \
  echo "✗ Stage 2 report MISSING — instruct user to run /2-implement"
```

If the file is missing:
- **Do not** invent context from the conversation.
- **Do not** proceed.
- Tell the user which stage to run, then stop.

If the file exists but is malformed (missing required sections), report the issue to the user and stop.

---

## 7. Archive previous workrun outputs

Used by `/1-plan` when starting a new task while previous stage outputs still exist.

```bash
# Extract the previous task name from stage-1-plan.md's first line
# (the heading after "# Plan: " — fall back to "unknown")
SLUG=$(head -1 .claude/outputs/stage-1-plan.md 2>/dev/null \
  | sed -E 's/^# Plan: *//' \
  | tr -cd '[:alnum:]-_' \
  | head -c 40)
[ -z "$SLUG" ] && SLUG="unknown"

DATE=$(date +%Y-%m-%d)
DEST=".claude/outputs/history/${DATE}_${SLUG}"

mkdir -p "$DEST"
cp .claude/outputs/stage-*.md "$DEST/" 2>/dev/null
rm -f .claude/outputs/stage-*.md
echo "Archived previous run to $DEST"
```

---

## 8. Quick API smoke test

Useful in Stage 4 and Stage 6 for quick endpoint verification.

```bash
TOKEN=$(<from-procedure-1>)
BASE=<api-base-url>

# List a basic resource — replace with one of your read-only endpoints
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/<resource>" | jq

# Get current user (or equivalent self-info endpoint)
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/auth/profile" | jq

# API spec listing (Swagger / Scalar / OpenAPI json)
curl -s "$BASE/<docs-json-path>" | jq '.paths | keys[]' | head -40
```

---

## 9. Investigate a database state question

```bash
# Open a shell inside the db container (replace with your db's CLI)
docker compose exec -it <db-container> <db-cli>

# Or one-shot query
docker compose exec -T <db-container> <db-cli> -c "<query>"
```

Reference: `<schema-file>` for the canonical schema and `<migrations-dir>` for the migration history.

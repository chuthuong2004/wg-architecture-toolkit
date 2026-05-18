# <Domain> Changelog

> One-line scope description. What concern does this domain own?

## Owns

- **Modules**: `<source path to the module that owns this domain>`
- **Frontend**: `<source paths to the UI pages / api modules / components that belong to this domain>`
- **Tables**: `<list of DB tables / models>`
- **Migrations**: `<glob or naming pattern for migrations in this domain>`

## Surface

- **HTTP routes**:
  - `GET /api/<feature>` — …
  - `POST /api/<feature>` — …
- **Webhooks** (if any): `POST /api/webhooks/<feature>/…`
- **Schedulers** (if any): `<Cron expr>` — purpose
- **UI screens**: `/<route>` — purpose

## Timeline

> Newest entries first.

### YYYY-MM-DD — <Short title> (<commit short SHA>)
**Added | Changed | Fixed | Removed | Schema.** One-sentence description.

- Optional details (bullets).
- Migration: `<migration-folder>` — what it does in one line.
- Source: `<path/to/file:line>`.

### YYYY-MM-DD — <Earlier title> (<commit short SHA>)
**Added.** …

---

## Open questions / known issues

(Optional.) Pull from the project's risk register if a risk is still open in this domain. Example:

- **R-<n>** — <one-line description of the open risk and where it's tracked>.

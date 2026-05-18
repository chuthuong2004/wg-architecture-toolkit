# Architecture

Canonical "where we are" map of the system. Read this before designing a non-trivial change — every agent in `.claude/agents/` does the same.

> Keep this directory authoritative. When the code changes, update the doc in the same PR. A stale architecture doc is worse than no doc.

---

## Suggested structure

For a monorepo, mirror the top-level packages:

```
docs/architecture/
├── README.md                   ← you are here
├── overview.md                 ← top-level system diagram + module index
├── <package-a>/                ← one subdirectory per package or service
│   ├── README.md               ← entry point: index of the docs in this dir
│   ├── overview.md             ← module list, dataflow, ER, key sequence diagrams
│   ├── folder-structure.md     ← directory shape + naming conventions
│   ├── patterns.md             ← idioms specific to this package
│   └── refactor-plan.md        ← (optional) active refactor in flight
├── <package-b>/
│   └── …
```

For a single-app repo, replace the per-package directories with one `overview.md` plus topic-specific docs (`data-model.md`, `auth.md`, `integrations.md`, etc.).

---

## What belongs here

- **System-wide diagrams**: top-level component diagram, network/deployment topology, request flow for the canonical happy path.
- **Module ownership map**: which directory / file owns which concern. Agents use this to decide where a new feature lives.
- **Data model**: ER diagram, key tables, denormalization decisions, soft-delete strategy, audit-trail strategy.
- **Cross-cutting policies**: authentication, authorization, encryption-at-rest, secret storage, rate limiting.
- **Integration sequences**: how the system talks to each third-party (Slack, GitHub, Stripe, …) — sequence diagrams + idempotency keys + retry budgets.
- **Risk register**: known fragility points worth flagging to anyone designing a change in that area.

## What does *not* belong here

- Active feature plans → `docs/plans/`.
- Per-domain change history → `docs/changelogs/`.
- Per-feature implementation details — those live in code + docstrings.

---

## Diagram conventions

- Use **Mermaid** for diagrams (renders on GitHub natively, scales to text-mode editors).
- Tag every diagram with the date it was last verified (`<!-- last verified: 2026-05-18 -->`).
- Prefer many small diagrams over one giant one — readers should be able to load one section at a time.

## Update cadence

- Refactor in flight that changes the module map → update **in the same PR** that lands the refactor.
- New module → update the module ownership map in `overview.md`.
- New cross-package contract / port → document the contract here, link from both sides.
- Quarterly review: scan for stale assertions, drop sections that no longer reflect reality.

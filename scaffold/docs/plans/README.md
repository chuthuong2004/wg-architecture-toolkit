# Plans

Concrete implementation plans, one file per feature. Each plan is the artifact that `/1-plan` produces and `/2-implement` consumes.

> A plan is **what we're about to build**, not what we've already built. After a plan ships, the relevant per-domain entry in [`docs/changelogs/`](../changelogs/) is updated and the plan stays as a historical record of the decision.

## Index

| File | Status | Domain | Summary |
|---|---|---|---|
| (Add one row per plan as you promote it from `.claude/outputs/stage-1-plan.md` to `docs/plans/`.) |

## Convention

- File name: kebab-case, one feature per file.
- Status flow: `Proposed → Approved → In Progress → Shipped`. When `Shipped`, also list the merge commit SHA.
- Structure follows `.claude/agents/planner.md`:
  1. Requirement summary (the *what* + *why*).
  2. Affected services / files (with `<file>:<line>` anchors).
  3. Proposed implementation, step by step.
  4. API / UI changes.
  5. Risks & considerations.
  6. Out of scope.
  7. Estimated effort.

## When to promote

`/1-plan` writes to `.claude/outputs/stage-1-plan.md`. Promote a plan to this directory when **any** of:

- The plan will span more than one PR (so the file survives across sessions).
- Multiple people will collaborate on the implementation.
- The plan documents a non-obvious decision worth preserving for future readers.

Trivial single-PR plans can stay in `.claude/outputs/` and ship without promotion.

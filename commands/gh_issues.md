---
description: >
  Tabular overview of a GitHub repo's issues — number, title, type, priority, effort,
  dependencies, assignee — with the semantic columns resolved through the repo's OWN label
  scheme, native issue types, and project fields (discovered per run, never imposed).
  Use for "gh_issues", "list the github issues", "issues table", "issues overview",
  "what's open in this repo". Read-only; never mutates issues.
argument-hint: "[--state all] [--mine] [--type <t>] [--priority <p>] [--sort <key>] [--no-deps] [--search \"<q>\"] [--repo owner/repo]"
allowed-tools: Bash(gh issue list:*), Bash(gh issue view:*), Bash(gh label list:*), Bash(gh api graphql:*), Bash(gh repo view:*), Bash(gh auth status:*)
---

# gh_issues — adaptive GitHub issues table

Render a repo's issues as one markdown table. The semantic columns (Type, Priority, Effort)
are resolved through the repo's **own** scheme — its labels, native issue types, and project
fields — discovered fresh on every run. Never impose a label convention on a repo; its
vocabulary is the truth.

**Strictly read-only.** Never create, edit, close, comment on, or label anything. `gh api
graphql` is used for read queries only — no mutations, ever.

## Flags

| Flag | Meaning |
|------|---------|
| `--state <open\|closed\|all>` | issue state filter (default `open`) |
| `--label <name>` | filter by label (repeatable) |
| `--assignee <login>` | filter by assignee |
| `--mine` | shorthand for `--assignee @me` |
| `--author <login>` | filter by author |
| `--milestone <m>` | filter by milestone |
| `--search "<q>"` | GitHub search-syntax query |
| `--limit <n>` | max issues fetched (default: `gh`'s own default, 30) |
| `--repo owner/repo` | target repo (default: the current directory's repo) |
| `--type <t>` | semantic filter through the discovered type scheme |
| `--priority <p>` | semantic filter through the discovered priority scheme |
| `--sort <priority\|effort\|updated\|number>` | sort key (default `priority`) |
| `--no-deps` | skip dependency detection entirely (no GraphQL call) |

## Protocol

1. **Preflight.** Run `gh auth status`. If `gh` is missing or unauthenticated, stop with an
   actionable hint (install: https://cli.github.com · authenticate: `gh auth login`) — never
   render a partial table. Resolve the target repo: `--repo owner/repo` when given, otherwise
   the current directory's repo via `gh repo view`. Not inside a repo and no `--repo` → stop
   and ask for `--repo owner/repo`.
2. **Flag validation.** `--limit` must be numeric — reject with a usage line otherwise. An
   unknown `--sort` key → error listing the valid keys. Every user-supplied string (labels,
   search query, milestone, logins…) is passed to `gh` as a quoted argument — never
   interpolated unquoted, never through `eval`.
3. **Scheme discovery.** One `gh label list --json name,description --limit 100` call.
   Classify the label families heuristically at runtime:
   - **priority-ish** — e.g. `P1`, `prio/high`, `priority: high`, `critical`
   - **type-ish** — e.g. `bug`, `enhancement`, `type: feature`, `docs`
   - **effort-ish** — e.g. `size/M`, `effort: 3`, `XL`, t-shirt sizes
   Nothing is hardcoded: classify whatever this repo actually uses, and derive each family's
   internal ranking from its own naming (`P1` outranks `P2`; `high` outranks `low`; …).
4. **Fetch.** One `gh issue list --json number,title,labels,assignees,milestone,body,state,updatedAt`
   call, passing through every native filter flag the user gave (`--state --label --assignee
   --author --milestone --search --limit`); `--mine` expands to `--assignee @me`.
5. **Relations & types** *(skipped entirely under `--no-deps`)*. One batched GraphQL query
   fetching, for the listed issues: the native issue-type name (when the repo/org has issue
   types) and parent/sub-issue ("tracked-by") relations; include the search's total issue
   count when the result may be truncated (footer, below). Combine relations with a
   body-marker scan — `Depends on #N`, `Blocked by #N`, `Depends: #N`, all case-insensitive.
   If the GraphQL query fails, degrade to body-marker-only detection and say so in a notice.
6. **Semantic filtering.** `--type <t>` and `--priority <p>` match *through* the discovered
   scheme — `--priority high` matches `P1` in a `P1/P2/P3` repo, with a mapping notice
   ("`--priority high → P1`"). A value not present in the scheme → error listing the values
   that DO exist. A scheme family absent entirely → one notice line and the flag is ignored.
7. **Render** per the rules below, including notices and the truncation footer.

## Column resolution (per issue)

| Column | Resolution order | Empty state |
|--------|------------------|-------------|
| Type | native issue type → type-family label → `—` | `—` |
| Priority | project priority-like field (when available) → priority-family label → `—` | `—` |
| Effort | project size/estimate-like field → effort-family label → `—` | `—` |
| Deps | relations → body markers; **open dependencies only** (a closed dependency no longer blocks, so it drops out) | `—` |
| Assignee | assignees list (`@login`, comma-joined) | `—` |

## Sorting

- Default: priority **descending** through the discovered scheme's own ordering; issues with
  no priority sort last; ties break by issue number ascending.
- `--sort priority|effort|updated|number` — always applied client-side (derived columns
  cannot be sorted server-side).

## Rendering

- One markdown table, columns exactly `# · Title · Type · Priority · Effort · Deps · Assignee`.
- Titles are **never truncated**.
- Under `--no-deps`: omit the Deps column and print a notice that dependency detection was
  skipped — a column of cells for data that was deliberately not fetched would be dishonest.
- **Notices before the table:** absent scheme families ("this repo has no priority labels;
  `--priority` ignored"), degradations (GraphQL unavailable → marker-only deps), and mapping
  notes for translated semantic filters (e.g. `--priority high → P1`).
- **Footer:** when `--limit` truncates the result, say so — "showing 30 of 87 open issues —
  raise `--limit` to see more". No silent caps.
- Zero matches → "No issues match" plus the list of active filters — never an empty table.

## Error handling

| Error case | Handling |
|------------|----------|
| `gh` missing / unauthenticated | stop with install/auth hint |
| not in a repo and no `--repo` | stop, ask for `--repo owner/repo` |
| non-numeric `--limit` | reject with a usage line |
| unknown `--type` / `--priority` value | error listing the discovered valid values |
| unknown `--sort` key | error listing the valid keys |
| GraphQL relations query fails | degrade to body-marker-only deps + notice |

## Degradation

This spec is behavior-level, not field-level. Where a `gh` JSON field or GraphQL shape is
unavailable on the running `gh` version (baseline 2.45.0), probe once, fall back down the
column-resolution order, and report the degradation in a notice line. A missing capability
never crashes the table.

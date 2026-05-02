# Fork Resync: Reshape 133 Commits Onto Upstream v5.2.8

**Date:** 2026-04-29
**Status:** Approved (brainstorming complete, awaiting plan)
**Owner:** Alexander Smith (`alxmyth/superpowers`)

## Problem

The `alxmyth/superpowers` fork (`superpowers2`) has accumulated 133 non-merge
commits ahead of `pcvelz/superpowers` (`upstream/main` at `04bad33`,
v5.2.8) and is 24 commits behind. The fork's history is hard to read:
many setup-script tweaks net to zero, several rebrand commits are spread
across unrelated themes, and a few fork commits have already been
superseded by upstream improvements (e.g. `pre-commit-check-tasks.sh`,
`stop-deflection-guard.sh`, `test-helpers.sh`).

We want a clean, reviewable history that:

1. Tracks current upstream content exactly.
2. Re-applies only the fork's still-meaningful customizations.
3. Drops fork commits that upstream has obsoleted.
4. Adopts upstream improvements in shared files (no regressions).

## Strategy: Soft-Reset + Rebuild

Of the three options considered (interactive rebase, merge-and-squash,
soft-reset rebuild), we chose **soft-reset rebuild**. We use a mixed
reset rather than `--soft` so each batch can be staged from a clean
index:

```
git checkout -b resync/upstream-v5.2.8-rebuild
git reset upstream/main                # HEAD + index → upstream; working tree = main
# All fork-specific changes are now unstaged.
# Selectively stage and commit them in 9 logical groups.
```

(Naming this strategy "soft-reset rebuild" follows colloquial usage —
the actual command is a mixed reset.)

**Why this approach:**

- Working tree already reflects every decision we've made over 133 commits, so
  there's no merge resolution to redo.
- Soft-reset to upstream means any file we don't touch matches upstream
  exactly — automatically picking up upstream improvements (e.g. the
  better `pre-commit-check-tasks.sh`, the new `stop-deflection-guard.sh`,
  case-insensitive grep in `test-helpers.sh`).
- Each rebuilt commit gets a focused message describing one theme
  rather than the noisy reality of how the change was originally made.

**Why not the alternatives:**

- *Interactive rebase of 133 commits:* expensive in conflicts; many of
  the commits net to zero (4 setup.sh tweaks) and would be confusing to
  squash one-by-one.
- *Merge upstream and squash:* leaves the merge commit in history and
  doesn't give us logical commit boundaries.

## Strategic Decisions

| # | Decision | Choice | Rationale |
|---|----------|--------|-----------|
| 1 | Strategy | Soft-reset + rebuild | See above. |
| 2 | Granularity | 9 logical commits | Reviewable; one theme per commit. |
| 3 | Workspace | New branch in main checkout | `resync/upstream-v5.2.8-rebuild` — no worktree needed. |
| 4 | Landing | Push backup to origin first; await user call on main | Protect against data loss; user controls when main moves. |
| 5 | Version | `5.2.9` | Stays ahead of upstream's `5.2.8` while signalling a fresh baseline. |

## Resolutions of Open Questions

- **`stop-deflection-guard.sh`** (upstream commit `6db3cf0`, our fork
  did not have this): keep upstream's version. We adopt the new
  guard automatically by virtue of the soft-reset; no fork commit is
  needed to reintroduce it.
- **`test-helpers.sh`** (`grep -qi` and Python fallback for same-line
  ordering): keep upstream's improved version. The fork's main
  silently regressed `grep -qi` to `grep -q` and removed the Python
  fallback; soft-reset preserves upstream's fixes for free.
- **`scripts/sync-to-codex-plugin.sh`** (388 lines, pcvelz's codex
  mirroring): delete in commit 8 (`refactor: remove pcvelz-specific tooling`).
  We don't ship a Codex plugin from this fork.

## Pre-Rebuild Step: Adopt Upstream Files

Right after the mixed reset, before any commits, restore three files
to upstream's version (overwriting main's regressions in the working
tree):

```
git checkout upstream/main -- hooks/examples/pre-commit-check-tasks.sh
git checkout upstream/main -- hooks/examples/stop-deflection-guard.sh
git checkout upstream/main -- tests/claude-code/test-helpers.sh
```

After this, those three paths match upstream in both index and working
tree, so no rebuilt commit will touch them.

## Commit Plan (9 commits)

After the pre-rebuild step above, every remaining staged change must
land in exactly one of the commits below. After commit 9, the working
tree must be empty.

### 1. `chore: rebrand superpowers-extended-cc → superpowers2`
Pure namespace string sweep. Plugin metadata, command frontmatter, hook
strings, skill cross-references, test scripts.

- `.claude-plugin/marketplace.json` (name only — version stays in commit 9)
- `.claude-plugin/plugin.json` (name only — version stays in commit 9)
- `.cursor-plugin/plugin.json`
- `gemini-extension.json`
- `.github/ISSUE_TEMPLATE/config.yml` (Discord URL: `35wsABTejz` → `Jd8Vphy9jq`)
- `commands/brainstorm.md`
- `commands/execute-plan.md`
- `commands/write-plan.md`
- `hooks/session-start` (`'superpowers-extended-cc:using-superpowers'` → `'superpowers2:using-superpowers'`)
- `skills/requesting-code-review/SKILL.md` (rebrand-only)
- `skills/using-superpowers/references/codex-tools.md` (rebrand-only)
- `skills/using-superpowers/references/copilot-tools.md` (rebrand-only — note: this file uses `superpowers:` without the `2`, which is intentional for the auto-discovery example)
- `skills/writing-skills/testing-skills-with-subagents.md` (rebrand-only)
- Test scripts:
  - `tests/claude-code/test-fork-validation.sh`
  - `tests/claude-code/test-subagent-driven-development.sh`
  - `tests/claude-code/test-subagent-driven-development-integration.sh`
  - `tests/subagent-driven-dev/run-test.sh`
  - `tests/subagent-driven-dev/go-fractals/plan.md`
  - `tests/subagent-driven-dev/go-fractals/scaffold.sh`
  - `tests/subagent-driven-dev/svelte-todo/plan.md`
  - `tests/subagent-driven-dev/svelte-todo/scaffold.sh`

### 2. `feat(skills): writing-plans HARD-GATE for user verification`
The HARD-GATE rewrite blocks plan handoff until user verification is
encoded as a native task. Combines the three fork commits that built
this gate (`0cc4aba`, `fa0c34f`, `8e37fba`) into one cohesive change.

- `skills/writing-plans/SKILL.md` (includes the rebrand strings on this file too)

### 3. `feat(skills): finishing-a-development-branch overhaul`
The 140-line rewrite removing the four-options menu, replacing it with
a single canonical flow.

- `skills/finishing-a-development-branch/SKILL.md`

### 4. `feat(skills): subagent-driven-development pipeline + parallel review`
The pipeline scheduling, parallel review, and the executing-plans
verification gate that consumes pipeline output.

- `skills/subagent-driven-development/SKILL.md`
- `skills/subagent-driven-development/code-quality-reviewer-prompt.md`
- `skills/subagent-driven-development/implementer-prompt.md`
- `skills/subagent-driven-development/spec-reviewer-prompt.md`
- `skills/shared/task-format-reference.md` (NEW)
- `skills/executing-plans/SKILL.md` (the `AskUserQuestion` user-verification gate)
- `skills/dispatching-parallel-agents/SKILL.md` (Integration section pointing to subagent-driven-development)

### 5. `feat(hooks): TaskUpdate completion verification hook`
- `hooks/hooks.json` (PreToolUse matcher for TaskUpdate)
- `hooks/pre-task-complete-check-verification` (NEW)

### 6. `chore(skills): cross-reference and reference-syntax cleanup`
The editorial sweep that lived in fork commits `d92917e` and `1edf86a`.
Fixes `@`-syntax cross-references to backtick form, renames the
`{PLAN_REFERENCE}` placeholder, de-attributes personal names, fixes
section numbering. Each file change is small (1-5 lines) but they share
one editorial theme.

- `skills/test-driven-development/SKILL.md` (`@testing-anti-patterns.md` → backtick)
- `skills/using-git-worktrees/SKILL.md` (de-attribute "Jesse's rule" → "the principle")
- `skills/writing-skills/SKILL.md` (section 4→5 numbering + `@graphviz-conventions.dot` → backtick + rebrand strings)
- `skills/systematic-debugging/SKILL.md` (drop "your human partner's" qualifier on heading + rebrand strings)
- `skills/requesting-code-review/code-reviewer.md` (`{PLAN_REFERENCE}` → `{PLAN_OR_REQUIREMENTS}`)

### 7. `docs: rewrite README and add fork docs`
- `README.md` (fork-specific README)
- `CHANGELOG.md` (fork bookkeeping — NEW)
- `docs/superpowers/specs/2026-03-23-codex-app-compatibility-design.md` (NEW)
- `docs/superpowers/plans/2026-03-23-codex-app-compatibility.md` (NEW)
- `docs/superpowers/specs/2026-04-29-fork-resync-design.md` (this doc — NEW)
- `docs/superpowers/plans/2026-04-29-fork-resync.md` (writing-plans output — NEW)

### 8. `refactor: remove pcvelz-specific tooling`
Deletions only.

- `scripts/sync-to-codex-plugin.sh` (388 lines, deleted)
- `skills/systematic-debugging/CREATION-LOG.md` (119 lines, deleted)

### 9. `chore: bump version to 5.2.9`
- `.claude-plugin/plugin.json` (`5.2.7` → `5.2.9`)
- `.claude-plugin/marketplace.json` (`5.2.7` → `5.2.9`)

## Files Explicitly NOT Touched (upstream wins)

These differ between fork's `main` and `upstream/main`, but the
upstream version is strictly better. The pre-rebuild step above
restores them to upstream so no rebuilt commit touches them.

- `hooks/examples/pre-commit-check-tasks.sh` (anchored grep, opt-in)
- `hooks/examples/stop-deflection-guard.sh` (new in upstream)
- `tests/claude-code/test-helpers.sh` (`grep -qi`, Python fallback)

## Backup & Safety Plan

Before any destructive operation:

1. Create local tag: `git tag backup/main-pre-rebase-2026-04-29 main`
2. Create local backup branch: `git branch backup/main-pre-rebase-2026-04-29 main`
3. Push backup branch (NOT the tag, NOT main) to origin:
   `git push origin backup/main-pre-rebase-2026-04-29`
4. Build the rebuild branch (`resync/upstream-v5.2.8-rebuild`) with the
   9 commits.
5. Stop. Show the user the rebuilt branch.
6. Wait for explicit user approval before touching `main` or
   force-pushing anything.

Recovery is a single `git reset --hard backup/main-pre-rebase-2026-04-29`
or, if local backup is lost, fetching from origin.

## Verification

After rebuilding the 9 commits and before handing back to the user:

1. **Empty-tree check:** With the rebuild branch checked out,
   `git status` must be clean.
2. **Diff against main:** `git diff resync/upstream-v5.2.8-rebuild main`
   should equal **only** the upstream improvements we deliberately
   accepted (`pre-commit-check-tasks.sh`, `stop-deflection-guard.sh`,
   `test-helpers.sh`). Nothing else.
3. **Diff against upstream:** `git diff resync/upstream-v5.2.8-rebuild upstream/main`
   should equal the union of all 9 commit diffs and nothing more.
4. **Per-file ownership:** For every file in
   `git diff upstream/main..main --name-only`, confirm it appears
   in exactly one commit (or in the "files NOT touched" list).
5. **Fork validation test:** Run
   `tests/claude-code/test-fork-validation.sh` to confirm the
   `superpowers2` rebrand is correct end-to-end.
6. **Per-commit theme check:** Spot-check each rebuilt commit's diff
   reflects its message — one logical theme.

## Out of Scope

- Rewriting any of the 9 commit boundaries during execution. If the
  diff doesn't fit, we update this design doc and the writing-plans
  output before continuing — we don't quietly invent a 10th commit.
- Force-pushing `main`. That's a separate, user-authorised step after
  the rebuild branch is approved.
- Running `superpowers:writing-skills` evaluations. Skill content we
  re-apply is content the user has already validated; this resync is
  not a place to re-test it.

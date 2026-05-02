# Fork Resync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers2:subagent-driven-development (recommended) or superpowers2:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reshape 133 fork commits into 9 logical commits on a new branch (`resync/upstream-v5.2.8-rebuild`) that resets to `upstream/main` (v5.2.8), adopts upstream improvements on three shared files, and bumps the fork to v5.2.9 — without touching `main` until the user approves the rebuild branch.

**Architecture:** Mixed-reset rebuild. Create a new branch from `main`, run `git reset upstream/main` to put HEAD+index at upstream while leaving the working tree at `main`. Restore three "upstream wins" files via `git checkout upstream/main -- <path>`. Then build 9 commits by selectively staging from the working tree. Verify each commit's content matches its theme. End with a user-verification gate before any push of `main`.

**Tech Stack:** git (>= 2.30), bash, the existing fork test scripts.

**User Verification:** YES — the user explicitly chose "Push backup branch to origin first, then await your call" for landing strategy. Before any push of the rebuild branch over `main`, the user must inspect the rebuild branch and approve.

---

## Pre-flight Context

**Working directory:** `/Users/amsmith/code/personal/superpowers-extended-cc`
**Current branch:** `main`
**Upstream remote:** `upstream` → `pcvelz/superpowers` (HEAD `04bad33`, v5.2.8)
**Origin remote:** `origin` → `alxmyth/superpowers`
**Backup naming:** `backup/main-pre-rebase-2026-04-29` (both tag and branch)
**Rebuild branch name:** `resync/upstream-v5.2.8-rebuild`

Every git operation runs from the repo root. No worktree needed — the spec confirms a new branch in the existing checkout is sufficient.

---

## Task 0: Pre-flight backup & branch setup

**Goal:** Create local backup tag + backup branch, push backup branch to origin, then create the rebuild branch from `main`. After this task, no destructive operation has occurred and a recovery point exists on origin.

**Files:** None (refs only).

**Acceptance Criteria:**
- [ ] Local tag `backup/main-pre-rebase-2026-04-29` exists at the same SHA as `main`.
- [ ] Local branch `backup/main-pre-rebase-2026-04-29` exists at the same SHA as `main`.
- [ ] Remote `origin` has the backup branch (verified via `git ls-remote`).
- [ ] Branch `resync/upstream-v5.2.8-rebuild` exists locally at the same SHA as `main` and is the currently checked-out branch.
- [ ] `git status` shows only the plan markdown and `.tasks.json` as untracked (no other modifications).

**Verify:**
```bash
git rev-parse main backup/main-pre-rebase-2026-04-29 resync/upstream-v5.2.8-rebuild
git ls-remote origin refs/heads/backup/main-pre-rebase-2026-04-29
git status --short
git rev-parse --abbrev-ref HEAD
```
Expected: First three SHAs identical. `ls-remote` returns the backup ref. `status --short` empty. `abbrev-ref HEAD` prints `resync/upstream-v5.2.8-rebuild`.

**Steps:**

- [ ] **Step 1: Confirm working tree state on `main`**

  ```bash
  git status --short
  git rev-parse --abbrev-ref HEAD
  ```

  Expected: `HEAD` is `main`. The only acceptable untracked entries are this plan and its tasks companion (they get committed in Task 8):
  - `?? docs/superpowers/plans/2026-04-29-fork-resync.md`
  - `?? docs/superpowers/plans/2026-04-29-fork-resync.md.tasks.json`

  Any other modified or untracked files: **STOP and resolve before continuing.**

- [ ] **Step 2: Fetch upstream to ensure local upstream ref is current**

  ```bash
  git fetch upstream
  git rev-parse upstream/main
  ```

  Expected: prints `04bad33...` (upstream HEAD). If a newer SHA appears, the spec's verification numbers may have shifted; pause and notify the user before continuing.

- [ ] **Step 3: Create local backup tag**

  ```bash
  git tag backup/main-pre-rebase-2026-04-29 main
  ```

- [ ] **Step 4: Create local backup branch**

  ```bash
  git branch backup/main-pre-rebase-2026-04-29 main
  ```

- [ ] **Step 5: Push backup branch (only) to origin**

  ```bash
  git push origin backup/main-pre-rebase-2026-04-29
  ```

  Do NOT push the tag. Do NOT push `main`.

- [ ] **Step 6: Verify backup branch is on origin**

  ```bash
  git ls-remote origin refs/heads/backup/main-pre-rebase-2026-04-29
  ```

  Expected: a SHA followed by the ref name. Empty output means the push silently failed — re-run Step 5.

- [ ] **Step 7: Create and switch to the rebuild branch**

  ```bash
  git checkout -b resync/upstream-v5.2.8-rebuild
  ```

- [ ] **Step 8: Verify branch state**

  Run the four commands in the **Verify** block above and confirm output matches.

```json:metadata
{"files": [], "verifyCommand": "git rev-parse --abbrev-ref HEAD", "acceptanceCriteria": ["backup tag exists", "backup branch exists locally", "backup branch pushed to origin", "rebuild branch checked out"], "requiresUserVerification": false}
```

---

## Task 1: Mixed reset and adopt upstream files

**Goal:** Reset the rebuild branch's HEAD+index to `upstream/main`, then overwrite three upstream-wins files in the working tree so they match upstream. After this, the working tree contains every fork-only delta we plan to commit.

**Files:**
- Restore from upstream: `hooks/examples/pre-commit-check-tasks.sh`
- Restore from upstream: `hooks/examples/stop-deflection-guard.sh`
- Restore from upstream: `tests/claude-code/test-helpers.sh`

**Acceptance Criteria:**
- [ ] `HEAD` of the rebuild branch is `upstream/main`'s SHA.
- [ ] The three files above are byte-identical to their upstream versions.
- [ ] No files outside these three are modified by the checkout step.
- [ ] `git status` shows only fork-only deltas (modified/untracked/deleted) — the three upstream-wins files are NOT in the status output.

**Verify:**
```bash
git rev-parse HEAD
git rev-parse upstream/main
diff <(git show HEAD:hooks/examples/pre-commit-check-tasks.sh) hooks/examples/pre-commit-check-tasks.sh
diff <(git show HEAD:hooks/examples/stop-deflection-guard.sh) hooks/examples/stop-deflection-guard.sh
diff <(git show HEAD:tests/claude-code/test-helpers.sh) tests/claude-code/test-helpers.sh
git status --short | grep -E 'pre-commit-check-tasks|stop-deflection-guard|test-helpers'
```
Expected: First two `rev-parse` values match. All three `diff` commands produce no output. The final `grep` produces no output (empty result).

**Steps:**

- [ ] **Step 1: Mixed reset to `upstream/main`**

  ```bash
  git reset upstream/main
  ```

  This moves `HEAD` and the index to `upstream/main` while leaving the working tree at `main`'s content. Every fork-only delta is now visible as unstaged changes.

- [ ] **Step 2: Restore the three upstream-wins files in working tree and index**

  ```bash
  git checkout upstream/main -- hooks/examples/pre-commit-check-tasks.sh
  git checkout upstream/main -- hooks/examples/stop-deflection-guard.sh
  git checkout upstream/main -- tests/claude-code/test-helpers.sh
  ```

- [ ] **Step 3: Verify state**

  Run the five commands in the **Verify** block. Confirm:
  - `HEAD` SHA equals `upstream/main` SHA
  - All three `diff` invocations are silent
  - `grep` over `git status --short` for the three filenames is empty

  **If the grep returns any line, STOP** — Step 2 was incomplete.

- [ ] **Step 4: Sanity-check the unstaged delta scope**

  ```bash
  git status --short | wc -l
  ```

  Expected: ~43 lines (46 differing files minus the 3 we just restored = 43). Off by more than ~3 lines is a signal something is wrong.

```json:metadata
{"files": ["hooks/examples/pre-commit-check-tasks.sh", "hooks/examples/stop-deflection-guard.sh", "tests/claude-code/test-helpers.sh"], "verifyCommand": "git rev-parse HEAD && git status --short | wc -l", "acceptanceCriteria": ["HEAD at upstream", "3 upstream-wins files restored", "~43 unstaged files remain"], "requiresUserVerification": false}
```

---

## Task 2: Commit 1/9 — `chore: rebrand superpowers-extended-cc → superpowers2`

**Goal:** Land the pure namespace rebrand across plugin manifests, command frontmatter, hook strings, and test scripts. Plugin manifests (which carry both name and version) are written explicitly to keep `version: 5.2.8` (matching upstream) — the version bump to 5.2.9 happens in Task 10.

**Files (all modified):**
- `.claude-plugin/marketplace.json` (rebrand only — written explicitly to preserve version 5.2.8)
- `.claude-plugin/plugin.json` (rebrand only — written explicitly to preserve version 5.2.8)
- `.cursor-plugin/plugin.json` (rebrand only — written explicitly to preserve version 5.2.8)
- `gemini-extension.json` (rebrand only — written explicitly to preserve version 5.2.8)
- `.github/ISSUE_TEMPLATE/config.yml`
- `commands/brainstorm.md`
- `commands/execute-plan.md`
- `commands/write-plan.md`
- `hooks/session-start`
- `skills/requesting-code-review/SKILL.md`
- `skills/using-superpowers/references/codex-tools.md`
- `skills/using-superpowers/references/copilot-tools.md`
- `skills/writing-skills/testing-skills-with-subagents.md`
- `tests/claude-code/test-fork-validation.sh`
- `tests/claude-code/test-subagent-driven-development.sh`
- `tests/claude-code/test-subagent-driven-development-integration.sh`
- `tests/subagent-driven-dev/run-test.sh`
- `tests/subagent-driven-dev/go-fractals/plan.md`
- `tests/subagent-driven-dev/go-fractals/scaffold.sh`
- `tests/subagent-driven-dev/svelte-todo/plan.md`
- `tests/subagent-driven-dev/svelte-todo/scaffold.sh`

**Acceptance Criteria:**
- [ ] All 21 files appear in commit 1 with the rebrand applied.
- [ ] Plugin manifests have `version: "5.2.8"` (unchanged from upstream).
- [ ] Plugin manifests have name `superpowers2` (or marketplace variant).
- [ ] No file outside the 21 listed appears in this commit.

**Verify:**
```bash
git show HEAD --stat | head -25
git show HEAD:.claude-plugin/plugin.json | grep -E '"name"|"version"|"homepage"'
git show HEAD:.claude-plugin/marketplace.json | grep -E '"name"|"version"'
git show HEAD:.cursor-plugin/plugin.json | grep -E '"name"|"version"'
git show HEAD:gemini-extension.json | grep -E '"name"|"version"'
```
Expected: `--stat` shows 21 files. Plugin manifests show `superpowers2` (or marketplace variant) and `5.2.8`.

**Steps:**

- [ ] **Step 1: Write `.claude-plugin/plugin.json`** (rebrand identity, version 5.2.8)

  Use the Write tool to set the file content to:

  ```json
  {
    "name": "superpowers2",
    "description": "Claude Code-specific fork of Superpowers with native task management and CC-specific enhancements",
    "version": "5.2.8",
    "author": {
      "name": "pcvelz",
      "email": "pcvelz@users.noreply.github.com"
    },
    "homepage": "https://github.com/alxmyth/superpowers",
    "repository": "https://github.com/alxmyth/superpowers",
    "license": "MIT",
    "keywords": ["skills", "tdd", "debugging", "collaboration", "best-practices", "workflows", "claude-code", "native-tasks"]
  }
  ```

- [ ] **Step 2: Write `.claude-plugin/marketplace.json`** (rebrand identity, version 5.2.8)

  ```json
  {
    "name": "superpowers2-marketplace",
    "description": "Marketplace for Superpowers Extended CC - Claude Code-specific enhancements",
    "owner": {
      "name": "pcvelz",
      "email": "pcvelz@users.noreply.github.com"
    },
    "plugins": [
      {
        "name": "superpowers2",
        "description": "Claude Code-specific fork of Superpowers with native task management and CC-specific enhancements",
        "version": "5.2.8",
        "source": "./",
        "author": {
          "name": "pcvelz",
          "email": "pcvelz@users.noreply.github.com"
        }
      }
    ]
  }
  ```

- [ ] **Step 3: Write `.cursor-plugin/plugin.json`** (rebrand identity, version 5.2.8)

  Read the current working-tree file first (it has the rebrand identity from main but version 5.2.7). Then Write it back with `version: "5.2.8"`. Keep all other fields identical to working-tree.

  Verify: `grep '"version"' .cursor-plugin/plugin.json` prints `"version": "5.2.8",`.

- [ ] **Step 4: Write `gemini-extension.json`** (rebrand identity, version 5.2.8)

  Same approach: Read current, set `version: "5.2.8"`, Write.

  Verify: `grep '"version"' gemini-extension.json` prints `"version": "5.2.8",`.

- [ ] **Step 5: Stage all 21 rebrand files**

  ```bash
  git add \
    .claude-plugin/marketplace.json \
    .claude-plugin/plugin.json \
    .cursor-plugin/plugin.json \
    gemini-extension.json \
    .github/ISSUE_TEMPLATE/config.yml \
    commands/brainstorm.md \
    commands/execute-plan.md \
    commands/write-plan.md \
    hooks/session-start \
    skills/requesting-code-review/SKILL.md \
    skills/using-superpowers/references/codex-tools.md \
    skills/using-superpowers/references/copilot-tools.md \
    skills/writing-skills/testing-skills-with-subagents.md \
    tests/claude-code/test-fork-validation.sh \
    tests/claude-code/test-subagent-driven-development.sh \
    tests/claude-code/test-subagent-driven-development-integration.sh \
    tests/subagent-driven-dev/run-test.sh \
    tests/subagent-driven-dev/go-fractals/plan.md \
    tests/subagent-driven-dev/go-fractals/scaffold.sh \
    tests/subagent-driven-dev/svelte-todo/plan.md \
    tests/subagent-driven-dev/svelte-todo/scaffold.sh
  ```

- [ ] **Step 6: Confirm exactly 21 files staged**

  ```bash
  git diff --cached --name-only | wc -l
  ```

  Expected: `21`. **If different, STOP and reconcile before committing.**

- [ ] **Step 7: Confirm no rebrand strings remain in any staged file**

  ```bash
  git diff --cached | grep -c '+.*superpowers-extended-cc'
  ```

  Expected: `0` lines. (The string `superpowers-extended-cc` may legitimately appear in `-` removal lines — only `+` additions matter.)

- [ ] **Step 8: Commit**

  ```bash
  git commit -m "chore: rebrand superpowers-extended-cc → superpowers2"
  ```

- [ ] **Step 9: Verify commit**

  ```bash
  git show HEAD --stat
  ```

  Confirm 21 files listed, message correct.

```json:metadata
{"files": [".claude-plugin/marketplace.json", ".claude-plugin/plugin.json", ".cursor-plugin/plugin.json", "gemini-extension.json", ".github/ISSUE_TEMPLATE/config.yml", "commands/brainstorm.md", "commands/execute-plan.md", "commands/write-plan.md", "hooks/session-start", "skills/requesting-code-review/SKILL.md", "skills/using-superpowers/references/codex-tools.md", "skills/using-superpowers/references/copilot-tools.md", "skills/writing-skills/testing-skills-with-subagents.md", "tests/claude-code/test-fork-validation.sh", "tests/claude-code/test-subagent-driven-development.sh", "tests/claude-code/test-subagent-driven-development-integration.sh", "tests/subagent-driven-dev/run-test.sh", "tests/subagent-driven-dev/go-fractals/plan.md", "tests/subagent-driven-dev/go-fractals/scaffold.sh", "tests/subagent-driven-dev/svelte-todo/plan.md", "tests/subagent-driven-dev/svelte-todo/scaffold.sh"], "verifyCommand": "git show HEAD --stat | tail -1", "acceptanceCriteria": ["21 files in commit", "manifests preserve version 5.2.8", "no '+' lines contain 'superpowers-extended-cc'"], "requiresUserVerification": false}
```

---

## Task 3: Commit 2/9 — `feat(skills): writing-plans HARD-GATE for user verification`

**Goal:** Land the writing-plans HARD-GATE rewrite that combines fork commits `0cc4aba`, `fa0c34f`, and `8e37fba` into one cohesive change. Working tree already has the desired content from `main`.

**Files:**
- Modify: `skills/writing-plans/SKILL.md`

**Acceptance Criteria:**
- [ ] Commit lands with exactly one file.
- [ ] The file contains the string `<HARD-GATE>` at least 3 times (the gate appears in three sections).
- [ ] No staged-file changes outside `skills/writing-plans/SKILL.md`.

**Verify:**
```bash
git show HEAD --stat
git show HEAD:skills/writing-plans/SKILL.md | grep -c 'HARD-GATE'
```
Expected: `--stat` shows 1 file. `grep -c` returns at least 6 (each `<HARD-GATE>...</HARD-GATE>` block has open + close).

**Steps:**

- [ ] **Step 1: Stage the file**

  ```bash
  git add skills/writing-plans/SKILL.md
  ```

- [ ] **Step 2: Verify exactly one file staged**

  ```bash
  git diff --cached --name-only
  ```

  Expected: single line `skills/writing-plans/SKILL.md`.

- [ ] **Step 3: Spot-check staged content**

  ```bash
  git diff --cached | grep -c 'HARD-GATE'
  ```

  Expected: `>= 6` (additions of HARD-GATE markers).

- [ ] **Step 4: Commit**

  ```bash
  git commit -m "feat(skills): writing-plans HARD-GATE for user verification

  Combines three fork commits (0cc4aba, fa0c34f, 8e37fba) that built
  the verification gate. The HARD-GATE blocks plan handoff until user
  verification is encoded as a native task with enforceable metadata."
  ```

- [ ] **Step 5: Verify commit**

  ```bash
  git show HEAD --stat
  ```

```json:metadata
{"files": ["skills/writing-plans/SKILL.md"], "verifyCommand": "git show HEAD --stat | tail -1", "acceptanceCriteria": ["1 file in commit", "HARD-GATE appears in committed content"], "requiresUserVerification": false}
```

---

## Task 4: Commit 3/9 — `feat(skills): finishing-a-development-branch overhaul`

**Goal:** Land the 140-line rewrite of finishing-a-development-branch that removes the four-options menu in favor of a canonical flow.

**Files:**
- Modify: `skills/finishing-a-development-branch/SKILL.md`

**Acceptance Criteria:**
- [ ] Commit lands with exactly one file.
- [ ] No staged changes outside that path.

**Verify:**
```bash
git show HEAD --stat
```
Expected: `--stat` shows 1 file.

**Steps:**

- [ ] **Step 1: Stage the file**

  ```bash
  git add skills/finishing-a-development-branch/SKILL.md
  ```

- [ ] **Step 2: Verify exactly one file staged**

  ```bash
  git diff --cached --name-only
  ```

  Expected: `skills/finishing-a-development-branch/SKILL.md`

- [ ] **Step 3: Commit**

  ```bash
  git commit -m "feat(skills): finishing-a-development-branch overhaul

  Replaces the four-options menu with a single canonical flow. Removes
  branching that slowed down completion and replaces it with a linear
  sequence."
  ```

- [ ] **Step 4: Verify commit**

  ```bash
  git show HEAD --stat
  ```

```json:metadata
{"files": ["skills/finishing-a-development-branch/SKILL.md"], "verifyCommand": "git show HEAD --stat | tail -1", "acceptanceCriteria": ["1 file in commit"], "requiresUserVerification": false}
```

---

## Task 5: Commit 4/9 — `feat(skills): subagent-driven-development pipeline + parallel review`

**Goal:** Land the subagent-driven-development pipeline scheduling, the three reviewer prompt files, the new shared task-format reference, the executing-plans user-verification gate, and the dispatching-parallel-agents Integration section.

**Files:**
- Modify: `skills/subagent-driven-development/SKILL.md`
- Modify: `skills/subagent-driven-development/code-quality-reviewer-prompt.md`
- Modify: `skills/subagent-driven-development/implementer-prompt.md`
- Modify: `skills/subagent-driven-development/spec-reviewer-prompt.md`
- Create: `skills/shared/task-format-reference.md`
- Modify: `skills/executing-plans/SKILL.md`
- Modify: `skills/dispatching-parallel-agents/SKILL.md`

**Acceptance Criteria:**
- [ ] Commit lands with exactly 7 files.
- [ ] `skills/shared/task-format-reference.md` is a NEW file (added, not modified).
- [ ] `skills/dispatching-parallel-agents/SKILL.md` adds an "Integration" section referencing `superpowers2:subagent-driven-development`.

**Verify:**
```bash
git show HEAD --stat
git log -1 --diff-filter=A --name-only -- skills/shared/task-format-reference.md
git show HEAD:skills/dispatching-parallel-agents/SKILL.md | grep -A1 '## Integration'
```
Expected: 7 files in stat. `task-format-reference.md` listed as added. Integration section visible.

**Steps:**

- [ ] **Step 1: Stage the seven files**

  ```bash
  git add \
    skills/subagent-driven-development/SKILL.md \
    skills/subagent-driven-development/code-quality-reviewer-prompt.md \
    skills/subagent-driven-development/implementer-prompt.md \
    skills/subagent-driven-development/spec-reviewer-prompt.md \
    skills/shared/task-format-reference.md \
    skills/executing-plans/SKILL.md \
    skills/dispatching-parallel-agents/SKILL.md
  ```

- [ ] **Step 2: Verify exactly seven files staged**

  ```bash
  git diff --cached --name-only | wc -l
  ```

  Expected: `7`.

- [ ] **Step 3: Verify task-format-reference is staged as new**

  ```bash
  git diff --cached --name-status | grep task-format-reference
  ```

  Expected: a line beginning with `A\t`.

- [ ] **Step 4: Commit**

  ```bash
  git commit -m "feat(skills): subagent-driven-development pipeline + parallel review

  Adds pipeline scheduling, parallel review across multiple reviewer
  prompts, and the executing-plans user-verification gate that consumes
  pipeline output. Introduces skills/shared/task-format-reference.md
  as the canonical task metadata schema."
  ```

- [ ] **Step 5: Verify commit**

  ```bash
  git show HEAD --stat
  ```

```json:metadata
{"files": ["skills/subagent-driven-development/SKILL.md", "skills/subagent-driven-development/code-quality-reviewer-prompt.md", "skills/subagent-driven-development/implementer-prompt.md", "skills/subagent-driven-development/spec-reviewer-prompt.md", "skills/shared/task-format-reference.md", "skills/executing-plans/SKILL.md", "skills/dispatching-parallel-agents/SKILL.md"], "verifyCommand": "git show HEAD --stat | tail -1", "acceptanceCriteria": ["7 files in commit", "task-format-reference.md added as new", "dispatching-parallel-agents Integration section present"], "requiresUserVerification": false}
```

---

## Task 6: Commit 5/9 — `feat(hooks): TaskUpdate completion verification hook`

**Goal:** Land the PreToolUse hook configuration and the verification script that prevents marking tasks complete without their verification block.

**Files:**
- Modify: `hooks/hooks.json`
- Create: `hooks/pre-task-complete-check-verification`

**Acceptance Criteria:**
- [ ] Commit lands with exactly 2 files.
- [ ] `hooks/pre-task-complete-check-verification` is added.
- [ ] `hooks/hooks.json` contains a `PreToolUse` matcher for `TaskUpdate`.

**Verify:**
```bash
git show HEAD --stat
git show HEAD:hooks/hooks.json | grep -A1 'TaskUpdate'
git show HEAD --name-status | grep pre-task-complete-check-verification
```
Expected: 2 files in stat. `TaskUpdate` matcher visible. Verification file added.

**Steps:**

- [ ] **Step 1: Stage**

  ```bash
  git add hooks/hooks.json hooks/pre-task-complete-check-verification
  ```

- [ ] **Step 2: Verify exactly two files staged**

  ```bash
  git diff --cached --name-only
  ```

  Expected: the two paths above, no others.

- [ ] **Step 3: Verify the verification script is executable**

  ```bash
  ls -la hooks/pre-task-complete-check-verification | awk '{print $1}'
  ```

  If the executable bit is not set (no `x` in the output), set it:

  ```bash
  chmod +x hooks/pre-task-complete-check-verification
  git add hooks/pre-task-complete-check-verification
  ```

- [ ] **Step 4: Commit**

  ```bash
  git commit -m "feat(hooks): TaskUpdate completion verification hook

  Adds a PreToolUse matcher for TaskUpdate that runs
  pre-task-complete-check-verification before allowing a task to be
  marked completed when its metadata declares requiresUserVerification."
  ```

- [ ] **Step 5: Verify commit**

  ```bash
  git show HEAD --stat
  ```

```json:metadata
{"files": ["hooks/hooks.json", "hooks/pre-task-complete-check-verification"], "verifyCommand": "git show HEAD --stat | tail -1", "acceptanceCriteria": ["2 files in commit", "TaskUpdate matcher present", "verification script executable"], "requiresUserVerification": false}
```

---

## Task 7: Commit 6/9 — `chore(skills): cross-reference and reference-syntax cleanup`

**Goal:** Land the small editorial sweep across five skills that fixed `@`-syntax cross-references, renamed a placeholder, de-attributed a personal name, and corrected section numbering.

**Files:**
- Modify: `skills/test-driven-development/SKILL.md`
- Modify: `skills/using-git-worktrees/SKILL.md`
- Modify: `skills/writing-skills/SKILL.md`
- Modify: `skills/systematic-debugging/SKILL.md`
- Modify: `skills/requesting-code-review/code-reviewer.md`

**Acceptance Criteria:**
- [ ] Commit lands with exactly 5 files.
- [ ] No file outside the 5 listed appears.

**Verify:**
```bash
git show HEAD --stat
git diff HEAD~1 HEAD --name-only | sort
```
Expected: 5 files, sorted output matches the list above.

**Steps:**

- [ ] **Step 1: Stage**

  ```bash
  git add \
    skills/test-driven-development/SKILL.md \
    skills/using-git-worktrees/SKILL.md \
    skills/writing-skills/SKILL.md \
    skills/systematic-debugging/SKILL.md \
    skills/requesting-code-review/code-reviewer.md
  ```

- [ ] **Step 2: Verify exactly 5 files staged**

  ```bash
  git diff --cached --name-only | wc -l
  ```

  Expected: `5`.

- [ ] **Step 3: Commit**

  ```bash
  git commit -m "chore(skills): cross-reference and reference-syntax cleanup

  Editorial sweep across five skills:
  - test-driven-development: @testing-anti-patterns.md → backtick form
  - using-git-worktrees: de-attribute personal name on rule
  - writing-skills: section numbering fix + @graphviz-conventions.dot → backtick
  - systematic-debugging: drop 'your human partner's' qualifier on heading
  - requesting-code-review/code-reviewer.md: rename {PLAN_REFERENCE} placeholder"
  ```

- [ ] **Step 4: Verify commit**

  ```bash
  git show HEAD --stat
  ```

```json:metadata
{"files": ["skills/test-driven-development/SKILL.md", "skills/using-git-worktrees/SKILL.md", "skills/writing-skills/SKILL.md", "skills/systematic-debugging/SKILL.md", "skills/requesting-code-review/code-reviewer.md"], "verifyCommand": "git show HEAD --stat | tail -1", "acceptanceCriteria": ["5 files in commit"], "requiresUserVerification": false}
```

---

## Task 8: Commit 7/9 — `docs: rewrite README and add fork docs`

**Goal:** Land the fork-specific README, the new CHANGELOG, the codex-app-compatibility design + plan, and this resync design + plan. The two resync docs were committed to `main` before the rebuild started; their content must also exist on the rebuild branch.

**Files:**
- Modify: `README.md`
- Create: `CHANGELOG.md`
- Create: `docs/superpowers/specs/2026-03-23-codex-app-compatibility-design.md`
- Create: `docs/superpowers/plans/2026-03-23-codex-app-compatibility.md`
- Create: `docs/superpowers/specs/2026-04-29-fork-resync-design.md`
- Create: `docs/superpowers/plans/2026-04-29-fork-resync.md` (this file)
- Create: `docs/superpowers/plans/2026-04-29-fork-resync.md.tasks.json` (writing-plans persistence companion)

**Acceptance Criteria:**
- [ ] Commit lands with exactly 7 files.
- [ ] All 6 doc files (CHANGELOG + 2 codex-app + design + plan + tasks.json) are added (not modified).
- [ ] `README.md` is modified.

**Verify:**
```bash
git show HEAD --stat
git diff HEAD~1 HEAD --name-status
```
Expected: 7 files. `README.md` shows as `M`. The 6 doc files show as `A`.

**Steps:**

- [ ] **Step 1: Confirm resync docs and tasks.json companion exist in working tree**

  After the mixed reset in Task 1, the design doc and plan (committed to `main` before the rebuild started) were lost from `HEAD` because we reset to `upstream/main`. But they should still be in the working tree because the working tree is preserved by mixed reset.

  ```bash
  ls -la docs/superpowers/specs/2026-04-29-fork-resync-design.md
  ls -la docs/superpowers/plans/2026-04-29-fork-resync.md
  ls -la docs/superpowers/plans/2026-04-29-fork-resync.md.tasks.json
  ```

  All three must exist. **If any is missing, STOP** and recover from `backup/main-pre-rebase-2026-04-29` before continuing:
  ```bash
  git checkout backup/main-pre-rebase-2026-04-29 -- docs/superpowers/specs/2026-04-29-fork-resync-design.md
  git checkout backup/main-pre-rebase-2026-04-29 -- docs/superpowers/plans/2026-04-29-fork-resync.md
  git checkout backup/main-pre-rebase-2026-04-29 -- docs/superpowers/plans/2026-04-29-fork-resync.md.tasks.json
  ```

- [ ] **Step 2: Stage**

  ```bash
  git add \
    README.md \
    CHANGELOG.md \
    docs/superpowers/specs/2026-03-23-codex-app-compatibility-design.md \
    docs/superpowers/plans/2026-03-23-codex-app-compatibility.md \
    docs/superpowers/specs/2026-04-29-fork-resync-design.md \
    docs/superpowers/plans/2026-04-29-fork-resync.md \
    docs/superpowers/plans/2026-04-29-fork-resync.md.tasks.json
  ```

- [ ] **Step 3: Verify exactly 7 files staged**

  ```bash
  git diff --cached --name-only | wc -l
  ```

  Expected: `7`.

- [ ] **Step 4: Verify add-vs-modify status**

  ```bash
  git diff --cached --name-status
  ```

  Expected: 1 line starting `M\t` (`README.md`), 6 lines starting `A\t` (the four new docs + this plan + the `.tasks.json` companion).

- [ ] **Step 5: Commit**

  ```bash
  git commit -m "docs: rewrite README and add fork docs

  - README rewrite for the superpowers2 fork
  - CHANGELOG seeded for fork bookkeeping
  - codex-app-compatibility design + plan (2026-03-23)
  - fork-resync design + plan + tasks.json (2026-04-29)"
  ```

- [ ] **Step 6: Verify commit**

  ```bash
  git show HEAD --stat
  ```

```json:metadata
{"files": ["README.md", "CHANGELOG.md", "docs/superpowers/specs/2026-03-23-codex-app-compatibility-design.md", "docs/superpowers/plans/2026-03-23-codex-app-compatibility.md", "docs/superpowers/specs/2026-04-29-fork-resync-design.md", "docs/superpowers/plans/2026-04-29-fork-resync.md", "docs/superpowers/plans/2026-04-29-fork-resync.md.tasks.json"], "verifyCommand": "git show HEAD --stat | tail -1", "acceptanceCriteria": ["7 files in commit", "README modified, 6 docs added"], "requiresUserVerification": false}
```

---

## Task 9: Commit 8/9 — `refactor: remove pcvelz-specific tooling`

**Goal:** Land the deletion of pcvelz's codex-mirroring script and the systematic-debugging creation log. Both files are present on `HEAD` (which is now `upstream/main`) but absent from the working tree (because they were already deleted on fork's `main`); we just need to stage the deletions.

**Files:**
- Delete: `scripts/sync-to-codex-plugin.sh` (388 lines)
- Delete: `skills/systematic-debugging/CREATION-LOG.md` (119 lines)

**Acceptance Criteria:**
- [ ] Commit lands with exactly 2 files, both deletions.
- [ ] No file additions or modifications.

**Verify:**
```bash
git show HEAD --stat
git diff HEAD~1 HEAD --name-status
```
Expected: 2 files. Both lines start with `D\t`.

**Steps:**

- [ ] **Step 1: Confirm both files are absent in working tree**

  ```bash
  ls -la scripts/sync-to-codex-plugin.sh 2>&1
  ls -la skills/systematic-debugging/CREATION-LOG.md 2>&1
  ```

  Both should report "No such file or directory". **If either exists, STOP** — fork's `main` had them deleted, so the working tree should not have them after Task 1.

- [ ] **Step 2: Stage the deletions**

  ```bash
  git add -u scripts/sync-to-codex-plugin.sh
  git add -u skills/systematic-debugging/CREATION-LOG.md
  ```

  (`git add -u` records "remove from index" for files that exist in the index but not the working tree — exactly our case.)

- [ ] **Step 3: Verify exactly two deletions staged**

  ```bash
  git diff --cached --name-status
  ```

  Expected: exactly two lines, both starting with `D\t`.

- [ ] **Step 4: Commit**

  ```bash
  git commit -m "refactor: remove pcvelz-specific tooling

  - scripts/sync-to-codex-plugin.sh: removed; this fork does not ship a
    Codex plugin
  - skills/systematic-debugging/CREATION-LOG.md: removed; the log was a
    one-off historical artifact"
  ```

- [ ] **Step 5: Verify commit**

  ```bash
  git show HEAD --stat
  ```

```json:metadata
{"files": ["scripts/sync-to-codex-plugin.sh", "skills/systematic-debugging/CREATION-LOG.md"], "verifyCommand": "git diff HEAD~1 HEAD --name-status", "acceptanceCriteria": ["2 file deletions in commit"], "requiresUserVerification": false}
```

---

## Task 10: Commit 9/9 — `chore: bump version to 5.2.9`

**Goal:** Bump the version field to `5.2.9` across all four plugin manifests (Claude Code, Cursor, Gemini, marketplace).

**Files:**
- Modify: `.claude-plugin/plugin.json` (version only)
- Modify: `.claude-plugin/marketplace.json` (version only)
- Modify: `.cursor-plugin/plugin.json` (version only)
- Modify: `gemini-extension.json` (version only)

**Acceptance Criteria:**
- [ ] Commit lands with exactly 4 files.
- [ ] Each file's only change is `version: "5.2.8"` → `version: "5.2.9"`.
- [ ] No other field changes.

**Verify:**
```bash
git show HEAD --stat
git diff HEAD~1 HEAD -- '*.json' | grep -E '^[+-].*version'
git show HEAD:.claude-plugin/plugin.json | grep version
git show HEAD:.claude-plugin/marketplace.json | grep version
git show HEAD:.cursor-plugin/plugin.json | grep version
git show HEAD:gemini-extension.json | grep version
```
Expected: 4 files. All version-grep results show `5.2.9`. Diff shows only `+/- version` lines (no other field changes).

**Steps:**

- [ ] **Step 1: Edit `.claude-plugin/plugin.json`**

  Use the Edit tool to change the version line:
  - `old_string`: `"version": "5.2.8",`
  - `new_string`: `"version": "5.2.9",`

- [ ] **Step 2: Edit `.claude-plugin/marketplace.json`**

  - `old_string`: `"version": "5.2.8",`
  - `new_string`: `"version": "5.2.9",`

- [ ] **Step 3: Edit `.cursor-plugin/plugin.json`**

  - `old_string`: `"version": "5.2.8",`
  - `new_string`: `"version": "5.2.9",`

- [ ] **Step 4: Edit `gemini-extension.json`**

  - `old_string`: `"version": "5.2.8"`
  - `new_string`: `"version": "5.2.9"`

  (Note: `gemini-extension.json` has no trailing comma on the version line — it's the last field before `contextFileName`. Confirm before editing by reading the file.)

- [ ] **Step 5: Stage**

  ```bash
  git add \
    .claude-plugin/plugin.json \
    .claude-plugin/marketplace.json \
    .cursor-plugin/plugin.json \
    gemini-extension.json
  ```

- [ ] **Step 6: Verify exactly 4 files, version-only changes**

  ```bash
  git diff --cached --name-only | wc -l
  git diff --cached | grep -E '^[+-]' | grep -v -E '^(\+\+\+|---)' | grep -v version
  ```

  Expected: `4`. Second command empty (only version lines should differ).

- [ ] **Step 7: Commit**

  ```bash
  git commit -m "chore: bump version to 5.2.9"
  ```

- [ ] **Step 8: Verify commit**

  ```bash
  git show HEAD --stat
  ```

```json:metadata
{"files": [".claude-plugin/plugin.json", ".claude-plugin/marketplace.json", ".cursor-plugin/plugin.json", "gemini-extension.json"], "verifyCommand": "git show HEAD --stat | tail -1", "acceptanceCriteria": ["4 files in commit", "only version line changes", "version is 5.2.9"], "requiresUserVerification": false}
```

---

## Task 11: Final verification suite

**Goal:** Run all six verification checks from the spec to confirm the rebuild branch is correct before showing it to the user.

**Files:** None (read-only checks).

**Acceptance Criteria:**
- [ ] Working tree is clean (`git status` empty).
- [ ] `git diff resync/upstream-v5.2.8-rebuild upstream/main` is non-empty (the 9 commits' content) and shows no unexpected paths.
- [ ] `git diff resync/upstream-v5.2.8-rebuild main -- <untouched-files>` shows the upstream improvements we deliberately kept.
- [ ] Every file in `git diff upstream/main..main --name-only` is accounted for (in exactly one commit, or in the "files NOT touched" list).
- [ ] `tests/claude-code/test-fork-validation.sh` passes.
- [ ] Each of the 9 commits has a coherent diff for its theme (spot-checked).

**Verify:** See per-step checks below.

**Steps:**

- [ ] **Step 1: Working tree clean**

  ```bash
  git status --short
  ```

  Expected: empty.

- [ ] **Step 2: Branch is the rebuild branch with 9 new commits**

  ```bash
  git rev-parse --abbrev-ref HEAD
  git log --oneline upstream/main..HEAD | wc -l
  ```

  Expected: `resync/upstream-v5.2.8-rebuild`, then `9`.

- [ ] **Step 3: Diff against upstream — must be non-empty and contain only expected files**

  ```bash
  git diff upstream/main..HEAD --name-only | sort > /tmp/rebuild-files.txt
  wc -l /tmp/rebuild-files.txt
  cat /tmp/rebuild-files.txt
  ```

  Expected count: `48` files (46 differing files - 3 untouched + 2 new docs (this plan, the design doc) = 45... actually let me recompute). Recompute: we touched 21 (commit 1) + 1 (2) + 1 (3) + 7 (4) + 2 (5) + 5 (6) + 6 (7) + 2 (8) + 4 (9) = **49**, minus the 4 manifest files appearing in BOTH commit 1 and commit 9 (counted once for `--name-only`) = **45**. So expected: `45` distinct files.

  Confirm the file list contains:
  - All 21 commit-1 files
  - `skills/writing-plans/SKILL.md`
  - `skills/finishing-a-development-branch/SKILL.md`
  - All 7 commit-4 files
  - `hooks/hooks.json` and `hooks/pre-task-complete-check-verification`
  - All 5 commit-6 files
  - All 6 commit-7 files (including this plan + the design doc)
  - The 2 deletions (commit 8)

- [ ] **Step 4: Diff against `main` — must be ONLY upstream improvements on the 3 untouched files**

  ```bash
  git diff HEAD..main --name-only
  ```

  Expected: exactly these three lines (in some order):
  - `hooks/examples/pre-commit-check-tasks.sh`
  - `hooks/examples/stop-deflection-guard.sh`
  - `tests/claude-code/test-helpers.sh`

  **Any other file appearing in this output is a missed delta — STOP and reconcile.**

- [ ] **Step 5: Confirm those 3 files match upstream**

  ```bash
  for f in hooks/examples/pre-commit-check-tasks.sh hooks/examples/stop-deflection-guard.sh tests/claude-code/test-helpers.sh; do
    diff <(git show HEAD:"$f") <(git show upstream/main:"$f") > /dev/null && echo "OK: $f" || echo "MISMATCH: $f"
  done
  ```

  Expected: 3 lines, all starting with `OK:`.

- [ ] **Step 6: Run fork validation test**

  ```bash
  bash tests/claude-code/test-fork-validation.sh
  ```

  Expected: exit code 0, success output. **If it fails, STOP** and inspect the failure before continuing.

- [ ] **Step 7: Per-commit theme spot check**

  ```bash
  git log --oneline upstream/main..HEAD
  ```

  For each of the 9 commits, run `git show <SHA> --stat` and confirm the listed files match its theme description. Specifically:
  - Commit 1: 21 files, all rebrand or version-keeping
  - Commit 2: 1 file (writing-plans)
  - Commit 3: 1 file (finishing-a-development-branch)
  - Commit 4: 7 files (subagent-driven-development + shared + executing-plans + dispatching-parallel-agents)
  - Commit 5: 2 files (hooks)
  - Commit 6: 5 files (skill editorial)
  - Commit 7: 6 files (docs)
  - Commit 8: 2 deletions
  - Commit 9: 4 manifest files (version only)

```json:metadata
{"files": [], "verifyCommand": "git diff HEAD..main --name-only | wc -l", "acceptanceCriteria": ["working tree clean", "9 commits ahead of upstream", "diff against main shows only 3 untouched files", "fork-validation test passes", "per-commit themes match"], "requiresUserVerification": false}
```

---

## Task 12: User verification of rebuild branch

**Goal:** Get explicit user approval of the rebuild branch before any push of `main`.

**Files:** None.

**Acceptance Criteria:**
- [ ] User has reviewed the rebuild branch (commit list, key diffs, fork-validation result).
- [ ] User has chosen one of the next-step options (push or pause).

**User Verification Required:**
Before marking this task complete, you MUST call AskUserQuestion:

```yaml
AskUserQuestion:
  question: "Rebuild branch resync/upstream-v5.2.8-rebuild has 9 commits and Task 11 verification passed. Diff against upstream covers ~45 files; diff against main shows only the 3 upstream-wins files. Does the rebuild branch look correct?"
  header: "Verification"
  options:
    - label: "Approved — proceed to landing"
      description: "Rebuild looks right. Tell me what to do next: force-push to main, push branch + open PR, or hold for further review."
    - label: "Needs changes"
      description: "Something looks off. Describe what to revise; we'll iterate before any push."
```

**If the user selects "Needs changes":** The task is NOT complete. Make the requested changes (typically by amending or adding commits to the rebuild branch — never to `main`), re-run Task 11 verification, then call AskUserQuestion again.

**If the user selects "Approved":** Task is complete. Do NOT auto-push. The user said "await your call" for the landing strategy — wait for their explicit instruction on what to do with the rebuild branch (force-push to main, open PR, etc.).

**Steps:**

- [ ] **Step 1: Surface the relevant diffs and stats to the user**

  Print, in order:

  ```bash
  echo "=== Commit log ==="
  git log --oneline upstream/main..HEAD
  echo ""
  echo "=== Stat per commit ==="
  for sha in $(git log --reverse --format=%H upstream/main..HEAD); do
    git show "$sha" --stat | head -3
    echo "---"
  done
  echo ""
  echo "=== Diff vs main (should be 3 files only) ==="
  git diff HEAD..main --name-only
  echo ""
  echo "=== Backup refs ==="
  git rev-parse backup/main-pre-rebase-2026-04-29
  git ls-remote origin refs/heads/backup/main-pre-rebase-2026-04-29
  ```

- [ ] **Step 2: Call `AskUserQuestion`**

  Use the exact YAML in the **User Verification Required** block above.

- [ ] **Step 3: Branch on the user's response**

  - If **Approved**: stop and wait for the user's explicit landing instruction. Do not push, force-push, or open a PR without further direction.
  - If **Needs changes**: ask the user what specifically they want changed; iterate; re-run Task 11; re-call AskUserQuestion.

```json:metadata
{"files": [], "verifyCommand": "", "acceptanceCriteria": ["user confirms rebuild branch is correct"], "requiresUserVerification": true, "userVerificationPrompt": "Rebuild branch resync/upstream-v5.2.8-rebuild has 9 commits and Task 11 verification passed. Diff against upstream covers ~45 files; diff against main shows only the 3 upstream-wins files. Does the rebuild branch look correct?"}
```

---

## Recovery Procedures

If anything goes wrong after Task 0, recovery is:

1. **Lost local state, backup intact on origin:**
   ```bash
   git fetch origin
   git checkout backup/main-pre-rebase-2026-04-29 -- .
   ```

2. **Need to redo the entire rebuild from `main`:**
   ```bash
   git checkout main
   git branch -D resync/upstream-v5.2.8-rebuild
   git checkout -b resync/upstream-v5.2.8-rebuild
   # restart from Task 1
   ```

3. **`main` has been mutated and we want to restore it:**
   ```bash
   git checkout main
   git reset --hard backup/main-pre-rebase-2026-04-29
   # main is now back to its pre-rebuild state
   ```

The backup branch on origin is the canonical recovery anchor. **Do not delete it** until the user has explicitly confirmed the rebuild has landed and the fork is in its desired state.

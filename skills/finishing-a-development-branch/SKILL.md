---
name: finishing-a-development-branch
description: Use when implementation is complete, all tests pass, and you need to integrate the work - merges to base branch and cleans up worktree
---

# Finishing a Development Branch

## Overview

Verify tests, merge to base branch, clean up worktree.

**Core principle:** Verify tests → Merge to base branch → Clean up.

**Announce at start:** "I'm using the finishing-a-development-branch skill to complete this work."

## The Process

### Step 1: Verify Tests

```bash
# Run project's test suite
npm test / cargo test / pytest / go test ./...
```

**If tests fail:** Stop. Report failures. Do not proceed until tests pass.

**If tests pass:** Continue to Step 2.

### Step 2: Determine Base Branch

```bash
# Try common base branches
git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null
```

Or ask: "This branch split from main - is that correct?"

### Step 3: Merge to Base Branch

**Do not prompt the user for options.** Always merge back to the base branch:

```bash
# Switch to base branch
git checkout <base-branch>

# Pull latest
git pull

# Merge feature branch
git merge <feature-branch>

# Verify tests on merged result
<test command>

# If tests pass, delete the feature branch
git branch -d <feature-branch>
```

Report: "Merged <feature-branch> into <base-branch>. Tests passing."

### Step 4: Cleanup Worktree

Check if in worktree:
```bash
git worktree list | grep $(git branch --show-current)
```

If yes:
```bash
git worktree remove <worktree-path>
```

## Common Mistakes

**Skipping test verification**
- **Problem:** Merge broken code
- **Fix:** Always verify tests before merging

**Merging without verifying tests on result**
- **Problem:** Feature branch tests pass but merged result fails
- **Fix:** Run tests after merge, before reporting success

## Red Flags

**Never:**
- Proceed with failing tests
- Merge without verifying tests on result
- Force-push without explicit request

**Always:**
- Verify tests before merging
- Verify tests after merging
- Clean up worktree after merge

## Integration

**Called by:**
- **subagent-driven-development** (Step 7) - After all tasks complete
- **executing-plans** (Step 5) - After all batches complete

**Pairs with:**
- **using-git-worktrees** - Cleans up worktree created by that skill

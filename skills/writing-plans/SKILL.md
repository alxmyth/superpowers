---
name: writing-plans
description: Use when you have a spec or requirements for a multi-step task, before touching code
---

# Writing Plans

## CRITICAL CONSTRAINTS — Read Before Anything Else

**You MUST NOT call `EnterPlanMode` or `ExitPlanMode` at any point during this skill.** This skill operates in normal mode and manages its own completion flow via `AskUserQuestion`. Calling `EnterPlanMode` traps the session in plan mode where Write/Edit are restricted. Calling `ExitPlanMode` breaks the workflow and skips the user's execution choice. If you feel the urge to call either, STOP — follow this skill's instructions instead.

## Overview

Write comprehensive implementation plans assuming the engineer has zero context for our codebase and questionable taste. Document everything they need to know: which files to touch for each task, code, testing, docs they might need to check, how to test it. Give them the whole plan as bite-sized tasks. DRY. YAGNI. TDD. Frequent commits.

Assume they are a skilled developer, but know almost nothing about our toolset or problem domain. Assume they don't know good test design very well.

**Announce at start:** "I'm using the writing-plans skill to create the implementation plan."

**Context:** This should be run in a dedicated worktree (created by brainstorming skill).

**Save plans to:** `docs/plans/YYYY-MM-DD-<feature-name>.md`

## REQUIRED FIRST STEP: Initialize Task Tracking

**BEFORE exploring code or writing the plan, you MUST:**

1. Call `TaskList` to check for existing tasks from brainstorming
2. If tasks exist: you will enhance them with implementation details as you write the plan
3. If no tasks: you will create them with `TaskCreate` as you write each plan task

**Do not proceed to exploration until TaskList has been called.**

```
TaskList
```

## Bite-Sized Task Granularity

**Each step is one action (2-5 minutes):**
- "Write the failing test" - step
- "Run it to make sure it fails" - step
- "Implement the minimal code to make the test pass" - step
- "Run the tests and make sure they pass" - step
- "Commit" - step

## Plan Document Header

**Every plan MUST start with this header:**

```markdown
# [Feature Name] Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

**Parallel Groups:** [Summary of which task groups can run concurrently — e.g., "Tasks 2-4 (parallel), Task 5 (sequential)"]

---
```

## Task Structure

````markdown
### Task N: [Component Name]

**Parallel Group: N** — [group label, e.g., "Foundation" or "Independent Features"]

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

**Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

**Step 2: Run test to verify it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

**Step 3: Write minimal implementation**

```python
def function(input):
    return expected
```

**Step 4: Run test to verify it passes**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

**Step 5: Commit**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```
````

## Remember
- Exact file paths always
- Complete code in plan (not "add validation")
- Exact commands with expected output
- Reference relevant skills with @ syntax
- DRY, YAGNI, TDD, frequent commits

## Identifying Parallel Execution Groups

After writing all tasks, analyze file dependencies to identify which tasks can run concurrently.

**Rules for parallel grouping:**
1. Tasks that touch **no overlapping files** (create, modify, or test) can run in parallel
2. Tasks that share files MUST be in different groups with sequential ordering
3. Foundation tasks (shared types, config, schemas) are typically Group 1 (sequential)
4. Feature tasks building on the foundation are often parallelizable
5. Integration/glue tasks that wire features together must come after their dependencies
6. Maximum **5 tasks** per parallel group (API rate limits and coordination overhead)

**Commonly missed shared files — check every parallel group for these:**
- Barrel exports: `index.ts`, `__init__.py`, `mod.rs`
- Package manifests: `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`
- Config files: `settings.py`, `.env.example`, `config.json`
- Test infrastructure: `conftest.py`, `jest.config.ts`, `setupTests.ts`
- Type definitions: shared `types.ts`, `interfaces.py`, `models.py`
- Documentation: `README.md`, `CHANGELOG.md`

If ANY task in a parallel group might touch one of these files, either move it to a sequential group or explicitly list the file in `filesTouched` so the overlap check catches it.

**How to assign groups:**
- **Group 1:** Foundation — tasks that create shared infrastructure. Run sequentially first.
- **Group 2+:** Independent features — tasks with no file overlap. Run in parallel within the group.
- **Final Group:** Integration — tasks that wire everything together. Run sequentially last.

**Example grouping:**
```
Group 1 (sequential):  Task 1 — Database schema + shared types
Group 2 (parallel):    Task 2 — User API endpoint
                       Task 3 — Product API endpoint
                       Task 4 — Search service
Group 3 (sequential):  Task 5 — Integration tests + wiring
```

Tasks 2, 3, 4 each create their own files and tests, never touching files from other tasks in the group. The execution skills will spawn concurrent agent teammates for parallel groups.

**When in doubt, make it sequential.** False parallelism (tasks that actually share files) causes merge conflicts and wasted work. Only group tasks as parallel when you are certain they have zero file overlap.

## Execution Handoff

<HARD-GATE>
STOP. You are about to complete the plan. DO NOT call EnterPlanMode or ExitPlanMode. You MUST call AskUserQuestion below. Both are FORBIDDEN — EnterPlanMode traps the session, ExitPlanMode skips the user's execution choice.
</HARD-GATE>

Your ONLY permitted next action is calling `AskUserQuestion` with this EXACT structure:

```yaml
AskUserQuestion:
  question: "Plan complete and saved to docs/plans/<filename>.md. How would you like to execute it?"
  header: "Execution"
  options:
    - label: "Subagent-Driven (this session)"
      description: "I dispatch fresh subagent per task, review between tasks, fast iteration"
    - label: "Parallel Session (separate)"
      description: "Open new session in worktree with executing-plans, batch execution with checkpoints"
```

**If you are about to call ExitPlanMode, STOP — call AskUserQuestion instead.**

**If Subagent-Driven chosen:**
- **REQUIRED SUB-SKILL:** Use superpowers-extended-cc:subagent-driven-development
- Stay in this session
- Fresh subagent per task + code review

**If Parallel Session chosen:**
- Guide them to open new session in worktree
- **REQUIRED SUB-SKILL:** New session uses superpowers-extended-cc:executing-plans

---

## Native Task Integration Reference

Use Claude Code's native task tools (v2.1.16+) to create structured tasks alongside the plan document.

### Creating Native Tasks

For each task in the plan, create a corresponding native task:

```
TaskCreate:
  subject: "Task N: [Component Name]"
  description: |
    [Copy the full task content from the plan you just wrote — files, steps, acceptance criteria, everything]
  activeForm: "Implementing [Component Name]"
```

### Setting Dependencies

After all tasks created, set blockedBy relationships:

```
TaskUpdate:
  taskId: [task-id]
  addBlockedBy: [prerequisite-task-ids]
```

### During Execution

Update task status as work progresses:

```
TaskUpdate:
  taskId: [task-id]
  status: in_progress  # when starting

TaskUpdate:
  taskId: [task-id]
  status: completed    # when done
```

### Notes

- Native tasks provide CLI-visible progress tracking
- Plan document remains the permanent record

---

## Task Persistence

At plan completion, write the task persistence file **in the same directory as the plan document**.

If the plan is saved to `docs/plans/2026-01-15-feature.md`, the tasks file MUST be saved to `docs/plans/2026-01-15-feature.md.tasks.json`.

```json
{
  "planPath": "docs/plans/2026-01-15-feature.md",
  "parallelGroups": [
    {"group": 1, "label": "Foundation", "execution": "sequential"},
    {"group": 2, "label": "Independent Features", "execution": "parallel"},
    {"group": 3, "label": "Integration", "execution": "sequential"}
  ],
  "tasks": [
    {"id": 1, "subject": "Task 1: Database schema", "status": "pending", "parallelGroup": 1, "filesTouched": ["src/schema.py", "tests/test_schema.py"]},
    {"id": 2, "subject": "Task 2: User API", "status": "pending", "blockedBy": [1], "parallelGroup": 2, "filesTouched": ["src/users.py", "tests/test_users.py"]},
    {"id": 3, "subject": "Task 3: Product API", "status": "pending", "blockedBy": [1], "parallelGroup": 2, "filesTouched": ["src/products.py", "tests/test_products.py"]},
    {"id": 4, "subject": "Task 4: Integration", "status": "pending", "blockedBy": [2, 3], "parallelGroup": 3, "filesTouched": ["src/app.py", "tests/test_integration.py"]}
  ],
  "lastUpdated": "<timestamp>"
}
```

**Key fields:**
- `parallelGroups` — declares execution groups with labels and whether they run in parallel or sequentially
- `parallelGroup` — per-task field linking it to a group number
- `filesTouched` — all files a task creates, modifies, or tests — including shared infrastructure files like barrel exports, configs, and test fixtures (used by execution skills to verify no overlap within parallel groups)
- `blockedBy` — optional array of task IDs that must complete before this task starts (drives execution ordering and native task dependencies)
- `execution: "parallel"` — signals execution skills to spawn concurrent agent teammates for that group
- `status` — valid values: `"pending"`, `"in_progress"`, `"completed"`, `"failed"`

Both the plan `.md` and `.tasks.json` must be co-located in `docs/plans/`.

### Resuming Work

Any new session can resume by running:
```
/superpowers-extended-cc:executing-plans <plan-path>
```

The skill reads the `.tasks.json` file and continues from where it left off.

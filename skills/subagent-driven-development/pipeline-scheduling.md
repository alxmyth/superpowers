# Pipeline Scheduling Reference

Rules for overlapping implementation and review phases to maximize throughput.

## Core Concept

Instead of completing all reviews for Task N before starting Task N+1, start Task N+1's implementation as soon as Task N enters review — **if they don't touch the same files**.

```
Sequential (old):
  Task N: [implement]──[review]
  Task N+1:                     [implement]──[review]

Pipelined (new):
  Task N: [implement]──[review]
  Task N+1:            [implement]──[review]
```

## File-Ownership Conflict Detection

Two tasks **conflict** if their file lists share any path. Check all file categories from the plan:

- **Create** files
- **Modify** files
- **Test** files

### Algorithm

```
function canPipeline(taskA_in_review, taskB_to_start):
  filesA = taskA.create + taskA.modify + taskA.test
  filesB = taskB.create + taskB.modify + taskB.test

  if intersection(filesA, filesB) is not empty:
    return false  # CONFLICT — must wait

  # Also check commonly missed shared files
  sharedFiles = [
    barrel exports (index.ts, index.js, __init__.py, mod.rs),
    config files (package.json, tsconfig.json, pyproject.toml, Cargo.toml),
    shared test fixtures (conftest.py, test-utils.ts, setupTests.ts),
    shared types (types.ts, types.d.ts, interfaces.ts),
    route registrations (routes.ts, app.ts, main.ts)
  ]

  for file in sharedFiles:
    if file in filesA and file in filesB:
      return false  # CONFLICT on shared file

  return true  # Safe to pipeline
```

### When In Doubt

**Treat as conflicting.** False sequentiality costs time. False parallelism causes merge conflicts and wasted work. Time cost of sequentiality is linear; cost of a bad merge is unpredictable.

## Pipeline Rules

1. **Maximum pipeline depth: 3.** No more than 3 tasks in-flight simultaneously (1 implementing + 2 in various review stages). Beyond this, coordination overhead exceeds parallelism benefit.

2. **Review feedback takes priority.** If Task N's review returns with issues while Task N+1 is implementing, the implementer for Task N starts fixing immediately. Task N+1 continues unaffected (different files).

3. **Re-review after fixes.** When a fix subagent addresses review feedback, only the reviewers that flagged issues re-review. Reviewers that passed don't need to re-run.

4. **Pipeline stall on conflict.** If Task N's review feedback requires changes to files that Task N+1 touches, Task N+1 must STOP and wait for Task N's fixes to land. This should be rare if file-ownership analysis is correct.

5. **Crash safety.** Each task's status is written to `.tasks.json` at every transition. A crashed session can resume by checking which tasks are `in_progress` and which have commits.

## Integration with Parallel Groups

Pipeline scheduling applies WITHIN a parallel group's sequential tasks, and BETWEEN groups when tasks are independent.

- **Within a group:** If group has sequential tasks (common for setup → use chains), pipeline the independent ones.
- **Between groups:** The last tasks of group N and first tasks of group N+1 can pipeline if files don't conflict.

## Example

Plan has 5 tasks:
- Task 0: Create database schema (files: schema.sql, db.ts)
- Task 1: Add user API (files: users.ts, users.test.ts)
- Task 2: Add product API (files: products.ts, products.test.ts)
- Task 3: Add search (files: search.ts, search.test.ts)
- Task 4: Integration tests (files: integration.test.ts, users.ts, products.ts)

Dependency: Tasks 1-3 depend on Task 0. Task 4 depends on Tasks 1-3.

Schedule:
```
Task 0: [implement]──[review]
Task 1:              [implement]──[review]          ← pipeline with Task 0 review (no file conflict)
Task 2:              [implement]──[review]          ← parallel with Task 1 (no file conflict)
Task 3:              [implement]──[review]          ← parallel with Tasks 1, 2 (no file conflict)
Task 4:                           [implement]──[review]  ← must wait (shares users.ts, products.ts)
```

Tasks 1, 2, 3 start as soon as Task 0 enters review (pipelined) AND run in parallel with each other (aggressive batching). Task 4 must wait because it touches files owned by Tasks 1 and 2.

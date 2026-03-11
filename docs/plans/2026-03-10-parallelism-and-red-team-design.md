# Parallelism & Red Team Agent Improvements

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** Increase execution throughput via pipeline parallelism and improve output quality via adversarial red team agents at every phase.

**Architecture:** Two orthogonal improvements — (1) pipeline parallelism that overlaps implementation and review phases, and (2) a red team agent template with three modes (devil's advocate, chaos tester, skeptic reviewer) that runs in parallel with existing work at each phase.

**Status:** Approved design

---

## Problem Statement

### Parallelism Gaps

The current skill chain has three parallelism bottlenecks:

1. **Sequential review:** Spec review completes before code quality review begins. Each review reads the same code independently — no reason they can't run simultaneously.

2. **No pipeline overlap:** Task N must complete all reviews before Task N+1 begins implementation, even when the tasks touch entirely different files.

3. **Conservative batch sizing:** The executor respects `blockedBy` dependencies but doesn't analyze file ownership to find additional parallelism among unblocked tasks.

### Missing Adversarial Feedback

The current agent roster is cooperative — implementers build, reviewers check, but no agent actively tries to **break** things. This means:

- Design assumptions go unchallenged until implementation reveals problems
- Edge cases and boundary conditions are only caught if the implementer or reviewer thinks of them
- Tests prove code runs, but rarely prove it's correct under adversarial inputs
- Reviewers assess quality but don't question whether the change fundamentally solves the problem

---

## Design

### Part 1: Parallel Execution Improvements

#### 1a. Pipelined Execution

**Current behavior:** Complete all reviews for task N → then start task N+1.

**New behavior:** When task N enters review, immediately start task N+1 if no file-ownership conflict.

```
Timeline (current):
  Task 1: [implement]──[spec review]──[code review]
  Task 2:                                           [implement]──[review]...

Timeline (pipelined):
  Task 1: [implement]──[spec review]──[code review]
  Task 2:              [implement]──[spec review]──[code review]
  Task 3:                           [implement]──...
```

**Constraint:** File ownership — if task N and N+1 touch the same files, they must remain sequential. The skill analyzes the plan's file lists to determine overlap before dispatching.

**Conflict detection rule:** Two tasks conflict if their file lists (Create + Modify + Test) share any path. When in doubt, treat as conflicting — false sequentiality is safe, false parallelism causes merge pain.

#### 1b. Parallel Review

**Current behavior:** Spec review → code quality review (sequential two-stage).

**New behavior:** Spec review and code quality review dispatch simultaneously.

If either finds issues, the implementer fixes them, then only the reviewers that flagged issues re-review. This cuts review time roughly in half for passing tasks.

**Rationale for change:** The two-stage ordering was motivated by "can't quality-review code that doesn't meet spec." In practice, both reviewers read the same code independently. Running them in parallel and merging feedback is safe — a quality review on code that fails spec is wasted tokens but not harmful, and the common case (code passes both) benefits significantly.

#### 1c. Aggressive Batch Sizing

**Current behavior:** Respects `blockedBy` but doesn't analyze file ownership.

**New behavior:** Before each batch, the executor:

1. Identifies all unblocked tasks (no pending `blockedBy`)
2. Analyzes their file lists for conflicts
3. Groups non-conflicting tasks into the largest possible parallel batch
4. Tasks with file conflicts go into the next wave within the same batch

This means a 12-task plan with only 3 true dependency chains could run 4+ tasks simultaneously.

**Algorithm:**
```
unblocked = tasks where all blockedBy are completed
groups = []
remaining = unblocked

while remaining:
  group = [remaining[0]]
  group_files = set(remaining[0].files)

  for task in remaining[1:]:
    if task.files ∩ group_files == ∅:
      group.append(task)
      group_files |= task.files

  groups.append(group)
  remaining -= group

dispatch all groups[0] in parallel
when any task completes review, check if groups[1+] can start
```

---

### Part 2: Red Team Agent

A single agent template with a `mode` parameter that adapts its adversarial focus to the current phase. Runs **in parallel** with existing work — never on the critical path.

#### 2a. Devil's Advocate Mode (brainstorming phase)

**When dispatched:** In parallel after the design is drafted, before user approval.

**Purpose:** Challenge assumptions, identify risks, find missing requirements.

**Prompt template:**
```
You are a devil's advocate reviewing a proposed design.

Your job is to BREAK this design — find the flaws, not confirm it works.

Design:
---
{design_text}
---

Challenge each of these:
1. Assumptions — what is assumed true that might not be?
2. Missing requirements — what hasn't been considered?
3. Failure modes — how does this break under load, edge cases, bad input?
4. Scope creep risk — is this overbuilt? Underbuilt?
5. Alternative approaches — is there a simpler way?

Output a ranked list of concerns (critical → minor).
Do NOT suggest solutions — only identify problems.
```

**Integration:** The brainstorming skill presents the red team's concerns alongside the design for user review. The user decides which concerns to address.

#### 2b. Chaos Tester Mode (implementation phase)

**When dispatched:** In parallel as soon as a task's implementation commits, overlapping with review.

**Purpose:** Write adversarial tests that try to break the implementation.

**Prompt template:**
```
You are a chaos tester. Code was just written. Your job is to BREAK it.

Files changed: {file_list}
What was implemented: {summary}
Test framework: {framework}
Test command: {command}

Write tests that target:
1. Boundary conditions — empty input, max values, zero, negative
2. Type coercion — wrong types, null, undefined where not expected
3. State corruption — concurrent access, partial failures, interrupted operations
4. Contract violations — call methods in wrong order, missing required fields
5. Resource exhaustion — large inputs, deep nesting, many iterations

Rules:
- Each test must be runnable with the existing test framework
- Focus on tests that SHOULD pass but you suspect WON'T
- If all your tests pass, that's a GOOD sign — report clean
- If any fail, report the failure with root cause analysis

Output: test file + results + ranked list of vulnerabilities found
```

**Integration:** Results feed into the review merge. Failing chaos tests are treated as review feedback for the implementer to fix.

#### 2c. Skeptic Reviewer Mode (review phase)

**When dispatched:** In parallel alongside spec review and code quality review.

**Purpose:** Question whether the change solves the stated problem and whether tests prove what they claim.

**Prompt template:**
```
You are a skeptic reviewer. Your job is to question EVERYTHING.

Requirement: {requirement}
Implementation: {diff_or_files}
Tests: {test_files}
Implementer's claim: {report}

Question each of these:
1. Does this actually solve the requirement, or does it solve something adjacent?
2. Do the tests prove correctness, or do they just prove the code runs?
3. Are there inputs where this silently produces wrong results (no error, just wrong)?
4. Does the happy path test actually exercise the changed code?
5. What would a user do that the developer didn't think of?

For each concern, provide:
- The specific claim you're challenging
- Why you're skeptical (concrete reasoning, not vague doubt)
- What evidence would resolve your concern

Do NOT nitpick style. Focus on CORRECTNESS and COMPLETENESS only.
```

**Integration:** Skeptic feedback is merged with spec + code quality feedback. Critical concerns must be addressed; minor concerns are noted but optional.

#### Parallel Execution Map (full picture)

```
Task N completes implementation
  ├── [parallel] Spec Reviewer
  ├── [parallel] Code Quality Reviewer
  ├── [parallel] Skeptic Reviewer (red team)
  └── [parallel] Chaos Tester (red team)
       │
       ▼
  Merge all feedback → Implementer fixes → Re-review only flagging reviewers

Meanwhile (if no file conflict):
  Task N+1 begins implementation (pipelined)
```

---

### Part 3: Integration Into Existing Skills

#### Skills Modified

| Skill | Change | Scope |
|-------|--------|-------|
| `subagent-driven-development` | Pipeline execution, parallel review, red team dispatch | Major — rewrite execution loop |
| `executing-plans` | Same parallelism improvements for batch mode | Moderate — batch logic changes |
| `brainstorming` | Dispatch devil's advocate in parallel after design draft | Small addition |
| `dispatching-parallel-agents` | Aggressive batch sizing with file-ownership analysis | Moderate enhancement |

#### New Files

| File | Purpose |
|------|---------|
| `skills/subagent-driven-development/red-team-prompt.md` | Red team agent template with mode parameter |
| `skills/subagent-driven-development/pipeline-scheduling.md` | Reference doc for file-ownership conflict detection and pipeline rules |

#### No Changes To

- `writing-plans` — plan format stays the same; the executor handles parallelism
- `finishing-a-development-branch` — completion flow unchanged
- `verification-before-completion` — unchanged, still applies to all claims
- No global agent type definitions — scoped to superpowers until proven

#### Revised Execution Flow (subagent-driven-development)

```
For each batch of unblocked tasks:

1. ANALYZE file ownership across all unblocked tasks
2. GROUP into max-width non-conflicting parallel set
3. DISPATCH implementer subagents (parallel)
4. As each implementer completes:
   a. DISPATCH in parallel:
      - Spec reviewer
      - Code quality reviewer
      - Skeptic reviewer (red team)
      - Chaos tester (red team)
   b. IF next task has no file conflict with in-review tasks:
      - DISPATCH next implementer (pipeline)
5. MERGE all feedback for each task
6. IF issues found:
   - Dispatch implementer to fix
   - Re-run only the reviewers that flagged issues
7. MARK task completed, sync .tasks.json
8. REPEAT until all tasks done
```

#### Revised Brainstorming Flow

```
Current:
1. Explore context
2. Ask questions
3. Propose approaches
4. Present design → user approves
5. Write doc → handoff

Revised (change at step 4):
4. Present design to user
4b. IN PARALLEL: dispatch devil's advocate (red team)
4c. Present red team concerns alongside design
5. User approves (incorporating concerns they agree with)
6. Write doc → handoff
```

---

## Expected Impact

| Metric | Current | After |
|--------|---------|-------|
| Review time per task | ~2x (sequential spec + quality) | ~1x (parallel) |
| Tasks in flight simultaneously | 1-3 | Limited only by file conflicts |
| Adversarial testing | None | Every task gets chaos-tested |
| Design challenge | None (user is sole critic) | Devil's advocate runs automatically |
| Correctness feedback signals | 2 (spec + quality) | 4 (spec + quality + skeptic + chaos) |
| Net critical path impact | — | Faster (pipeline) despite more review |
| Token cost per task | Baseline | ~2x (additional reviewers) |

---

## Risks and Mitigations

### Risk: Merge conflicts from pipelining
**Problem:** Task N+1 implements while task N is in review; review feedback changes task N's code, conflicting with N+1.
**Mitigation:** File-ownership analysis prevents parallel dispatch when files overlap. For indirect conflicts (shared state, APIs), the spec reviewer catches mismatches.

### Risk: Red team noise
**Problem:** Adversarial agents generate low-value concerns that waste implementer time.
**Mitigation:** All red team output is ranked (critical → minor). Only critical concerns require action. The user/orchestrator can tune the threshold.

### Risk: Token cost increase
**Problem:** 4 parallel reviewers per task vs. current 2 sequential.
**Mitigation:** Accepted trade-off per user preference. Parallel execution means wall-clock time doesn't increase proportionally.

### Risk: Chaos tester writes flawed tests
**Problem:** Adversarial tests may be incorrectly written and produce false failures.
**Mitigation:** Chaos test failures are treated as review feedback, not blockers. The implementer evaluates whether failures are genuine bugs or test errors.

---

## Open Questions

1. **Red team threshold tuning:** Should we allow users to configure which red team modes are active? (e.g., skip devil's advocate for small changes)
2. **Chaos test persistence:** Should adversarial tests be committed alongside regular tests, or discarded after review?
3. **Pipeline depth:** Should we limit how many tasks can be in-flight simultaneously, or let it be unbounded?

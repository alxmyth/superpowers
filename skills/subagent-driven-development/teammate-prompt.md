# Teammate Implementation Prompt Template

Use this template when dispatching parallel teammates for independent tasks.
Each teammate works on its own branch: implement → test → commit → self-review.

After all teammates complete, the controller merges branches, dispatches independent
spec reviewers (one per task, in parallel), then a group code quality reviewer.

```
Agent tool:
  description: "Implement Task N: [task name]"
  prompt: |
    You are implementing Task N: [task name]

    You are one of several teammates working **concurrently** on independent tasks.
    Other teammates are implementing other tasks at the same time.

    ## CRITICAL: Branch Isolation

    Before doing ANY work, create and switch to your task branch:

    ```bash
    git checkout -b task-N-[short-task-name]
    ```

    All your commits MUST go to this branch. Do NOT commit to the main feature
    branch. The controller will merge your branch after all teammates complete.

    ## CRITICAL: File Ownership

    You own ONLY these files:
    [LIST of filesTouched for this task]

    **Do NOT modify any files outside your ownership list.** Other teammates own other
    files. Modifying shared files will cause merge conflicts and wasted work.

    If you discover you need to modify a file not in your list, STOP and report back
    with the issue. Do not proceed.

    ## Task Description

    [FULL TEXT of task from plan - paste it here, don't make teammate read file]

    ## Context

    [Scene-setting: where this fits, what the foundation tasks built, architectural context]

    ## Your Job

    1. Create your task branch (see above)
    2. Implement exactly what the task specifies
    3. Write tests (following TDD if task says to)
    4. Verify implementation works
    5. Commit your work to your task branch with a descriptive message
    6. Self-review (see below)
    7. Report back

    Work from: [directory]

    ## Self-Review Before Reporting

    **Completeness:**
    - Did you fully implement everything in the spec?
    - Did you miss any requirements?
    - Are there edge cases you didn't handle?

    **Quality:**
    - Is this your best work?
    - Are names clear and accurate?
    - Is the code clean and maintainable?

    **Discipline:**
    - Did you avoid overbuilding (YAGNI)?
    - Did you only build what was requested?
    - Did you follow existing patterns in the codebase?

    **Testing:**
    - Do tests actually verify behavior (not just mock behavior)?
    - Did you follow TDD if required?
    - Are tests comprehensive?

    If you find issues during self-review, fix them before reporting.

    ## Report Format

    When done, report:
    - Your branch name
    - What you implemented
    - What you tested and test results
    - Files changed (confirm all are within your ownership list)
    - Self-review findings (if any)
    - Any issues or concerns
```

## Why Teammates Differ from Sequential Implementers

| Aspect | Sequential Implementer | Parallel Teammate |
|--------|----------------------|-------------------|
| Branch | Works on main feature branch | **Creates own task branch** |
| Commits | Commits directly | Commits to task branch; controller merges |
| Spec review | Separate subagent after | **Separate subagent after all teammates** (in parallel) |
| Quality review | Separate subagent after | Group review after spec reviews pass |
| File scope | Full codebase access | **Restricted to owned files only** |
| Questions | Can ask controller, controller answers | Should report back rather than block |
| Context | Controller provides custom context | Self-contained prompt with full task text |

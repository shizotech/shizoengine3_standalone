# Batch Task Tool Specification

The batch task tool creates one independent agent task for every item matched by a path selector.

Its purpose is to let the agent apply the same meaningful workload to many files without manually creating one `task_start()` call per file.

The agent provides the workload. The harness discovers the files, creates the child tasks, manages scheduling and concurrency, and aggregates the results.

## Tool

task_batch(
    target,
    goal,
    context?,
    contract?,
    constraints?
)

## Arguments

### `target`

Path selector describing the files to process.

The target uses the `glob()` path semantics.

Examples:

src/
src/**/*.cpp
src/shaders/*.frag

The harness resolves the target before creating any child tasks.

The resulting file list is a fixed snapshot for the lifetime of the batch.

### `goal`

The workload that every child task must complete for its assigned file.

The goal must describe the desired result, not a sequence of trivial actions.

For example:

"Update this file to use the new rendering API, preserve existing behavior, debug any issues caused by the change, and verify the result."

Do not provide a list of files in the goal.

The harness automatically tells each child which file it owns.

### `context`

Optional additional context shared with every child task.

Only include information relevant to the batch workload.

### `contract`

Optional contract describing what every child must provide when finished.

The child must satisfy this contract for its assigned file.

### `constraints`

Optional restrictions applying to every child.

Examples:

* do not modify unrelated files;
* do not change public APIs;
* preserve existing behavior;
* only modify files within the selected subtree.

## Target resolution

The harness resolves `target` before starting the batch.

Example:

task_batch(
    target = "src/effects/*.cpp",
    goal = "Migrate this file to the new Effect API and verify it."
)

The harness might resolve:

src/effects/a.cpp
src/effects/b.cpp
src/effects/c.cpp
...
src/effects/z.cpp

It then creates one child task for each file.

The agent does not need to enumerate these files manually.

## Child tasks

Every matched item becomes a normal task in the existing task system.

Each child receives:

AGENT TASK

Goal:
<batch goal>

Context:
<batch context>

Contract:
<batch contract>

Constraints:
<batch constraints>

Assigned item:
<concrete project-relative path>

Task hierarchy:
<automatically appended>

The assigned item is the child's responsibility.

The child owns the entire workload for that item, including:

* inspecting the existing implementation;
* implementing the required changes;
* debugging;
* testing;
* verification;
* updating the Mind when useful;
* signalling the final result.

Do not create separate child tasks for implementation, testing, debugging, or verification unless those become independently substantial workloads.

## Scheduling

The harness is responsible for creating, scheduling, and running the child tasks.

The harness manages concurrency internally.

The agent does not manually manage batch parallelism or create individual `task_start()` calls for matched items.

When one child finishes, the harness may start another pending child.

## Isolation

A batch child normally owns only its assigned item.

Children must not independently modify the same file.

A child may modify shared files only when explicitly permitted by the batch constraints or contract.

If the workload requires coordinated changes across multiple files, it should normally be handled by a higher-level task instead of multiple independent batch children.

## Failure handling

A failure in one child does not automatically fail the entire batch.

Each child is evaluated independently.

For example:

Total: 100
Finished: 96
Failed: 3
Questions: 1

The batch continues processing other items even when individual children fail or require parent input.

The final batch result contains the status and report for every child that was started.

## Question handling

If a child emits `QUESTION`, the batch records the question.

The batch does not invent an answer on behalf of the parent.

The parent may inspect the batch result and decide how to continue the affected child.

A question from one child must not automatically stop unrelated children.

## Completion

The batch finishes only after every matched item has reached a terminal state:

FINISHED
FAILED
QUESTION

The batch returns an aggregate result containing:

* total number of matched items;
* number of finished items;
* number of failed items;
* number of questions;
* per-item status;
* per-item report;
* child task id for each item.

Example:

BATCH FINISHED

Total: 20
Finished: 18
Failed: 1
Questions: 1

Results:

src/effects/a.cpp     FINISHED
src/effects/b.cpp     FINISHED
src/effects/c.cpp     FAILED
src/effects/d.cpp     QUESTION
...

## Empty target

If the target matches no files, the batch completes successfully with:

Total: 0
Finished: 0
Failed: 0
Questions: 0

This is not an error.

## Determinism

The target is resolved exactly once at batch creation time.

Files created, deleted, or renamed after the snapshot do not become new batch items.

The batch therefore operates on a fixed set of items.

## Important design principle

The batch tool is a workload multiplier, not an action multiplier.

For example, this is correct:

task_batch(
    target = "src/shaders/*.frag",
    goal = "Create or update this shader, debug it, and verify that it works."
)

Result:

Batch
├── Shader A — complete workload
├── Shader B — complete workload
├── Shader C — complete workload
└── ...

Do NOT turn the batch into:

Batch
├── implement A
├── verify A
├── implement B
├── verify B
└── ...

Implementation, debugging, testing, and verification normally belong to the same child workload.

The parent specifies what should be accomplished.

The child decides how to accomplish it.

**The batch tool automatically turns one workload into N independent workload tasks.**
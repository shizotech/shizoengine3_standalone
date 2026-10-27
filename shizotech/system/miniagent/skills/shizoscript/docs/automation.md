# What runs by itself (since 2026-10-23)

There is no GitHub CI (`.github/workflows-disabled/`). Claude runs take its place: cloud routines (claude.ai/code/routines,
environment "Shizo") and scheduled tasks of the Claude desktop app on the test machines. All of them report on GitHub;
nothing merges by itself: merging stays with Marc. A PR without a platform label is merged once its checks are green;
the nightly checks of `main` test it on Windows and the Mac afterwards.

```
issue opened ──► Issue worker ──► PR (claude/auto-<n>-…) ──► PR precheck ──► no label: Marc reviews and merges
                                                                 │
                                                                 └─► needs-windows / needs-mac (only what needs the machine)
                                                                          ▼
                                                     Windows / Mac test queue at night ──► windows-tested / mac-tested
nightly check of main (Linux, Windows, Mac) ──► #625, branch `stable` moved when all three pass
daily PR maintenance ──► main merged into behind PR branches, status table in #630
```
## Cloud routines

| Routine | When | What | Reports |
|---|---|---|---|
| Issue worker (Opus) | an issue is opened / reopened; and 02:00 UTC | picks open issues an agent can finish alone (bugs first, `verified`, severity), implements them on `claude/auto-<n>-<slug>`, checks them (`/precheck`), opens a PR `Fixes #n`. At most 10 a day; asks instead of guessing (`needs-info`) | PR, comments on the issue |
| PR precheck | a PR is opened / reopened / ready for review | the checks of `/precheck` for what the PR changes (Linux build, tests, the macOS build with clang + libc++, shaders, assets, wiki), a review for real problems, the labels `needs-windows` / `needs-mac` by the table of `CLAUDE.md` (*Tests on Windows and the Mac*) | one comment per head commit |
| Daily PR maintenance | 05:00 UTC | merges `main` into `claude/*` PR branches that fell behind (clean or mechanical conflicts only, built before the push), lists every open PR with what it waits for | body of #630, comments on conflicts |
| Nightly Linux / macOS check | 01:00 UTC | build, `run_tests.sh` (also the GUI tests under Xvfb), `check_stdlib.sh`, `check_libcxx_linux.sh`, `check_glsl.py`, assets, `smoke.py static generators` of `main` | #625, only on change |

In the cloud containers `gh` reaches only the REST API of this repository: `gh issue list` / `gh pr list` / `gh issue view`
(GraphQL) and `search/issues` answer 403 (2026-10-26, #733). Use `gh api repos/shizotech/shizoscript3_source/...` (`issues`,
`issues/<n>/comments`, `pulls?state=all`, `issues/<n>/labels`) or the GitHub MCP tools. The Ubuntu packages of
`_testing/linux_app/build.sh` need an `apt-get update` first in a fresh container.

## Scheduled tasks on the machines

| Task | Machine | When | What | Prompt |
|---|---|---|---|---|
| Nightly Windows check | Windows PC | 04:00 | `_testing/windows_app/nightly.ps1`: MSVC build of everything, tests, stdlib, VibeVJ start; moves branch `stable` to the commit when Windows, the Mac and Linux pass | `_testing/windows_app/nightly_task.md` |
| Windows test queue | Windows PC | 05:00 | up to three PRs / issues labelled `needs-windows`, real input only when nobody used the PC for 15 min (`idle.ps1`) | `_testing/windows_app/queue_task.md` |
| Nightly macOS check | Mac | 03:30 | `_testing/mac_app/nightly.sh`: build + bundle, tests, stdlib, packages, GUI scripts, VibeVJ over MCP (not when the Mac is in use), thread stress; Sundays every shader | `_testing/mac_app/nightly_task.md` |
| Mac test queue | Mac | 03:50, after the nightly check | up to three PRs / issues labelled `needs-mac`, nothing that opens a window when the Mac was used in the last 15 min (`ioreg` HIDIdleTime) | `_testing/mac_app/queue_task.md` |

The tasks run only while the Claude app is open (a missed one runs at the next start), with the permission mode set on
the task. The binaries in `x64\Release` still come from the build machine; the checks only build to check.

## Labels

| Label | Set by | Meaning |
|---|---|---|
| `needs-windows` / `needs-mac` | precheck, issue worker, sessions, Marc | test it on that machine (the queue there takes it at night). Only for platform code, devices, GPU, Retina, Windows paths: the table in `CLAUDE.md`, *Tests on Windows and the Mac* (since 2026-10-24; before, every C++ change got one) |
| `windows-tested` / `mac-tested`, `test-problems` | the test queues | tested; results in a comment; something failed |
| `auto-in-progress`, `auto-pr`, `auto-failed`, `needs-info` | issue worker | taken now; PR opened; gave up (see comment); a question to answer |
| `auto-skip` | Marc | the issue worker never takes this issue |
| `owner:claude` | issue worker, Marc | reserved for Claude: the Shizotech AI does not take it |

## Steering it

- Keep an issue away from the worker: `auto-skip`. Answer a `needs-info` question in the issue: the next nightly run
  takes it again.
- Daily view: #630 (open PRs, what each waits for), #625 (what broke or works again).
- Pause or change a routine: claude.ai/code/routines; a scheduled task: the "Scheduled" section of the desktop app.
- The prompts of the routines and of the machines' tasks are the source of their behaviour. Copies are kept in the repo
  (`docs/routines/` for the PR precheck and the issue worker, the files named above for the machines): change both
  together. Routines made over the API can only be edited by Marc on claude.ai/code/routines, not by an agent.
- What a run had to find out goes into the docs (`CLAUDE.md`, *Write down what you found out*): sessions and the issue
  worker write it in their PR (`/precheck` asks for it), unattended runs that may not push list it under **Learned**
  in their report and the next interactive session writes it down.
- Merging many open PRs at once (asked by Marc, 2026-10-24 / 26): simulate them in one order in a scratch worktree
  (`git merge` one after the other from `origin/main`), resolve the conflicts on the PR branches with merge commits,
  build and test the end state once (`/precheck`), then merge on GitHub **one at a time** in that order. Merges sent
  in parallel race, and GitHub can report a PR as conflicting (`mergeable_state: dirty`, merge refused with 405) that
  `git merge-tree` shows clean: merging `origin/main` into the PR branch and pushing fixes it. Do not switch branches
  in a worktree while a check (`check_libcxx_linux.sh`, `run_tests.sh`) runs there: its tests vanish mid-run.

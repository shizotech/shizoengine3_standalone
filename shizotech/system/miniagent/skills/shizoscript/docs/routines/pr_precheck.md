# Routine: PR precheck

The prompt of the cloud routine *PR precheck (shizoscript3_source)* (claude.ai/code/routines, model Sonnet, started
by pull_request events). The routine is the source of its behaviour: change it there and here together. Since
2026-10-24 step 4 sets the platform labels by the table in `CLAUDE.md` (*Tests on Windows and the Mac*).

---

Pre-merge check of pull requests of shizotech/shizoscript3_source. There is no CI (`.github/workflows-disabled/`); this run is the check a PR gets before it is merged. Do NOT change code, push, merge or close anything.

## Which PRs
This run was started by a GitHub pull_request event (opened, reopened, ready for review); its PR is named in the event data of this session if there is any. In any case check every open, non-draft PR whose head commit has no comment containing `<!-- precheck <head sha>` yet (`gh pr list --state open --json number,isDraft,headRefOid,headRefName,title` and the comments of each), at most three per run, the one of the event first.

## Each PR
1. `git fetch origin pull/<n>/head:pr<n> && git checkout pr<n>`; the changed files: `git diff --name-only $(git merge-base origin/main HEAD)`.
2. Follow `.claude/skills/precheck/SKILL.md` of that checkout (the Linux part): the table there says which checks the changed files need (Linux build + run_tests for C++, `check_libcxx_linux.sh` = the macOS build and `_testing/windows_app/check_msvc_linux.sh --install` = the Windows compile for any C++, the core copies in sync, check_glsl for shaders, `app.sh check` / check_assets for app scripts, wiki links). Install Ubuntu packages as the top of `_testing/linux_app/build.sh` lists them; a check that cannot run is 'not run' with the reason. Before blaming the PR for a failure, check whether `main` fails the same (the nightly reports on issue #625 list what fails on main).
3. Read the diff for correctness problems a reviewer would block on (wrong logic, a missing file in a project list - a new module `.cpp` belongs in its `.vcxproj`, its `_linux` `.vcxproj` and `shz_add_module` of `shzscript_macos/CMakeLists.txt` -, platform code missing for one platform, MSVC-only constructs such as `near`/`far` names or `false` as a pointer). Only real findings, each with file:line and why; no style remarks.
4. Labels for the test machines: by the table in `CLAUDE.md`, section *Tests on Windows and the Mac*, of that checkout. Scripts, docs, shaders, assets, tests and portable C++ get NO label: the nightly checks of `main` test them on Windows and the Mac after the merge. `needs-windows` only for Windows-only code (`#ifdef _WIN32` branches, `shz_shell_ext`, `.vcxproj` / `.sln` changes, `_testing/windows_app`) or what needs the real Windows machine; `needs-mac` only for Apple-only code (`#ifdef __APPLE__`, `*.m` / `*.mm`, `shzscript_macos/`, `_testing/mac_app`) or what needs the real Mac. "Needs the real machine" = devices (cameras, MIDI hardware, Art-Net / DMX lamps, Spout / Syphon / NDI, sound), GPU or driver behaviour Mesa cannot show, Retina / HiDPI, Windows paths (drive letters, `\`) in new path code. Name the reason for each label you set in the report. Not when the PR already has `windows-tested` / `mac-tested` for the same head commit. Do not remove labels a person or session set.

## Report
ONE comment per PR (`gh pr comment <n> --body-file <file>`): title `Precheck of <short sha>`, a table check | result (pass / FAIL with the failing names / not run + reason / also fails on main), the review findings (or 'no findings'), the labels set and why (or 'no platform label needed: <category of the table>'). Last line: `<!-- precheck <full head sha> -->`. Short and concrete, in English. If gh cannot post, put the reports into your final message.

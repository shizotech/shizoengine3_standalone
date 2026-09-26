# Command Sessions

Command sessions provide non-blocking process execution for agents.

A command may continue running after a tool call returns. The agent can later inspect the process or provide additional input without restarting it.

Each running command is identified by a `session_id`.

## `command_start`

Starts a new command session.

```text
command_start(
    command,
    timeout,
    cwd?,
    script_type?
)
```

### Arguments

`command`
: Command line to execute. Multiple lines are allowed.

`timeout`
: Maximum time to wait for the command during this call.

`cwd`
: Optional working directory for the process.

`script_type`
: Optional interpreter used when the command is executed from a script file: `"auto"` (default), `"bat"`, `"ps1"`, `"sh"` or `"py"`.

### Behavior

Start the process and wait until one of these conditions occurs:

1. The process exits.
2. The timeout expires.

If the process exits, return its final state, exit code, and available console output.

If the timeout expires while the process is still running, **do not terminate it**. Return its current state and output together with its `session_id`.

A timeout is therefore not an error.

### Multi-line commands

A `command` containing line breaks is not passed to the shell as one collapsed statement. It is written to a script file in a `.shz_cmd` directory inside `cwd` and executed line by line with the interpreter selected by `script_type` (`bat` on Windows, `sh` elsewhere). The file is named after the session (`shz_cmd_<session_id>.bat`) and removed when the session ends. This is how inline scripts, heredoc-like input and batch files with control flow are supported.

A single-line command with an explicit `script_type` is stored as a script file as well.

### Example

```text
command_start("./build.sh", 30000)
```

Process finishes:

```text
state: EXITED
exit_code: 0
output: Build successful
```

Process is still running:

```text
state: RUNNING
session_id: 42
output: Starting application...
```

The existing session must then be used for further interaction.

---

## `command_read`

Reads output and state from an existing command session.

```text
command_read(
    session_id,
    timeout?
)
```

### Arguments

`session_id`
: Session returned by `command_start`.

`timeout`
: Optional maximum time to wait for additional output or process termination.

### Behavior

Return:

* current process state;
* new console output since the previous read;
* exit code when the process has exited.

Output should be incremental. Previously returned output should not normally be sent again.

If `timeout` is specified and the process produces no output or exits during that period, return the current state anyway.

If the process is still running, the session remains active.

### Example

```text
command_read(42, 2000)
```

Possible result:

```text
state: RUNNING
output:
Shader compilation started...
```

Later:

```text
command_read(42, 2000)
```

Possible result:

```text
state: EXITED
exit_code: 1
output:
Shader compilation failed at line 42.
```

---

## `command_input`

Sends input to an existing command session.

```text
command_input(
    session_id,
    input,
    close_stdin?
)
```

### Arguments

`session_id`
: Session to send input to.

`input`
: Data written to the process stdin. May be empty when only closing stdin.

`close_stdin`
: Optional flag to close the stdin pipe after writing, which tells the process that there is no more input.

### Behavior

Write the supplied input directly to the session's stdin.

The process remains running after the call unless the input itself causes it to exit.

Input should not automatically be appended with a newline. The caller is responsible for providing exactly the desired input.

This allows both ordinary interactive input and programs requiring precise byte/line input.

Closing the stdin pipe (`close_stdin`) is the only reliable way to signal the end of the input. Sending `Ctrl+Z` as text does not work.

### Example

Process:

```text
Continue installation? [y/N]
```

Agent:

```text
command_input(42, "y\n")
```

The agent can then use `command_read()` to inspect the result.

---

## `command_kill`

Terminate or force-kill a running command session.

```text
command_kill(
    session_id,
    mode?,
    wait_ms?
)
```

### Arguments

`session_id`
: Session to terminate.

`mode`
: `"graceful"` (default) to request a clean shutdown (SIGTERM, Ctrl+C on Windows), or `"force"` to kill the process and everything it started (SIGKILL on the process group, job object on Windows).

`wait_ms`
: Optional milliseconds to wait for the process to exit after sending the signal (default 3000).

### Behavior

1. Send the requested termination signal to the process.
2. Wait up to `wait_ms` for the process to exit.
3. If graceful termination times out, automatically escalate to force kill (SIGKILL).
4. Drain any remaining stdout/stderr output.
5. Remove the session from the active session registry.

If the process had already exited before the kill request, the session is pruned and the exit code is reported.

### Example

```text
command_kill(42)
```

```text
state: KILLED
pid: 12345
mode_used: graceful
exit_code: 0
output: (final output if any)
```

Force kill:

```text
command_kill(42, "force")
```

---

## `command_list_sessions`

List all currently active command sessions.

```text
command_list_sessions()
```

### Arguments

None.

### Behavior

Returns a summary of every registered session:

* `session_id`
* `pid`
* `command` — the command line that was started
* `cwd` — working directory
* `uptime_seconds` — how long the process has been running
* `state` — `RUNNING`
* `pending_output_bytes` — bytes of unconsumed output

Exited sessions are automatically pruned from the registry during this call. Their ids are reported in `pruned_exited_sessions`.

Use this to identify runaway or orphaned command processes.

### Example

```text
command_list_sessions()
```

```text
total_sessions: 2
running_sessions:
  session_id: 1  pid: 12345  command: ./server.sh  cwd: ./  uptime_seconds: 42
  session_id: 2  pid: 12346  command: watch build  cwd: ./src  uptime_seconds: 5
```

---

## Session lifecycle

```text
command_start
      |
      v
   RUNNING
      |
      +---- command_read ----+
      |                      |
      +---- command_input ---+
      |                      |
      v                      |
   EXITED <------------------+
```

A command remains alive until the process itself exits or the harness terminates the session.

A timeout from `command_start` or `command_read` must never implicitly terminate a running process.

## Process output

Command sessions should capture stdout and stderr.

Output should be made available incrementally so long-running processes do not repeatedly inject their entire output history into the agent context.

The harness should impose a bounded session output buffer to prevent unbounded memory or context growth.

## Interactive processes

Command sessions should use a terminal-like interface where possible rather than simple blocking pipes.

The implementation should support:

* long-running processes;
* interactive stdin;
* stdout/stderr streaming;
* programs that do not naturally terminate;
* development servers;
* file watchers;
* test runners;
* GUI applications;
* interactive CLI programs.

The command session abstraction must hide platform-specific process handling from the agent.

## Important semantics

A running process is **not** a blocked agent.

The agent is free to continue reasoning and performing other task work while a command session remains alive.

Do not restart a running process merely because the initial timeout expired. Continue interacting with the existing session.

The reported `state` comes from the process itself (`subprocess.process.status().running` / `running()`), which checks the live OS process. It is authoritative: a session is only reported as `RUNNING` while the process is really alive, and `EXITED` always carries the process exit code when the OS can still report it.

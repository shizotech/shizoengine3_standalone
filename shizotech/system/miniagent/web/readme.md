# web/ — the web interface of a node

Served by `web_ui.shio` when a node runs with `--web` (`shz miniagent --web`). Plain
HTML / CSS / JS, no build step and no CDN: the pages work without internet.

```
web/
├── index.html, dashboard.js/.css   the shell: compact workspace tree + main pane
├── chat/                           legacy standalone chat page (retained on disk, denied at /chat)
├── tasks/                          legacy worker-pool page (retained on disk, denied at /tasks)
├── architecture/                   the architecture graph (served, embedded by the Architecture tab; /api/workspaces/<id>/architecture/..., ../architecture_spec.md)
│   ├── graph.js                    SVG renderer, layout, editing, side panel
│   └── style.css
├── components/
│   ├── nodeapi.js                  fetch helper: the {ok, data} envelope, the API token (X-Api-Token)
│   ├── icons.css                   the fa-* icon classes as plain glyphs (no Font Awesome download)
│   ├── minimd.js                   small Markdown renderer + highlight.js stand-in for the chat
│   ├── theme.css, ui.css, utils.js shared theme and helpers
│   ├── industrial.css               animated old-console layer loaded after dashboard.css
└── cow_lays_eggs.html              the secret egg
```

Notes for changes:

* An empty list arrives as `{}` (ShizoScript json): turn API lists into arrays before
  using them (`Array.isArray(x) ? x : Object.values(x || {})`).
* With `--api-token` every `/api/` call needs the token; `NodeApi` asks once and keeps it
  in `localStorage` (`?token=<t>` in the URL sets it as well).
* The API is documented in `../node_api.md` (node) and `../architecture_spec.md` (graph).
* The session SSE URL is `/api/sessions/<id>/stream?token=<t>&since=<seq>`. EventSource cannot
  send headers, so the token is accepted as a query value; `since` stops the page from
  replaying the history it already rendered. The route sets `Content-Type: text/event-stream`.
* Selecting a session loads the complete transcript from `chat.json` (via `GET /api/sessions/<id>`)
   and the in-flight `live_text`, then starts the stream at the latest sequence. The bounded
   `session.json.events` window is only a live/replay buffer, never the chat transcript.
   A terminal `done`/`failed` report is rendered from the session's `report` (or the `done`
   event) even when `chat.json` already contains the final assistant text; switching away and
   back therefore keeps the finalize report bubble.
* The worker serializes and retries `chat.json` saves after every turn and at tool starts; a
  transient save failure emits a warning instead of killing the session.
* The dashboard hides miniagent's synthetic `<---SYTEM MESSAGE--->` finalize reminder prompts;
  they are internal context, not user messages.
* On restart the session manager loads the saved `session.json` files from each workspace's
  `.megamind/sessions/`; sessions that were running are marked stopped.
* A workspace that already has a legacy `.agentspace/architecture.json` gets it copied into
  `.megamind/architecture/architecture.json` when the workspace is created.
## Workspace dashboard (issue #907)

`index.html`, `dashboard.css` and `dashboard.js` provide a compact Project tree: the store's synthetic
`root` is hidden, actual projects are top-level rows, subprojects and their sessions form a connected
hierarchy, and clicking a project or subproject toggles only its own branch. Open branches stay open
when selection moves elsewhere. Sessions are opened only when clicked; selecting a project never creates
or auto-opens a session. Tree connectors use 13px per level.
Session streams resume from the latest sequence and the manager drains buffered agent output before
restarting a child process, preserving the final delta and terminal event. Each worker saves the model's
chat transcript to `.megamind/sessions/<id>/chat.json` after a turn and imports it on the next spawn, so
new prompts continue the session conversation. For older sessions without that file, retained user and
assistant events seed a transcript on the next spawn. Sessions, architecture and tasks live under that
project's `.megamind/`. Chat streams through
`GET /api/sessions/<id>/stream`; a new prompt interrupts the running turn. Settings edits
`max_sessions`; live token/usage stats and notifications are shown in the shell. Removing a workspace stops and deletes its sessions automatically; its project files stay on disk, and sub-workspaces must be removed first.
API contract: `../workspace_spec.md`. The architecture tab embeds `architecture/` for the pan/zoom,
node editing and layout controls, scoped to the selected workspace. The graph refreshes explicitly
and polls every 10 seconds only while a worker job is active; it does not poll while idle.
Reasoning events are incremental chunks: the dashboard accumulates each contiguous run, then shows only
its latest sentence. Tool cards show selected identifying parameters and completion/failure, not raw
argument or result payloads. Normal-mode turns finish after one agent task; Loop mode retries until
its goal is reported finished or failed. Per-session `low` / `medium` / `high` reasoning effort is
persisted and applied to every worker turn; changing it in the composer persists immediately through
`POST /api/sessions/<id>/effort`, and the selector is not reset by SSE status/token updates. The
sidebar status indicator updates from the lightweight stats endpoint without rebuilding the tree. Workers
initialize the workspace goal store and receive validated goal/task tools plus architecture inspection and
pending-edit tools (including node and relationship edits); architecture jobs and source edits remain under
owner control. New dashboard one-off tasks are active manual goals queued through the scheduler, while a
session switch only replaces the browser's event stream and never stops the worker. Every registered workspace
and subworkspace is initialized with `.agentspace/` from `agentspace_template/` for the goal engine, without
replacing existing files. Older goal files under `.megamind/tasks/` are imported into `.agentspace/` on load;
the legacy directory is retained as a backup and is not an active store. For workers, a recurring task is a
recurring Goal: use `create_recurring_goal`, never the one-off `create_workspace_task` tool.
The hazard stripe is a compact sidebar footer. The workspace task tab and Global Tasks view poll every 15 seconds and skip unchanged
render signatures. The task form is a persistent sibling of `taskContent`, so task polling only replaces task
cards and leaves an open form and its typed values intact. On the first prompt, the dashboard displays the accepted
user message immediately, then reloads the session and reconciles it with saved history. The separate `tasks/` worker-pool page is a legacy page denied at `/tasks`; the dashboard's Tasks tab uses the workspace goal/task API instead.

## Industrial console layer (2026-11-11)

`components/industrial.css` is loaded after `dashboard.css` and adds the animated old-console layer:

* the yellow/black hazard stripe slowly slides (`hazardSlide`) and has a moving light sweep (`hazardSweep`);
* the topbar has a POWER / LINK / BUSY / WARN lamp bank; `dashboard.js` toggles the `on` class from live session status, while the LEDs blink (`lampBusyBlink`, `lampWarnFlash`);
* status dots, active tabs and task cards pulse (`statusLampPulse`, `statusAmberBlink`, `statusRedFlash`, `tabLampPulse`);
* a pointer-events-free CRT overlay adds scanlines, a vignette and a slow scan (`crtScan`);
* panel edges get rivets/bevels; labels use a monospaced console font; the topbar and lamp bank flicker subtly;
* `prefers-reduced-motion` disables the animations and calms the overlay.

`web_ui_protect` denies the legacy standalone `/chat` and `/tasks` pages but serves `/architecture/`
because the dashboard's Architecture tab embeds `architecture/index.html`.
* The agent's internal compaction/handover run is not shown in the chat: `miniagent` suppresses
  its deltas and resets the stopped state after the handover, so a session turn shows one real
  answer, not the handover draft plus a second answer. A `done` status `failed` with "Agent was
  stopped during its run." is the old compaction bug, not an intentional stop.

* A goal with `dry_run: true` is shown as **Dry run only** in the Tasks tab. **Activate live** / **Run live** clears that policy (through `clear_dry_run: "yes"` on the status route) before moving it to active; the scheduler then dispatches a worker instead of writing only a prompt to `history.md`.
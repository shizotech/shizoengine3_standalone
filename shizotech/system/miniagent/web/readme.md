# web/ — the web interface of a node

Served by `web_ui.shio` when a node runs with `--web` (`shz miniagent --node --web`). Plain
HTML / CSS / JS, no build step and no CDN: the pages work without internet.

```
web/
├── index.html, dashboard.js/.css   the page: nodes › workspaces › sessions in the sidebar, chat / tasks / architecture
├── chat/                           legacy standalone chat page (retained on disk, denied at /chat)
├── tasks/                          legacy worker-pool page (retained on disk, denied at /tasks)
├── architecture/                   the architecture graph (served, embedded by the Architecture tab; /api/workspaces/<id>/architecture/..., ../architecture_spec.md)
│   ├── graph.js                    SVG renderer, layout, editing, side panel
│   └── style.css
├── components/
│   ├── nodeapi.js                  fetch helper: the {ok, data} envelope, the API token (X-Api-Token), NodeApi.at(<node id>)
│   ├── icons.css                   the fa-* icon classes as inline SVG masks (no Font Awesome download)
│   ├── minimd.js                   small Markdown renderer + highlight.js stand-in for the chat
│   ├── theme.css                   colours and base styles
│   └── utils.js                    helpers of the legacy pages
└── cow_lays_eggs.html              the secret egg
```

## How the page works (dashboard.js, #1015)

* **Every node through one helper.** `NodeApi.at(id)` gives `get / post / put / del / url` for
  a node: the one the page comes from (`'local'`) directly, another one under
  `/api/nodes/<id>` (its node passes the call on over ShizoNet). Every call of the page takes
  the node of the thing it works on, so a remote node needs no special code. A page opened
  with `?node=<id>` (the architecture frame of a remote workspace) uses that node for the
  plain `NodeApi.get(...)` calls.
* **No timer, no redraw.** For its own node and the node of the open workspace the page holds
  one long-poll `GET /api/live?since=<rev>&wait=20000&workspace=<id>`; another opened node is
  asked every 5 s (a browser has six connections per host). The answer has the sessions with
  their status, the stats and four counters (`tree_rev`, `goals_rev`, `notifications`,
  `peers_rev`); the page reloads only what a counter says has changed.
* **Patch, never rebuild.** `reconcile(parent, items, keyOf, create, update)` keeps the element
  of a key that is still there, makes one for a new key and removes one that went;
  `setHtml` writes `innerHTML` only when the text differs. The tree, the task cards and the
  All tasks view are drawn with it. A view that is cleared and filled again flashes and loses
  scroll and focus, which is what the 2 s task refresh did before.
* **The chat is a list of items** (`user`, `text`, `reasoning`, `tool`, `report`, `error`,
  `notice`), the same for the three sources: finished turns from `chat_history` (chat.json),
  the running turn from `turn` of `GET /api/sessions/<id>`, live events from the SSE stream
  starting at `turn_seq`. Reasoning deltas of one block are one item whose line shows the
  sentence being thought; a tool call is one item with its state. Both open on a click
  (`fillDetail`: the body is made when it is opened): the whole reasoning, every parameter of
  the call and the result; the square opens the same in a window with a copy button. The
  text of a long transcript is drawn 160 items at a time ("Show earlier").
* Markdown of a streaming answer is rendered at most every 70 ms (the whole block again per
  token was quadratic); the chat follows the stream only while it is at the bottom, otherwise
  a button to jump down shows.
* An `EventSource` that the server closed would reconnect by itself with the **old** `since`:
  the page closes it on error and opens a new one with the current position.
* A session started somewhere else (a gateway, a scheduled goal) appears through the live
  feed; opening it works the same. A finished session that is continued elsewhere comes back
  to life in the open chat (the feed says it runs, the page reloads it).

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
## Workspace dashboard (issues #907, #1015)

The sidebar is a tree: nodes (this one first, a gateway as a row without children), under a
node its "General" workspace and the registered ones, sub-workspaces and sessions below them.
A click on a node or a workspace toggles only its own branch; open branches and the selection
are remembered in the browser (`localStorage`). Sessions are opened only when clicked. `+`
on a workspace focuses the composer: the session is created by its first prompt.
Session streams resume from the latest sequence and the manager drains buffered agent output before
restarting a child process, preserving the final delta and terminal event. Each worker saves the model's
chat transcript to `.megamind/sessions/<id>/chat.json` after a turn and imports it on the next spawn, so
new prompts continue the session conversation. Sessions, architecture and tasks live under that
project's `.megamind/`. A new prompt interrupts the running turn. Removing a workspace stops and
deletes its sessions automatically; its project files stay on disk, and sub-workspaces must be removed first.
API contract: `../workspace_spec.md`. The architecture tab embeds `architecture/` for the pan/zoom,
node editing and layout controls, scoped to the selected workspace (and node). The graph refreshes explicitly
and polls every 10 seconds only while a worker job is active; it does not poll while idle.
Normal-mode turns finish after one agent task; Loop mode retries until
its goal is reported finished or failed. Per-session `low` / `medium` / `high` reasoning effort is
persisted and applied to every worker turn; changing it in the composer persists immediately through
`POST /api/sessions/<id>/effort`, and the selector is not reset by status/token updates.
New dashboard one-off tasks are active manual goals queued through the scheduler (a title that
is taken gets a number), while a session switch only replaces the browser's event stream and
never stops the worker. The task form is a sibling of `taskContent`, so a task update leaves an
open form and its typed values intact. The separate `tasks/` worker-pool page is a legacy page
denied at `/tasks`; the dashboard's Tasks tab uses the workspace goal/task API instead.

Settings are per node (the select at the top of the dialog): the session limit and the
Telegram gateway (`GET / PUT /api/gateway`; the token field is write-only, the status and the
last log lines of the gateway process refresh while the dialog is open).

## Look (2026-11-17)

One stylesheet, `dashboard.css` (colours in `components/theme.css`): dark metal, amber, the
hazard stripe on the sidebar, the LINK / BUSY / WARN lamps in the top bar (`updateLamps()`
toggles `on`: LINK = the live feed of this node answers, BUSY = a session generates, WARN = a
session asks a question or a node stopped answering). The former three layers
(`ui.css`, `dashboard.css`, `industrial.css`) overrode each other and were replaced by it;
`prefers-reduced-motion` switches the animations off. Phone width (≤ 900 px): the sidebar
is an overlay behind the menu button.

Testing the page without a model: a scripted OpenAI-compatible endpoint, two nodes with
`--data-dir` (the one with `--web` started first, so it owns the ShizoNet port and sees the
other) and headless Chromium are enough; what was checked that way is in the PR of #1015.

`web_ui_protect` denies the legacy standalone `/chat` and `/tasks` pages but serves `/architecture/`
because the dashboard's Architecture tab embeds `architecture/index.html`.
* The agent's internal compaction/handover run is not shown in the chat: `miniagent` suppresses
  its deltas and resets the stopped state after the handover, so a session turn shows one real
  answer, not the handover draft plus a second answer. A `done` status `failed` with "Agent was
  stopped during its run." is the old compaction bug, not an intentional stop.

* A goal with `dry_run: true` says so on its card in the Tasks tab ("Dry run: the prompt is written to history.md, no worker starts"). **Activate** / **Resume** clears that policy (through `clear_dry_run: "yes"` on the status route) before moving it to active; the scheduler then dispatches a worker instead of writing only a prompt to `history.md`.* A task/session accepted while every session slot is busy is shown in the **Queued** section of the Tasks tab; it starts FIFO when a slot frees, and the section label says it is waiting for a free session.

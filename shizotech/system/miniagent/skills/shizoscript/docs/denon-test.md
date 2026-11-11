# DJ Watch for Denon players: test on Windows, macOS and real Denon hardware

Goal (request of 2026-10-28): "make DJ Watch Denon compatible". DJ Watch (the program `_standalones/djwatch_standalone/`
and the VibeVJ generators *Prolink Bridge* / *Prolink Decks*) reads Denon players with Engine DJ over StageLinQ, next to
Pioneer CDJs over Pro DJ Link, with the source *Network card*.

Built and checked in a Linux container. What that could not show: a real Denon player (none here, the protocol is not
published: it follows the open implementations listed in `modules/shzmodule_prolink/stagelinq/README.md`), the Windows
firewall and the shared UDP port 51337 on Windows, the loopback alias on macOS. **C++ changed**: the prolink module
needs a build.

## What changed

| Area | Files | Before -> now |
|---|---|---|
| StageLinQ listener | `modules/shzmodule_prolink/stagelinq/sl_listener.*`, `sl_protocol.*` | new: discovery, directory, StateMap, BeatInfo, FileTransfer; Denon decks as DJ Watch lines |
| Engine library | `stagelinq/sl_engine.*`, `sl_sqlite.*`, `sl_inflate.*` | new: reads `Engine Library/Database2/m.db` (Engine DJ 2.x and 3.x+), turns waveform / beat grid / cues into the formats of the CDJ data |
| Session | `prolink_session.cpp` | the *Network card* session runs the Denon listener next to the Pro DJ Link one; `port()` / `error()` count Denon players |
| State | `prolink_state.cpp` | new line `sl` -> `state().esp.stagelinq` |
| Sockets | `djlink/djlink_net.*` | `tcp_socket::read_some`, `local_port`, `wait_readable` for TCP; `udp_socket::open(..., shared)` (Windows: `SO_REUSEADDR`, macOS: `SO_REUSEPORT`) |
| UI | `_standalones/djwatch_standalone/DJWatch/__init__.shio`, `ProlinkBridge.asset`, `ProlinkDecks.asset` | status texts with Denon players, *Devices* lists Denon units, library progress |
| Build | both prolink `.vcxproj` (+ filters), `shzscript_macos/CMakeLists.txt`, `test/run.sh`, `test/run.bat` | five new sources; new test `test_stagelinq`, tool `fake_denon` |

No save keys or control IDs changed; projects load as before.

The DJ Watch box (ESP32 firmware, shizotech/prolink-bridge) gets the same listener in its own PR (copies in
`firmware/lib/stagelinq/`, checklist `docs/denon-test.md` there). For it the listener got options that the program does
not use: `download`, `cache_bytes`, `few_sockets`, `max_units` (`stagelinq/README.md`), plus an `ESP_PLATFORM` branch in
`djlink/djlink_net.cpp`. The program behaves as before with their defaults.

## Checked on Linux

- `modules/shzmodule_prolink/test/run.sh`: `test_state` (all), `test_djlink` (all), `test_stagelinq` (all: inflate,
  protocol, both library schemas decoded by the CDJ decoders, the listener against the simulated SC6000, the same through
  `prolink::session`), also with `SANITIZE=thread` and `address,undefined`.
- `shzscript_macos/check_libcxx_linux.sh` and `_testing/windows_app/check_msvc_linux.sh --only prolink`: see the PR.

## Phase 0: get the branch

- Windows: build (`_testing/windows_app/build.ps1`), then `_testing/windows_app/testcopy.ps1 -Name denon -Binaries`.
- macOS: `sh shzscript_macos/setup_mac.sh --build`; for the loopback tests `sudo ifconfig lo0 alias 127.0.0.2` first.

## Phase 1: automatic tests (Windows, macOS)

- [ ] Windows: `modules\shzmodule_prolink\test\run.bat` from an x64 Native Tools prompt: `stagelinq: all tests passed`
  (the session test opens UDP 51337: the firewall may ask once).
- [ ] macOS: `sh modules/shzmodule_prolink/test/run.sh`: the three tests pass.

## Phase 2: the simulated SC6000 in the programs (Windows, macOS; no hardware)

`fake_denon` is built by `run.sh` / `run.bat`; start it in `modules/shzmodule_prolink/test/` (it reads `engine_v3.db`).

- [ ] DJ Watch program with `--card 127.0.0.1`: *Devices* shows "Denon SC6000 127.0.0.2 connected · deck 2", then
  "Engine library of USB 1 opened, read from the player as needed" under *Messages*.
- [ ] *Decks*: deck 2 "Song One" by "DJ Test", artwork (a grey test picture), waveform without bass in the first half and
  with bass in the second, hot cues A "Drop" (red) and C "Break" (blue), loop "Loop A"; the beat boxes on top run at
  128 BPM.
- [ ] VibeVJ: *Prolink Decks* with *Source* › *Network card*, card `127.0.0.1`: the same deck; *Prolink Bridge* gives
  128 BPM and the beat.

## Phase 3: real Denon hardware (a person with a player)

Needs: a Denon player or controller with Engine DJ (SC6000 / SC5000 / Prime 4 / Prime 2 / Prime Go / SC Live), a USB
stick with an Engine DJ library (analysed tracks), a network cable to the computer (switch, or straight into the
player). The tester notes the model and the Engine OS version.

- [ ] *Devices* lists the unit as "Denon SC6000 ... connected" (or Prime 4 ...) with its deck numbers. If it stays at
  "connecting…": the error after it, and the console text.
- [ ] Deck number = the player number of the player; layer B shows up as deck 3 / 4 when a track is loaded there.
- [ ] *Messages*: "Engine library of USB 1 opened, read from the player as needed". If it says "… read, N tracks"
  after "library USB 1: … %" instead, the player does not hand out parts of a file (the whole library was copied):
  note it, with the Engine OS version.
- [ ] Load a track: title and artist at once; album, artwork, waveform, beat grid and hot cues within a second or two.
- [ ] Play: the beat boxes match the beat counter of the player (1 on the downbeat). Write down if they are off by one
  or more beats.
- [ ] The waveform runs with the music; jump to a hot cue, loop, scratch: it follows within a second.
- [ ] Pitch fader: BPM and pitch on the deck change like on the player.
- [ ] Master / sync: the deck the player shows as master is master in DJ Watch.
- [ ] Track from the USB stick of another player (two players): waveform and cues come too.
- [ ] Prime 4 / Prime Go: *On air* only while the channel fader is open. SC players with an X1850: the same with its
  faders.
- [ ] History: a track counts after 30 s of playing.
- [ ] Eject the stick: the deck empties; insert another: its tracks get their data.
- [ ] Analyse a new track on the player, load it: it gets its waveform (the library is read again after a change).
- [ ] Pull the network cable for 10 s and put it back: the player comes back by itself.
- [ ] The player keeps working normally the whole time (no message, no slow browsing when tracks are loaded).
- [ ] SoundSwitch or another StageLinQ program on the same computer at the same time: does DJ Watch still see the
  player?

Known: the waveform is coarse (Engine keeps only an overview); phrases are found in the waveform; the cue countdown
counts to hot cues. Not supported: Engine Prime 1.x libraries (message "Engine Prime 1.x library").

## Results

### Windows (<date>)

Machine, per phase pass / fail, screenshots of anything wrong, bugs fixed during the test with their commit.

### macOS (<date>)

### Denon hardware (<date>)

Model, Engine OS version, per item pass / fail, the console text and `settings.json` of the DJ Watch program.

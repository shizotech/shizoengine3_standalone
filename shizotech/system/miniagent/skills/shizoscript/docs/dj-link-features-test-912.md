# DJ Link features after #912: test on Windows, macOS and with real gear

Six pull requests stacked on #912 (each one's base is the one before), from comparing our DJ Link / StageLinQ module with
about 30 projects on GitHub (beat-link family, SuperTimecodeConverter, prolink-connect, StageLinQ libraries, simulators;
facts and licences in each PR):

| PR | Branch | What |
|---|---|---|
| 1 | `claude/jolly-newton-da3lfw-1-stagelinq` | Denon: Syncing and Broadcast services, Engine 5 artwork / overview files, key lock, announce before dial |
| 2 | `claude/jolly-newton-da3lfw-2-mixer` | mixer data: Pioneer DJM faders / EQ / VU through a bridge identity, Denon channel assignment, enhanced on air, DJ Watch tab *Mixer* |
| 3 | `claude/jolly-newton-da3lfw-3-export-tests` | fake CDJ serves a real rekordbox export; three decoder fixes (phrases, 3-band preview, blue preview) |
| 4 | `claude/jolly-newton-da3lfw-4-show-cues` | lighting desk: track shows by signature, cue-name rules, phrase triggers, look-ahead, limits, back-off, *Cue call* + `/cuecall` page |
| 5 | `claude/jolly-newton-da3lfw-5-midi-nowplaying` | DJ MIDI Out (+ SoundSwitch), now playing, playlist writer, Ableton Link nudging, lead deck debounce |
| 6 | `claude/jolly-newton-da3lfw-6-timecode-tcnet` | timecode from the decks (Art-Net, MTC, LTC, track offsets) and a TCNet server |

Built and checked on Linux in a container (software OpenGL under Xvfb) against simulated devices only: fake CDJs, a
fake DJM, a fake SC6000, loopback Link peers, an Art-Net / TCNet receiver, virtual MIDI. Nothing ran against real CDJs,
DJMs, Denon players, desks, Resolume, SoundSwitch or phones. **C++ changed** in every PR but 4 (4 only a little):
build the prolink module.

## Checked on Linux (the top of the stack, PR 6, with all six)

- `modules/shzmodule_prolink/test/run.sh`: state 311/0, djlink (incl. the real export), stagelinq (incl. extras), tempo
  170/0, mixer, timecode 176/0.
- `_testing/linux_app/build.sh`; `run_tests.sh` 161/0; `app.sh check __init__.shio`; DJ Watch `shz --check`;
  `check_assets.sh` 95/0; `check_links.py` 0 broken.
- `check_msvc_linux.sh --only prolink`: ok. `check_libcxx_linux.sh` (the Mac build): 162/0; the stdlib part has 3
  miniagent failures that the base has too (release snapshot, not these PRs).
- Smoke phases: `static generators tempoout decktc desk deskshow`.

## Phase 0: get the stack

- Windows: `build.ps1 -Only prolink`, `testcopy.ps1 -Name pr6 -Binaries <out>`, then `modules\shzmodule_prolink\test\run.bat`
  (first MSVC build of `test_mixer`, `test_timecode`, `fake_djm`).
- macOS: `sh shzscript_macos/setup_mac.sh --build`; `test/run.sh` **with the Mac awake** (lid open: the tempo and
  timecode tests measure real time).
- The PRs merge in order 1 → 6; test the top one unless a phase says otherwise.

## Phase 1: Denon (PR 1; needs an Engine DJ player)

- [ ] Prime / SC6000 on Engine 5: covers of tracks that show none in older builds; the overview waveform of tracks
  analysed on the player.
- [ ] Key lock on the player: `keyLock` true / false in `player(n)`.
- [ ] Sync master on the player: the master's tempo in DJ Watch follows within a beat (Syncing service).
- [ ] Edit a cue / the grid on the player: DJ Watch shows the change without reloading (Broadcast service).
- [ ] The first connection works at once (no 2 s delay).

## Phase 2: mixer data (PR 2; needs a DJM, best a 900NXS2, A9 or V10; or a Denon mixer)

- [ ] DJ Watch › *Mixer* › *Mixer data (DJM)* on, the DJM switched on afterwards: faders, EQ, VU move; status *active*.
  Note: a DJM that refuses needs a power cycle (the reason it is off by default).
- [ ] Bridge and our virtual CDJ from one computer: no conflict on the DJM or the CDJs.
- [ ] *Channel n?* hint: player 1 on channel 2: the hint shows; *Channel of each player* fixes it.
- [ ] *Enhanced on air*: fader dip during a sing-along keeps the Live ring and the history.
- [ ] Denon X1800 / X1850 / Prime 4: channel assignment and fader values (full scale 1.27 assumed).

## Phase 3: real export (PR 3; CDJs with rekordbox USB)

- [ ] Phrases of rekordbox 6+ tracks appear in Prolink Decks (they never did from real players before the fix).
- [ ] The 3-band preview looks like on the CDJ-3000 (bands not shifted); the blue preview fills the width (400 columns).
- [ ] `fake_cdj --export modules/shzmodule_prolink/test/data/rekordbox_demo` on Windows / macOS: DJ Watch shows both
  demo tracks with phrases.

## Phase 4: lighting desk shows (PR 4; desk checklist `docs/desk-test-719.md` Phase 9 has the details)

- [ ] *Track show*: a cue at bar 17 of a track fires its stack on a real CDJ, also after the same track came from
  another USB stick (signature).
- [ ] A memory cue named `DROP` fires the rule; jump back / forward on the CDJ: re-arm / skip.
- [ ] *Cue call* on a phone through the web remote (`/cuecall`).

## Phase 5: MIDI, now playing, Link (PR 5)

- [ ] DJ MIDI Out to loopMIDI (Windows) / IAC (macOS): notes on the beat (±8 ms at 60 fps), CCs.
- [ ] SoundSwitch: *Map* an AutoLoop, *Send* here; per phrase one bank select + one AutoLoop.
- [ ] Now playing during a real mix: the new track counts after 128 beats; history CSV written live.
- [ ] Ableton Link (Live / Resolume) led from a CDJ: the bar stays within a few ms over 10 minutes, no jumps.

## Phase 6: timecode and TCNet (PR 6)

- [ ] Art-Net timecode into a desk (grandMA3 onPC, ChamSys MagicQ PC): per-track offset; pause holds the frame.
- [ ] MTC to a MIDI output; LTC on an audio output into a desk's LTC input or Resolume (virtual cable).
- [ ] TCNet: Resolume Arena / ChamSys see the layers, track names, play state and position; artwork in Resolume.
- [ ] Windows: the firewall prompt for TCNet (UDP 60000-60002, 65023) and Art-Net.

## Results

### Windows (<date>)

Machine, per phase pass / fail, screenshots for anything wrong, fixes with their commit.

### macOS (<date>)

Machine, macOS version, per phase as above.

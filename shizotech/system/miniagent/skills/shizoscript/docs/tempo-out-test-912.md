# Tempo out, deck view, Denon length (#912): test on Windows and macOS

[#912](https://github.com/shizotech/shizoscript3_source/pull/912) takes ideas from LJ Link
(github.com/skyplayser/LJ-Link, a DJ monitor for lighting jockeys, tried on real CDJs and a Denon Prime 4+):

- VibeVJ and the DJ Watch program send their tempo and beats to Ableton Link and to lighting desks: OSC,
  grandMA3 OSC, grandMA2 Telnet, OSC taps for Daslight and ChamSys, and OS2L for Wolfmix.
- The deck view (*Prolink Decks*, also the Decks tab of DJ Watch) has CDJ-3000 details in the Shizo UI, a Live ring,
  artwork, the key, up to 6 decks and a *Send BPM* chip.
- The fix of the Denon track length (`Track/TrackLength` is samples).

Branch `claude/jolly-newton-da3lfw`. It was built and checked on Linux in a container (software OpenGL under Xvfb),
with only stand-ins on the loopback card. A container cannot show:

- real desks, real Link programs, real CDJs and Denon players;
- the Windows firewall prompt;
- Link multicast on a real network card;
- sharing UDP port 20808 with Resolume / Ableton Live on one computer;
- the deck view on a real GPU and on a Retina screen.

**C++ changed** (`modules/shzmodule_prolink`: new `tempo/`, `shz_tempo.*`, `djlink_net`, `prolink_state`,
`stagelinq/sl_listener.cpp`): build the prolink module before testing.

Write the results into *Results* at the end of this file, or as a comment on #912.

---

## What changed

### Tempo out (new)

| Where | What |
|---|---|
| `prolink.tempo_out()` (C++, `modules/shzmodule_prolink/tempo/`) | a sender thread: Ableton Link peer (own code, lead and follow), OSC float, grandMA3 `/cmd`, grandMA2 Telnet (login, command on change and every 15 s), Daslight tap (255 then 0), ChamSys tap, OS2L beats; a steadied tempo for the desks (0.1 steps, dead band 0.15 BPM) |
| VibeVJ, TC button of the timeline bar | the popup has a new part, *Tempo to lighting desks and Ableton Link* (`src/menu/timeline/tempo_panel.shio`). *Ableton Link* is a new source to chase. Saved in `timecode.json`, key `tempo` |
| ProlinkBridge | new setting *Tempo from* (Auto / Deck 1-6) |
| DJ Watch | new tab *Send BPM*: *Tempo from* (Auto / Deck 1-6 / Fixed tempo) and the same targets. Saved in `settings.json` and `DJWatch/tempo_out.json` |
| MCP of VibeVJ | `get_tempo_output`, `set_tempo_output`, `send_tempo_test`, `search_grandma2` |

Defaults that only a real desk can confirm:
- grandMA2: `SpecialMaster 3.16 At {bpm}`, port 30000, user `administrator` / `admin`.
- grandMA3: `Master 3.1 At BPM {bpm}` to `/cmd`, port 8000.
- Daslight / ChamSys: `/tap`, port 8000.
- OS2L: 127.0.0.1:5000.

### Deck view

Live ring and badge (green, the `live` token), artwork, key, the player model, a BPM box on the master, up to 6 decks
(DECKS: Auto / 1-6, new items at the end so saved projects keep theirs), and the played part at half brightness.
The *Send BPM* chip in `on` green sits on the deck the tempo comes from. Control IDs of existing outputs did not change;
decks 5 and 6 got new output sections.

### Denon

`Track/TrackLength` above one day is taken as samples at `Track/SampleRate`.

## Checked on Linux

- `modules/shzmodule_prolink/test/run.sh`: state 247/0; djlink and stagelinq passed; `test_tempo` 126/0 (also under
  Thread / Address / UB sanitizers). Two Link peers were 1 ms apart in phase.
- `test/link_oracle.py` against Ableton's Link library (LinkPython): tempo and bar phase match, joining and following
  work.
- `_testing/linux_app/build.sh`; `run_tests.sh` 159/0; `app.sh check __init__.shio`; `check_assets.sh` 92/0;
  `check_links.py` 0 broken.
- `smoke.py static tlsync tempoout` passed: OSC, grandMA2, OS2L to stand-ins, Link lead and chase, save / load.
- `check_libcxx_linux.sh` (the macOS build): 160/0, stdlib 73/0.
- `check_msvc_linux.sh --only prolink`: 60 files ok. The test program `test_tempo.cpp` itself was not compiled with
  MSVC.
- DJ Watch `--demo` under Xvfb: the Send BPM tab says "Tempo from deck 1 (master, on air, playing)", and the Decks tab
  shows the chip on deck 1.

## Phase 0: get the branch

- Windows:
  1. `& .\_testing\windows_app\build.ps1 -Only prolink`
  2. `& .\_testing\windows_app\testcopy.ps1 -Name pr912 -Binaries <build out>`
  3. Run `..\test\run.bat` in `modules\shzmodule_prolink\test` (it builds `test_tempo` with MSVC too).
- macOS: `sh shzscript_macos/setup_mac.sh --build`. For `test/run.sh` first run `sudo ifconfig lo0 alias 127.0.0.2`.
- DJ Watch from the checkout: `shz _standalones/djwatch_standalone/DJWatch --demo`.

## Phase 1: automatic

- [ ] `test/run.sh` / `run.bat` of the prolink module: all pass, including `test_tempo`. **With the machine awake**: `test_tempo`
  measures real time (beat timing, Link peers), so a Mac in maintenance sleep (lid closed on battery) fails random checks
  of it (2026-11-11/12). `run.sh` keeps an idle Mac awake with `caffeinate -i`; that cannot help with a closed lid.
  On Windows this is the first time `test_tempo.cpp` compiles with MSVC.
- [ ] Optional: `pip install LinkPython-extern`, then `run.sh` runs `link_oracle.py` (0 failed).
- [ ] Windows: `python _testing/linux_app/smoke.py tempoout` has no Windows twin. Instead check through MCP:
  `set_tempo_output` with OSC on to 127.0.0.1, then `get_tempo_output` shows "Sends ...".

## Phase 2: Ableton Link (needs a Link program; no desk)

Use Ableton Live, Resolume, Traktor, or the free *LinkHut* / *Link to MIDI* apps; on the same computer and on a second
one in the same network.

- [ ] **Windows:** the first start of the sender asks the firewall. Allow *Private networks*. Without that, Link
  only works on this computer; note what happens.
- [ ] VibeVJ TC popup › *Ableton Link* › *Send*:
  - the other program shows one more peer;
  - its tempo follows the timeline;
  - with *Bar* on, its bar starts with VibeVJ's (watch the metronome).
- [ ] Change the BPM in VibeVJ: the other program follows within about a second, without jumping its bar.
- [ ] Chase: TC source *Ableton Link*, Play. The timeline takes the tempo of the session and its beat in the bar.
  Change the tempo in Live: the timeline follows.
- [ ] **Same computer** (Resolume or Live running together with VibeVJ): both see each other. On macOS check that both
  can bind UDP 20808 at once, which is exactly what the container could not show.
- [ ] With CDJs or the demo set: ProlinkBridge with *Sync timeline* on, and Link on. The Link program follows the
  DJ's tempo and downbeat.

## Phase 3: lighting desks (needs the desk or its PC version)

For each desk:
1. Set it up as in the wiki `Lighting-Desk.md` › *Tempo to lighting desks*.
2. Press *Send test*.
3. Then play: the timeline at 128, then 130.

| Target | Should show | Known open |
|---|---|---|
| grandMA2 onPC (free) / console | status "logged in"; the SpecialMaster (Speed 16) shows the BPM, whole numbers; *Search* finds the onPC on this computer and a console in the /24 | the greeting / login texts were taken from LJ Link; whether `SpecialMaster 3.16` is the right default |
| grandMA2 with *Login Enabled* off | status explains that Telnet is switched off on the desk | |
| grandMA3 onPC (free) | the master `3.1` shows the BPM (In & Out › OSC: UDP 8000, Receive Command: Yes, Enable Input) | never tried |
| Daslight 4/5 | BPM tap mapped to `/tap`: the BPM of Daslight follows within a few beats | the 255 / 0 mapping |
| ChamSys MagicQ PC (free) | Tap to Time on `/tap` follows | LJ Link calls its own ChamSys support an untested alpha too |
| WTOOLS (Wolfmix) | OS2L on: the Wolfmix runs on the beat | whether WTOOLS takes our line-delimited messages |
| Resolume (OSC float) | an OSC input mapped to `/bpm` shows the tempo | |

- [ ] A tempo that wobbles (CDJ pitch fader barely touched, or audio BPM detection) does not make the desk flicker
  between 137.9 and 138.0.

## Phase 4: deck view and DJ Watch (GPU, Retina, real CDJs if there are any)

- [ ] Prolink Decks with the demo set: the Live ring is round and sharp, the badge readable; the artwork squares (from
  real CDJs) show the cover, the right way up. On Retina the chips are crisp.
- [ ] Five or six real players: DECKS Auto shows two rows of three panels.
- [ ] DJ Watch › *Send BPM* › Auto: the Decks tab shows *Send BPM* on the master deck; a fixed deck moves the chip.
- [ ] A real Denon (Prime 4+, SC6000): the length and the remaining time of a track are right (minutes, not
  millions of seconds).

## Results

### Windows (<date>)

Machine, GPU, driver. Per phase: pass / fail, with screenshots for anything wrong, bugs fixed during the test with
their commit.

### macOS (<date>)

Machine, macOS version. Per phase as above.

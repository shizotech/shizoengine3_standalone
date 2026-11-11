# ESP32 threads (#444): test on an ESP32-P4 LED controller

[#444](https://github.com/shizotech/shizoscript3_source/issues/444): on the ESP32 every FreeRTOS task shared one
`shz_thread_local`, the script lock never locked, and the worker of `ctx.return_thread()` (most of `fileio`)
allocated from the pools of the script while the script task ran. Branch `claude/esp32-threads-444`, stacked on
#821 (the core only compiles for the ESP32 with it). Checked on Linux only: the firmware compiles and links for the
ESP32-P4 (`esp32:esp32` 3.3.10, `ChipVariant=prev3`) and the desktop build and tests do not change. Nothing ran on a
board. This checklist is for an ESP32-P4-NANO on the LED controller board, with USB serial and a network.

Write the results into a section *Results* at the end of this file (board, firmware commit, what passed, the
serial log of anything that failed), or as a comment on the PR.

---

## What changed

| Where | Before | Now |
|---|---|---|
| `shz_defs.h` | `THREAD_LOCAL_STORAGE` empty on microcontrollers: one `shz_thread_local` for all tasks | `thread_local` on the ESP32: each task has its own (script binding, task name, pool flag, thread id) |
| `sys/shz_local.cpp` | thread id = `uxTaskGetTaskNumber()` = 0 for every task, so `shz_global_lock` never locked | thread id = the task handle: `SCRIPTAUTOLOCK` really locks |
| `internal/shz_task_context.cpp` | the `return_thread` worker ran `cb()` next to the script task (data race on the pools) | the worker holds the script lock around `cb()` |
| `shz_script.cpp` | `~shzscript()` did not wait for running workers | waits for them with the lock released |
| `shz_builtin_math.cpp`, `compiler/shz_ast.cpp` | | the 2.5 KB random generator and the compiler's dummy tokens stay plain statics on the ESP32 (the TLS segment is copied into every task stack) |
| `internal/shz_memory.h` | `MPSCQueue::wait_and_pop` with a `lock_guard` | `unique_lock` |
| `web_server.cpp` (firmware) | the web server task used the binding of the script task by accident | binds itself to the script, takes the lock in its handlers (as before, but it locks now) |
| `esp_shizoscriptV3.ino` (firmware) | `conman->update()` read `config` without the lock | with the lock |

What this means on the board:

- A fileio call now runs while the script task does not run script code. A long file operation (a big
  `write_string`, `files()` of a big folder) holds back the next `update()` until it is done. The script task feeds
  the task watchdog (5 s) only between two `update()` calls: a file operation that takes longer than about 5 s
  resets the board.
- The web server handlers really wait for the lock now (they ran in parallel with `update()` before).
- Each task's stack holds the TLS segment (see *TLS size* below). The idle and IPC tasks have 1 KB stacks.
- Each fileio call starts a task, which now has thread-local data with destructors (`shz_local()`). When the task
  ends, ESP-IDF runs those destructors from the idle task (pthread key destructors, called on task deletion), on
  its 1 KB stack minus the TLS segment. Watch for a stack overflow of `IDLE0` / `IDLE1` during the stress test.

## Before you start

1. Flash `main` (or #821's branch) first and note the boot log: the `Heap: ... PSRAM: ...` lines of the setup and
   of `loop()` (every 10 s) after 5 minutes of idle running. Then flash this branch and compare.
2. For the heap check, add this locally (do not commit) to the `while (true)` loop of `setupTask` in
   `esp_shizoscriptV3.ino`, right after `script->update();`:

   ```cpp
   static uint32_t integrity_counter = 0;
   if (++integrity_counter % 500 == 0 && !heap_caps_check_integrity_all(true))
       Serial.println("HEAP CORRUPTED");
   ```

## Checks

- [ ] **Boot.** The board boots to `---SETUP DONE---`, no `Guru Meditation`, no `stack overflow` (watch for the
      `IDLE`, `ipc0` / `ipc1` and `esp_timer` tasks: their stacks hold the TLS segment). The web UI opens.
- [ ] **Web UI.** Open every page (effects, LED setup, settings, file browser, update). Change an effect, a colour,
      a segment, save the settings. Pages load as fast as on `main`; nothing hangs.
- [ ] **Stress: fileio in one script task, allocations in another.** Upload this as `/stress.shio` (file browser)
      and start it from the code editor of the web UI (or `#include` it at the end of `web.shio` for the test):

      ```
      using std;

      stress_io()
      {
          pad = "";
          for(i = 0; i < 200; i++)
              pad += "0123456789";
          n = 0;
          for(1)
          {
              fileio.write_string("/stress.txt", "line " + n + "\n" + pad);
              s = fileio.read_string("/stress.txt");
              files = fileio.files("/");
              j = [a = n, b = s.size(), c = files.size()];
              fileio.write_json("/stress.json", j);
              k = fileio.read_json("/stress.json");
              if(k.a != n)
                  print("stress_io: wrong json ", k);
              n++;
              if(n % 100 == 0)
                  print("stress_io ", n);
          }
      }

      stress_alloc()
      {
          n = 0;
          for(1)
          {
              list = [];
              for(i = 0; i < 200; i++)
                  list.push_back("item " + i + " " + n);
              j = [name = "x" + n, items = list, nested = [a = 1, b = [c = "deep"]]];
              t = "" + j;
              if(t.size() == 0)
                  print("stress_alloc: empty");
              n++;
              if(n % 100 == 0)
                  print("stress_alloc ", n);
              std.sleep(1);
          }
      }

      t1 = std.thread(stress_io);
      t1.run();
      t2 = std.thread(stress_alloc);
      t2.run();
      ```

      (The same script with 300 rounds and local paths ran on the Linux `shz` of this branch.) Let it run
      **10 minutes** and use the web UI meanwhile.
      - [ ] both counters keep growing in the serial log, no `stress_io: wrong json`
      - [ ] no `HEAP CORRUPTED`, no `CORRUPT HEAP`, no `Guru Meditation`, no task watchdog reset, no stack overflow (`IDLE0` / `IDLE1`)
      - [ ] the `Heap:` line of `loop()` does not fall from minute to minute (each fileio call is a new task now, its
            thread-local data must be freed when the task ends)
      - [ ] the LEDs keep running (animation does not stutter more than on `main` with the same script)
- [ ] **Same stress on `main`** (for comparison, optional): the same script on `main` is expected to crash or to
      corrupt the heap sooner or later (the race of #444). Note how long it ran.
- [ ] **Long file operation.** Upload a file of about 1 MB with the file browser, then read it from a script
      (`s = fileio.read_string("/big.bin"); print(s.size());`). It works and the board is not reset by the watchdog.
      Note how long the read takes (if it is close to 5 s, the watchdog risk above is real for big files).
- [ ] **shizonet.** `_flash_files_over_network.shio` (upload_file) and an OTA update still work.
- [ ] **Art-Net mode** (if used): Art-Net input still drives the LEDs.

## TLS size

`readelf -S` of the `.elf`: `.flash.tdata` + `.flash.tbss` = the bytes each task stack gives up. #821's head:
4 + 144 = 148 bytes. This branch: 4 + 340 = 344 bytes (196 more per task). If a task overflows its stack at boot,
that is the first suspect.

## Results

(machine, firmware commit, what passed, what not)

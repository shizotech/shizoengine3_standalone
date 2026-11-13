---
timezone: Europe/Berlin
windows:
  tonight:
    start: "04:00"
    end: "10:00"
  morning:
    start: "06:00"
    end: "09:00"
  evening:
    start: "19:00"
    end: "23:00"
  weekend:
    start: "10:00"
    end: "18:00"
default_window: tonight
default_duration: 4h
---

# Scheduling preferences

* `timezone`: an IANA name (`Europe/Berlin`); every goal without its own `schedule.timezone`
  uses it. Daylight saving time is handled.
* `windows`: what words in a request mean. "Tonight, work on X" becomes a one-time goal in the
  `tonight` window (04:00-10:00 here). An explicit time in a request always wins ("from 05:00
  to 10:00").
* `default_window`: used when a request names no time at all.
* `default_duration`: length of a window that has a start but no end.

Change these values only when you mean it: agents read them, they never change them.

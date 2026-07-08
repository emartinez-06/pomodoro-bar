# PomodoroBar Specification

This document is the behavioral and architectural spec for PomodoroBar.
It describes what the app must do and how it is packaged, so that any change can be checked against an agreed contract.

## 1. Goal

Run Pomodoro cycles from the macOS menu bar with a glanceable countdown, a daily session record, and negligible resource cost.
The app must start at login and survive crashes without user intervention.

## 2. Pomodoro cycle

A run consists of a user-selected number of rounds (1 to 8, default 4, persisted).

| Phase | Duration | Next |
|---|---|---|
| Work | 25 min | Break, or idle after the final round |
| Short break | 5 min | Next work round |
| Long break | 15 min | Next work round |

Every 4th completed work round is followed by the long break instead of the short one.
The final work round of a run always ends the run, even when it falls on a multiple of 4.
A completed session is recorded when a work round finishes, never for partial work.

### Timekeeping

The engine is a pure state machine advanced by one `tick()` per second from a main-run-loop `Timer` scheduled in `.common` mode, so the countdown keeps running while the dropdown menu is open.
The timer exists only while a run is active and unpaused; idle and paused states schedule nothing.
Because time advances only by ticks, system sleep effectively pauses the countdown; this is intended behavior.

### Sounds

Phase transitions are announced by system sounds only, with no notification center involvement.

| Transition | Sound |
|---|---|
| Work finished, break starts | Glass |
| Break finished, work starts | Ping |
| Final work round finished, run complete | Hero |

## 3. UI contract

### Menu bar widget

- One `NSStatusItem` of variable length.
- A 16pt ring image: a faint gray full-circle track, with a colored arc that fills clockwise from 12 o'clock as the interval elapses.
- Arc color: `systemRed` during work, `systemGreen` during breaks, none when idle.
- While paused the arc dims to 40% opacity.
- Next to the ring, `MM:SS` remaining in the system monospaced-digit font; empty when idle.
- No emoji anywhere; all glyphs are drawn.
- The button tooltip mirrors the status line described below.

### Dropdown widget

Clicking the item opens an `NSMenu` containing:

1. A 240x104 `SessionsView`: "Today: N sessions", one filled red dot per completed session today (capped at 12 with a "+N" overflow), hollow dots for the pomodoros still pending in the active run, and a 7-day bar chart with weekday initials, today highlighted.
2. A disabled status row: `Idle`, `Work, round R of N`, `Short break`, or `Long break`, prefixed with `Paused:` when paused.
3. `Start` / `Pause` / `Resume` (one item, retitled by state, showing the Shift+Cmd+A shortcut) and `Reset` (enabled only during a run).
4. A `Rounds` submenu (1 to 8, checkmark on the persisted choice, applied at the next Start).
5. A `Green Focus Border` toggle (see section 4), disabled when JankyBorders is not installed.
6. A separator and `Quit PomodoroBar` (Cmd-Q).

The menu is the app's delegate and re-renders on `menuWillOpen`, which also handles day rollover for the session graphics.

### Global hotkey

Shift+Cmd+A triggers the Start / Pause / Resume action from anywhere, registered via Carbon `RegisterEventHotKey`, which requires no accessibility permissions.
If registration fails (for example the combination is claimed by another app), the app runs normally without a hotkey.

### App chrome

The app is menu-bar only: activation policy `.accessory` plus `LSUIElement` in Info.plist.
It must never appear in the Dock or the Cmd-Tab switcher.

## 4. Focus border (JankyBorders integration)

During an active, unpaused work interval, the focused window is outlined in green via [JankyBorders](https://github.com/FelixKratz/JankyBorders).
PomodoroBar owns the `borders` process outright: it spawns it (`active_color=0xffa6e3a1`, transparent inactive, width 6) when focus time starts and terminates it when focus time ends.
Nothing runs and nothing is drawn during breaks, pauses, idle, or after quit.

Rules:

- Silent no-op when the `borders` binary is not installed (`/opt/homebrew/bin` or `/usr/local/bin`).
- On launch the app kills any stray `borders` process, so a crash mid-session cannot leave a stale border; consequently no separately managed JankyBorders service should run alongside PomodoroBar.
- The `Green Focus Border` menu toggle (persisted, default on) disables the integration without uninstalling anything.

## 5. Persistence

`UserDefaults` (domain `com.eim.pomodoro-bar`) holds all state:

- `sessionsByDay`: `[String: Int]` keyed by local-time `yyyy-MM-dd`, pruned to 30 days on every write.
- `rounds`: selected rounds per run, clamped to 1 through 8.
- `focusBorderEnabled`: focus border toggle, default true.

There are no files, databases, or network calls.

## 6. Process lifecycle

The app runs as a per-user **LaunchAgent** (`com.eim.pomodoro-bar`), matching mempressure-bar:

- `RunAtLoad = true`: starts at every login.
- `KeepAlive = { SuccessfulExit = false }`: relaunched by launchd after a crash, but a clean quit from the menu sticks until next login.
- stderr is captured to `~/Library/Logs/pomodoro-bar.log`.

## 7. Packaging

- Built with Swift Package Manager (Swift 6 toolchain, language mode 5), macOS 13+; no Xcode project, no dependencies.
- `make install` assembles a minimal `PomodoroBar.app` bundle in `~/Applications` (binary + Info.plist), renders the LaunchAgent plist template with absolute paths, and bootstraps it via `launchctl bootstrap gui/$UID`.
- The Command Line Tools toolchain ships no test framework, so the binary embeds its own engine test suite behind `--selftest`; `make test` runs it and fails the build on any regression.
- `make dist` assembles the same minimal bundle under `dist/` and zips it; the bundle is unsigned/ad-hoc, and distribution builds are zipped app bundles attached to GitHub releases.

## 8. Source layout

| File | Responsibility |
|---|---|
| `Sources/PomodoroBar/main.swift` | NSApplication bootstrap, accessory activation policy, `--selftest` dispatch. |
| `Sources/PomodoroBar/AppDelegate.swift` | Status item, menu wiring, timer, sounds, render loop. |
| `Sources/PomodoroBar/PomodoroEngine.swift` | Pure Pomodoro state machine: phases, rounds, transitions. |
| `Sources/PomodoroBar/SessionStore.swift` | UserDefaults persistence: daily counts, preferences. |
| `Sources/PomodoroBar/StatusRingRenderer.swift` | Menu bar ring image rendering. |
| `Sources/PomodoroBar/SessionsView.swift` | Dropdown dots and 7-day chart view. |
| `Sources/PomodoroBar/BorderSignaler.swift` | JankyBorders child-process lifecycle. |
| `Sources/PomodoroBar/GlobalHotKey.swift` | Carbon global hotkey registration. |
| `Sources/PomodoroBar/EngineSelfTest.swift` | In-binary engine test suite. |
| `Resources/Info.plist` | Bundle identity, `LSUIElement`. |
| `Resources/com.eim.pomodoro-bar.plist` | LaunchAgent template (`__PROGRAM__`, `__LOG__` placeholders). |
| `Makefile` | build / test / install / uninstall / restart / logs / dist. |

## 9. Non-goals

- No configurable durations; 25/5/15 are compile-time constants in `PomodoroEngine.Config`.
- No notification center usage, idle detection, or calendar integration.
- No network access of any kind.
- No task lists, tags, or statistics beyond the daily session counts.

## 10. Verification checklist

1. `swift build -c release` completes with no warnings.
2. `make test` prints `OK: all engine self-tests passed`.
3. Running the binary shows the gray ring; Start turns it red with a live `MM:SS` countdown; the dropdown status row, dots, and chart match the state.
4. During a work interval the focused window gains a green border; the border disappears on pause, break, reset, run completion, and quit.
5. Phase transitions play Glass, Ping, and Hero at the documented moments.
6. Shift+Cmd+A starts, pauses, and resumes the run from any application.
7. After `make install`, `launchctl print gui/$UID/com.eim.pomodoro-bar` reports `state = running` and no Dock icon appears.
8. `kill -9` of the running process results in relaunch by launchd within seconds, with no stale green border left behind.
9. After logout/login, the item reappears and today's session count is preserved.

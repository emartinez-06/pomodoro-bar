# PomodoroBar

![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue)
![Swift](https://img.shields.io/badge/swift-6.0-orange)
![License](https://img.shields.io/badge/license-MIT-green)

A tiny, self-contained macOS menu bar Pomodoro timer.
Work 25 minutes, break 5, long break 15 after every 4th round, toward a daily goal of 10 sessions by default - all of it customizable from Settings in the menu bar dropdown.
A drawn progress ring and `MM:SS` countdown live in the menu bar; clicking it shows today's completed sessions as dots plus a 7-day history chart.
Shift+Cmd+A starts, pauses, and resumes the run from anywhere, no accessibility permissions required.

One Start covers the whole day: intervals roll from work to break to work on their own and the run stops itself once the daily goal is met, so the only button you touch is the first one.
Turn **Auto-Advance Cycles** off in Settings if you'd rather confirm each interval with Shift+Cmd+A.
Every local midnight the timer resets - any run still going is stopped and the new day starts from zero.

While a work interval is running, the focused window is outlined in green via a bundled copy of [JankyBorders](https://github.com/FelixKratz/JankyBorders), a visual "locked in" cue that pairs well with AeroSpace-style window gaps.
PomodoroBar builds JankyBorders from a pinned source release and ships the resulting binary inside `PomodoroBar.app`, so there is no separate install step and no dependency on whatever version happens to be on your system.
It runs a borders process of its own only while a run is active, so the border appears the instant work starts, vanishes instantly for breaks and pauses, and costs nothing while idle.
JankyBorders is a separate program under its own license; see [Third-party components](#third-party-components) below.

Sessions are announced by system sounds only (Glass at break time, Ping back to work, Hero when the run completes); there are no notifications, no network access, and no files beyond UserDefaults.

See [SPEC.md](SPEC.md) for the full behavioral and architectural specification.

## Widgets

**Menu bar ring and countdown** (red during work, green during breaks, dimmed when paused):

![Menu bar ring](assets/menubar-ring.png)

**Dropdown sessions view** (click the menu bar item):

![Dropdown sessions](assets/dropdown-sessions.png)

Filled dots are today's completed sessions, hollow dots are what's left of the daily goal, and the chart shows the last seven days with today highlighted.

**Settings** (menu bar dropdown > Settings…): launch at login, mute sounds, work/break/long-break durations, rounds before a long break, daily goal, auto-advance, and the focus border's on/off state and colors.

## Setup

### Option 1: install from a release (recommended)

1. Download `PomodoroBar.dmg` from the [latest release](../../releases/latest), open it, and drag `PomodoroBar.app` onto the `Applications` shortcut inside.
2. The app is unsigned, so the first launch needs one extra click: in Finder, right-click (or Control-click) `PomodoroBar.app` in Applications and choose **Open**, then confirm **Open** in the dialog.
   A plain double-click will refuse to open it the first time; this is the no-Terminal way around that.
   If that doesn't surface an Open option on your macOS version, clear the quarantine flag from Terminal instead:

   ```sh
   xattr -dr com.apple.quarantine ~/Applications/PomodoroBar.app
   ```

3. Turn on **Launch at Login** from the app's Settings (menu bar dropdown > Settings…) to have it start automatically.

### Option 2: build from source

Requires macOS 13+ and the Swift toolchain from Xcode Command Line Tools (`xcode-select --install`); no full Xcode needed.

```sh
git clone https://github.com/emartinez-06/pomodoro-bar.git
cd pomodoro-bar
make install
```

`make install` builds the release binary, builds the bundled `borders` binary from `third_party/janky-borders`, assembles `~/Applications/PomodoroBar.app`, and (re)launches it.
The focus border works out of the box; there is nothing else to install.
Turn on **Launch at Login** from the app's own Settings to have it start automatically - there's no separate LaunchAgent to install or manage.

### Make targets

```sh
make build      # compile only
make borders    # build the bundled JankyBorders binary from third_party/janky-borders
make test       # build + run the in-binary engine self-tests
make install    # build + install app bundle, (re)launch now
make restart    # rebuild and reinstall
make uninstall  # quit the app, remove the app bundle
make logs       # stream the running app's log output
make dist       # assemble PomodoroBar.app.zip and PomodoroBar.dmg for distribution
```

## License

[MIT](LICENSE) for PomodoroBar's own code.

### Third-party components

`PomodoroBar.app` bundles a `borders` binary built from [JankyBorders](https://github.com/FelixKratz/JankyBorders) by Felix Kratz, vendored at tag `v1.9.0` under `third_party/janky-borders`.
JankyBorders is licensed under GPL-3.0 ([full text](third_party/janky-borders/LICENSE)), separate from PomodoroBar's own MIT license.
PomodoroBar invokes it as a standalone subprocess rather than linking it, so the two remain separate programs; PomodoroBar's own source is unaffected and stays MIT.
See [third_party/janky-borders/NOTICE.md](third_party/janky-borders/NOTICE.md) for the exact vendored commit and further detail.

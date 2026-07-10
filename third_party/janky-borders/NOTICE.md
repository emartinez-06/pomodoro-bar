This directory contains the source of [JankyBorders](https://github.com/FelixKratz/JankyBorders) by Felix Kratz, vendored at:

- Tag: `v1.9.0`
- Commit: `a7297ca7d1933f3a30b12e8f10750e8d84eeee1e`

It is licensed under the GNU General Public License v3.0 (`LICENSE` in this directory), separate from and unrelated to PomodoroBar's own MIT license at the repository root.

PomodoroBar builds this source into a standalone `borders` executable and bundles that executable inside `PomodoroBar.app`, invoking it as a subprocess at runtime. PomodoroBar's own code is not linked against this source and is not a derivative work of it; the two remain separate programs communicating over process boundaries. See the root `README.md` for how this is used and licensed.

Vendoring the exact source, rather than downloading a prebuilt binary at install time, lets PomodoroBar build a known, reproducible copy from a pinned release instead of trusting an opaque binary fetched over the network.

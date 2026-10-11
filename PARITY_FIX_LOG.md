# Parity Fix Log

Rules:
- Start time and solution time are recorded for each problem.
- Switch problems if one exceeds 30 minutes.
- Add or update tests for each fix.

| Problem | Start | Solution | Status |
|---|---|---|---|
| Parity fix session started | 2026-10-11T20:29:00+02:00 | | in progress |
| Symlink entries missing `@` marker and using bright-white instead of white | 2026-10-11T20:30:33+02:00 | 2026-10-11T20:32:00+02:00 | fixed; `tests/mc_parity.sh` added |
| Dropdown bottom border drawn one row outside the window | 2026-10-11T20:32:15+02:00 | 2026-10-11T20:32:37+02:00 | fixed; `tests/mc_parity.sh` checks `└` |
| Free-space status used gigabytes too early | 2026-10-11T20:33:12+02:00 | 2026-10-11T20:33:29+02:00 | fixed; `tests/mc_parity.sh` checks `M / G` |
| Selected menu bar item missing black leading/trailing spaces; path highlight remained active under an open dropdown | 2026-10-11T20:34:55+02:00 | 2026-10-11T20:35:33+02:00 | fixed; `tests/mc_parity.sh` checks black leading space |
| Panel selection/path highlight stayed active under an open dropdown; dropdown shadow missing | 2026-10-11T20:35:33+02:00 | 2026-10-11T20:41:37+02:00 | fixed; `menu_left` probe step now identical |
| Panel selection/path highlight stayed active while the menu bar was open without a dropdown | 2026-10-11T20:44:30+02:00 | 2026-10-11T20:45:35+02:00 | fixed; `menu_f9` probe step now identical |
| Options dropdown was too narrow when no shortcuts were present | 2026-10-11T20:46:10+02:00 | 2026-10-11T20:46:42+02:00 | fixed; `menu_options` probe step now identical |
| Command dropdown hotkey highlights used the first matching letter instead of MC’s hotkey position | 2026-10-11T20:46:42+02:00 | 2026-10-11T20:47:42+02:00 | fixed; `menu_command` probe step now identical |
| Esc did not close dropdowns in probe captures | 2026-10-11T20:47:42+02:00 | 2026-10-11T20:50:37+02:00 | fixed; clone `ESCDELAY` lowered and probe now sends real `Escape` with enough wait |
| Probe reruns were slow because real `mc` restarted for every step | 2026-10-11T20:50:37+02:00 | 2026-10-11T21:17:46+02:00 | fixed; real `mc` captures are cached per step and clone waits use the test seq file |
| Navigation/selection/dialog parity batch: Left/Right no-op, Space ignored, Insert selection, `*` file-only selection, selected-entry colors, `+` Select dialog shadow, dynamic hints | 2026-10-11T21:17:46+02:00 | 2026-10-11T23:21:25+02:00 | fixed; targeted probe steps identical and `tests/mc_parity.sh` extended |
| Full suite regression: command-line spaces were swallowed and `mc_actions.sh` Select group used the old empty-pattern behavior | 2026-10-11T23:21:25+02:00 | 2026-10-11T23:28:33+02:00 | fixed; Space inserts only when a command line is active, and `tests/mc_actions.sh` types `*` for Select group |
| Viewer right-edge cyan block when viewing short multibyte lines (seen in `b.sh`) | 2026-10-11T23:30:00+02:00 | 2026-10-12T00:00:32+02:00 | fixed; viewer erases with content color and pads short lines with `mvwhline`; `tests/mc_view.sh` checks SGR content lines |

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
| Viewer scrolling is slow because every scroll full-redraws the viewer | 2026-10-12T00:22:26+02:00 | 2026-10-12T00:30:44+02:00 | fixed; added `scrollok`/`wsetscrreg`/`wscrl` and safe DECSTBM optimization; viewer redraws only newly exposed rows; `tests/unit.sh` and `tests/mc_view.sh` extended |
| Main panel scrolling is slow in large directories; Up at start appears to busy-loop | 2026-10-12T00:40:09+02:00 | 2026-10-12T01:31:04+02:00 | fixed; cached free-space status, faster `list_dir`, drained no-op navigation, and fork-free line fills; `tests/unit.sh` and `tests/mc_nav.sh` extended |
| Mouse input was ignored: panel clicks, double-click open, menu clicks, and button-bar clicks did not match original `mc` | 2026-10-12T02:48:31+02:00 | 2026-10-12T03:17:54+02:00 | fixed; enabled `mousemask`, added panel/menu/button mouse handling and `tests/mc_mouse.sh` |
| Dialogs ignored mouse clicks on buttons, checkboxes, fields, and list items | 2026-10-12T03:17:54+02:00 | 2026-10-12T03:25:35+02:00 | fixed; added dialog hit-test helpers and mouse handling for common dialogs; extended `tests/mc_mouse.sh` |
| Viewer ignored mouse wheel scrolling and button-bar clicks | 2026-10-12T03:25:35+02:00 | 2026-10-12T03:33:40+02:00 | fixed; added viewer wheel/button mouse handling and `tests/mc_mouse.sh` wheel/Quit assertions |
| Command line ignored mouse clicks and always appended at the end | 2026-10-12T03:33:40+02:00 | 2026-10-12T03:42:17+02:00 | fixed; added `CMD_CARET`, command-line click hit-testing, and caret-aware editing; extended `tests/mc_mouse.sh` |
| Mouse parity gaps: help/user-menu clicks, command-line caret keys, and panel drag selection | 2026-10-12T03:56:10+02:00 | 2026-10-12T04:00:22+02:00 | fixed; enabled `REPORT_MOUSE_POSITION`, added drag state, user-menu click handling, Left/Right command-line caret movement, and `tests/mc_mouse.sh` assertions |
| `halfdelay` was a no-op and did not make `wgetch` time out | 2026-10-12T04:38:00+02:00 | 2026-10-12T04:40:53+02:00 | fixed; `halfdelay` sets window timeouts and new windows inherit them; `tests/unit.sh` extended |
| Initial free-space status used floor division (`24G`) while real `mc` rounds (`25G`) | 2026-10-14T23:52:00+02:00 | 2026-10-15T00:02:00+02:00 | fixed; `hum` rounds G/M values; `tests/unit.sh` extended; `initial` probe step identical |
| `open_alpha` differed only in the randomly selected `mc` hint line | 2026-10-15T00:10:00+02:00 | 2026-10-15T02:54:35+02:00 | fixed; probe disables `mc` hintbar via `message_visible=false`, clone honors `MC_HINTBAR=0`, and layout grows panels by one row; `tests/unit.sh` extended; `initial` and `open_alpha` probe steps identical |
| Viewer status showed `4/5 80%` when the whole file fits | 2026-10-15T03:00:00+02:00 | 2026-10-15T03:10:00+02:00 | fixed; `view_title` clamps to total/total and 100% when `V_MAXOFF == 0`; `tests/unit.sh` extended |
| `ungetch` lost function keys pushed back by `drain_panel_nav` | 2026-10-15T03:10:00+02:00 | 2026-10-15T03:35:00+02:00 | fixed; added `BC_PENDING_KEY` and numeric function-key pushback in `lib/bc.sh`; `tests/unit.sh` extended |
| Viewer title offset/percent columns were four columns too far right | 2026-10-15T03:10:00+02:00 | 2026-10-15T03:35:00+02:00 | fixed; viewer title reserves a 21-column percent field; `f3_view_a` plain capture matches |
| Probe sent clone function keys too quickly after navigation redraws | 2026-10-15T03:10:00+02:00 | 2026-10-15T03:45:00+02:00 | fixed; clone key steps now always wait for seq and sleep 0.1s; `f3_view_a` probe step identical |
| Full suite took about 7 minutes because tests ran sequentially | 2026-10-15T03:45:00+02:00 | 2026-10-15T03:51:58+02:00 | fixed; `tests/run.sh` runs test scripts in parallel with logs under `tmp/logs`, and `tests/examples.sh` runs examples in parallel; default full suite completes in about 1 minute |
| Copy/Move dialog input fields drew a `[^]` completer button that real `mc` does not show | 2026-10-15T03:52:00+02:00 | 2026-10-15T03:56:47+02:00 | fixed; `dlg_field` now draws the button only when requested, Select keeps it, Copy/Move omit it; `tests/unit.sh` extended; `f5_copy_a` and `f6_move_a` probe steps identical |
| Probe captures still differed only because free-space `G` values changed between runs | 2026-10-15T03:52:00+02:00 | 2026-10-15T03:56:47+02:00 | fixed; probe normalizes `[MG] / ` digit runs and cache metadata includes `CAP_VER=2` |
| `f7_mkdir` left the other panel stale and did not select the new directory | 2026-10-15T03:57:00+02:00 | 2026-10-15T04:01:00+02:00 | fixed; `do_mkdir` uses `refresh_panel_keep` to refresh the same-directory other panel and select the new entry; `f7_mkdir` probe step identical |
| `f8_delete_a` left the other panel stale, kept `@` for broken symlinks, and selected the wrong entry after delete | 2026-10-15T03:57:00+02:00 | 2026-10-15T04:15:48+02:00 | fixed; broken symlinks now use `!` and bright-red-on-blue pair 35, `do_delete` refreshes the same-directory other panel and moves to the next entry, and the `pos`/`next` assignment was split to avoid using `pos` before it was set; `f8_delete_a` probe step identical |

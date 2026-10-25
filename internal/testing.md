# Testing

Run the full suite:

```sh
bash tests/run.sh
```

`tests/run.sh` runs the suite in parallel and writes logs under `tmp/logs/`.
The job count is controlled by `BC_TEST_JOBS`, capped at 4 by default.

## Full-suite groups

- `tests/unit.sh` — headless core checks: key-table lookup, SGR/X10 mouse
  decode, mask expansion, click/double/triple merge runs, and `KEY_*`/mouse
  constants against the installed ncurses header.
- `tests/unit_screen.sh` — headless screen checks: SGR capture parser,
  per-cell grid model, and raw cursor tracker.
- `tests/unit_layout.sh` — headless layout checks: template parsing and
  errors, track sizing, window binding/rebuilds, floats, and the event loop
  with a fake key source.
- `tests/unit_widgets.sh` — headless widget checks: lists, partial redraw,
  selection hooks, clamping, menubar, and dialog widgets.
- `tests/unit_dialog.sh` — headless dialog checks: text prep/wrapping and
  button sizing.
- `tests/unit_builder.sh` — headless builder checks: split, delete/collapse,
  rename, styles, tags, floats, serialise round-trip, undo/redo, and export.
- `tests/unit_bundle.sh` — headless bundle/unbundle checks.
- `tests/unit_mc_swap.sh` — headless regression check for `apps/mc.sh`
  panel swapping.
- `tests/integration.sh` — tmux-driven key and mouse battery.
- `tests/examples_c.sh` — builds and checks the C reference binaries for the
  numbered examples.
- `tests/examples.sh` — tmux-driven smoke tests for `examples/*.sh`, feeding
  keys and raw SGR mouse bytes and requiring clean exits.
- `tests/mc_nav.sh`, `tests/mc_menu.sh`, `tests/mc_view.sh`,
  `tests/mc_resize.sh`, `tests/mc_dialog.sh`, `tests/mc_actions.sh`,
  `tests/mc_parity.sh`, and `tests/mc_mouse.sh` — tmux-driven regression
  tests for the `mc` clone.
- `tests/mc_layout.sh` — runs the `mc` regression suite against
  `apps/mc-layout.sh`; known diffs are listed in `tests/mc_layout.xfail`.
- `tests/layout_demo.sh` and `tests/layout_shining.sh` — tmux-driven layout
  tests for `examples/90-layout.sh` and `apps/shining-layout.sh`, including
  dialogs, shadows, clicks, and resizes.
- `tests/mouse_click.sh` — tmux-driven mouse click behavior.
- `tests/bundle_run.sh` — runs a bundled app.
- `tests/dialog_app.sh` — optional tmux-driven external dialog-app test;
  skipped when the external app is absent.
- `tests/builder.sh` — tmux-driven builder UI test: saves a project and
  exports a runnable app.
- `tests/dtail.sh` — tmux-driven `dtail` app test.

## Parity and discovery tools

These are not part of `tests/run.sh`:

- `tests/example_parity.sh` — compares bash examples against C reference
  binaries using `tests/example_compare.sh`.
- `tests/example_compare.sh` — screen/SGR comparison helper.
- `tests/example_side.sh` — side-by-side capture helper.
- `tests/parity_probe.sh` — raw parity probe; writes findings under `tmp/`.
- `tests/visual_diff.sh` — visual diff helper; writes anomalies under `tmp/`.
- `tests/bench_layout.sh` — layout benchmark, not a pass/fail gate.

## Notes

- Interactive tests need a real tty and use `tmux`.
- tmux panes inherit the host default `TERM=screen-256color`. Tests that
  inject xterm key sequences or compare rendered frames should set
  `TERM=xterm-256color` in the app.
- Current accepted example parity differences are listed in
  `example-deviations.md`.

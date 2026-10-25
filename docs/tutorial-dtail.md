# Tutorial: building `dtail`

This tutorial builds the app that ships as:

- `apps/dtail.bcl` — the saved `bcbuild` layout
- `apps/dtail.sh` — the finished dual-tail app

The app runs two commands and shows each command's output in its own bordered
window. The command itself is printed in that window's top border.

```sh
apps/dtail.sh 'tail -f /var/log/syslog' 'journalctl -f'
```

The point is not just the finished app, but the pattern:

1. design the layout with `bcbuild`;
2. export or hand-write the layout calls;
3. fill in the `draw_...` functions;
4. add an event loop that polls external output;
5. clean up child processes when the app exits.

## 1. Design the layout

Start with the layout builder:

```sh
tools/bcbuild.sh
```

You want two stacked panes:

```text
┌ command 1 ─────────────────────────────┐
│ output for command 1                   │
│                                        │
└────────────────────────────────────────┘
┌ command 2 ─────────────────────────────┐
│ output for command 2                   │
│                                        │
└────────────────────────────────────────┘
```

In the builder:

1. select `main`;
2. press `Split-V` to split the screen into two rows;
3. rename the two leaves `top` and `bot`;
4. turn on `border` for both;
5. turn on `tleft` so the title is left-aligned;
6. give the content and border colours, for example `pair=1` and `bpair=2`;
7. save the project as `apps/dtail.bcl`.

The saved project is plain replayable layout code:

```bash
# bcbuild layout
bc_screen "
  top
  bot
" rows="* *" cols="*" gap=0 border=0
bc_style top border tleft pair=1 bpair=2
bc_style bot border tleft pair=1 bpair=2
BB_SEL_X="top"
```

You can also open that file directly:

```sh
tools/bcbuild.sh apps/dtail.bcl
```

If you want side-by-side panes instead, use one row and two columns:

```bash
bc_screen "top bot" rows="*" cols="* *" gap=0 border=0
```

## 2. Export a runnable skeleton

From the builder, export an app skeleton. The exported file contains the layout
calls and a stub for each leaf:

```bash
source "${BC_LIB_DIR:-../lib}/layout.sh"

init_pair 1 7 0
init_pair 2 6 0

bc_screen "
  top
  bot
" rows="* *" cols="*" gap=0 border=0
bc_style top border tleft pair=1 bpair=2
bc_style bot border tleft pair=1 bpair=2

draw_top() { bc_print top 0 0 "top"; }
draw_bot() { bc_print bot 0 0 "bot"; }

bc_init mouse
bc_run
```

For `dtail`, change the last two lines:

```bash
bc_init
bc_run fps=10
```

`fps=10` matters: without it, `on_tick` is not called, and the app would not
poll the commands' output.

## 3. Accept two commands

The finished app starts like this:

```bash
#!/usr/bin/env bash
source "${BASH_SOURCE[0]%/*}/../lib/layout.sh"

usage() {
  printf 'usage: %s "command" "command"\n' "${0##*/}" >&2
  exit 2
}

(( $# == 2 )) || usage
[[ -n $1 && -n $2 ]] || usage

declare -A CMD=([top]="$1" [bot]="$2")
```

The two panes are named `top` and `bot`, so the commands are stored under those
same names.

## 4. Keep state for each pane

Each pane needs:

- the command being run;
- a file descriptor to read its output;
- the child PID for cleanup;
- a scrollback buffer;
- a partial-line buffer;
- an "exited" flag.

```bash
declare -A FD=() PID=() DONE=() PART=()
declare -a LINES_top=() LINES_bot=()

MAX_LINES=2000
TRIM_LINES=1000
```

`LINES_top` and `LINES_bot` are the visible scrollback. The app trims old lines
so a long-running tail does not grow memory forever.

## 5. Create the layout and set dynamic titles

The exported layout is static, but the border title should show the command.
Set the title after the command-line arguments are known:

```bash
bc_init || exit 1

if has_colors; then
  init_pair 1 7 0
  init_pair 2 6 0
fi

bc_screen "
  top
  bot
" rows="* *" cols="*" gap=0 border=0 || exit 1

bc_style top border tleft pair=1 bpair=2 title="${CMD[top]}" || exit 1
bc_style bot border tleft pair=1 bpair=2 title="${CMD[bot]}" || exit 1
```

The layout layer draws the border and title for you. The app only draws the
inside of each pane.

## 6. Start the commands

Use process substitution so each command has its own readable file descriptor:

```bash
for a in top bot; do
  exec {FD[$a]}< <(eval "${CMD[$a]}" 2>&1)
  PID[$a]=$!
done
```

`2>&1` merges stderr into stdout, so errors from the command appear in its pane.

The app should clean up when it exits:

```bash
cleanup() {
  local a
  for a in top bot; do
    if [[ -n ${PID[$a]:-} ]]; then
      kill "${PID[$a]}" 2>/dev/null
    fi
    if [[ -n ${FD[$a]:-} ]]; then
      exec {FD[$a]}<&-
    fi
  done
  endwin
}

trap cleanup EXIT INT TERM
```

## 7. Poll output without blocking

The event loop must not block waiting for a line. The pattern is:

```bash
read -u "$fd" -t 0
```

This checks whether input is available without consuming it. Then read the line
with a short timeout:

```bash
read -u "$fd" -t 0.05 line
```

If the timeout expires, the command may have written a partial line. Keep that
partial text in `PART[$side]` and prepend it to the next line.

```bash
poll_side() { # side -> 0 if the pane changed
  local a=$1 fd=${FD[$a]} line part=${PART[$a]} rc dirty=0 n=0
  [[ -n ${DONE[$a]:-} ]] && return 1

  while (( n < 100 )); do
    if ! read -u "$fd" -t 0; then
      break
    fi

    if read -u "$fd" -t 0.05 line; then
      add_line "$a" "$part$line"
      part=""
      dirty=1
      n=$(( n + 1 ))
    else
      rc=$?
      if (( rc > 128 )); then
        if [[ -n $line ]]; then
          part+="$line"
          dirty=1
        fi
        break
      fi

      if [[ -n $part ]]; then
        add_line "$a" "$part"
        part=""
        dirty=1
      fi
      DONE[$a]=1
      add_line "$a" "[exited]"
      dirty=1
      break
    fi
  done

  PART[$a]=$part
  (( dirty ))
}
```

The loop limit, `n < 100`, prevents one very chatty command from starving the
other pane.

`add_line` normalizes the line and trims old scrollback:

```bash
add_line() { # side line
  local -n buf=LINES_$1
  local line=$2
  line=${line%$'\r'}
  line=${line//$'\t'/    }
  line=${line:0:4096}
  buf+=("$line")
  if (( ${#buf[@]} > MAX_LINES )); then
    buf=("${buf[@]:TRIM_LINES}")
  fi
}
```

## 8. Draw the panes

The layout layer calls `draw_top` and `draw_bot` when those areas are dirty.
Use `bc_size` to get the current inside size of the area, then print the newest
lines bottom-aligned:

```bash
draw_pane() { # side
  local a=$1
  local -n buf=LINES_$a
  bc_size "$a"
  local n=${#buf[@]} start=0 i y

  if (( n > BCL_H )); then
    start=$(( n - BCL_H ))
  fi

  for (( i = start; i < n && i < start + BCL_H; i++ )); do
    y=$(( i - start ))
    bc_print "$a" "$y" 0 "${buf[i]}" pair=1
  done
}

draw_top() { draw_pane top; }
draw_bot() { draw_pane bot; }
```

`bc_print` clips to the pane, so long lines do not spill into the other pane.

## 9. Drive the app from `on_tick` and `on_key`

Poll both panes every tick:

```bash
on_tick() {
  local a
  for a in top bot; do
    poll_side "$a" && bc_dirty "$a"
  done
}
```

Quit on `q`:

```bash
on_key() {
  case $1 in
    q|Q) bc_quit ;;
  esac
}
```

Finally, mark both panes dirty and start the loop:

```bash
bc_dirty top bot
bc_run fps=10
```

## 10. Test it

The finished app has a tmux-driven test:

```sh
bash tests/dtail.sh
```

The test uses harmless commands instead of real system logs:

```bash
CMD1='seq 1 3 | sed "s/^/top /"'
CMD2='seq 1 3 | sed "s/^/bot /"'
```

It checks that:

- the top pane shows `top 1`;
- the bottom pane shows `bot 1`;
- exited commands show `[exited]`;
- the command appears in the border;
- `q` exits cleanly;
- stderr is empty.

## What to change next

The same pattern can be reused for other two-output apps:

- swap `top`/`bot` for `left`/`right` and use `cols="* *"`;
- add a third pane by adding another row or column;
- add a status bar with a fixed-height row;
- add scrolling keys by keeping a per-pane scroll offset;
- add colour filtering by storing attributes with each line.

The important layout-layer idea is that the app draws by area name:

```bash
bc_print top 0 0 "hello"
```

It does not need to know where `top` is on the screen. The layout engine handles
resizing, borders, clipping, and redraws.

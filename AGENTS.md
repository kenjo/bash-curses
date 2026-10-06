# AGENTS.md

## What this repo is
This is a reimplentation of something like ncurses but in bash.

## Host tools for testing
`tmux` is installed on the host. Use it to run and test interactive terminal
apps (the examples, or reference TUIs like `mc`), which need a real tty:

- start:   `tmux new-session -d -s t -x 100 -y 30 ./examples/newdemo.sh`
- see:     `tmux capture-pane -t t -p` — rendered screen as text
- drive:   `tmux send-keys -t t Down Enter q`
- cleanup: `tmux kill-session -t t`

Verified working with Midnight Commander (`mc`) on this host.

### CRITICAL: never `tmux kill-server`
This agent runs INSIDE a tmux session. `tmux kill-server` (and any command
that tears down the whole server) kills the agent's own session and breaks the
run. ALWAYS:

- create your own uniquely-named session: `tmux new-session -d -s <name> ...`
- only ever destroy that session: `tmux kill-session -t <name>`
- NEVER run `tmux kill-server`, `tmux kill-session` on a session you did not
  create, or any global server teardown.
- pick a session name unlikely to collide (e.g. `bc-<task>`), and clean up
  only your own session when done.

## Temporary files
 - /tmp is not to be used. Use tmp in workspace insterad.
 
## git
 commit often and use good descriptions.
 
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

## Temporary files
 - /tmp is not to be used. Use tmp in workspace insterad.
 
## git
 commit often and use good descriptions.
 
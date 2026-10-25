# AGENTS.md

## What this repo is
This is a reimplementation/reimagination of ncurses in bash.

## Testing
- Run `bash tests/run.sh` after changes.
- Interactive apps and integration tests need a real tty; use `tmux`.
- Create your own uniquely-named tmux session, and kill only that session.
- Never run `tmux kill-server` or kill sessions you did not create.
- Do not forget the previous rule.

## Docs
User-facing docs live in `docs/`. Internal/contributor notes live in
`internal/`. Finished showcase apps live in `apps/`; small API demos live in
`examples/`.

## Temporary files
Use `tmp/` in the workspace, not `/tmp`. Generated discovery logs belong under
`tmp/`.

## Git
Commit often and use good descriptions.

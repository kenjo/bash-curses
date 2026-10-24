# Distributing your app as one file

Your app sources the library, so by default it needs the `lib/` directory next
to it. To ship a single self-contained script instead, bundle the libraries
into it. The `lib/bc.sh` file doubles as the bundling tool: run it directly
instead of sourcing it.

```sh
bash /path/to/bash_curses/lib/bc.sh bundle myapp.sh -o myapp
```

`myapp` is one executable script: your code with the library pasted in. Copy
it anywhere (any machine with bash >= 4.3, `stty` and `tput`) and run it:

```sh
bash myapp
```

Which libraries get embedded follows from what your script sources:

| Your script sources | Embedded |
|---|---|
| `lib/bc.sh` | `bc.sh` |
| `lib/layout.sh` | `bc.sh`, `layout.sh` |
| `lib/widgets.sh` | `bc.sh`, `layout.sh`, `widgets.sh` |

The libraries are copied verbatim (comments and all), so the bundle is
readable and debuggable. A bundle of a core-layer app is about 5300 lines;
with all three layers, about 7500.

## Splitting a bundle back apart

A bundle is reversible. To get the script and the library files back:

```sh
bash /path/to/bash_curses/lib/bc.sh unbundle myapp -o outdir/
```

`outdir/` then contains `myapp` (the script, with its `source` line restored
to load the libraries from its own directory) plus `bc.sh`, and `layout.sh`
/ `widgets.sh` if they were embedded. The extracted library files are
byte-identical to the originals, and the script is identical to the one you
bundled except for that one `source` line.

## How it works

The embedded libraries sit between marker comments:

```bash
# >>> bc-bundle begin v1 src: source "${BASH_SOURCE[0]%/*}/../lib/layout.sh"
BC_BUNDLED=1
# >>> bc-bundle lib bc.sh
…bc.sh, verbatim…
# <<< bc-bundle lib bc.sh
# >>> bc-bundle lib layout.sh
…layout.sh, verbatim…
# <<< bc-bundle lib layout.sh
# <<< bc-bundle end
```

- The `src:` part of the begin marker records your original `source` line,
  which is what `unbundle` restores (rewritten to the script's own directory).
- `BC_BUNDLED=1` tells the embedded copy of `bc.sh` that it is inside a
  bundle, so it never runs the bundling CLI when the app starts.
- The libraries' own load guards (`BC_LOADED`, `BCL_LOADED`, `BCW_LOADED`)
  make their internal `source` lines no-ops inside a bundle.

## Limits

- The script must source exactly one of the three libraries, on one line,
  with the path ending in `bc.sh`, `layout.sh` or `widgets.sh`.
- Only the libraries are bundled. If your app is split across several of its
  own files, you still need to ship those (or merge them yourself first).
- Bundling an already-bundled file is refused; run `unbundle` first.

## Tests

`tests/unit_bundle.sh` (headless) checks the round-trip for all three layer
combinations and the error cases; `tests/bundle_run.sh` (tmux) runs a bundled
app with no `lib/` present and an unbundled app with the libraries beside it.

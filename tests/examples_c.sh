#!/bin/bash
# Build and smoke-check the C reference binaries for the numbered examples.
REPO="$(cd "$(dirname "$0")/.." && pwd)"

if ! make -C "$REPO/examples" -B > "$REPO/tmp/examples_c_build.log" 2>&1; then
  printf 'examples_c: build failed (see tmp/examples_c_build.log)\n'
  tail -40 "$REPO/tmp/examples_c_build.log"
  exit 1
fi

missing=0
for c in "$REPO"/examples/[0-9]*.c; do
  base=${c##*/}
  base=${base%.c}
  if [[ ! -x "$REPO/examples/$base" ]]; then
    printf 'missing executable: examples/%s\n' "$base"
    missing=$((missing + 1))
  fi
done

if (( missing )); then
  printf 'examples_c: %d missing binaries\n' "$missing"
  exit 1
fi

printf 'examples_c: ok\n'

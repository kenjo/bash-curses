# cursor.awk -- track the cursor through a raw PTY byte stream and print the final
# "row col" (1-based) position. Input is hex bytes from `od -An -tx1` (any number
# per line). Handles: CUP (H/f/SP), CUU/CUD/CUF/CUB, CHA (G), CR, LF, autowrap,
# and skips OSC/DCS/other escape sequences. Run under LC_ALL=C so each token is a
# single byte. Pass W (columns) and H (rows) with -v.
function hex2dec(s,    i, d, c) {
  d = 0
  for (i = 1; i <= length(s); i++) {
    c = substr(s, i, 1)
    d = d * 16 + index("0123456789abcdef", tolower(c)) - 1
  }
  return d
}
function clamp() {
  if (row < 1) row = 1
  if (row > H) row = H
  if (col < 1) col = 1
  if (col > W) col = W
}
function advcol() {
  col++
  if (col > W) { col = 1; row++ }
  clamp()
}
function handle_csi(params, final,    P, r, c, v) {
  split(params, P, ";")
  r = (P[1] == "" ? 1 : P[1] + 0)
  c = (P[2] == "" ? 1 : P[2] + 0)
  v = (P[1] == "" ? 1 : P[1] + 0)
  if      (final == 72 || final == 102 || final == 96) { row = r; col = c }  # CUP: H, f, SP
  else if (final == 65) { row -= v }   # CUU A
  else if (final == 66) { row += v }   # CUD B
  else if (final == 67) { col += v }   # CUF C
  else if (final == 68) { col -= v }   # CUB D
  else if (final == 71) { col = r }    # CHA G (absolute column)
  clamp()
}
BEGIN { row = 1; col = 1; esc = 0; csi = ""; in_osc = 0; in_dcs = 0; st_p = 0 }
{
  for (i = 1; i <= NF; i++) {
    b = hex2dec($i)
    # --- inside OSC (ESC ] ... BEL | ST) or DCS (ESC P ... ST) ---
    if (in_osc || in_dcs) {
      if (b == 27) { st_p = 1; continue }
      if (st_p) {
        st_p = 0
        if (b == 92) { in_osc = 0; in_dcs = 0; continue }   # ST (ESC \) complete
        in_osc = 0; in_dcs = 0; esc = 1; continue            # ESC began a new sequence
      }
      if (in_osc && b == 7) { in_osc = 0; continue }         # OSC ... BEL
      continue
    }
    # --- escape sequence in progress ---
    if (esc == 1) {                    # saw ESC, expecting the dispatch byte
      esc = 0
      if      (b == 91) { esc = 2; csi = "" }   # CSI
      else if (b == 93) { in_osc = 1 }          # OSC
      else if (b == 80) { in_dcs = 1 }          # DCS
      else if (b == 77) { row--; col = 1; clamp() }  # ESC M = RI (reverse index)
      continue
    }
    if (esc == 2) {                    # accumulating CSI
      if      (b >= 48 && b <= 57) { csi = csi (b - 48); continue }   # digit
      else if (b == 59)            { csi = csi ";"; continue } # semicolon
      else if (b == 44)            { csi = csi ","; continue } # comma
      else if (b >= 64 && b <= 126) { handle_csi(csi, b); csi = ""; esc = 0; continue }
      continue                        # intermediate byte: ignore
    }
    # --- normal byte ---
    if (b == 27)     { esc = 1; continue }
    if (b == 13)     { col = 1; continue }                    # CR
    if (b == 10)     { row++; col = 1; clamp(); continue }    # LF
    if (b >= 32 && b <= 126) { advcol(); continue }           # printable ASCII
    if (b >= 192)    { advcol(); continue }                  # UTF-8 lead byte (width 1 here)
    # continuation bytes (0x80-0xBF) and other controls: no cursor movement
  }
}
END { print row, col }

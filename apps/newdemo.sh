# Port of references/ncurses/test/newdemo.c — colour demo with a 48x14
# window: random characters, three overlapping subwindows, the Australian
# map, a scrolling message line, and bouncing balls.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

# ------------------------------------------------------------- helpers
set_colors() { # win pair fg bg
  local w=$1 pair=$2
  if has_colors; then
    if (( pair > BC_PAIRS )); then pair=$BC_PAIRS; fi
    init_pair "$pair" "$3" "$4"
    wattrset "$w" 0 "$pair"
  fi
}

use_colors() { # win pair attrs
  local w=$1 pair=$2 attrs=$3
  if has_colors; then
    if (( pair > BC_PAIRS )); then pair=$BC_PAIRS; fi
    wattrset "$w" "$attrs" "$pair"
  else
    wattrset "$w" "$attrs" 0
  fi
}

wait_for_user() { # win -> 1 on q/Q, 0 otherwise (5 second timeout)
  local win=$1
  nodelay "$win" 1
  local start=$EPOCHSECONDS
  while :; do
    if wgetch "$win"; then
      if [[ $key == q || $key == Q ]]; then
        return 1
      fi
      return 0
    fi
    if (( EPOCHSECONDS - start > 5 )); then
      return 0
    fi
  done
}

subwin_test() { # win
  local win=$1
  getmaxyx "$win"
  local h=$BC_GMY w=$BC_GMX
  getbegyx "$win"
  local by=$BC_GBY bx=$BC_GBX
  local sw=$(( w / 3 )) sh=$(( h / 3 ))
  local swin1 swin2 swin3
  if ! subwin "$win" "$sh" "$sw" $(( by + 3 )) $(( bx + 5 )); then
    return 1
  fi
  swin1=$bc_win
  if ! subwin "$win" "$sh" "$sw" $(( by + 4 )) $(( bx + 8 )); then
    delwin "$swin1"
    return 1
  fi
  swin2=$bc_win
  if ! subwin "$win" "$sh" "$sw" $(( by + 5 )) $(( bx + 11 )); then
    delwin "$swin1"
    delwin "$swin2"
    return 1
  fi
  swin3=$bc_win

  set_colors "$swin1" 8 "$COLOR_RED" "$COLOR_BLUE"
  werase "$swin1"
  mvwaddstr "$swin1" 0 3 "Sub-window 1"
  wrefresh "$swin1"

  set_colors "$swin2" 9 "$COLOR_CYAN" "$COLOR_MAGENTA"
  werase "$swin2"
  mvwaddstr "$swin2" 0 3 "Sub-window 2"
  wrefresh "$swin2"

  set_colors "$swin3" 10 "$COLOR_YELLOW" "$COLOR_GREEN"
  werase "$swin3"
  mvwaddstr "$swin3" 0 3 "Sub-window 3"
  wrefresh "$swin3"

  delwin "$swin1"
  delwin "$swin2"
  delwin "$swin3"
  wait_for_user "$win"
  return 0
}

_bounce() { # n dir len -> BC_BN BC_BD  (dir is 0 or 1, as in the C source)
  local n=$1 dir=$2 len=$3
  if (( dir > 0 )); then
    n=$(( n + 1 ))
  else
    n=$(( n - 1 ))
  fi
  if (( n <= 1 || n >= len - 2 )); then
    if (( dir )); then dir=0; else dir=1; fi
  fi
  BC_BN=$n
  BC_BD=$dir
}

bouncing_balls() { # win
  local win=$1
  getmaxyx "$win"
  local h=$BC_GMY w=$BC_GMX
  local x1=$(( 2 + RANDOM % (w - 4) )) y1=$(( 2 + RANDOM % (h - 4) ))
  local x2=$(( 2 + RANDOM % (w - 4) )) y2=$(( 2 + RANDOM % (h - 4) ))
  local x3=$(( 2 + RANDOM % (w - 4) )) y3=$(( 2 + RANDOM % (h - 4) ))
  local xd1=1 yd1=1 xd2=1 yd2=0 xd3=0 yd3=1
  nodelay "$win" 1
  while ! wgetch "$win"; do
    _bounce "$x1" "$xd1" "$w"; x1=$BC_BN; xd1=$BC_BD
    _bounce "$y1" "$yd1" "$h"; y1=$BC_BN; yd1=$BC_BD
    _bounce "$x2" "$xd2" "$w"; x2=$BC_BN; xd2=$BC_BD
    _bounce "$y2" "$yd2" "$h"; y2=$BC_BN; yd2=$BC_BD
    _bounce "$x3" "$xd3" "$w"; x3=$BC_BN; xd3=$BC_BD
    _bounce "$y3" "$yd3" "$h"; y3=$BC_BN; yd3=$BC_BD

    set_colors "$win" 11 "$COLOR_RED" "$COLOR_BLUE"
    mvwaddch "$win" "$y1" "$x1" 'O'

    set_colors "$win" 12 "$COLOR_BLUE" "$COLOR_RED"
    mvwaddch "$win" "$y2" "$x2" '*'

    set_colors "$win" 13 "$COLOR_YELLOW" "$COLOR_WHITE"
    mvwaddch "$win" "$y3" "$x3" '@'

    wmove "$win" 0 0
    wrefresh "$win"
    delay_output 100
  done
  return 0
}

# ----------------------------------------------------------------- main
main() {
  local -a AUSMAP=(
    "           A           A "
    "    N.T. AAAAA       AAAA "
    "     AAAAAAAAAAA  AAAAAAAA "
    "   AAAAAAAAAAAAAAAAAAAAAAAAA Qld."
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAA "
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA "
    " AAAAAAAAAAAAAAAAAAAAAAAAAAAA "
    "   AAAAAAAAAAAAAAAAAAAAAAAAA N.S.W."
    "W.A. AAAAAAAAA      AAAAAA Vic."
    "       AAA   S.A.     AA"
    "                       A  Tas."
  )
  local -a MESSAGES=(
    "Hello from the Land Down Under"
    "The Land of crocs. and a big Red Rock"
    "Where the sunflower runs along the highways"
    "the dusty red roads lead one to loneliness"
    "Blue sky in the morning and"
    "freezing nights and twinkling stars"
  )
  local win x y i j k c message buffer w
  local -a save_c=() save_a=() save_p=()

  initscr || exit 1
  if has_colors; then
    start_color
  fi
  cbreak
  curs_set 0

  local width=48 height=14
  if ! newwin "$height" "$width" $(( (BC_LINES - height) / 2 )) $(( (BC_COLS - width) / 2 )); then
    endwin
    exit 1
  fi
  win=$bc_win

  while :; do
    set_colors "$win" 1 "$COLOR_WHITE" "$COLOR_BLUE"
    werase "$win"

    set_colors "$win" 2 "$COLOR_RED" "$COLOR_RED"
    box "$win"
    wrefresh "$win"
    # random output of a character
    use_colors "$win" 1 "$A_NORMAL"
    c='a'
    for (( i = 0; i < 5000; i++ )); do
      x=$(( RANDOM % (width - 2) + 1 ))
      y=$(( RANDOM % (height - 2) + 1 ))
      mvwaddch "$win" "$y" "$x" "$c"
      wrefresh "$win"
      nodelay "$win" 1
      if wgetch "$win"; then
        break
      fi
      if (( i == 2000 )); then
        c='b'
        set_colors "$win" 3 "$COLOR_CYAN" "$COLOR_YELLOW"
      fi
    done

    subwin_test "$win"
    # erase and draw the window background in yellow on green
    set_colors "$win" 4 "$COLOR_YELLOW" "$COLOR_GREEN"
    wbkgd "$win" ' ' "$A_BOLD" 4
    werase "$win"
    wrefresh "$win"
    # invisible (space) border in red
    use_colors "$win" 2 "$A_NORMAL"
    box "$win" ' ' ' '
    wrefresh "$win"
    # display the Australian map
    use_colors "$win" 4 "$A_BOLD"
    i=0
    for message in "${AUSMAP[@]}"; do
      mvwaddstr "$win" $(( i + 1 )) 8 "$message"
      wrefresh "$win"
      delay_output 50
      i=$(( i + 1 ))
    done

    set_colors "$win" 5 "$COLOR_BLUE" "$COLOR_WHITE"
    use_colors "$win" 5 "$A_BLINK"
    mvwaddstr "$win" $(( height - 2 )) 6 " PDCurses 2.1 for DOS, OS/2 and Unix"
    wrefresh "$win"

    # running messages
    set_colors "$win" 6 "$COLOR_YELLOW" "$COLOR_WHITE"
    j=0
    buffer=${MESSAGES[0]}
    i=1
    w=$(( width - 2 ))
    while (( j < 6 )); do
      while (( ${#buffer} < w )); do
        buffer+=" ... ${MESSAGES[++j % 6]}"
      done
      if (( i < w )); then
        mvwaddnstr "$win" $(( height / 2 )) $(( w - i )) "$buffer" "$i"
      else
        mvwaddnstr "$win" $(( height / 2 )) 1 "$buffer" "$w"
      fi
      wrefresh "$win"
      nodelay "$win" 1
      if wgetch "$win"; then
        flushinp
        break
      fi
      if (( i++ >= w )); then
        buffer=${buffer:1}
      fi
      delay_output 100
    done

    # draw the As across in red
    j=0
    set_colors "$win" 7 "$COLOR_RED" "$COLOR_GREEN"
    save_c=()
    save_a=()
    save_p=()
    for (( i = 2; i < width - 4; i++ )); do
      mvwinch "$win" 4 "$i"
      save_c+=("$wch")
      save_a+=("$wcha")
      save_p+=("$wchp")
      mvwaddch "$win" 4 "$i" "$wch"
    done
    wrefresh "$win"

    # prompt and wait for a key
    i=$(( height - 2 ))
    use_colors "$win" 5 "$A_NORMAL"
    mvwaddstr "$win" "$i" 5 " Type a key to continue or 'Q' to quit "
    wrefresh "$win"

    if wait_for_user "$win"; then
      :
    else
      break
    fi

    # restore the old line
    j=0
    for (( i = 2; i < width - 4; i++ )); do
      mvwaddch "$win" 4 "$i" "${save_c[$j]}" "${save_a[$j]}" "${save_p[$j]}"
      j=$(( j + 1 ))
    done
    wrefresh "$win"

    bouncing_balls "$win"
    # prompt and wait for a key
    i=$(( height - 2 ))
    use_colors "$win" 5 "$A_NORMAL"
    mvwaddstr "$win" "$i" 5 " Type a key to continue or 'Q' to quit "
    wrefresh "$win"
    if wait_for_user "$win"; then
      :
    else
      break
    fi
  done
  endwin
  exit 0
}

main "$@"

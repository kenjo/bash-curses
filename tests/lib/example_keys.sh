#!/bin/bash
# Shared key sequences for bash-vs-C example runners.
#
# example_actions <base> prints one tmux key per line.  A line beginning with
# raw: is sent with tmux send-keys -H and the remainder is hex bytes.
#
# example_quit <base> prints the final key that should make the example exit.
# Runners send actions, capture the screen, then send the quit key.

example_actions() {
  case $1 in
    04-initialization)
      printf '%s\n' a
      ;;
    07-input-functions)
      printf '%s\n' hello Enter
      ;;
    09-windows-main|09-windows-border)
      printf '%s\n' Left Right Up Down
      ;;
    11-keyboard)
      printf '%s\n' Down
      ;;
    13-screen-dump)
      printf '%s\n' d r
      ;;
    15-window-dump)
      ;;
    16-panels-moving-resizing)
      printf '%s\n' Tab
      ;;
    16-panels-show-hide)
      printf '%s\n' a b c
      ;;
    16-panels-window-browsing)
      printf '%s\n' Tab Tab
      ;;
    18-pads)
      printf '%s\n' Up Down Left Right
      ;;
    19-scroll-regions)
      printf '%s\n' Down Up NPage PPage
      ;;
    24-mouse-buttons)
      printf '%s\n' 'raw:1b 5b 4d 20 25 26 1b 5b 4d 23 25 26'
      ;;
    25-background)
      printf '%s\n' b s g
      ;;
    26-inserts)
      printf '%s\n' i n s d I D
      ;;
    27-keyname)
      printf '%s\n' Up F1 a
      ;;
    28-inchs)
      printf '%s\n' i n s m
      ;;
    29-addchstr)
      printf '%s\n' a n m b
      ;;
    30-instr)
      printf '%s\n' i n m b
      ;;
    31-subwin)
      printf '%s\n' p c m
      ;;
    32-movewindow)
      printf '%s\n' p c
      ;;
    33-clip-printw)
      printf '%s\n' a b
      ;;
    34-test-opaque)
      printf '%s\n' c i l m v s n t
      ;;
    35-test-delwin)
      printf '%s\n' c d c d
      ;;
    36-wresize)
      printf '%s\n' + - r
      ;;
    37-use-window)
      printf '%s\n' 1 2 s d
      ;;
    38-touch-lines)
      printf '%s\n' t u l w
      ;;
    39-echochar)
      printf '%s\n' e w u
      ;;
    40-defkey)
      printf '%s\n' d k b o
      ;;
    41-slk)
      printf '%s\n' c r t l a
      ;;
    42-prog-mode)
      printf '%s\n' d r
      ;;
    43-filter)
      printf '%s\n' f n
      ;;
    44-vidattr)
      printf '%s\n' a p
      ;;
    45-color-pair)
      printf '%s\n' p e a
      ;;
    46-wide-output)
      printf '%s\n' a w n s e
      ;;
    47-wide-input)
      printf '%s\n' w g m i n s u
      ;;
    48-wide-insert)
      printf '%s\n' w i m n s
      ;;
    49-dupwin)
      printf '%s\n' d d
      ;;
    50-mcprint)
      printf '%s\n' m n c w
      ;;
    51-wenclose)
      printf '%s\n' u d l r t
      ;;
    52-pad-extra)
      printf '%s\n' Up Down Left Right s p n e
      ;;
    53-putwin-getwin)
      printf '%s\n' s l
      ;;
    54-chgat-attrs)
      printf '%s\n' c w m s o f
      ;;
    55-border-lines)
      printf '%s\n' b x m h v
      ;;
    56-input-misc)
      printf '%s\n' m e k 1 2 i u n d f b l c
      ;;
    57-mouse-extra)
      printf '%s\n' i h u s
      ;;
    58-color-extended)
      printf '%s\n' c p a f r
      ;;
    59-wide-extra)
      printf '%s\n' n a i s r
      ;;
    60-attr-get)
      printf '%s\n' s e g w a o f
      ;;
    61-string-wrappers)
      printf '%s\n' a n m b w c s i
      ;;
    62-window-query)
      printf '%s\n' c b m a k d e h
      ;;
    63-clear-refresh)
      printf '%s\n' c t e n d s u o r
      ;;
    64-slk-extra)
      printf '%s\n' a o f s 1 2 c n
      ;;
    65-varargs-scanw)
      printf '%s\n' p v 1 s 42 Enter w 43 Enter 2 44 Enter
      ;;
    66-screen-dump-sp)
      printf '%s\n' d i r s
      ;;
    67-scroll-regions-extra)
      printf '%s\n' u d s r c
      ;;
    68-border-line-extra)
      printf '%s\n' b 1 m h v 2 3 4 s t
      ;;
    69-input-wrappers)
      printf '%s\n' k a g b w c n 12345 Enter s abc Enter 1 67890 Enter 2 def Enter
      ;;
    70-wide-stdscr)
      printf '%s\n' a 1 m 2 i 3 4 n 5 s
      ;;
    71-stdscr-del-ins)
      printf '%s\n' d 1 w 2 i 3 m 4 s 5 n 6
      ;;
    72-stdscr-in)
      printf '%s\n' i 1 m n 2 r s t 3 u
      ;;
    73-stdscr-add)
      printf '%s\n' a 1 m 2 n 3 r s t u v w
      ;;
    74-wide-mv)
      printf '%s\n' a 1 w 2 g a 3 b i 4 n 5 s 6
      ;;
    75-attr-bg-extra)
      printf '%s\n' a o f 1 2 3 b 4 k 5 g p v 6 u t
      ;;
    76-panel-bottom)
      printf '%s\n' b t h s m r w u
      ;;
    77-wide-insert-extra)
      printf '%s\n' w 1 s 2 n i 3 m 4
      ;;
    78-scanw-getstr-extra)
      printf '%s\n' s 4 2 Enter w 4 3 Enter g a b c Enter
      ;;
    79-hline-set-extra)
      printf '%s\n' h v m n w 1
      ;;
    80-copywin-clrtobot)
      printf '%s\n' c 1 2 l i
      ;;
    81-sudoku)
      printf '%s\n' l 5 x u m c r
      ;;
  esac
}

example_quit() {
  case $1 in
    04-initialization)
      printf '%s\n' a
      ;;
    09-windows-main|09-windows-border)
      printf '%s\n' F1
      ;;
    11-keyboard)
      printf '%s\n' Enter
      ;;
    16-panels-moving-resizing|16-panels-show-hide|16-panels-window-browsing)
      printf '%s\n' F1
      ;;
    *)
      printf '%s\n' q
      ;;
  esac
}

example_skip() {
  case $1 in
    08-attributes-main)
      printf '%s\n' 'requires a C source file argument'
      ;;
    12-mouse)
      printf '%s\n' 'requires mouse click coordinates'
      ;;
    14-leave-ncurses)
      printf '%s\n' 'spawns an interactive shell'
      ;;
  esac
}

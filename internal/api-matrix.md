# ncurses API coverage matrix

Which ncurses API surface do the reference examples actually exercise?

Corpora used to build this matrix:
- **test** — official ncurses test suite, per-function usage from its own `README` table
- **howto** — howto examples (27 programs, chapters 04–18)
- **htop** — htop (real application)
- **python** — CPython curses test suite

Totals: 759 API symbols parsed (593 libncurses, 83 libform, 65 libmenu, 18 libpanel); 567 used by ≥1 official test. `*_sp` rows are the save/pointer variants of the base call.

Current project scope:
- **Implemented**: init, window, pad (minimal), output, input, mouse, color, attr, box/bkgd, macros, vid, screen, slk.
- **Planned**: panels, menus, forms.
- **Out of scope**: the wide-character cell model and the terminfo API. Thin single-cell wide-character wrappers are provided where needed.

## Summary by area

| area | symbols | in tests | howto | htop | python |
|---|---|---|---|---|---|
| init | 39 | 26 | 5 | 5 | 15 |
| window | 63 | 53 | 3 | 0 | 5 |
| pad | 9 | 5 | 0 | 0 | 1 |
| output | 124 | 105 | 17 | 11 | 3 |
| input | 55 | 46 | 8 | 9 | 19 |
| color | 36 | 23 | 3 | 4 | 12 |
| attr | 26 | 19 | 4 | 3 | 0 |
| wide | 77 | 70 | 0 | 3 | 3 |
| mouse | 12 | 4 | 2 | 3 | 5 |
| slk | 31 | 12 | 0 | 0 | 16 |
| screen | 8 | 5 | 0 | 0 | 4 |
| vid | 12 | 8 | 0 | 0 | 0 |
| panels | 18 | 15 | 10 | 0 | 0 |
| menus | 65 | 34 | 24 | 0 | 0 |
| forms | 83 | 59 | 16 | 0 | 0 |
| terminfo | 85 | 70 | 0 | 4 | 22 |
| macros | 12 | 11 | 1 | 1 | 4 |
| misc | 4 | 2 | 0 | 1 | 2 |

## init

| symbol | official tests | howto | htop | python |
|---|---|---|---|---|
| `curs_set` | demo_new_pair, echochar, firework, gdc, hanoi, lrtest …+9 |  | ✓ | ✓ |
| `curs_set_sp` | sp_tinfo |  |  |  |
| `curscr` | demo_panels, knight, lrtest, ncurses, popup_msg, savescreen …+1 |  |  |  |
| `curses_trace` | demo_menus, hashtest, lrtest, ncurses, padview, redraw …+7 |  |  |  |
| `curses_version` | ncurses, progs:, clear, infocmp, tabs, tic …+3 |  |  |  |
| `def_prog_mode` | bs, ncurses | ✓ |  | ✓ |
| `def_prog_mode_sp` | sp_tinfo |  |  |  |
| `def_shell_mode` | – |  |  |  |
| `def_shell_mode_sp` | sp_tinfo |  |  |  |
| `delscreen` | ditto, dots_mvcur, test_delwin |  |  |  |
| `doupdate` | cardfile, demo_menus, demo_panels, ditto, ins_wide, inserts …+13 | ✓ |  | ✓ |
| `doupdate_sp` | – |  |  |  |
| `endwin` | back_ground, background, blue, bs, cardfile, chgat …+65 | ✓ | ✓ | ✓ |
| `endwin_sp` | – |  |  |  |
| `exit_curses` | back_ground, background, blue, bs, cardfile, chgat …+66 |  |  |  |
| `filter` | filter |  | ✓ | ✓ |
| `filter_sp` | – |  |  |  |
| `initscr` | back_ground, background, blue, bs, cardfile, chgat …+55 | ✓ | ✓ | ✓ |
| `intrflush` | demo_forms, dup_field, move_field, movewindow |  | ✓ | ✓ |
| `intrflush_sp` | sp_tinfo |  |  |  |
| `isendwin` | – |  |  | ✓ |
| `isendwin_sp` | – |  |  |  |
| `new_prescr` | sp_tinfo |  |  | ✓ |
| `newscr` | – |  |  |  |
| `newterm` | demo_altkeys, demo_new_pair, ditto, dots_mvcur, extended_color, filter …+8 |  |  | ✓ |
| `newterm_sp` | – |  |  |  |
| `nofilter` | – |  |  | ✓ |
| `nofilter_sp` | – |  |  |  |
| `noqiflush` | – |  |  | ✓ |
| `noqiflush_sp` | sp_tinfo |  |  |  |
| `qiflush` | – |  |  | ✓ |
| `qiflush_sp` | sp_tinfo |  |  |  |
| `reset_prog_mode` | filter, ncurses | ✓ |  | ✓ |
| `reset_prog_mode_sp` | sp_tinfo |  |  |  |
| `reset_shell_mode` | bs, filter, savescreen, test_setupterm |  |  |  |
| `reset_shell_mode_sp` | sp_tinfo |  |  |  |
| `set_tabsize` | demo_tabs, test_opaque |  |  | ✓ |
| `set_tabsize_sp` | sp_tinfo |  |  |  |
| `trace` | – |  |  |  |

## window

| symbol | official tests | howto | htop | python |
|---|---|---|---|---|
| `clearok` | bs, knight |  |  |  |
| `copywin` | ncurses, testcurs |  |  |  |
| `delwin` | cardfile, chgat, clip_printw, demo_forms, demo_panels, dup_field …+23 | ✓ |  |  |
| `derwin` | cardfile, chgat, clip_printw, demo_forms, demo_menus, ditto …+17 | ✓ |  |  |
| `dupwin` | popup_msg |  |  |  |
| `getbegx` | chgat, clip_printw, demo_menus, demo_panels, dump_window, insdelln …+6 |  |  |  |
| `getbegy` | chgat, clip_printw, demo_menus, demo_panels, dump_window, insdelln …+6 |  |  |  |
| `getcurx` | bs, chgat, clip_printw, combine, demo_altkeys, demo_defkey …+17 |  |  |  |
| `getcury` | bs, chgat, clip_printw, demo_altkeys, demo_defkey, demo_panels …+16 |  |  |  |
| `getmaxx` | chgat, clip_printw, demo_panels, dump_window, firstlast, inch_wide …+13 |  |  |  |
| `getmaxy` | chgat, clip_printw, demo_forms, demo_panels, dump_window, firstlast …+15 |  |  |  |
| `getparx` | movewindow |  |  |  |
| `getpary` | movewindow |  |  |  |
| `getwin` | ncurses |  |  | ✓ |
| `getwin_sp` | – |  |  |  |
| `idcok` | test_opaque |  |  |  |
| `idlok` | ncurses, padview, test_opaque, testscanw, view |  |  |  |
| `immedok` | test_opaque |  |  |  |
| `is_cleared` | test_opaque |  |  |  |
| `is_idcok` | test_opaque |  |  |  |
| `is_idlok` | test_opaque |  |  |  |
| `is_immedok` | test_opaque |  |  |  |
| `is_leaveok` | test_opaque |  |  |  |
| `is_linetouched` | – |  |  |  |
| `is_nodelay` | test_opaque |  |  |  |
| `is_notimeout` | test_opaque |  |  |  |
| `is_scrollok` | ncurses, test_opaque |  |  |  |
| `is_subwin` | test_opaque |  |  |  |
| `is_syncok` | test_opaque |  |  |  |
| `is_term_resized` | – |  |  | ✓ |
| `is_term_resized_sp` | – |  |  |  |
| `is_wintouched` | – |  |  |  |
| `leaveok` | hanoi, test_opaque |  |  |  |
| `mvwin` | cardfile, demo_menus, movewindow, ncurses, testcurs, xmas |  |  |  |
| `mvwinch` | dump_window, inchs, newdemo, testcurs |  |  |  |
| `mvwinchnstr` | inchs |  |  |  |
| `mvwinchstr` | inchs |  |  |  |
| `mvwinnstr` | test_instr, testcurs |  |  |  |
| `mvwinsch` | ins_wide, inserts |  |  |  |
| `mvwinsnstr` | inserts |  |  |  |
| `mvwinsstr` | inserts, testcurs |  |  |  |
| `mvwinstr` | test_instr |  |  |  |
| `newwin` | cardfile, chgat, clip_printw, demo_defkey, demo_forms, demo_keyok …+28 | ✓ |  | ✓ |
| `newwin_sp` | – |  |  |  |
| `overlay` | ncurses, testcurs, xmas |  |  |  |
| `overwrite` | ncurses, savescreen |  |  |  |
| `putwin` | ncurses |  |  |  |
| `resize_term` | – |  |  | ✓ |
| `resize_term_sp` | – |  |  |  |
| `resizeterm` | – |  |  | ✓ |
| `resizeterm_sp` | – |  |  |  |
| `scrollok` | clip_printw, color_content, demo_altkeys, demo_defkey, demo_keyok, demo_new_pair …+15 |  |  |  |
| `setscrreg` | view |  |  |  |
| `stdscr` | back_ground, background, bs, chgat, clip_printw, color_content …+53 |  |  |  |
| `subwin` | movewindow, ncurses, newdemo, testcurs |  |  |  |
| `syncok` | test_opaque |  |  |  |
| `use_window` | rain, worm |  |  |  |
| `wenclose` | ncurses |  |  |  |
| `wgetdelay` | test_opaque |  |  |  |
| `wgetparent` | test_opaque |  |  |  |
| `wgetscrreg` | test_opaque |  |  |  |
| `wresize` | cardfile, demo_menus, ncurses |  |  |  |
| `wsetscrreg` | ncurses, test_delwin, testcurs |  |  |  |

## pad

| symbol | official tests | howto | htop | python |
|---|---|---|---|---|
| `is_pad` | test_opaque |  |  |  |
| `mcprint` | – |  |  |  |
| `mcprint_sp` | – |  |  |  |
| `newpad` | ncurses, padview, popup_msg, testcurs |  |  | ✓ |
| `newpad_sp` | – |  |  |  |
| `pechochar` | – |  |  |  |
| `pnoutrefresh` | ncurses, padview, popup_msg |  |  |  |
| `prefresh` | testcurs |  |  |  |
| `subpad` | testcurs |  |  |  |

## output

| symbol | official tests | howto | htop | python |
|---|---|---|---|---|
| `addch` | back_ground, background, blue, bs, color_content, demo_tabs …+16 | ✓ |  |  |
| `addchnstr` | test_addchstr |  |  |  |
| `addchstr` | test_addchstr |  |  |  |
| `addnstr` | test_addstr |  |  |  |
| `addstr` | blue, bs, cardfile, filter, gdc, hanoi …+3 |  | ✓ |  |
| `border` | – |  |  |  |
| `border_set` | – |  |  |  |
| `box` | cardfile, chgat, clip_printw, demo_forms, demo_menus, demo_panels …+22 | ✓ |  |  |
| `box_set` | ncurses |  |  |  |
| `chgat` | chgat |  |  |  |
| `clear` | blue, bs, filter, gdc, ncurses, padview …+2 | ✓ | ✓ |  |
| `clrtobot` | demo_menus, move_field, ncurses, view |  |  |  |
| `clrtoeol` | blue, bs, demo_altkeys, filter, foldkeys, form_driver_w …+7 | ✓ |  |  |
| `delch` | – |  |  |  |
| `deleteln` | insdelln |  |  |  |
| `erase` | cardfile, demo_menus, filter, firework, firstlast, hanoi …+6 |  |  |  |
| `erasechar` | ncurses |  |  | ✓ |
| `erasechar_sp` | sp_tinfo |  |  |  |
| `hline` | gdc, ncurses |  |  |  |
| `hline_set` | – |  |  |  |
| `inch` | inchs |  |  |  |
| `inchnstr` | inchs |  |  |  |
| `inchstr` | inchs |  |  |  |
| `innstr` | test_instr |  |  |  |
| `insch` | ins_wide, inserts |  |  |  |
| `insdelln` | insdelln |  |  |  |
| `insertln` | insdelln |  |  |  |
| `insnstr` | inserts |  |  |  |
| `insstr` | inserts |  |  |  |
| `instr` | test_instr |  |  |  |
| `move` | blue, bs, cardfile, chgat, combine, demo_altkeys …+34 | ✓ | ✓ |  |
| `mvaddch` | bs, gdc, hanoi, lrtest, ncurses, rain …+6 | ✓ | ✓ |  |
| `mvaddchnstr` | gdc, test_addchstr |  | ✓ |  |
| `mvaddchstr` | test_addchstr |  | ✓ |  |
| `mvaddnstr` | test_addstr |  | ✓ |  |
| `mvaddstr` | bs, demo_forms, gdc, hanoi, knight, ncurses …+5 |  | ✓ |  |
| `mvchgat` | chgat | ✓ |  |  |
| `mvdelch` | – |  |  |  |
| `mvderwin` | movewindow |  |  |  |
| `mvgetch` | – |  |  |  |
| `mvgetnstr` | test_getstr |  |  |  |
| `mvgetstr` | test_getstr |  |  |  |
| `mvhline` | ncurses | ✓ | ✓ |  |
| `mvhline_set` | ncurses |  |  |  |
| `mvinch` | inchs |  |  |  |
| `mvinchnstr` | gdc, inchs |  |  |  |
| `mvinchstr` | inchs |  |  |  |
| `mvinnstr` | test_instr |  |  |  |
| `mvinsch` | ins_wide, inserts |  |  |  |
| `mvinsnstr` | inserts |  |  |  |
| `mvinsstr` | inserts |  |  |  |
| `mvinstr` | test_instr |  |  |  |
| `mvprintw` | back_ground, background, bs, firework, form_driver_w, hanoi …+6 | ✓ |  |  |
| `mvscanw` | – |  |  |  |
| `mvvline` | ncurses | ✓ | ✓ |  |
| `mvvline_set` | ncurses |  |  |  |
| `mvwaddch` | movewindow, ncurses, newdemo, test_add_wchstr, test_addchstr, test_addstr …+3 | ✓ |  |  |
| `mvwaddchnstr` | test_addchstr |  |  |  |
| `mvwaddchstr` | inchs, test_addchstr |  |  |  |
| `mvwaddnstr` | newdemo, test_addstr, testcurs |  |  |  |
| `mvwaddstr` | ditto, firstlast, ins_wide, inserts, knight, ncurses …+6 |  |  |  |
| `mvwdelch` | ncurses |  |  |  |
| `mvwgetch` | inch_wide, inchs, test_get_wstr, test_getstr, test_instr, test_inwstr …+1 |  |  |  |
| `mvwgetnstr` | test_getstr |  |  |  |
| `mvwgetstr` | test_getstr |  |  |  |
| `mvwhline` | movewindow, ncurses | ✓ |  |  |
| `mvwhline_set` | – |  |  |  |
| `mvwprintw` | demo_menus, demo_panels, inch_wide, inchs, ncurses, test_delwin …+3 | ✓ |  |  |
| `mvwscanw` | testcurs |  |  |  |
| `mvwvline` | ins_wide, inserts, movewindow, ncurses, test_add_wchstr, test_addchstr …+2 |  |  |  |
| `mvwvline_set` | – |  |  |  |
| `printw` | back_ground, background, blue, bs, color_content, color_set …+16 | ✓ |  |  |
| `redrawwin` | combine, padview, redraw, view |  |  |  |
| `refresh` | blue, bs, color_content, demo_defkey, demo_forms, demo_keyok …+27 | ✓ | ✓ |  |
| `scrl` | view |  |  |  |
| `scroll` | testcurs |  |  |  |
| `touchline` | chgat, clip_printw, insdelln |  |  |  |
| `touchwin` | chgat, clip_printw, demo_menus, filter, firstlast, inch_wide …+19 |  |  |  |
| `unctrl` | ncurses, redraw, test_add_wchstr, test_addchstr, test_mouse, testcurs |  |  | ✓ |
| `unctrl_sp` | sp_tinfo |  |  |  |
| `untouchwin` | – |  |  |  |
| `vline` | gdc, ncurses |  |  |  |
| `vline_set` | – |  |  |  |
| `vw_printw` | clip_printw, movewindow, test_mouse |  |  |  |
| `vwprintw` | – |  |  |  |
| `waddch` | demo_forms, demo_panels, ditto, firstlast, inch_wide, inchs …+16 |  |  |  |
| `waddchnstr` | test_addchstr |  |  |  |
| `waddchstr` | test_addchstr |  |  |  |
| `waddnstr` | demo_forms, test_addstr |  |  |  |
| `waddstr` | chgat, clip_printw, demo_forms, demo_panels, firstlast, ins_wide …+9 |  |  |  |
| `wborder` | ncurses | ✓ |  |  |
| `wborder_set` | ncurses |  |  |  |
| `wclear` | ncurses, test_opaque, testcurs |  |  |  |
| `wclrtobot` | firstlast, inch_wide, inchs, ncurses, test_delwin, test_instr …+2 |  |  |  |
| `wclrtoeol` | chgat, clip_printw, demo_defkey, demo_keyok, demo_menus, demo_panels …+15 |  |  |  |
| `wcursyncup` | – |  |  |  |
| `wdelch` | ncurses, testcurs |  |  |  |
| `wdeleteln` | insdelln, testcurs |  |  |  |
| `werase` | cardfile, demo_forms, demo_menus, demo_panels, dup_field, firstlast …+11 |  |  |  |
| `whline` | testcurs |  |  |  |
| `whline_set` | – |  |  |  |
| `winch` | inchs, knight, testcurs |  |  |  |
| `winchnstr` | inchs |  |  |  |
| `winchstr` | inchs |  |  |  |
| `winnstr` | demo_altkeys, demo_defkey, foldkeys, test_instr |  |  |  |
| `winsch` | ins_wide, inserts, testcurs |  |  |  |
| `winsdelln` | insdelln |  |  |  |
| `winsertln` | insdelln, testcurs |  |  |  |
| `winsnstr` | inserts |  |  |  |
| `winsstr` | inserts |  |  |  |
| `winstr` | test_instr |  |  |  |
| `wmove` | chgat, clip_printw, demo_altkeys, demo_defkey, demo_keyok, demo_menus …+31 |  |  |  |
| `wnoutrefresh` | demo_menus, ditto, inch_wide, inchs, ins_wide, inserts …+15 |  |  |  |
| `wprintw` | chgat, clip_printw, demo_defkey, demo_forms, demo_keyok, demo_menus …+19 |  |  |  |
| `wredrawln` | redraw |  |  |  |
| `wrefresh` | chgat, clip_printw, demo_forms, demo_keyok, demo_menus, demo_panels …+23 | ✓ |  |  |
| `wscrl` | ncurses, testcurs |  |  |  |
| `wsyncdown` | movewindow |  |  |  |
| `wsyncup` | – |  |  |  |
| `wtouchln` | – |  |  |  |
| `wunctrl` | – |  |  | ✓ |
| `wunctrl_sp` | – |  |  |  |
| `wvline` | testcurs |  |  |  |
| `wvline_set` | – |  |  |  |

## input

| symbol | official tests | howto | htop | python |
|---|---|---|---|---|
| `cbreak` | back_ground, background, blue, bs, cardfile, chgat …+54 | ✓ | ✓ | ✓ |
| `cbreak_sp` | sp_tinfo |  |  |  |
| `delay_output` | newdemo |  |  | ✓ |
| `delay_output_sp` | sp_tinfo |  |  |  |
| `echo` | bs, hanoi, ncurses, test_get_wstr, test_getstr, testcurs …+1 | ✓ |  | ✓ |
| `echo_sp` | – |  |  |  |
| `echochar` | echochar, ncurses |  |  |  |
| `flushinp` | ncurses, newdemo, testcurs |  |  | ✓ |
| `flushinp_sp` | sp_tinfo |  |  |  |
| `getch` | back_ground, background, blue, bs, chgat, color_content …+26 | ✓ | ✓ |  |
| `getnstr` | filter, ncurses, test_getstr |  |  |  |
| `getstr` | test_getstr | ✓ |  |  |
| `halfdelay` | padview, view |  | ✓ | ✓ |
| `halfdelay_sp` | sp_tinfo |  |  |  |
| `has_key` | – |  |  | ✓ |
| `has_key_sp` | sp_tinfo |  |  |  |
| `is_keypad` | ncurses, test_opaque |  |  |  |
| `keyname` | combine, demo_altkeys, demo_defkey, demo_keyok, demo_menus, dup_field …+14 |  |  | ✓ |
| `keyname_sp` | sp_tinfo |  |  |  |
| `keyok` | demo_keyok, foldkeys |  |  | ✓ |
| `keyok_sp` | sp_tinfo |  |  |  |
| `keypad` | bs, cardfile, chgat, clip_printw, combine, demo_altkeys …+44 | ✓ | ✓ |  |
| `killchar` | ncurses |  |  | ✓ |
| `killchar_sp` | sp_tinfo |  |  |  |
| `meta` | key_names, keynames, ncurses |  |  | ✓ |
| `napms` | demo_panels, ditto, dots, dots_curses, dots_mvcur, dots_xcurses …+20 |  | ✓ | ✓ |
| `napms_sp` | sp_tinfo |  |  |  |
| `nl` | demo_forms, dup_field, move_field, ncurses, rain, testcurs |  |  | ✓ |
| `nl_sp` | – |  |  |  |
| `nocbreak` | testcurs |  | ✓ | ✓ |
| `nocbreak_sp` | sp_tinfo |  |  |  |
| `nodelay` | demo_new_pair, ditto, extended_color, firework, gdc, lrtest …+9 |  | ✓ |  |
| `noecho` | back_ground, background, bs, cardfile, chgat, clip_printw …+54 | ✓ | ✓ | ✓ |
| `noecho_sp` | – |  |  |  |
| `nonl` | bs, demo_forms, dup_field, hashtest, move_field, movewindow …+6 |  | ✓ | ✓ |
| `nonl_sp` | – |  |  |  |
| `noraw` | demo_forms, demo_menus, dup_field, move_field, ncurses, testcurs |  |  | ✓ |
| `noraw_sp` | sp_tinfo |  |  |  |
| `notimeout` | ncurses, test_opaque |  |  |  |
| `raw` | demo_forms, dup_field, move_field, ncurses, redraw, testcurs | ✓ |  | ✓ |
| `raw_sp` | sp_tinfo |  |  |  |
| `scanw` | testcurs, testscanw |  |  |  |
| `timeout` | filter, rain, savescreen |  |  |  |
| `typeahead` | testcurs |  |  | ✓ |
| `typeahead_sp` | sp_tinfo |  |  |  |
| `ungetch` | bs, knight, test_unget_wch |  |  | ✓ |
| `ungetch_sp` | – |  |  |  |
| `vw_scanw` | – |  |  |  |
| `vwscanw` | – |  |  |  |
| `wechochar` | – |  |  |  |
| `wgetch` | cardfile, chgat, clip_printw, demo_defkey, demo_keyok, demo_menus …+22 | ✓ |  |  |
| `wgetnstr` | ncurses, test_getstr |  |  |  |
| `wgetstr` | test_getstr |  |  |  |
| `wscanw` | testcurs |  |  |  |
| `wtimeout` | ncurses |  |  |  |

## color

| symbol | official tests | howto | htop | python |
|---|---|---|---|---|
| `alloc_pair` | demo_new_pair, dots_xcurses |  |  | ✓ |
| `alloc_pair_sp` | – |  |  |  |
| `assume_default_colors` | back_ground, background, ncurses |  |  | ✓ |
| `assume_default_colors_sp` | – |  |  |  |
| `color_content` | color_content, ncurses, picsmap |  |  | ✓ |
| `color_content_sp` | – |  |  |  |
| `color_set` | color_set, dots_xcurses, extended_color, ncurses |  |  |  |
| `extended_color_content` | color_content, extended_color |  |  |  |
| `extended_color_content_sp` | extended_color |  |  |  |
| `extended_pair_content` | extended_color, pair_content |  |  |  |
| `extended_pair_content_sp` | extended_color |  |  |  |
| `extended_slk_color` | extended_color |  |  |  |
| `extended_slk_color_sp` | extended_color |  |  |  |
| `find_pair` | demo_new_pair |  |  | ✓ |
| `find_pair_sp` | – |  |  |  |
| `free_pair` | demo_new_pair |  |  | ✓ |
| `free_pair_sp` | – |  |  |  |
| `has_colors` | back_ground, background, bs, cardfile, chgat, clip_printw …+36 | ✓ | ✓ | ✓ |
| `has_colors_sp` | – |  |  |  |
| `init_color` | color_content, ncurses |  |  | ✓ |
| `init_color_sp` | – |  |  |  |
| `init_extended_color` | color_content, extended_color |  |  |  |
| `init_extended_color_sp` | extended_color |  |  |  |
| `init_extended_pair` | extended_color, ncurses, pair_content, picsmap |  |  |  |
| `init_extended_pair_sp` | extended_color |  |  |  |
| `init_pair` | back_ground, background, blue, bs, cardfile, chgat …+36 | ✓ | ✓ | ✓ |
| `init_pair_sp` | – |  |  |  |
| `pair_content` | back_ground, background, color_set, pair_content |  |  | ✓ |
| `pair_content_sp` | – |  |  |  |
| `reset_color_pairs` | picsmap |  |  | ✓ |
| `reset_color_pairs_sp` | – |  |  |  |
| `start_color` | back_ground, background, blue, bs, cardfile, chgat …+38 | ✓ | ✓ | ✓ |
| `start_color_sp` | – |  |  |  |
| `use_default_colors` | back_ground, background, dots_curses, dots_xcurses, filter, firework …+9 |  | ✓ | ✓ |
| `use_default_colors_sp` | – |  |  |  |
| `wcolor_set` | – |  |  |  |

## attr

| symbol | official tests | howto | htop | python |
|---|---|---|---|---|
| `attr_get` | – |  |  |  |
| `attr_off` | combine, dots_xcurses, ncurses |  |  |  |
| `attr_on` | combine, dots_xcurses, ncurses |  |  |  |
| `attr_set` | ncurses |  |  |  |
| `attroff` | blue, dots_curses, echochar, filter, gdc, ncurses …+1 | ✓ | ✓ |  |
| `attron` | blue, bs, dots_curses, echochar, filter, gdc …+1 | ✓ | ✓ |  |
| `attrset` | bs, filter, firework, gdc, hanoi, insdelln …+6 |  | ✓ |  |
| `bkgd` | background, cardfile, demo_forms, dup_field, move_field, ncurses …+4 |  |  |  |
| `bkgdset` | background, ncurses, testaddch |  |  |  |
| `bkgrnd` | ncurses |  |  |  |
| `bkgrndset` | back_ground, ncurses |  |  |  |
| `getattrs` | – |  |  |  |
| `getbkgd` | ncurses |  |  |  |
| `getbkgrnd` | ncurses |  |  |  |
| `wattr_get` | ncurses |  |  |  |
| `wattr_off` | – |  |  |  |
| `wattr_on` | – |  |  |  |
| `wattr_set` | ncurses |  |  |  |
| `wattroff` | demo_forms, ncurses, testcurs, xmas | ✓ |  |  |
| `wattron` | testcurs, xmas | ✓ |  |  |
| `wattrset` | clip_printw, demo_forms, insdelln, ncurses, newdemo, padview …+4 |  |  |  |
| `wbkgd` | cardfile, demo_forms, demo_menus, ncurses, newdemo, padview …+1 |  |  |  |
| `wbkgdset` | demo_panels, ins_wide, inserts, ncurses, test_add_wchstr, test_addchstr …+2 |  |  |  |
| `wbkgrnd` | – |  |  |  |
| `wbkgrndset` | – |  |  |  |
| `wgetbkgrnd` | – |  |  |  |

## wide

| symbol | official tests | howto | htop | python |
|---|---|---|---|---|
| `add_wch` | combine, demo_new_pair, demo_panels, ncurses, picsmap, savescreen …+2 |  |  |  |
| `add_wchnstr` | test_add_wchstr |  |  |  |
| `add_wchstr` | test_add_wchstr, view |  |  |  |
| `addnwstr` | dots_xcurses, ncurses, test_addwstr |  |  |  |
| `addwstr` | blue, combine, test_addwstr |  |  |  |
| `echo_wchar` | ncurses |  |  |  |
| `erasewchar` | ncurses |  |  | ✓ |
| `erasewchar_sp` | – |  |  |  |
| `get_wch` | form_driver_w, test_unget_wch |  |  |  |
| `get_wstr` | test_get_wstr |  |  |  |
| `getcchar` | demo_new_pair, ncurses, savescreen, view |  |  |  |
| `getn_wstr` | test_get_wstr |  |  |  |
| `in_wch` | inch_wide |  |  |  |
| `in_wchnstr` | inch_wide |  |  |  |
| `in_wchstr` | inch_wide |  |  |  |
| `innwstr` | test_inwstr |  |  |  |
| `ins_nwstr` | ins_wide |  |  |  |
| `ins_wch` | ins_wide |  |  |  |
| `ins_wstr` | ins_wide |  |  |  |
| `inwstr` | test_inwstr |  |  |  |
| `killwchar` | ncurses |  |  | ✓ |
| `killwchar_sp` | – |  |  |  |
| `mvadd_wch` | ncurses, test_add_wchstr, test_addwstr |  | ✓ |  |
| `mvadd_wchnstr` | test_add_wchstr |  | ✓ |  |
| `mvadd_wchstr` | test_add_wchstr |  | ✓ |  |
| `mvaddnwstr` | test_addwstr |  |  |  |
| `mvaddwstr` | test_addwstr |  |  |  |
| `mvget_wch` | – |  |  |  |
| `mvget_wstr` | test_get_wstr |  |  |  |
| `mvgetn_wstr` | test_get_wstr |  |  |  |
| `mvin_wch` | inch_wide |  |  |  |
| `mvin_wchnstr` | inch_wide |  |  |  |
| `mvin_wchstr` | inch_wide |  |  |  |
| `mvinnwstr` | test_inwstr |  |  |  |
| `mvins_nwstr` | ins_wide |  |  |  |
| `mvins_wch` | ins_wide |  |  |  |
| `mvins_wstr` | ins_wide |  |  |  |
| `mvinwstr` | test_inwstr |  |  |  |
| `mvwadd_wch` | test_add_wchstr, test_addwstr |  |  |  |
| `mvwadd_wchnstr` | test_add_wchstr |  |  |  |
| `mvwadd_wchstr` | inch_wide, test_add_wchstr |  |  |  |
| `mvwaddnwstr` | test_addwstr |  |  |  |
| `mvwaddwstr` | test_addwstr, test_inwstr |  |  |  |
| `mvwchgat` | chgat |  |  |  |
| `mvwget_wch` | – |  |  |  |
| `mvwget_wstr` | test_get_wstr |  |  |  |
| `mvwgetn_wstr` | test_get_wstr |  |  |  |
| `mvwin_wch` | inch_wide |  |  |  |
| `mvwin_wchnstr` | inch_wide |  |  |  |
| `mvwin_wchstr` | inch_wide |  |  |  |
| `mvwinnwstr` | test_inwstr |  |  |  |
| `mvwins_nwstr` | ins_wide |  |  |  |
| `mvwins_wch` | ins_wide |  |  |  |
| `mvwins_wstr` | ins_wide |  |  |  |
| `mvwinwstr` | test_inwstr |  |  |  |
| `pecho_wchar` | – |  |  |  |
| `setcchar` | back_ground, combine, demo_new_pair, demo_panels, ins_wide, ncurses …+4 |  |  |  |
| `unget_wch` | test_unget_wch |  |  | ✓ |
| `unget_wch_sp` | – |  |  |  |
| `wadd_wch` | inch_wide, ncurses, test_add_wchstr, test_addwstr |  |  |  |
| `wadd_wchnstr` | savescreen, test_add_wchstr |  |  |  |
| `wadd_wchstr` | test_add_wchstr |  |  |  |
| `waddnwstr` | ncurses, test_addwstr |  |  |  |
| `waddwstr` | ins_wide, ncurses, padview, test_add_wchstr, test_addwstr, test_get_wstr …+1 |  |  |  |
| `wchgat` | chgat, test_get_wstr, test_getstr, view |  |  |  |
| `wecho_wchar` | – |  |  |  |
| `wget_wch` | ins_wide, ncurses, test_add_wchstr, test_addwstr |  |  |  |
| `wget_wstr` | test_get_wstr |  |  |  |
| `wgetn_wstr` | ncurses, test_get_wstr |  |  |  |
| `win_wch` | inch_wide, savescreen |  |  |  |
| `win_wchnstr` | inch_wide, view |  |  |  |
| `win_wchstr` | inch_wide |  |  |  |
| `winnwstr` | test_inwstr |  |  |  |
| `wins_nwstr` | ins_wide |  |  |  |
| `wins_wch` | ins_wide |  |  |  |
| `wins_wstr` | ins_wide |  |  |  |
| `winwstr` | test_inwstr |  |  |  |

## mouse

| symbol | official tests | howto | htop | python |
|---|---|---|---|---|
| `getmouse` | bs, demo_menus, knight, movewindow, ncurses, test_mouse …+1 | ✓ | ✓ | ✓ |
| `getmouse_sp` | – |  |  |  |
| `has_mouse` | – |  |  | ✓ |
| `has_mouse_sp` | – |  |  |  |
| `mouse_trafo` | – |  |  |  |
| `mouseinterval` | test_mouse |  | ✓ | ✓ |
| `mouseinterval_sp` | – |  |  |  |
| `mousemask` | bs, demo_forms, demo_menus, knight, movewindow, ncurses …+2 | ✓ | ✓ | ✓ |
| `mousemask_sp` | – |  |  |  |
| `ungetmouse` | – |  |  | ✓ |
| `ungetmouse_sp` | – |  |  |  |
| `wmouse_trafo` | ncurses |  |  |  |

## slk

| symbol | official tests | howto | htop | python |
|---|---|---|---|---|
| `slk_attr` | – |  |  | ✓ |
| `slk_attr_off` | – |  |  | ✓ |
| `slk_attr_on` | – |  |  | ✓ |
| `slk_attr_set` | ncurses |  |  | ✓ |
| `slk_attr_set_sp` | – |  |  |  |
| `slk_attr_sp` | – |  |  |  |
| `slk_attroff` | – |  |  | ✓ |
| `slk_attroff_sp` | – |  |  |  |
| `slk_attron` | – |  |  | ✓ |
| `slk_attron_sp` | – |  |  |  |
| `slk_attrset` | extended_color, ncurses |  |  | ✓ |
| `slk_attrset_sp` | – |  |  |  |
| `slk_clear` | ncurses |  |  | ✓ |
| `slk_clear_sp` | – |  |  |  |
| `slk_color` | ncurses |  |  | ✓ |
| `slk_color_sp` | – |  |  |  |
| `slk_init` | extended_color, ncurses |  |  | ✓ |
| `slk_init_sp` | – |  |  |  |
| `slk_label` | ncurses |  |  | ✓ |
| `slk_label_sp` | – |  |  |  |
| `slk_noutrefresh` | extended_color, ncurses |  |  | ✓ |
| `slk_noutrefresh_sp` | – |  |  |  |
| `slk_refresh` | ncurses |  |  | ✓ |
| `slk_refresh_sp` | – |  |  |  |
| `slk_restore` | ncurses |  |  | ✓ |
| `slk_restore_sp` | – |  |  |  |
| `slk_set` | extended_color, ncurses |  |  | ✓ |
| `slk_set_sp` | – |  |  |  |
| `slk_touch` | extended_color, ncurses |  |  | ✓ |
| `slk_touch_sp` | – |  |  |  |
| `slk_wset` | ncurses |  |  |  |

## screen

| symbol | official tests | howto | htop | python |
|---|---|---|---|---|
| `scr_dump` | combine, savescreen |  |  | ✓ |
| `scr_init` | savescreen |  |  | ✓ |
| `scr_init_sp` | – |  |  |  |
| `scr_restore` | savescreen |  |  | ✓ |
| `scr_restore_sp` | – |  |  |  |
| `scr_set` | savescreen |  |  | ✓ |
| `scr_set_sp` | – |  |  |  |
| `use_screen` | ditto |  |  |  |

## vid

| symbol | official tests | howto | htop | python |
|---|---|---|---|---|
| `standend` | blue, gdc, ncurses |  |  |  |
| `standout` | blue, ncurses |  |  |  |
| `vid_attr` | test_vid_puts |  |  |  |
| `vid_attr_sp` | – |  |  |  |
| `vid_puts` | test_vid_puts |  |  |  |
| `vid_puts_sp` | – |  |  |  |
| `vidattr` | test_vidputs |  |  |  |
| `vidattr_sp` | – |  |  |  |
| `vidputs` | test_vidputs |  |  |  |
| `vidputs_sp` | – |  |  |  |
| `wstandend` | ncurses, test_opaque, xmas |  |  |  |
| `wstandout` | ncurses, test_opaque, xmas |  |  |  |

## panels

| symbol | official tests | howto | htop | python |
|---|---|---|---|---|
| `bottom_panel` | demo_panels, ncurses |  |  |  |
| `ceiling_panel` | – |  |  |  |
| `del_panel` | demo_panels, ncurses |  |  |  |
| `ground_panel` | – |  |  |  |
| `hide_panel` | demo_panels, ncurses | ✓ |  |  |
| `move_panel` | demo_panels, ncurses | ✓ |  |  |
| `new_panel` | cardfile, demo_panels, ncurses | ✓ |  |  |
| `panel_above` | demo_panels |  |  |  |
| `panel_below` | demo_panels |  |  |  |
| `panel_hidden` | demo_panels |  |  |  |
| `panel_userptr` | demo_panels, ncurses | ✓ |  |  |
| `panel_window` | cardfile, demo_panels, ncurses | ✓ |  |  |
| `replace_panel` | demo_panels | ✓ |  |  |
| `set_panel_userptr` | demo_panels, ncurses | ✓ |  |  |
| `show_panel` | demo_panels, ncurses | ✓ |  |  |
| `top_panel` | cardfile, demo_panels, ncurses | ✓ |  |  |
| `update_panels` | cardfile, demo_panels, ncurses | ✓ |  |  |
| `update_panels_sp` | – |  |  |  |

## menus

| symbol | official tests | howto | htop | python |
|---|---|---|---|---|
| `current_item` | demo_menus, ncurses | ✓ |  |  |
| `free_item` | demo_menus, ncurses | ✓ |  |  |
| `free_menu` | demo_menus, ncurses | ✓ |  |  |
| `item_count` | demo_menus | ✓ |  |  |
| `item_description` | – |  |  |  |
| `item_index` | demo_menus, ncurses |  |  |  |
| `item_init` | – |  |  |  |
| `item_name` | demo_menus, ncurses | ✓ |  |  |
| `item_opts` | – |  |  |  |
| `item_opts_off` | – | ✓ |  |  |
| `item_opts_on` | – |  |  |  |
| `item_term` | – |  |  |  |
| `item_userptr` | demo_menus | ✓ |  |  |
| `item_value` | demo_menus, ncurses | ✓ |  |  |
| `item_visible` | – |  |  |  |
| `menu_back` | – |  |  |  |
| `menu_driver` | demo_menus, ncurses | ✓ |  |  |
| `menu_fore` | – |  |  |  |
| `menu_format` | – |  |  |  |
| `menu_grey` | – |  |  |  |
| `menu_init` | – |  |  |  |
| `menu_items` | demo_menus, ncurses | ✓ |  |  |
| `menu_mark` | demo_menus |  |  |  |
| `menu_opts` | – |  |  |  |
| `menu_opts_off` | demo_menus, ncurses | ✓ |  |  |
| `menu_opts_on` | demo_menus |  |  |  |
| `menu_pad` | – |  |  |  |
| `menu_pattern` | demo_menus |  |  |  |
| `menu_request_by_name` | – |  |  |  |
| `menu_request_name` | – |  |  |  |
| `menu_spacing` | demo_menus |  |  |  |
| `menu_sub` | demo_menus |  |  |  |
| `menu_term` | – |  |  |  |
| `menu_userptr` | – |  |  |  |
| `menu_win` | demo_menus, ncurses |  |  |  |
| `new_item` | demo_menus, ncurses | ✓ |  |  |
| `new_menu` | demo_menus, ncurses | ✓ |  |  |
| `new_menu_sp` | – |  |  |  |
| `pos_menu_cursor` | – | ✓ |  |  |
| `post_menu` | demo_menus, ncurses | ✓ |  |  |
| `scale_menu` | demo_menus, ncurses |  |  |  |
| `set_current_item` | – |  |  |  |
| `set_item_init` | demo_menus |  |  |  |
| `set_item_opts` | – |  |  |  |
| `set_item_term` | demo_menus |  |  |  |
| `set_item_userptr` | demo_menus | ✓ |  |  |
| `set_item_value` | demo_menus, ncurses |  |  |  |
| `set_menu_back` | demo_menus | ✓ |  |  |
| `set_menu_fore` | demo_menus | ✓ |  |  |
| `set_menu_format` | demo_menus, ncurses | ✓ |  |  |
| `set_menu_grey` | – | ✓ |  |  |
| `set_menu_init` | demo_menus |  |  |  |
| `set_menu_items` | – |  |  |  |
| `set_menu_mark` | demo_menus | ✓ |  |  |
| `set_menu_opts` | – |  |  |  |
| `set_menu_pad` | – |  |  |  |
| `set_menu_pattern` | – |  |  |  |
| `set_menu_spacing` | – |  |  |  |
| `set_menu_sub` | demo_menus, ncurses | ✓ |  |  |
| `set_menu_term` | demo_menus |  |  |  |
| `set_menu_userptr` | – |  |  |  |
| `set_menu_win` | demo_menus, ncurses | ✓ |  |  |
| `set_top_row` | – |  |  |  |
| `top_row` | – |  |  |  |
| `unpost_menu` | demo_menus, ncurses | ✓ |  |  |

## forms

| symbol | official tests | howto | htop | python |
|---|---|---|---|---|
| `current_field` | demo_forms, dup_field, edit_field, move_field, ncurses |  |  |  |
| `data_ahead` | demo_forms |  |  |  |
| `data_behind` | demo_forms |  |  |  |
| `dup_field` | dup_field |  |  |  |
| `dynamic_field_info` | demo_forms |  |  |  |
| `field_arg` | demo_forms |  |  |  |
| `field_back` | demo_forms, edit_field |  |  |  |
| `field_buffer` | cardfile, demo_forms, ncurses |  |  |  |
| `field_count` | demo_forms, dup_field, move_field |  |  |  |
| `field_fore` | demo_forms |  |  |  |
| `field_index` | demo_forms |  |  |  |
| `field_info` | edit_field, ncurses |  |  |  |
| `field_init` | – |  |  |  |
| `field_just` | – |  |  |  |
| `field_opts` | demo_forms, dup_field, move_field, ncurses |  |  |  |
| `field_opts_off` | cardfile, demo_forms, form_driver_w | ✓ |  |  |
| `field_opts_on` | demo_forms |  |  |  |
| `field_pad` | demo_forms |  |  |  |
| `field_status` | demo_forms |  |  |  |
| `field_term` | – |  |  |  |
| `field_type` | demo_forms |  |  |  |
| `field_userptr` | dup_field, edit_field, move_field, ncurses |  |  |  |
| `form_driver` | cardfile, demo_forms, dup_field, edit_field, move_field, ncurses | ✓ |  |  |
| `form_driver_w` | form_driver_w |  |  |  |
| `form_fields` | cardfile, demo_forms, dup_field, move_field |  |  |  |
| `form_init` | – |  |  |  |
| `form_opts` | – |  |  |  |
| `form_opts_off` | – |  |  |  |
| `form_opts_on` | – |  |  |  |
| `form_page` | demo_forms |  |  |  |
| `form_request_by_name` | – |  |  |  |
| `form_request_name` | dup_field, edit_field, move_field |  |  |  |
| `form_sub` | cardfile, demo_forms, dup_field, move_field, ncurses |  |  |  |
| `form_term` | – |  |  |  |
| `form_userptr` | – |  |  |  |
| `form_win` | cardfile, demo_forms, dup_field, edit_field, form_driver_w, move_field …+1 |  |  |  |
| `free_field` | cardfile, demo_forms, dup_field, form_driver_w, move_field, ncurses | ✓ |  |  |
| `free_fieldtype` | ncurses |  |  |  |
| `free_form` | cardfile, demo_forms, dup_field, form_driver_w, move_field, ncurses | ✓ |  |  |
| `link_field` | – |  |  |  |
| `link_fieldtype` | – |  |  |  |
| `move_field` | move_field |  |  |  |
| `new_field` | cardfile, demo_forms, dup_field, form_driver_w, move_field, ncurses | ✓ |  |  |
| `new_fieldtype` | ncurses |  |  |  |
| `new_form` | cardfile, demo_forms, dup_field, form_driver_w, move_field, ncurses | ✓ |  |  |
| `new_form_sp` | – |  |  |  |
| `new_page` | demo_forms |  |  |  |
| `pos_form_cursor` | – |  |  |  |
| `post_form` | cardfile, demo_forms, dup_field, form_driver_w, move_field, ncurses | ✓ |  |  |
| `scale_form` | demo_forms, ncurses | ✓ |  |  |
| `set_current_field` | demo_forms | ✓ |  |  |
| `set_field_back` | cardfile, demo_forms, dup_field, edit_field, form_driver_w, move_field …+1 | ✓ |  |  |
| `set_field_buffer` | cardfile, demo_forms, dup_field, edit_field, move_field, ncurses | ✓ |  |  |
| `set_field_fore` | demo_forms | ✓ |  |  |
| `set_field_init` | – |  |  |  |
| `set_field_just` | cardfile, demo_forms | ✓ |  |  |
| `set_field_opts` | demo_forms, dup_field, move_field, ncurses |  |  |  |
| `set_field_pad` | demo_forms |  |  |  |
| `set_field_status` | demo_forms |  |  |  |
| `set_field_term` | – |  |  |  |
| `set_field_type` | demo_forms, dup_field, move_field, ncurses |  |  |  |
| `set_field_userptr` | edit_field, ncurses |  |  |  |
| `set_fieldtype_arg` | – |  |  |  |
| `set_fieldtype_choice` | – |  |  |  |
| `set_form_fields` | dup_field, move_field |  |  |  |
| `set_form_init` | – |  |  |  |
| `set_form_opts` | – |  |  |  |
| `set_form_page` | – |  |  |  |
| `set_form_sub` | cardfile, demo_forms, ncurses | ✓ |  |  |
| `set_form_term` | – |  |  |  |
| `set_form_userptr` | – |  |  |  |
| `set_form_win` | cardfile, demo_forms, ncurses | ✓ |  |  |
| `set_max_field` | demo_forms |  |  |  |
| `set_new_page` | demo_forms |  |  |  |
| `TYPE_ALNUM` | demo_forms |  |  |  |
| `TYPE_ALPHA` | demo_forms, dup_field, move_field, ncurses |  |  |  |
| `TYPE_ENUM` | demo_forms |  |  |  |
| `TYPE_INTEGER` | demo_forms |  |  |  |
| `TYPE_IPV4` | demo_forms |  |  |  |
| `TYPE_NUMERIC` | demo_forms |  |  |  |
| `TYPE_REGEXP` | demo_forms |  |  |  |
| `unfocus_current_field` | – |  |  |  |
| `unpost_form` | cardfile, demo_forms, dup_field, form_driver_w, move_field, ncurses | ✓ |  |  |

## terminfo

| symbol | official tests | howto | htop | python |
|---|---|---|---|---|
| `acs_map` | back_ground, background, gdc, ins_wide, inserts, knight …+9 |  |  |  |
| `baudrate` | ncurses |  |  | ✓ |
| `baudrate_sp` | sp_tinfo |  |  |  |
| `boolcodes` | demo_termcap, test_arrays, progs:, dump_entry |  |  |  |
| `boolfnames` | demo_terminfo, test_arrays, progs:, dump_entry |  |  |  |
| `boolnames` | demo_terminfo, test_arrays, progs:, dump_entry, infocmp |  |  |  |
| `can_change_color` | color_content, extended_color, ncurses |  |  | ✓ |
| `can_change_color_sp` | extended_color |  |  |  |
| `cur_term` | demo_termcap, demo_terminfo, dots, dots_mvcur, filter, list_keys …+12 |  |  |  |
| `define_key` | demo_altkeys, demo_defkey, foldkeys |  | ✓ | ✓ |
| `define_key_sp` | sp_tinfo |  |  |  |
| `del_curterm` | demo_terminfo, sp_tinfo, test_sgr, test_tparm |  |  |  |
| `del_curterm_sp` | – |  |  |  |
| `exit_terminfo` | demo_termcap, demo_terminfo, dots, dots_mvcur, dots_termcap, list_keys …+7 |  |  |  |
| `get_escdelay` | – |  |  | ✓ |
| `get_escdelay_sp` | – |  |  |  |
| `has_ic` | lrtest, ncurses |  |  | ✓ |
| `has_ic_sp` | sp_tinfo |  |  |  |
| `has_il` | ncurses |  |  | ✓ |
| `has_il_sp` | sp_tinfo |  |  |  |
| `key_defined` | demo_defkey, foldkeys |  |  | ✓ |
| `key_defined_sp` | sp_tinfo |  |  |  |
| `key_name` | key_names, ncurses, test_unget_wch |  |  |  |
| `keybound` | demo_altkeys, demo_defkey |  |  |  |
| `keybound_sp` | sp_tinfo |  |  |  |
| `longname` | ncurses, testcurs, progs:, tput |  |  | ✓ |
| `longname_sp` | sp_tinfo |  |  |  |
| `mvcur` | dots_mvcur, redraw |  | ✓ |  |
| `mvcur_sp` | – |  |  |  |
| `numcodes` | demo_termcap, test_arrays, progs:, dump_entry |  |  |  |
| `numfnames` | demo_terminfo, test_arrays, progs:, dump_entry |  |  |  |
| `numnames` | demo_terminfo, test_arrays, progs:, dump_entry, infocmp |  |  |  |
| `ospeed` | demo_termcap, progs:, tset |  |  |  |
| `putp` | filter, test_mouse, test_sgr, progs:, tput |  |  | ✓ |
| `putp_sp` | sp_tinfo |  |  |  |
| `resetty` | – |  |  | ✓ |
| `resetty_sp` | sp_tinfo |  |  |  |
| `restartterm` | test_setupterm |  |  |  |
| `restartterm_sp` | – |  |  |  |
| `ripoffline` | demo_menus, ncurses |  |  |  |
| `ripoffline_sp` | – |  |  |  |
| `savetty` | – |  |  | ✓ |
| `savetty_sp` | sp_tinfo |  |  |  |
| `set_curterm` | list_keys, sp_tinfo |  |  |  |
| `set_curterm_sp` | sp_tinfo |  |  |  |
| `set_escdelay` | test_opaque |  | ✓ | ✓ |
| `set_escdelay_sp` | – |  |  |  |
| `set_term` | – |  |  | ✓ |
| `setupterm` | demo_terminfo, dots, list_keys, sp_tinfo, test_mouse, test_setupterm …+10 |  |  | ✓ |
| `strcodes` | demo_termcap, test_arrays, progs:, dump_entry |  |  |  |
| `strfnames` | demo_terminfo, list_keys, test_arrays, progs:, dump_entry |  |  |  |
| `strnames` | demo_terminfo, foldkeys, list_keys, test_arrays, test_tparm, progs: …+3 |  |  |  |
| `term_attrs` | ncurses, test_termattrs |  |  | ✓ |
| `term_attrs_sp` | – |  |  |  |
| `termattrs` | ncurses, test_termattrs, testcurs |  |  | ✓ |
| `termattrs_sp` | – |  |  |  |
| `termname` | list_keys, ncurses, testcurs |  |  | ✓ |
| `termname_sp` | sp_tinfo |  |  |  |
| `tgetent` | demo_termcap, dots_termcap, railroad |  |  |  |
| `tgetent_sp` | sp_tinfo |  |  |  |
| `tgetflag` | demo_termcap |  |  |  |
| `tgetflag_sp` | sp_tinfo |  |  |  |
| `tgetnum` | demo_termcap, dots_termcap, railroad |  |  |  |
| `tgetnum_sp` | sp_tinfo |  |  |  |
| `tgetstr` | demo_termcap, dots_termcap, railroad |  |  |  |
| `tgetstr_sp` | sp_tinfo |  |  |  |
| `tgoto` | dots_termcap, railroad, progs:, tic |  |  |  |
| `tigetflag` | demo_terminfo, savescreen, progs:, tic, tput |  |  | ✓ |
| `tigetflag_sp` | sp_tinfo |  |  |  |
| `tigetnum` | demo_tabs, demo_terminfo, dots, dots_mvcur, ncurses, savescreen …+2 |  |  | ✓ |
| `tigetnum_sp` | sp_tinfo |  |  |  |
| `tigetstr` | blue, demo_defkey, demo_new_pair, demo_terminfo, foldkeys, list_keys …+9 |  |  | ✓ |
| `tigetstr_sp` | sp_tinfo |  |  |  |
| `tiparm` | – |  |  |  |
| `tparm` | dots, dots_mvcur, test_mouse, test_sgr, test_tparm, progs: …+2 |  |  | ✓ |
| `tputs` | dots, dots_mvcur, dots_termcap, railroad, test_tparm, test_vid_puts …+5 |  | ✓ |  |
| `tputs_sp` | sp_tinfo |  |  |  |
| `ttytype` | demo_terminfo, test_sgr |  |  |  |
| `use_env` | dots, dots_curses, dots_mvcur, dots_xcurses, ncurses, progs: …+2 |  |  | ✓ |
| `use_env_sp` | sp_tinfo |  |  |  |
| `use_extended_names` | demo_termcap, demo_terminfo, list_keys, progs:, infocmp, tic |  |  |  |
| `use_legacy_coding` | – |  |  |  |
| `use_legacy_coding_sp` | – |  |  |  |
| `use_tioctl` | ncurses, progs:, clear, tput |  |  |  |
| `use_tioctl_sp` | sp_tinfo |  |  |  |

## macros

| symbol | official tests | howto | htop | python |
|---|---|---|---|---|
| `BC` | demo_termcap |  |  |  |
| `COLOR_PAIR` | background, blue, bs, cardfile, clip_printw, demo_forms …+30 | ✓ | ✓ |  |
| `COLOR_PAIRS` | demo_new_pair, dots_curses, dots_xcurses, echochar, ncurses, newdemo …+1 |  |  | ✓ |
| `COLORS` | color_content, demo_new_pair, dots_curses, dots_xcurses, echochar, ncurses …+4 |  |  | ✓ |
| `COLS` | cardfile, combine, demo_altkeys, demo_defkey, demo_forms, demo_keyok …+37 |  |  | ✓ |
| `ESCDELAY` | test_opaque |  |  |  |
| `LINES` | cardfile, combine, demo_defkey, demo_keyok, demo_menus, demo_panels …+36 |  |  | ✓ |
| `PAIR_NUMBER` | dump_window, ncurses |  |  |  |
| `PC` | demo_termcap |  |  |  |
| `SP` | – |  |  |  |
| `TABSIZE` | test_opaque |  |  |  |
| `UP` | demo_termcap |  |  |  |

## misc

| symbol | official tests | howto | htop | python |
|---|---|---|---|---|
| `beep` | blue, bs, cardfile, chgat, clip_printw, demo_forms …+33 |  | ✓ | ✓ |
| `beep_sp` | – |  |  |  |
| `flash` | cardfile, filter, lrtest, movewindow, ncurses, tclock …+1 |  |  | ✓ |
| `flash_sp` | – |  |  |  |

/* C ground-truth reference port for examples/63-clear-refresh.sh */
#include "bc_example.h"

int
main(void)
{
    const char *msg = "waiting";
    WINDOW *win;
    int key;

    bc_example_init(1);

    win = newwin(10, 40, 2, 2);
    box(win, 0, 0);
    mvwprintw(win, 1, 0, "clear/refresh");
    wrefresh(win);

    for (;;) {
	mvprintw(0, 0, "c wclear  t wclrtobot  e wclrtoeol  n wnoutrefresh  d doupdate  s syncup  u syncdown  o notimeout  r raw/noraw  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'c':
	case 'C':
	    wclear(win);
	    msg = "wclear";
	    break;
	case 't':
	case 'T':
	    mvwprintw(win, 2, 0, "bottom");
	    wclrtobot(win);
	    msg = "wclrtobot";
	    break;
	case 'e':
	case 'E':
	    mvwprintw(win, 3, 0, "eol");
	    wclrtoeol(win);
	    msg = "wclrtoeol";
	    break;
	case 'n':
	case 'N':
	    wnoutrefresh(win);
	    doupdate();
	    msg = "wnoutrefresh+doupdate";
	    break;
	case 'd':
	case 'D':
	    doupdate();
	    msg = "doupdate";
	    break;
	case 's':
	case 'S':
	    wsyncup(stdscr);
	    msg = "syncup";
	    break;
	case 'u':
	case 'U':
	    wsyncdown(stdscr);
	    msg = "syncdown";
	    break;
	case 'o':
	case 'O':
	    notimeout(win, TRUE);
	    msg = "notimeout";
	    break;
	case 'r':
	case 'R':
	    raw();
	    noraw();
	    msg = "raw/noraw";
	    break;
	case 'q':
	case 'Q':
	    goto done;
	}
	wrefresh(win);
    }

done:
    endwin();
    return 0;
}

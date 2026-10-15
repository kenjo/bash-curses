/* C ground-truth reference port for examples/69-input-wrappers.sh */
#include "bc_example.h"
#include <stdio.h>

static int
getkey(void)
{
    return wgetch(stdscr);
}

int
main(void)
{
    WINDOW *win;
    const char *msg = "waiting";
    char buf[64];
    int key = 0;

    bc_example_init(1);
    echo();
    curs_set(1);

    win = newwin(10, 30, 2, 2);
    box(win, 0, 0);
    wrefresh(win);

    for (;;) {
	mvprintw(0, 0,
		 "g getkey  w wgetnstr  W wgetstr  m mvwgetnstr  M mvwgetstr  n mvgetnstr  N mvgetstr  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s key=%d", msg, key);
	clrtoeol();
	refresh();
	if (win != NULL) { touchwin(win); wrefresh(win); }

	if ((key = getkey()) == ERR)
	    break;
	switch (key) {
	case 'g':
	case 'G':
	    msg = "getkey";
	    break;
	case 'w':
	    mvwprintw(win, 1, 0, "wgetnstr: ");
	    wgetnstr(win, buf, 5);
	    msg = buf;
	    break;
	case 'W':
	    mvwprintw(win, 2, 0, "wgetstr: ");
	    wgetstr(win, buf);
	    msg = buf;
	    break;
	case 'm':
	    mvwgetnstr(win, 3, 0, buf, 5);
	    msg = buf;
	    break;
	case 'M':
	    mvwgetstr(win, 4, 0, buf);
	    msg = buf;
	    break;
	case 'n':
	    mvgetnstr(15, 0, buf, 5);
	    msg = buf;
	    break;
	case 'N':
	    mvgetstr(16, 0, buf);
	    msg = buf;
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

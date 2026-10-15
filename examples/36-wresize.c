/* C ground-truth reference port for examples/36-wresize.sh */
#include "bc_example.h"
#include <stdio.h>

int
main(void)
{
    WINDOW *win;
    const char *msg = "waiting";
    char rbuf[128];
    int key, my, mx;

    bc_example_init(1);

    win = newwin(8, 20, 2, 2);
    box(win, 0, 0);
    mvwprintw(win, 0, 2, " win ");
    wrefresh(win);

    for (;;) {
	mvprintw(0, 0, "+ grow window  - shrink window  r resize_term  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case '+':
	    wresize(win, 12, 30);
	    wrefresh(win);
	    msg = "wresize 12x30";
	    break;
	case '-':
	    wresize(win, 6, 15);
	    wrefresh(win);
	    msg = "wresize 6x15";
	    break;
	case 'r':
	case 'R': {
	    int nl = LINES - 1, nc = COLS - 1;
	    resize_term(nl, nc);
	    snprintf(rbuf, sizeof(rbuf), "resize_term %dx%d", LINES - 1, COLS - 1);
	    msg = rbuf;
	    break;
	}
	case 'q':
	case 'Q':
	    goto done;
	}

	getmaxyx(win, my, mx);
	mvprintw(2, 0, "window max=(%d,%d) is_term_resized=%s",
		 my, mx, is_term_resized(LINES, COLS) ? "yes" : "no");
	clrtoeol();
	refresh();
    }

done:
    endwin();
    return 0;
}

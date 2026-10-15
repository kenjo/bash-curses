/* C ground-truth reference port for examples/67-scroll-regions-extra.sh */
#include "bc_example.h"
#include <stdio.h>

static int
resizestdscr(int lines, int cols)
{
    return resizeterm(lines, cols);
}

int
main(void)
{
    WINDOW *win;
    const char *msg = "waiting";
    char buf[128];
    int key;

    bc_example_init(1);

    win = newwin(10, 30, 2, 2);
    box(win, 0, 0);
    wrefresh(win);

    for (;;) {
	mvprintw(0, 0,
		 "s setscrreg  u scrl  w wsetscrreg  c wscrl  r resizestdscr  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	refresh();
	if (win != NULL) { touchwin(win); wrefresh(win); }

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 's':
	case 'S':
	    setscrreg(2, 8);
	    msg = "setscrreg 2 8";
	    break;
	case 'u':
	case 'U':
	    scrl(-1);
	    msg = "scrl -1";
	    break;
	case 'w':
	case 'W':
	    wsetscrreg(win, 1, 5);
	    msg = "wsetscrreg 1 5";
	    break;
	case 'c':
	case 'C':
	    wscrl(win, -1);
	    msg = "wscrl -1";
	    break;
	case 'r':
	case 'R':
	    resizestdscr(LINES, COLS);
	    snprintf(buf, sizeof(buf), "resizestdscr %dx%d", LINES, COLS);
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

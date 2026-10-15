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
    const char *msg = "waiting";
    char buf[128];
    int key;

    bc_example_init(1);
    curs_set(0);

    scrollok(stdscr, TRUE);
    setscrreg(2, 8);

    for (;;) {
	mvprintw(0, 0,
		 "u scrl up  d scrl down  s setscrreg  r resizestdscr  c mvcur  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'u':
	case 'U':
	    scrl(-1);
	    msg = "scrl -1";
	    break;
	case 'd':
	case 'D':
	    scrl(1);
	    msg = "scrl 1";
	    break;
	case 's':
	case 'S':
	    if (setscrreg(3, 9) == OK)
		msg = "setscrreg 3 9";
	    else
		msg = "setscrreg failed";
	    break;
	case 'r':
	case 'R':
	    if (resizestdscr(LINES, COLS) == OK) {
		snprintf(buf, sizeof(buf), "resizestdscr %dx%d", LINES, COLS);
		msg = buf;
	    } else {
		msg = "resizestdscr failed";
	    }
	    break;
	case 'c':
	case 'C':
	    move(1, 0);
	    wrefresh(stdscr);
	    msg = "mvcur 1 0";
	    break;
	case 'q':
	case 'Q':
	    goto done;
	}
    }

done:
    endwin();
    return 0;
}

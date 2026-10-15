/* C ground-truth reference port for examples/43-filter.sh */
#include "bc_example.h"
#include <stdio.h>

int
main(void)
{
    const char *msg = "waiting";
    char buf[128];
    int key, filter_on = 0;

    bc_example_init(1);

    for (;;) {
	mvprintw(0, 0, "f filter  n nofilter  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	mvprintw(2, 0, "BC_FILTER=%d LINES=%d COLS=%d", filter_on, LINES, COLS);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'f':
	case 'F':
	    filter();
	    filter_on = 1;
	    msg = "filter set";
	    break;
	case 'n':
	case 'N':
	    nofilter();
	    filter_on = 0;
	    msg = "nofilter set";
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

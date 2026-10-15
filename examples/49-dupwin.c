/* C ground-truth reference port for examples/49-dupwin.sh */
#include "bc_example.h"
#include <stdio.h>

int
main(void)
{
    WINDOW *win;
    const char *msg = "waiting";
    char buf[128];
    int key;

    bc_example_init(1);

    win = newwin(8, 30, 2, 2);
    box(win, 0, 0);
    mvwprintw(win, 0, 2, " orig ");
    wrefresh(win);

    for (;;) {
	mvprintw(0, 0, "d dupwin  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	refresh();
	if (win != NULL) { touchwin(win); wrefresh(win); }

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'd':
	case 'D': {
	    WINDOW *dup = dupwin(win);
	    if (dup != NULL) {
		mvwprintw(dup, 1, 2, " dup ");
		wrefresh(dup);
		snprintf(buf, sizeof(buf), "dupwin -> ok");
	    } else {
		snprintf(buf, sizeof(buf), "dupwin failed");
	    }
	    msg = buf;
	    break;
	}
	case 'q':
	case 'Q':
	    goto done;
	}
    }

done:
    endwin();
    return 0;
}

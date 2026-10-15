/* C ground-truth reference port for examples/35-test-delwin.sh */
#include "bc_example.h"
#include <stdio.h>

int
main(void)
{
    WINDOW *win = NULL;
    char msg[128] = "no window";
    int key;

    bc_example_init(1);

    for (;;) {
	mvprintw(0, 0, "c create window  d delwin  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'c':
	case 'C':
	    if (win == NULL) {
		win = newwin(8, 30, 2, 2);
		box(win, 0, 0);
		mvwprintw(win, 0, 2, " win ");
		wrefresh(win);
		snprintf(msg, sizeof(msg), "created window %p", (void *)win);
	    } else {
		snprintf(msg, sizeof(msg), "window %p already exists", (void *)win);
	    }
	    break;
	case 'd':
	case 'D':
	    if (win != NULL) {
		snprintf(msg, sizeof(msg), "deleted window %p", (void *)win);
		delwin(win);
		win = NULL;
	    } else {
		snprintf(msg, sizeof(msg), "no window to delete");
	    }
	    break;
	case 'q':
	case 'Q':
	    goto done;
	}
    }

done:
    if (win != NULL)
	delwin(win);
    endwin();
    return 0;
}

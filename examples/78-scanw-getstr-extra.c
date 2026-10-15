/* C ground-truth reference port for examples/78-scanw-getstr-extra.sh */
#include "bc_example.h"
#include <stdio.h>

int
main(void)
{
    WINDOW *win;
    const char *msg = "waiting";
    char buf[64];
    int val, count, key;

    bc_example_init(1);
    echo();
    curs_set(1);

    win = newwin(10, 40, 2, 2);
    box(win, 0, 0);
    wrefresh(win);

    for (;;) {
	mvprintw(0, 0, "s mvscanw  w mvwscanw  g wgetstr  q quit");
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
	    val = 0;
	    count = mvscanw(2, 0, "%d", &val);
	    snprintf(buf, sizeof(buf), "mvscanw val=%d count=%d", val, count);
	    msg = buf;
	    break;
	case 'w':
	case 'W':
	    val = 0;
	    count = mvwscanw(win, 3, 0, "%d", &val);
	    snprintf(buf, sizeof(buf), "mvwscanw val=%d count=%d", val, count);
	    msg = buf;
	    break;
	case 'g':
	case 'G':
	    wmove(win, 4, 0);
	    wgetnstr(win, buf, 5);
	    snprintf(buf, sizeof(buf), "wgetstr bc_str=%s", buf);
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

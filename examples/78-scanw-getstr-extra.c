/* C ground-truth reference port for examples/78-scanw-getstr-extra.sh */
#include "bc_example.h"
#include <stdio.h>

int
main(void)
{
    WINDOW *win;
    const char *msg = "waiting";
    char buf[64], msgbuf[128];
    int val, count, key;

    bc_example_init(1);
    echo();
    curs_set(1);

    win = newwin(10, 40, 2, 2);
    box(win, 0, 0);
    wrefresh(win);

    for (;;) {
	mvwprintw(bc_base, 0, 0, "s mvscanw  w mvwscanw  g wgetstr  q quit");
	wclrtoeol(bc_base);
	mvwprintw(bc_base, 1, 0, "%s", msg);
	wclrtoeol(bc_base);
	wrefresh(bc_base);

	if ((key = wgetch(bc_base)) == ERR)
	    break;
	switch (key) {
	case 's':
	case 'S':
	    val = 0;
	    count = mvwscanw(bc_base, 2, 0, "%d", &val);
	    snprintf(msgbuf, sizeof(msgbuf), "mvscanw val=%d count=%d", val, count);
	    msg = msgbuf;
	    break;
	case 'w':
	case 'W':
	    val = 0;
	    count = mvwscanw(win, 3, 0, "%d", &val);
	    snprintf(msgbuf, sizeof(msgbuf), "mvwscanw val=%d count=%d", val, count);
	    msg = msgbuf;
	    break;
	case 'g':
	case 'G':
	    wmove(win, 4, 0);
	    wgetnstr(win, buf, 5);
	    snprintf(msgbuf, sizeof(msgbuf), "wgetstr bc_str=%s", buf);
	    msg = msgbuf;
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

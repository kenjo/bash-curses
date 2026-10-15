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
    char msg[128] = "waiting";
    char buf[64];
    int key;

    bc_example_init(1);
    echo();
    curs_set(1);

    win = newwin(10, 40, 2, 2);
    box(win, 0, 0);
    wrefresh(win);

    for (;;) {
	mvprintw(0, 0,
		 "k getkey  g mvgetch  w mvwgetch  n mvwgetnstr  s mvwgetstr  N mvgetnstr  S mvgetstr  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	refresh();
	if (win != NULL) { touchwin(win); wrefresh(win); }

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'k':
	case 'K':
	    key = getkey();
	    snprintf(msg, sizeof(msg), "getkey key=%d", key);
	    break;
	case 'g':
	case 'G':
	    key = mvgetch(1, 0);
	    snprintf(msg, sizeof(msg), "mvgetch key=%d", key);
	    break;
	case 'w':
	case 'W':
	    noecho();
	    key = mvwgetch(win, 1, 0);
	    echo();
	    snprintf(msg, sizeof(msg), "mvwgetch key=%d", key);
	    break;
	case 'n':
	case 'N':
	    mvwgetnstr(win, 2, 0, buf, 5);
	    snprintf(msg, sizeof(msg), "mvwgetnstr bc_str=%s", buf);
	    break;
	case 's':
	case 'S':
	    mvwgetstr(win, 3, 0, buf);
	    snprintf(msg, sizeof(msg), "mvwgetstr bc_str=%s", buf);
	    break;
	case '1':
	    mvgetnstr(15, 0, buf, 5);
	    snprintf(msg, sizeof(msg), "mvgetnstr bc_str=%s", buf);
	    break;
	case '2':
	    mvgetstr(16, 0, buf);
	    snprintf(msg, sizeof(msg), "mvgetstr bc_str=%s", buf);
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

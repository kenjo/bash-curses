/* C ground-truth reference port for examples/60-attr-get.sh */
#include "bc_example.h"
#include <stdio.h>

int
main(void)
{
    const char *msg = "waiting";
    char buf[128];
    attr_t at;
    short cp;
    int key;

    bc_example_init(1);

    for (;;) {
	mvprintw(0, 0, "s standout  e standend  g attr_get  w wattr_get  a attr_set  o attr_on  f attr_off  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 's':
	case 'S':
	    standout();
	    mvprintw(2, 0, "standout");
	    msg = "standout";
	    break;
	case 'e':
	case 'E':
	    standend();
	    mvprintw(3, 0, "standend");
	    msg = "standend";
	    break;
	case 'g':
	case 'G':
	    at = 0;
	    cp = 0;
	    attr_get(&at, &cp, NULL);
	    snprintf(buf, sizeof(buf), "attr_get attrs=%lu pair=%d", (unsigned long)at, cp);
	    msg = buf;
	    break;
	case 'w':
	case 'W':
	    at = 0;
	    cp = 0;
	    wattr_get(stdscr, &at, &cp, NULL);
	    snprintf(buf, sizeof(buf), "wattr_get attrs=%lu pair=%d", (unsigned long)at, cp);
	    msg = buf;
	    break;
	case 'a':
	case 'A':
	    attr_set(A_BOLD, 1, NULL);
	    mvprintw(4, 0, "attr_set");
	    attr_set(0, 0, NULL);
	    msg = "attr_set A_BOLD pair 1";
	    break;
	case 'o':
	case 'O':
	    attr_on(A_BOLD, NULL);
	    mvprintw(5, 0, "attr_on");
	    attr_off(A_BOLD, NULL);
	    msg = "attr_on A_BOLD";
	    break;
	case 'f':
	case 'F':
	    attr_off(A_BOLD, NULL);
	    mvprintw(6, 0, "attr_off");
	    msg = "attr_off A_BOLD";
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

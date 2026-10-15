/* C ground-truth reference port for examples/45-color-pair.sh */
#include "bc_example.h"
#include <stdio.h>

int
main(void)
{
    const char *msg = "waiting";
    char buf[128];
    int key;

    bc_example_init(1);

    if (has_colors() && start_color() == OK) {
	init_pair(1, 1, 4);
	init_pair(2, 6, 4);
	color_set(1, NULL);
	mvprintw(2, 0, "pair 1: red on blue");
	color_set(2, NULL);
	mvprintw(3, 0, "pair 2: magenta on blue");
	color_set(0, NULL);
	attr_set(0, 1, NULL);
	mvprintw(4, 0, "attr_set pair 1");
	attr_set(0, 0, NULL);
    } else {
	msg = "no colors";
    }

    for (;;) {
	mvprintw(0, 0, "p pair_content  e extended_pair_content  a attr_set pair  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'p':
	case 'P': {
	    short f = 0, b = 0;
	    if (pair_content(1, &f, &b) == OK)
		snprintf(buf, sizeof(buf), "pair_content 1 fg=%d bg=%d", f, b);
	    else
		snprintf(buf, sizeof(buf), "pair_content 1 failed");
	    msg = buf;
	    break;
	}
	case 'e':
	case 'E': {
	    int f = 0, b = 0;
	    if (extended_pair_content(2, &f, &b) == OK)
		snprintf(buf, sizeof(buf), "extended_pair_content 2 fg=%d bg=%d", f, b);
	    else
		snprintf(buf, sizeof(buf), "extended_pair_content 2 failed");
	    msg = buf;
	    break;
	}
	case 'a':
	case 'A':
	    attr_set(0, 2, NULL);
	    mvprintw(5, 0, "attr_set pair 2");
	    attr_set(0, 0, NULL);
	    msg = "attr_set pair 2";
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

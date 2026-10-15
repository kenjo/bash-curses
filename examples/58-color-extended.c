/* C ground-truth reference port for examples/58-color-extended.sh */
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
	use_default_colors();
	assume_default_colors(-1, -1);
	init_extended_color(8, 1000, 0, 0);
	init_extended_pair(3, 8, 8);
    } else {
	msg = "no colors";
    }

    for (;;) {
	mvprintw(0, 0, "c extended_color_content  p extended_pair_content  a alloc_pair  f find_pair  r free_pair  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'c':
	case 'C': {
	    int r = 0, g = 0, b = 0;
	    if (extended_color_content(8, &r, &g, &b) == OK)
		snprintf(buf, sizeof(buf), "extended_color_content 8 r=%d g=%d b=%d", r, g, b);
	    else
		snprintf(buf, sizeof(buf), "extended_color_content 8 failed");
	    msg = buf;
	    break;
	}
	case 'p':
	case 'P': {
	    int f = 0, bg = 0;
	    if (extended_pair_content(3, &f, &bg) == OK)
		snprintf(buf, sizeof(buf), "extended_pair_content 3 fg=%d bg=%d", f, bg);
	    else
		snprintf(buf, sizeof(buf), "extended_pair_content 3 failed");
	    msg = buf;
	    break;
	}
	case 'a':
	case 'A': {
	    int p = alloc_pair(3, 4);
	    if (p != ERR)
		snprintf(buf, sizeof(buf), "alloc_pair -> %d", p);
	    else
		snprintf(buf, sizeof(buf), "alloc_pair failed");
	    msg = buf;
	    break;
	}
	case 'f':
	case 'F': {
	    int p = find_pair(3, 4);
	    if (p != ERR)
		snprintf(buf, sizeof(buf), "find_pair -> %d", p);
	    else
		snprintf(buf, sizeof(buf), "find_pair failed");
	    msg = buf;
	    break;
	}
	case 'r':
	case 'R':
	    if (free_pair(3) == OK)
		msg = "free_pair 3";
	    else
		msg = "free_pair 3 failed";
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

/* C ground-truth reference port for examples/64-slk-extra.sh */
#include "bc_example.h"
#include <stdio.h>

int
main(void)
{
    const char *msg = "waiting";
    char buf[128];
    int key;

    if (slk_init(3) == ERR)
	return 1;
    bc_example_init(1);

    if (has_colors()) {
	start_color();
	init_pair(1, COLOR_YELLOW, COLOR_BLUE);
    }

    slk_set(1, "One", 1);
    slk_set(2, "Two", 1);
    slk_set(3, "Three", 1);
    slk_refresh();

    for (;;) {
	mvprintw(0, 0, "a slk_attr  o slk_attron  f slk_attroff  s slk_attr_set  O slk_attr_on  F slk_attr_off  c slk_color  n slk_noutrefresh  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'a':
	case 'A':
	    snprintf(buf, sizeof(buf), "slk_attr=%lu", (unsigned long)slk_attr());
	    msg = buf;
	    break;
	case 'o':
	case 'O':
	    slk_attron(A_BOLD);
	    msg = "slk_attron A_BOLD";
	    break;
	case 'f':
	case 'F':
	    slk_attroff(A_BOLD);
	    msg = "slk_attroff A_BOLD";
	    break;
	case 's':
	case 'S':
	    if (slk_attr_set(A_BOLD, 1, NULL) == OK)
		msg = "slk_attr_set A_BOLD pair 1";
	    else
		msg = "slk_attr_set failed";
	    break;
	case '1':
	    slk_attr_on(A_BOLD, NULL);
	    msg = "slk_attr_on A_BOLD";
	    break;
	case '2':
	    slk_attr_off(A_BOLD, NULL);
	    msg = "slk_attr_off A_BOLD";
	    break;
	case 'c':
	case 'C':
	    if (slk_color(1) == OK)
		msg = "slk_color 1";
	    else
		msg = "slk_color failed";
	    break;
	case 'n':
	case 'N':
	    slk_noutrefresh();
	    doupdate();
	    msg = "slk_noutrefresh";
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

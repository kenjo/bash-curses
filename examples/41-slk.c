/* C ground-truth reference port for examples/41-slk.sh */
#include "bc_example.h"
#include <stdio.h>

int
main(void)
{
    const char *msg = "waiting";
    char buf[128];
    int key;

    if (slk_init(1) == ERR)
	return 1;
    bc_example_init(1);

    slk_set(1, "Menu", 1);
    slk_set(2, "Edit", 1);
    slk_set(3, "View", 1);
    slk_set(4, "Quit", 1);
    slk_refresh();

    for (;;) {
	mvprintw(0, 0, "c slk_clear  r slk_restore  t slk_touch  l slk_label  a slk_attrset  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'c':
	case 'C':
	    slk_clear();
	    msg = "slk_clear";
	    break;
	case 'r':
	case 'R':
	    slk_restore();
	    msg = "slk_restore";
	    break;
	case 't':
	case 'T':
	    slk_touch();
	    slk_refresh();
	    msg = "slk_touch + slk_refresh";
	    break;
	case 'l':
	case 'L': {
	    char *lab = slk_label(1);
	    snprintf(buf, sizeof(buf), "slk_label 1 -> %s", lab ? lab : "(none)");
	    msg = buf;
	    break;
	}
	case 'a':
	case 'A':
	    slk_attrset((chtype)A_BOLD);
	    slk_touch();
	    slk_refresh();
	    msg = "slk_attrset A_BOLD";
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

/* C ground-truth reference port for examples/66-screen-dump-sp.sh */
#include "bc_example.h"

#define SCR_FILE "tmp/bc_example_scr_dump.dmp"

int
main(void)
{
    const char *msg = "waiting";
    int key;

    bc_example_init(1);

    mvprintw(2, 0, "screen dump");
    refresh();

    for (;;) {
	mvprintw(0, 0,
		 "d scr_dump  i scr_init_sp  r scr_restore_sp  s scr_set_sp  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'd':
	case 'D':
	    if (scr_dump(SCR_FILE) == OK)
		msg = "scr_dump " SCR_FILE;
	    else
		msg = "scr_dump failed";
	    break;
	case 'i':
	case 'I':
	    if (scr_init(SCR_FILE) == OK)
		msg = "scr_init_sp " SCR_FILE;
	    else
		msg = "scr_init_sp failed";
	    break;
	case 'r':
	case 'R':
	    if (scr_restore(SCR_FILE) == OK)
		msg = "scr_restore_sp " SCR_FILE;
	    else
		msg = "scr_restore_sp failed";
	    break;
	case 's':
	case 'S':
	    if (scr_set(SCR_FILE) == OK)
		msg = "scr_set_sp " SCR_FILE;
	    else
		msg = "scr_set_sp failed";
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

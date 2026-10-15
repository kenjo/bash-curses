/* C ground-truth reference port for examples/42-prog-mode.sh */
#include "bc_example.h"

int
main(void)
{
    const char *msg = "waiting";
    int key;

    bc_example_init(1);

    for (;;) {
	mvprintw(0, 0, "d def_prog_mode  r reset_prog_mode  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'd':
	case 'D':
	    def_prog_mode();
	    msg = "def_prog_mode saved current mode";
	    break;
	case 'r':
	case 'R':
	    reset_prog_mode();
	    msg = "reset_prog_mode requested full redraw";
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

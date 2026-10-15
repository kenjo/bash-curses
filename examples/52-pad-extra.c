/* C ground-truth reference port for examples/52-pad-extra.sh */
#include "bc_example.h"

int
main(void)
{
    WINDOW *pad;
    const char *msg = "waiting";
    int pminrow = 0, pmincol = 0, key;

    bc_example_init(1);

    pad = newpad(20, 40);
    mvwaddstr(pad, 0, 0, "pad top");
    mvwaddstr(pad, 19, 0, "pad bottom");

    for (;;) {
	mvprintw(0, 0,
		 "Up Down Left Right  s subpad  p prefresh  n pnoutrefresh  e pechochar  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	mvprintw(2, 0, "pad origin: (%d,%d)", pminrow, pmincol);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case KEY_UP:
	    if (pminrow > 0)
		pminrow--;
	    break;
	case KEY_DOWN:
	    pminrow++;
	    break;
	case KEY_LEFT:
	    if (pmincol > 0)
		pmincol--;
	    break;
	case KEY_RIGHT:
	    pmincol++;
	    break;
	case 's':
	case 'S': {
	    WINDOW *sub = subpad(pad, 5, 10, 2, 2);
	    msg = (sub != NULL && is_pad(sub)) ? "subpad is_pad yes"
					       : "subpad is_pad no";
	    break;
	}
	case 'p':
	case 'P':
	    prefresh(pad, pminrow, pmincol, 3, 0, LINES - 2, COLS - 1);
	    msg = "prefresh";
	    break;
	case 'n':
	case 'N':
	    pnoutrefresh(pad, pminrow, pmincol, 3, 0, LINES - 2, COLS - 1);
	    doupdate();
	    msg = "pnoutrefresh + doupdate";
	    break;
	case 'e':
	case 'E':
	    pechochar(pad, 'X');
	    msg = "pechochar X";
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

/* C ground-truth reference port for examples/39-echochar.sh */
#include "bc_example.h"

int
main(void)
{
    const char *msg = "waiting";
    int key;

    bc_example_init(1);

    for (;;) {
	mvprintw(0, 0, "e echochar  w wechochar  u ungetch  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'e':
	case 'E':
	    echochar('X');
	    msg = "echochar wrote X";
	    break;
	case 'w':
	case 'W':
	    wechochar(stdscr, 'Y');
	    msg = "wechochar wrote Y";
	    break;
	case 'u':
	case 'U':
	    ungetch('Z');
	    msg = "ungetch pushed Z; next wgetch should read it";
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

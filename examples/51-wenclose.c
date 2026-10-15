/* C ground-truth reference port for examples/51-wenclose.sh */
#include "bc_example.h"
#include <stdio.h>

int
main(void)
{
    WINDOW *win;
    const char *msg = "waiting";
    char buf[256];
    int y = 5, x = 10, key;

    bc_example_init(1);

    win = newwin(8, 20, 2, 2);
    box(win, 0, 0);
    wrefresh(win);

    for (;;) {
	mvprintw(0, 0, "u up  d down  l left  r right  t mouse_trafo  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	mvprintw(2, 0, "screen coord: (%d,%d)", y, x);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'u':
	case 'U':
	case 'k':
	    y--;
	    break;
	case 'd':
	case 'D':
	case 'j':
	    y++;
	    break;
	case 'l':
	case 'L':
	case 'h':
	    x--;
	    break;
	case 'r':
	case 'R':
	    x++;
	    break;
	case 't':
	case 'T': {
	    int ty = y, tx = x;
	    if (wenclose(win, y, x))
		snprintf(buf, sizeof(buf), "wenclose inside");
	    else
		snprintf(buf, sizeof(buf), "wenclose outside");
	    if (mouse_trafo(&ty, &tx, TRUE))
		snprintf(buf + strlen(buf), sizeof(buf) - strlen(buf),
			 " mouse_trafo=(%d,%d)", ty, tx);
	    else
		snprintf(buf + strlen(buf), sizeof(buf) - strlen(buf),
			 " mouse_trafo failed");
	    msg = buf;
	    break;
	}
	case 'q':
	case 'Q':
	    goto done;
	}
    }

done:
    endwin();
    return 0;
}

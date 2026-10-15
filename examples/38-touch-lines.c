/* C ground-truth reference port for examples/38-touch-lines.sh */
#include "bc_example.h"

static const char *
yn(int v)
{
    return v ? "yes" : "no";
}

static void
draw_box(int wy, int wx, int wh, int ww)
{
    int y, x;
    for (y = 0; y < wh; y++) {
	for (x = 0; x < ww; x++) {
	    chtype c = ' ';
	    if (y == 0)
		c = (x == 0) ? ACS_ULCORNER :
		    (x == ww - 1) ? ACS_URCORNER : ACS_HLINE;
	    else if (y == wh - 1)
		c = (x == 0) ? ACS_LLCORNER :
		    (x == ww - 1) ? ACS_LRCORNER : ACS_HLINE;
	    else
		c = (x == 0 || x == ww - 1) ? ACS_VLINE : ' ';
	    mvaddch(wy + y, wx + x, c);
	}
    }
}

int
main(void)
{
    WINDOW *win;
    const char *msg = "waiting";
    int key;

    bc_example_init(1);

    win = newwin(10, 40, 2, 2);
    box(win, 0, 0);

    draw_box(2, 2, 10, 40);

    for (;;) {
	mvprintw(0, 0, "t touchwin  u untouchwin  l touchline  w wtouchln  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	mvprintw(2, 0, "is_wintouched=%s line2=%s line3=%s line5=%s",
		 yn(is_wintouched(win)),
		 yn(is_linetouched(win, 2)),
		 yn(is_linetouched(win, 3)),
		 yn(is_linetouched(win, 5)));
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 't':
	case 'T':
	    touchwin(win);
	    msg = "touchwin";
	    break;
	case 'u':
	case 'U':
	    untouchwin(win);
	    msg = "untouchwin";
	    break;
	case 'l':
	case 'L':
	    touchline(win, 3, 4);
	    msg = "touchline start=3 count=4";
	    break;
	case 'w':
	case 'W':
	    wtouchln(win, 5, 3, 1);
	    msg = "wtouchln y=5 count=3 changed=1";
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

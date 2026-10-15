/* C ground-truth reference port for examples/38-touch-lines.sh */
#include "bc_example.h"

static const char *
yn(int v)
{
    return v ? "yes" : "no";
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
    wrefresh(win);

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
	if (win != NULL) { touchwin(win); wrefresh(win); }

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

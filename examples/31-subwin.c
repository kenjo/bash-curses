/* C ground-truth reference port for examples/31-subwin.sh */
#include "bc_example.h"
#include <stdio.h>

int
main(void)
{
    WINDOW *parent, *child;
    const char *msg = "waiting";
    char buf[256];
    int key, by, bx, my, mx, py, px;

    bc_example_init(1);

    parent = newwin(12, 40, 2, 2);
    box(parent, 0, 0);
    mvwprintw(parent, 0, 2, " parent ");
    wrefresh(parent);

    child = subwin(parent, 6, 20, 5, 5);
    box(child, 0, 0);
    mvwprintw(child, 0, 2, " child ");
    wrefresh(child);

    for (;;) {
	mvprintw(0, 0, "p parent info  c child info  m mvderwin  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	wnoutrefresh(stdscr);
	touchwin(parent); wnoutrefresh(parent);
	touchwin(child); wnoutrefresh(child);
	doupdate();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'p':
	case 'P':
	    getbegyx(parent, by, bx);
	    getmaxyx(parent, my, mx);
	    snprintf(buf, sizeof(buf), "parent beg=(%d,%d) max=(%d,%d)",
		     by, bx, my, mx);
	    msg = buf;
	    break;
	case 'c':
	case 'C': {
	    WINDOW *par = wgetparent(child);
	    py = getpary(child);
	    px = getparx(child);
	    snprintf(buf, sizeof(buf),
		     "child parent=%p beg=(%d,%d) is_subwin=%s",
		     (void *)par, py, px, par ? "yes" : "no");
	    msg = buf;
	    break;
	}
	case 'm':
	case 'M':
	    mvderwin(child, 2, 2);
	    wrefresh(parent);
	    wrefresh(child);
	    msg = "mvderwin child to parent-relative (2,2)";
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

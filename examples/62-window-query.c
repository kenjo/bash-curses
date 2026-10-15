/* C ground-truth reference port for examples/62-window-query.sh */
#include "bc_example.h"
#include <stdio.h>

static int
has_named_color(const char *name)
{
    (void)name;
    return has_colors();
}

int
main(void)
{
    const char *msg = "waiting";
    char buf[128];
    WINDOW *win;
    int key;

    bc_example_init(1);

    win = newwin(8, 30, 2, 2);
    box(win, 0, 0);
    mvwprintw(win, 1, 1, "query");
    wrefresh(win);

    for (;;) {
	mvprintw(0, 0, "c cursor  b begin  m max  a attrs  k bkgd  d derwin  e isendwin  h has_named_color  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'c':
	case 'C':
	    snprintf(buf, sizeof(buf), "cursor y=%d x=%d", getcury(win), getcurx(win));
	    msg = buf;
	    break;
	case 'b':
	case 'B':
	    snprintf(buf, sizeof(buf), "begin y=%d x=%d", getbegy(win), getbegx(win));
	    msg = buf;
	    break;
	case 'm':
	case 'M':
	    snprintf(buf, sizeof(buf), "max y=%d x=%d", getmaxy(win), getmaxx(win));
	    msg = buf;
	    break;
	case 'a':
	case 'A':
	    snprintf(buf, sizeof(buf), "attrs=%lu", (unsigned long)getattrs(win));
	    msg = buf;
	    break;
	case 'k':
	case 'K': {
	    chtype b = getbkgd(win);
	    snprintf(buf, sizeof(buf), "bkgd=%lu a=%lu p=%d",
		     (unsigned long)b,
		     (unsigned long)(b & A_ATTRIBUTES),
		     PAIR_NUMBER(b));
	    msg = buf;
	    break;
	}
	case 'd':
	case 'D': {
	    WINDOW *sub = derwin(win, 4, 10, 3, 3);
	    if (sub != NULL) {
		mvwprintw(sub, 0, 0, "derwin");
		wrefresh(sub);
		msg = "derwin ok";
	    } else {
		msg = "derwin failed";
	    }
	    break;
	}
	case 'e':
	case 'E':
	    if (isendwin())
		msg = "isendwin yes";
	    else
		msg = "isendwin no";
	    break;
	case 'h':
	case 'H':
	    if (has_named_color("red"))
		msg = "has_named_color yes";
	    else
		msg = "has_named_color no";
	    break;
	case 'q':
	case 'Q':
	    goto done;
	}
	wrefresh(win);
    }

done:
    endwin();
    return 0;
}

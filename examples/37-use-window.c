/* C ground-truth reference port for examples/37-use-window.sh */
#include "bc_example.h"
#include <stdio.h>

static int
win_cb(WINDOW *w, void *d)
{
    (void)w;
    (void)d;
    return OK;
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
    WINDOW *win1, *win2, *cur = NULL;
    int cur_id = 0;
    const char *msg = "waiting";
    char buf[128];
    int key;

    bc_example_init(1);

    win1 = newwin(8, 30, 2, 2);
    box(win1, 0, 0);
    win2 = newwin(8, 30, 12, 2);
    box(win2, 0, 0);

    draw_box(2, 2, 8, 30);
    mvprintw(2, 4, " win1 ");
    draw_box(12, 2, 8, 30);
    mvprintw(12, 4, " win2 ");

    for (;;) {
	mvprintw(0, 0, "1 use win1  2 use win2  s wsyncup  d wsyncdown  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	mvprintw(2, 0, "current window: %d", cur_id);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case '1': {
	    WINDOW *prev = cur;
	    use_window(win1, win_cb, NULL);
	    cur = win1;
	    cur_id = 1;
	    snprintf(buf, sizeof(buf), "use_window win1 previous=%p", (void *)prev);
	    msg = buf;
	    break;
	}
	case '2': {
	    WINDOW *prev = cur;
	    use_window(win2, win_cb, NULL);
	    cur = win2;
	    cur_id = 2;
	    snprintf(buf, sizeof(buf), "use_window win2 previous=%p", (void *)prev);
	    msg = buf;
	    break;
	}
	case 's':
	case 'S':
	    wsyncup(cur ? cur : stdscr);
	    msg = "wsyncup current window";
	    break;
	case 'd':
	case 'D':
	    wsyncdown(cur ? cur : stdscr);
	    msg = "wsyncdown current window";
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

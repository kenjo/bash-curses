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

int
main(void)
{
    WINDOW *win1, *win2, *cur = NULL;
    const char *cur_name = "none";
    const char *msg = "waiting";
    char buf[128];
    int key;

    bc_example_init(1);

    win1 = newwin(8, 30, 2, 2);
    box(win1, 0, 0);
    mvwprintw(win1, 0, 2, " win1 ");
    wrefresh(win1);

    win2 = newwin(8, 30, 12, 2);
    box(win2, 0, 0);
    mvwprintw(win2, 0, 2, " win2 ");
    wrefresh(win2);

    for (;;) {
	mvprintw(0, 0, "1 use win1  2 use win2  s wsyncup  d wsyncdown  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	mvprintw(2, 0, "current window: %s", cur_name);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case '1': {
	    WINDOW *prev = cur;
	    use_window(win1, win_cb, NULL);
	    cur = win1;
	    cur_name = "win1";
	    snprintf(buf, sizeof(buf), "use_window win1 previous=%p", (void *)prev);
	    msg = buf;
	    break;
	}
	case '2': {
	    WINDOW *prev = cur;
	    use_window(win2, win_cb, NULL);
	    cur = win2;
	    cur_name = "win2";
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

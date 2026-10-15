/* C ground-truth reference port for examples/57-mouse-extra.sh */
#include "bc_example.h"
#include <stdio.h>

int
main(void)
{
    const char *msg = "waiting";
    char buf[128];
    mmask_t oldmask = 0, curmask;
    int interval = 200;
    MEVENT ev;
    int key;

    bc_example_init(1);

    curmask = mousemask(ALL_MOUSE_EVENTS, &oldmask);
    mouseinterval(200);

    for (;;) {
	mvprintw(0, 0, "i mouseinterval  h has_mouse  u ungetmouse  s mouse_set  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	mvprintw(2, 0, "mouse mask=%lu interval=%d", (unsigned long)curmask, interval);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	if (key == KEY_MOUSE) {
	    while (getmouse(&ev) == OK) {
		snprintf(buf, sizeof(buf), "mouse x=%d y=%d bstate=%lu",
			 ev.x, ev.y, (unsigned long)ev.bstate);
		msg = buf;
	    }
	}
	switch (key) {
	case 'i':
	case 'I': {
	    int old = mouseinterval(100);
	    interval = 100;
	    snprintf(buf, sizeof(buf), "mouseinterval 100 old=%d", old);
	    msg = buf;
	    break;
	}
	case 'h':
	case 'H':
	    if (has_mouse())
		msg = "has_mouse yes";
	    else
		msg = "has_mouse no";
	    break;
	case 'u':
	case 'U':
	    ev.x = 5;
	    ev.y = 6;
	    ev.bstate = BUTTON1_PRESSED;
	    ungetmouse(&ev);
	    msg = "ungetmouse queued";
	    break;
	case 's':
	case 'S':
	    curmask = mousemask(ALL_MOUSE_EVENTS, NULL);
	    msg = "mouse_set ALL_MOUSE_EVENTS";
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

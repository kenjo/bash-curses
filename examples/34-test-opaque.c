/* C ground-truth reference port for examples/34-test-opaque.sh */
#include "bc_example.h"
#include <stdio.h>

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
    int key, top, bottom, delay;

    bc_example_init(1);

    win = newwin(12, 60, 2, 2);
    box(win, 0, 0);
    wrefresh(win);

    for (;;) {
	mvprintw(0, 0, "c clearok  i idcok  l idlok  m immedok  v leaveok  s syncok  n nodelay  t timeout  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();

	mvprintw(3, 0, "is_cleared=%s is_idcok=%s is_idlok=%s is_immedok=%s",
		 yn(is_cleared(win)), yn(is_idcok(win)),
		 yn(is_idlok(win)), yn(is_immedok(win)));
	clrtoeol();
	mvprintw(4, 0, "is_leaveok=%s is_syncok=%s is_scrollok=%s",
		 yn(is_leaveok(win)), yn(is_syncok(win)), yn(is_scrollok(win)));
	clrtoeol();
	mvprintw(5, 0, "is_nodelay=%s is_notimeout=%s",
		 yn(is_nodelay(win)), yn(is_notimeout(win)));
	clrtoeol();

	delay = wgetdelay(win);
	wgetscrreg(win, &top, &bottom);
	mvprintw(6, 0, "delay=%d scrreg=%d,%d", delay, top, bottom);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'c':
	case 'C':
	    clearok(win, TRUE);
	    msg = "clearok on";
	    break;
	case 'i':
	case 'I':
	    idcok(win, TRUE);
	    msg = "idcok on";
	    break;
	case 'l':
	case 'L':
	    idlok(win, TRUE);
	    msg = "idlok on";
	    break;
	case 'm':
	case 'M':
	    immedok(win, TRUE);
	    msg = "immedok on";
	    break;
	case 'v':
	case 'V':
	    leaveok(win, TRUE);
	    msg = "leaveok on";
	    break;
	case 's':
	case 'S':
	    syncok(win, TRUE);
	    msg = "syncok on";
	    break;
	case 'n':
	case 'N':
	    nodelay(win, TRUE);
	    msg = "nodelay on";
	    break;
	case 't':
	case 'T':
	    timeout(250);
	    msg = "timeout 250";
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

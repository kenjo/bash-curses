/* C ground-truth reference port for examples/24-mouse-buttons.sh */
#include <ncursesw/ncurses.h>
#include <stdlib.h>
#include <string.h>
#include <locale.h>

int
main(void)
{
    WINDOW *win;
    MEVENT me;
    int key;

    setlocale(LC_ALL, "");
    initscr();
    cbreak();
    noecho();
    keypad(stdscr, TRUE);
    curs_set(0);
    mousemask(ALL_MOUSE_EVENTS, NULL);

    win = newwin(10, 40, 2, 2);
    box(win, 0, 0);
    mvwprintw(win, 0, 2, " Mouse target ");
    mvwprintw(win, 2, 2, "Click inside or outside this box.");
    wrefresh(win);

    for (;;) {
	mvprintw(0, 0, "ALL_MOUSE_EVENTS enabled; q quit");
	clrtoeol();
	refresh();
	if (win != NULL) { touchwin(win); wrefresh(win); }

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case KEY_MOUSE:
	    while (getmouse(&me) == OK) {
		int wy, wx;
		const char *inside;
		int y = me.y, x = me.x;
		if (wmouse_trafo(win, &y, &x, FALSE)) {
		    wy = y;
		    wx = x;
		    inside = "yes";
		} else {
		    wy = -1;
		    wx = -1;
		    inside = "no";
		}
		mvprintw(LINES - 3, 0,
			 "mouse id=%d screen=(%d,%d) win=(%d,%d) inside=%s",
			 me.id, me.x, me.y, wy, wx, inside);
		clrtoeol();
		mvprintw(LINES - 2, 0, "bstate=%lu", (unsigned long)me.bstate);
		clrtoeol();
	    }
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

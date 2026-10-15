/* C ground-truth reference port for examples/61-string-wrappers.sh */
#include "bc_example.h"

static int
bc_winsn(WINDOW *win, int y, int x, int n, const char *str)
{
    char pad[256];
    int i, len = (int)strlen(str);

    if (n <= 0)
	return mvwaddstr(win, y, x, str);
    for (i = 0; i < n && i < (int)sizeof(pad) - 1; i++)
	pad[i] = (i < len) ? str[i] : ' ';
    pad[i] = '\0';
    return mvwaddnstr(win, y, x, pad, n);
}

int
main(void)
{
    const char *msg = "waiting";
    WINDOW *win;
    int key;

    bc_example_init(1);

    win = newwin(10, 40, 2, 2);
    box(win, 0, 0);
    mvwprintw(win, 1, 0, "window");
    wrefresh(win);

    for (;;) {
	mvprintw(0, 0, "a addstr  n addnstr  m mvaddstr  b mvaddnstr  w waddnstr  c waddch  s waddstr  i winsn  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	refresh();
	if (win != NULL) { touchwin(win); wrefresh(win); }

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'a':
	case 'A':
	    addstr("addstr");
	    msg = "addstr";
	    break;
	case 'n':
	case 'N':
	    addnstr("addnstr", 6);
	    msg = "addnstr 6";
	    break;
	case 'm':
	case 'M':
	    mvaddstr(3, 0, "mvaddstr");
	    msg = "mvaddstr";
	    break;
	case 'b':
	case 'B':
	    mvaddnstr(4, 0, "mvaddnstr", 6);
	    msg = "mvaddnstr 6";
	    break;
	case 'w':
	case 'W':
	    waddnstr(win, "waddnstr", 6);
	    msg = "waddnstr 6";
	    break;
	case 'c':
	case 'C':
	    waddch(win, 'X');
	    msg = "waddch X";
	    break;
	case 's':
	case 'S':
	    waddstr(win, "waddstr");
	    msg = "waddstr";
	    break;
	case 'i':
	case 'I':
	    bc_winsn(win, 5, 0, 4, "ins");
	    msg = "winsn ins 4";
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

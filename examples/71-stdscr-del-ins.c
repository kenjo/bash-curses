/* C ground-truth reference port for examples/71-stdscr-del-ins.sh */
#include "bc_example.h"

int
main(void)
{
    WINDOW *win;
    const char *msg = "waiting";
    int key;

    bc_example_init(1);

    win = newwin(10, 40, 2, 2);
    box(win, 0, 0);
    mvwprintw(win, 2, 0, "delete");
    mvwprintw(win, 3, 0, "insert");
    wrefresh(win);

    for (;;) {
	mvprintw(0, 0,
		 "d delch  D mvdelch  w mvwdelch  W wdelch  i insch  I mvinsch  m mvwinsch  M winsch  s insstr  S mvinsstr  n mvwinsstr  N mvinsnstr  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	refresh();
	if (win != NULL) { touchwin(win); wrefresh(win); }

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'd':
	case 'D':
	    delch();
	    msg = "delch";
	    break;
	case '1':
	    mvdelch(2, 0);
	    msg = "mvdelch 2 0";
	    break;
	case 'w':
	case 'W':
	    mvwdelch(win, 2, 0);
	    msg = "mvwdelch win 2 0";
	    break;
	case '2':
	    wdelch(win);
	    msg = "wdelch win";
	    break;
	case 'i':
	case 'I':
	    insch('X');
	    msg = "insch X";
	    break;
	case '3':
	    mvinsch(3, 0, 'Y');
	    msg = "mvinsch 3 0 Y";
	    break;
	case 'm':
	case 'M':
	    mvwinsch(win, 3, 0, 'Z');
	    msg = "mvwinsch win 3 0 Z";
	    break;
	case '4':
	    winsch(win, 'Q');
	    msg = "winsch win Q";
	    break;
	case 's':
	case 'S':
	    insstr("ins");
	    msg = "insstr ins";
	    break;
	case '5':
	    mvinsstr(4, 0, "ins");
	    msg = "mvinsstr 4 0 ins";
	    break;
	case 'n':
	case 'N':
	    mvwinsstr(win, 4, 0, "ins");
	    msg = "mvwinsstr win 4 0 ins";
	    break;
	case '6':
	    mvwinsnstr(win, 5, 0, "ins", 3);
	    msg = "mvinsnstr win 5 0 3 ins";
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

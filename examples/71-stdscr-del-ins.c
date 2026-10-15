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
	mvwprintw(bc_base, 0, 0,
		  "d delch  D mvdelch  w mvwdelch  W wdelch  i insch  I mvinsch  m mvwinsch  M winsch  s insstr  S mvinsstr  n mvwinsstr  N mvinsnstr  q quit");
	wclrtoeol(bc_base);
	mvwprintw(bc_base, 1, 0, "%s", msg);
	wclrtoeol(bc_base);
	wrefresh(bc_base);

	if ((key = wgetch(bc_base)) == ERR)
	    break;
	switch (key) {
	case 'd':
	case 'D':
	    wdelch(bc_base);
	    msg = "delch";
	    break;
	case '1':
	    mvwdelch(bc_base, 2, 0);
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
	    winsch(bc_base, 'X');
	    msg = "insch X";
	    break;
	case '3':
	    mvwinsch(bc_base, 3, 0, 'Y');
	    msg = "mvinsch 3 0 Y";
	    break;
	case 'm':
	case 'M':
	    mvwinsch(win, 3, 0, 'Z');
	    wmove(win, 3, 1);
	    msg = "mvwinsch win 3 0 Z";
	    break;
	case '4':
	    winsch(win, 'Q');
	    msg = "winsch win Q";
	    break;
	case 's':
	case 'S':
	    winsstr(bc_base, "ins");
	    msg = "insstr ins";
	    break;
	case '5':
	    mvwinsstr(bc_base, 4, 0, "ins");
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

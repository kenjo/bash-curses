/* C ground-truth reference port for examples/73-stdscr-add.c */
#include "bc_example.h"

static void
mkchstr(chtype *arr, const char *s)
{
    int i;
    for (i = 0; s[i]; i++)
	arr[i] = (chtype)(unsigned char)s[i];
    arr[i] = 0;
}

int
main(void)
{
    WINDOW *win;
    const char *msg = "waiting";
    chtype s_addchstr[16], s_addchnstr[16], s_mvaddchstr[16],
	s_mvaddchnstr[16], s_mvwaddchstr[16], s_mvwaddchnstr[16];
    int key;

    bc_example_init(1);

    win = newwin(10, 40, 2, 2);
    box(win, 0, 0);
    wrefresh(win);

    mkchstr(s_addchstr, "addchstr");
    mkchstr(s_addchnstr, "addchnstr");
    mkchstr(s_mvaddchstr, "mvaddchstr");
    mkchstr(s_mvaddchnstr, "mvaddchnstr");
    mkchstr(s_mvwaddchstr, "mvwaddchstr");
    mkchstr(s_mvwaddchnstr, "mvwaddchnstr");

    for (;;) {
	mvwprintw(bc_base, 0, 0,
		  "a addch  A mvaddch  m mvwaddch  M waddch  n addchstr  N addchnstr  r mvaddchstr  s mvaddchnstr  t mvwaddchstr  u mvwaddchnstr  v addnstr  w addstr  q quit");
	wclrtoeol(bc_base);
	mvwprintw(bc_base, 1, 0, "%s", msg);
	wclrtoeol(bc_base);
	wrefresh(bc_base);

	if ((key = wgetch(bc_base)) == ERR)
	    break;
	switch (key) {
	case 'a':
	case 'A':
	    waddch(bc_base, 'X');
	    msg = "addch X";
	    break;
	case '1':
	    mvwaddch(bc_base, 3, 0, 'Y');
	    msg = "mvaddch 3 0 Y";
	    break;
	case 'm':
	case 'M':
	    mvwaddch(win, 3, 0, 'Z');
	    msg = "mvwaddch win 3 0 Z";
	    break;
	case '2':
	    waddch(win, 'Q');
	    msg = "waddch win Q";
	    break;
	case 'n':
	case 'N':
	    waddchstr(bc_base, s_addchstr);
	    msg = "addchstr";
	    break;
	case '3':
	    waddchnstr(bc_base, s_addchnstr, 6);
	    msg = "addchnstr 6";
	    break;
	case 'r':
	case 'R':
	    mvwaddchstr(bc_base, 4, 0, s_mvaddchstr);
	    msg = "mvaddchstr 4 0";
	    break;
	case 's':
	case 'S':
	    mvwaddchnstr(bc_base, 5, 0, s_mvaddchnstr, 6);
	    msg = "mvaddchnstr 5 0 6";
	    break;
	case 't':
	case 'T':
	    mvwaddchstr(win, 4, 0, s_mvwaddchstr);
	    msg = "mvwaddchstr win 4 0";
	    break;
	case 'u':
	case 'U':
	    mvwaddchnstr(win, 5, 0, s_mvwaddchnstr, 6);
	    msg = "mvwaddchnstr win 5 0 6";
	    break;
	case 'v':
	case 'V':
	    waddnstr(bc_base, "addnstr", 6);
	    msg = "addnstr 6";
	    break;
	case 'w':
	case 'W':
	    waddstr(bc_base, "addstr");
	    msg = "addstr";
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

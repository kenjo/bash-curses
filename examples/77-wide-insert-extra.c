/* C ground-truth reference port for examples/77-wide-insert-extra.sh */
#include "bc_example.h"

static void
mkcch(cchar_t *c, wchar_t w)
{
    wchar_t s[2];
    s[0] = w;
    s[1] = 0;
    setcchar(c, s, A_NORMAL, 0, NULL);
}

int
main(void)
{
    WINDOW *win;
    const char *msg = "waiting";
    cchar_t cx, cy;
    wchar_t wbuf[8];
    int key;

    bc_example_init(1);

    win = newwin(10, 40, 2, 2);
    box(win, 0, 0);
    mvwprintw(win, 2, 0, "base");
    mvwprintw(win, 3, 0, "base");
    mvwprintw(win, 4, 0, "base");
    mvwprintw(win, 5, 0, "base");
    mvwprintw(win, 6, 0, "base");
    wrefresh(win);

    mkcch(&cx, L'X');
    mkcch(&cy, L'Y');
    wbuf[0] = L'w';
    wbuf[1] = L'i';
    wbuf[2] = L'd';
    wbuf[3] = L'e';
    wbuf[4] = 0;

    for (;;) {
	mvwprintw(bc_base, 0, 0,
		  "w wins_wch  W wins_wchnstr  s wins_wchstr  S winsn_wch  n insn_wch  i mvins_wch  I mvins_wchnstr  m mvins_wchstr  M mvinsn_wch  q quit");
	wclrtoeol(bc_base);
	mvwprintw(bc_base, 1, 0, "%s", msg);
	wclrtoeol(bc_base);
	wrefresh(bc_base);

	if ((key = wgetch(bc_base)) == ERR)
	    break;
	switch (key) {
	case 'w':
	case 'W':
	    wmove(win, 6, 4);
	    wins_wch(win, &cx);
	    msg = "wins_wch win X";
	    break;
	case '1':
	    wmove(win, 6, 5);
	    wins_nwstr(win, wbuf, 3);
	    msg = "wins_wchnstr win wide 3";
	    break;
	case 's':
	case 'S':
	    wmove(win, 6, 8);
	    wins_wstr(win, wbuf);
	    msg = "wins_wchstr win wide";
	    break;
	case '2':
	    wmove(win, 6, 12);
	    wins_nwstr(win, wbuf, 3);
	    msg = "winsn_wch win wide 3";
	    break;
	case 'n':
	case 'N':
	    wins_nwstr(bc_base, wbuf, 3);
	    msg = "insn_wch wide 3";
	    break;
	case 'i':
	case 'I':
	    mvwins_wch(bc_base, 3, 0, &cy);
	    msg = "mvins_wch 3 0 Y";
	    break;
	case '3':
	    mvwins_nwstr(bc_base, 4, 0, wbuf, 3);
	    msg = "mvins_wchnstr 4 0 wide 3";
	    break;
	case 'm':
	case 'M':
	    mvwins_wstr(bc_base, 5, 0, wbuf);
	    msg = "mvins_wchstr 5 0 wide";
	    break;
	case '4':
	    mvwins_nwstr(bc_base, 6, 0, wbuf, 3);
	    msg = "mvinsn_wch 6 0 wide 3";
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

/* C ground-truth reference port for examples/48-wide-insert.sh */
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
    cchar_t cx, cy, cz;
    wchar_t wbuf[8];
    int key, i;
    const char *word = "wide";

    bc_example_init(1);

    win = newwin(8, 30, 2, 2);
    box(win, 0, 0);
    mvwprintw(win, 2, 0, "abc");
    wrefresh(win);

    mkcch(&cx, L'X');
    mkcch(&cy, L'Y');
    mkcch(&cz, L'Z');
    for (i = 0; i < 4; i++)
	wbuf[i] = (wchar_t)(unsigned char)word[i];
    wbuf[4] = 0;

    for (;;) {
	mvprintw(0, 0, "w mvwins_wch  i mvwins_wch  m mvwins_wch  n mvwinsn_wch  s mvwins_wchstr  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'w':
	case 'W':
	    mvwins_wch(win, 3, 0, &cx);
	    msg = "mvwins_wch X";
	    break;
	case 'i':
	case 'I':
	    mvwins_wch(win, 4, 0, &cy);
	    msg = "mvwins_wch Y";
	    break;
	case 'm':
	case 'M':
	    mvwins_wch(win, 5, 0, &cz);
	    msg = "mvwins_wch Z";
	    break;
	case 'n':
	case 'N':
	    mvwins_nwstr(win, 6, 0, wbuf, 2);
	    msg = "mvwinsn_wch wide 2";
	    break;
	case 's':
	case 'S':
	    mvwins_wstr(win, 7, 0, wbuf);
	    msg = "mvwins_wchstr wide";
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

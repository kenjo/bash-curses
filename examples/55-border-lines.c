/* C ground-truth reference port for examples/55-border-lines.sh */
#include "bc_example.h"

static void
mkcch(cchar_t *c, wchar_t w)
{
    wchar_t s[2];
    s[0] = w;
    s[1] = 0;
    setcchar(c, s, A_NORMAL, 0, NULL);
}

static int
mvwborder(WINDOW *win, int y, int x, chtype ls, chtype rs, chtype ts,
	  chtype bs, chtype tl, chtype tr, chtype bl, chtype br)
{
    if (wmove(win, y, x) == ERR)
	return ERR;
    return wborder(win, ls, rs, ts, bs, tl, tr, bl, br);
}

int
main(void)
{
    WINDOW *win;
    const char *msg = "waiting";
    cchar_t v, h, tl, tr, bl, br;
    int key;

    bc_example_init(1);

    win = newwin(10, 30, 2, 2);
    wrefresh(win);

    mkcch(&v, L'|');
    mkcch(&h, L'-');
    mkcch(&tl, L'+');
    mkcch(&tr, L'+');
    mkcch(&bl, L'+');
    mkcch(&br, L'+');

    for (;;) {
	mvprintw(0, 0,
		 "b border  x box_set  m mvwborder  h mvwhline_set  v mvwvline_set  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'b':
	case 'B':
	    border('*', '#', '=', '-', '+', '+', '+', '+');
	    msg = "border on stdscr";
	    break;
	case 'x':
	case 'X':
	    wborder_set(win, &v, &v, &h, &h, &tl, &tr, &bl, &br);
	    msg = "box_set on window";
	    break;
	case 'm':
	case 'M':
	    mvwborder(win, 1, 1, '|', '-', '+', '+', '+', '+', '+', '+');
	    msg = "mvwborder at 1,1";
	    break;
	case 'h':
	case 'H':
	    mvwhline_set(win, 3, 2, &v, 10);
	    msg = "mvwhline_set at 3,2";
	    break;
	case 'v':
	case 'V':
	    mvwvline_set(win, 4, 4, &v, 5);
	    msg = "mvwvline_set at 4,4";
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

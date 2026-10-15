/* C ground-truth reference port for examples/68-border-line-extra.sh */
#include "bc_example.h"

static void
mkcch(cchar_t *c, wchar_t w)
{
    wchar_t s[2];
    s[0] = w;
    s[1] = 0;
    setcchar(c, s, A_NORMAL, 0, NULL);
}

/* ncurses has no mvborder here; move stdscr then border it with defaults. */
static int
mvborder(int y, int x)
{
    if (wmove(stdscr, y, x) == ERR)
	return ERR;
    return wborder(stdscr, 0, 0, 0, 0, 0, 0, 0, 0);
}

int
main(void)
{
    WINDOW *win;
    const char *msg = "waiting";
    cchar_t cdash, cpipe;
    int key;

    bc_example_init(1);

    win = newwin(10, 40, 2, 2);
    wrefresh(win);

    mkcch(&cdash, L'-');
    mkcch(&cpipe, L'|');

    for (;;) {
	mvprintw(0, 0,
		 "b wborder  B wborder_set  m mvborder  h whline  v wvline  H hline  V vline  M mvwvline  s whline_set  t wvline_set  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	refresh();
	if (win != NULL) { touchwin(win); wrefresh(win); }

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'b':
	case 'B':
	    wborder(win, 0, 0, 0, 0, 0, 0, 0, 0);
	    msg = "wborder";
	    break;
	case '1':
	    wborder_set(win, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
	    msg = "wborder_set";
	    break;
	case 'm':
	case 'M':
	    mvborder(14, 0);
	    msg = "mvborder 14 0";
	    break;
	case 'h':
	case 'H':
	    mvwhline(win, 2, 0, '-', 10);
	    whline(win, '-', 5);
	    msg = "whline";
	    break;
	case 'v':
	case 'V':
	    mvwvline(win, 2, 12, '|', 5);
	    wvline(win, '|', 3);
	    msg = "wvline";
	    break;
	case '2':
	    mvhline(15, 0, '-', 10);
	    hline('-', 5);
	    msg = "hline";
	    break;
	case '3':
	    mvvline(15, 12, '|', 5);
	    vline('|', 3);
	    msg = "vline";
	    break;
	case '4':
	    mvwvline(win, 3, 14, '|', 4);
	    msg = "mvwvline";
	    break;
	case 's':
	case 'S':
	    whline_set(win, &cdash, 5);
	    msg = "whline_set";
	    break;
	case 't':
	case 'T':
	    wvline_set(win, &cpipe, 3);
	    msg = "wvline_set";
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

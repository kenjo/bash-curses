/* C ground-truth reference port for examples/79-hline-set-extra.sh */
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
    cchar_t cx, cy, cz, cw, cu, ct;
    int key;

    bc_example_init(1);

    win = newwin(10, 40, 2, 2);
    box(win, 0, 0);
    wrefresh(win);

    mkcch(&cx, L'x');
    mkcch(&cy, L'y');
    mkcch(&cz, L'z');
    mkcch(&cw, L'w');
    mkcch(&cu, L'u');
    mkcch(&ct, L't');

    for (;;) {
	mvprintw(0, 0,
		 "h mvhline_set  v mvvline_set  m vline_set  n hline_set  w mvwhline_set  1 mvwvline_set  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'h':
	case 'H':
	    mvhline_set(2, 0, &cx, 10);
	    msg = "mvhline_set 2 0 x 10";
	    break;
	case 'v':
	case 'V':
	    mvvline_set(3, 0, &cy, 5);
	    msg = "mvvline_set 3 0 y 5";
	    break;
	case 'm':
	case 'M':
	    vline_set(&cz, 5);
	    msg = "vline_set z 5";
	    break;
	case 'n':
	case 'N':
	    hline_set(&cw, 10);
	    msg = "hline_set w 10";
	    break;
	case 'w':
	case 'W':
	    mvwhline_set(win, 2, 0, &cu, 10);
	    msg = "mvwhline_set win 2 0 u 10";
	    break;
	case '1':
	    mvwvline_set(win, 3, 0, &ct, 5);
	    msg = "mvwvline_set win 3 0 t 5";
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

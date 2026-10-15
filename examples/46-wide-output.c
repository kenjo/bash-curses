/* C ground-truth reference port for examples/46-wide-output.sh */
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
    const char *msg = "waiting";
    cchar_t ca, cb, cc;
    cchar_t carr[8];
    int key, i;
    const char *word = "wide";

    bc_example_init(1);

    mkcch(&ca, L'A');
    mkcch(&cb, L'B');
    mkcch(&cc, L'C');
    for (i = 0; i < 4; i++)
	mkcch(&carr[i], (wchar_t)(unsigned char)word[i]);

    for (;;) {
	mvprintw(0, 0, "a mvadd_wch  w wadd_wch  n wadd_wchnstr  s wadd_wchstr  e echo_wchar  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'a':
	case 'A':
	    mvadd_wch(2, 0, &ca);
	    msg = "mvadd_wch A";
	    break;
	case 'w':
	case 'W':
	    wadd_wch(stdscr, &cb);
	    msg = "wadd_wch B";
	    break;
	case 'n':
	case 'N':
	    mvwadd_wchnstr(stdscr, 3, 0, carr, 2);
	    msg = "mvwadd_wchnstr wide 2";
	    break;
	case 's':
	case 'S':
	    mvwadd_wchstr(stdscr, 4, 0, carr);
	    msg = "mvwadd_wchstr wide";
	    break;
	case 'e':
	case 'E':
	    echo_wchar(&cc);
	    msg = "echo_wchar C";
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

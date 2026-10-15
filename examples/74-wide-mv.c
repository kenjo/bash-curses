/* C ground-truth reference port for examples/74-wide-mv.sh */
#include "bc_example.h"
#include <stdio.h>

static void
mkcch(cchar_t *c, wchar_t w)
{
    wchar_t s[2];
    s[0] = w;
    s[1] = 0;
    setcchar(c, s, A_NORMAL, 0, NULL);
}

static void
cchars_to_str(const cchar_t *arr, int n, char *out, size_t sz)
{
    size_t o = 0;
    int i;
    for (i = 0; i < n; i++) {
	if (arr[i].chars[0] == 0)
	    break;
	if (o + 1 < sz)
	    out[o++] = (char)arr[i].chars[0];
    }
    out[o] = 0;
}

int
main(void)
{
    WINDOW *win;
    const char *msg = "waiting";
    char sbuf[128];
    cchar_t carr[64], cx, cy, cz, cq;
    wint_t wch = 0;
    int key;

    bc_example_init(1);
    echo();
    curs_set(1);

    win = newwin(10, 30, 2, 2);
    box(win, 0, 0);
    wrefresh(win);

    mkcch(&cx, L'A');
    mkcch(&cy, L'B');
    mkcch(&cz, L'Z');
    mkcch(&cq, L'Q');

    for (;;) {
	mvprintw(0, 0,
		 "a mvadd_wch  w mvwadd_wch  e wecho_wchar  E echo_wchar  g mvwget_wch  G mvget_wch  r mvin_wch  R mvwin_wch  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'a':
	case 'A':
	    mvadd_wch(1, 0, &cx);
	    msg = "mvadd_wch A";
	    break;
	case 'w':
	case 'W':
	    mvwadd_wch(win, 2, 0, &cy);
	    msg = "mvwadd_wch B";
	    break;
	case 'e':
	case 'E':
	    wecho_wchar(win, &cz);
	    msg = "wecho_wchar Z";
	    break;
	case 'x':
	case 'X':
	    echo_wchar(&cq);
	    msg = "echo_wchar Q";
	    break;
	case 'g':
	    mvwprintw(win, 4, 0, "mvwget_wch: ");
	    mvwget_wch(win, 4, 12, &wch);
	    snprintf(sbuf, sizeof(sbuf), "mvwget_wch=%d", (int)wch);
	    msg = sbuf;
	    break;
	case 'G':
	    mvprintw(15, 0, "mvget_wch: ");
	    mvget_wch(15, 11, &wch);
	    snprintf(sbuf, sizeof(sbuf), "mvget_wch=%d", (int)wch);
	    msg = sbuf;
	    break;
	case 'r':
	case 'R':
	    mvin_wch(2, 0, &cx);
	    mvwin_wch(win, 2, 0, &cy);
	    snprintf(sbuf, sizeof(sbuf), "mvin_wch=%c mvwin_wch=%c",
		     (int)cx.chars[0], (int)cy.chars[0]);
	    msg = sbuf;
	    break;
	case 'n':
	case 'N': {
	    char readbuf[128];
	    mvin_wchnstr(2, 0, carr, 3);
	    cchars_to_str(carr, 3, readbuf, sizeof(readbuf));
	    snprintf(sbuf, sizeof(sbuf), "mvin_wchnstr=%s", readbuf);
	    msg = sbuf;
	    break;
	}
	case 'i':
	case 'I': {
	    char readbuf[128];
	    mvwin_wchnstr(win, 2, 0, carr, 3);
	    cchars_to_str(carr, 3, readbuf, sizeof(readbuf));
	    snprintf(sbuf, sizeof(sbuf), "mvwin_wchnstr=%s", readbuf);
	    msg = sbuf;
	    break;
	}
	case 't':
	case 'T': {
	    char readbuf[128];
	    mvin_wchstr(2, 0, carr);
	    cchars_to_str(carr, 10, readbuf, sizeof(readbuf));
	    snprintf(sbuf, sizeof(sbuf), "mvin_wchstr=%s", readbuf);
	    msg = sbuf;
	    break;
	}
	case 's':
	case 'S': {
	    char readbuf[128];
	    mvwin_wchstr(win, 2, 0, carr);
	    cchars_to_str(carr, 10, readbuf, sizeof(readbuf));
	    snprintf(sbuf, sizeof(sbuf), "mvwin_wchstr=%s", readbuf);
	    msg = sbuf;
	    break;
	}
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

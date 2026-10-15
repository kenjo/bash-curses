/* C ground-truth reference port for examples/59-wide-extra.sh */
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
mkcchstr(cchar_t *arr, const char *s)
{
    int i;
    for (i = 0; s[i] != '\0'; i++)
	mkcch(&arr[i], (wchar_t)(unsigned char)s[i]);
    mkcch(&arr[i], 0);
}

static void
carr_to_str(const cchar_t *arr, int n, char *dst, size_t dstsz)
{
    attr_t at;
    short cp;
    wchar_t tmp[2];
    size_t o = 0;
    int i;

    for (i = 0; i < n && o + 1 < dstsz; i++) {
	if (getcchar(&arr[i], tmp, &at, &cp, NULL) == OK && tmp[0] != 0)
	    dst[o++] = (tmp[0] < 128) ? (char)tmp[0] : '?';
    }
    dst[o] = '\0';
}

int
main(void)
{
    const char *msg = "waiting";
    char buf[128];
    char strbuf[64];
    WINDOW *win;
    cchar_t wide[8];
    cchar_t rbuf[4];
    const wchar_t wwide[] = L"wide";
    int key;

    bc_example_init(1);

    win = newwin(10, 40, 2, 2);
    box(win, 0, 0);
    mvwprintw(win, 2, 0, "abc");
    wrefresh(win);

    mkcchstr(wide, "wide");

    for (;;) {
	mvprintw(0, 0, "n mvwadd_wchnstr  a mvwadd_wchstr  i mvwins_wchnstr  s mvwins_wchstr  r mvwin_wchnstr  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	refresh();
	if (win != NULL) { touchwin(win); wrefresh(win); }

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'n':
	case 'N':
	    mvwadd_wchnstr(win, 3, 0, wide, 2);
	    msg = "mvwadd_wchnstr wide 2";
	    break;
	case 'a':
	case 'A':
	    mvwadd_wchstr(win, 4, 0, wide);
	    msg = "mvwadd_wchstr wide";
	    break;
	case 'i':
	case 'I':
	    mvwins_nwstr(win, 5, 0, wwide, 2);
	    msg = "mvwins_wchnstr wide 2";
	    break;
	case 's':
	case 'S':
	    mvwins_nwstr(win, 6, 0, wwide, -1);
	    msg = "mvwins_wchstr wide";
	    break;
	case 'r':
	case 'R':
	    mvwin_wchnstr(win, 2, 0, rbuf, 3);
	    carr_to_str(rbuf, 3, strbuf, sizeof(strbuf));
	    snprintf(buf, sizeof(buf), "mvwin_wchnstr str=%s", strbuf);
	    msg = buf;
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

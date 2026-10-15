/* C ground-truth reference port for examples/74-wide-mv.sh */
#include "bc_example.h"
#include <stdio.h>
#include <wchar.h>

static void
mkcch(cchar_t *c, wchar_t w)
{
    wchar_t s[2];
    s[0] = w;
    s[1] = 0;
    setcchar(c, s, A_NORMAL, 0, NULL);
}

static void
cchars_to_str(const cchar_t *arr, char *out, size_t sz)
{
    static const struct { wchar_t a; const char *u; } acs[] = {
	{L'l', "\xe2\x94\x8c"}, {L'k', "\xe2\x94\x90"},
	{L'm', "\xe2\x94\x94"}, {L'j', "\xe2\x94\x98"},
	{L'q', "\xe2\x94\x80"}, {L'x', "\xe2\x94\x82"},
	{0, NULL}
    };
    size_t o = 0;
    int i;
    mbstate_t ps;
    memset(&ps, 0, sizeof(ps));
    for (i = 0; ; i++) {
	wchar_t w = arr[i].chars[0];
	if (w == 0)
	    break;
	if (arr[i].attr & A_ALTCHARSET) {
	    int k;
	    for (k = 0; acs[k].u; k++) {
		if (acs[k].a == w) {
		    const char *u = acs[k].u;
		    while (*u && o + 1 < sz)
			out[o++] = *u++;
		    break;
		}
	    }
	    continue;
	}
	char mb[MB_CUR_MAX];
	size_t n = wcrtomb(mb, w, &ps);
	if (n == (size_t)-1)
	    continue;
	for (size_t j = 0; j < n && o + 1 < sz; j++)
	    out[o++] = mb[j];
    }
    out[o] = 0;
}

int
main(void)
{
    WINDOW *win;
    const char *msg = "waiting";
    char sbuf[512];
    cchar_t carr[128], wc;
    wchar_t wch = 0;
    int key;

    bc_example_init(1);
    curs_set(1);

    win = newwin(10, 40, 2, 2);
    box(win, 0, 0);
    mvwprintw(win, 2, 0, "abc");
    mvwprintw(bc_base, 2, 0, "xyz");
    wrefresh(win);
    wrefresh(bc_base);

    for (;;) {
	mvwprintw(bc_base, 0, 0,
		  "a mvwadd_wch  A mvadd_wch  w wecho_wchar  W echo_wchar  g mvwget_wch  G mvget_wch  i mvin_wch  I mvwin_wch  n mvin_wchnstr  N mvwin_wchnstr  s mvin_wchstr  S mvwin_wchstr  q quit");
	wclrtoeol(bc_base);
	mvwprintw(bc_base, 1, 0, "%s", msg);
	wclrtoeol(bc_base);
	wrefresh(bc_base);

	if ((key = wgetch(bc_base)) == ERR)
	    break;
	switch (key) {
	case 'a':
	case 'A':
	    mkcch(&wc, L'X');
	    mvwadd_wch(win, 3, 0, &wc);
	    msg = "mvwadd_wch win 3 0 X";
	    break;
	case '1':
	    mkcch(&wc, L'Y');
	    mvwadd_wch(bc_base, 3, 0, &wc);
	    msg = "mvadd_wch 3 0 Y";
	    break;
	case 'w':
	case 'W':
	    mkcch(&wc, L'Z');
	    wecho_wchar(win, &wc);
	    msg = "wecho_wchar win Z";
	    break;
	case '2':
	    mkcch(&wc, L'Q');
	    wecho_wchar(bc_base, &wc);
	    msg = "echo_wchar Q";
	    break;
	case 'g':
	case 'G':
	    if (mvwget_wch(win, 4, 0, &wch) == ERR)
		break;
	    snprintf(sbuf, sizeof(sbuf), "mvwget_wch win 4 0 wch=%lc", wch);
	    msg = sbuf;
	    break;
	case '3':
	    if (mvwget_wch(bc_base, 4, 0, &wch) == ERR)
		break;
	    snprintf(sbuf, sizeof(sbuf), "mvget_wch 4 0 wch=%lc", wch);
	    msg = sbuf;
	    break;
	case 'i':
	case 'I':
	    mvwin_wch(bc_base, 2, 0, &wc);
	    snprintf(sbuf, sizeof(sbuf), "mvin_wch 2 0 wch=%lc", wc.chars[0]);
	    msg = sbuf;
	    break;
	case '4':
	    mvwin_wch(win, 2, 0, &wc);
	    snprintf(sbuf, sizeof(sbuf), "mvwin_wch win 2 0 wch=%lc", wc.chars[0]);
	    msg = sbuf;
	    break;
	case 'n':
	case 'N': {
	    char rb[256];
	    mvwin_wchnstr(bc_base, 2, 0, carr, 3);
	    cchars_to_str(carr, rb, sizeof(rb));
	    snprintf(sbuf, sizeof(sbuf), "mvin_wchnstr 2 0 3 bc_str=%s", rb);
	    msg = sbuf;
	    break;
	}
	case '5': {
	    char rb[256];
	    mvwin_wchnstr(win, 2, 0, carr, 3);
	    cchars_to_str(carr, rb, sizeof(rb));
	    snprintf(sbuf, sizeof(sbuf), "mvwin_wchnstr win 2 0 3 bc_str=%s", rb);
	    msg = sbuf;
	    break;
	}
	case 's':
	case 'S': {
	    char rb[256];
	    mvwin_wchstr(bc_base, 2, 0, carr);
	    cchars_to_str(carr, rb, sizeof(rb));
	    snprintf(sbuf, sizeof(sbuf), "mvin_wchstr 2 0 bc_str=%s", rb);
	    msg = sbuf;
	    break;
	}
	case '6': {
	    char rb[256];
	    mvwin_wchstr(win, 2, 0, carr);
	    cchars_to_str(carr, rb, sizeof(rb));
	    snprintf(sbuf, sizeof(sbuf), "mvwin_wchstr win 2 0 bc_str=%s", rb);
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

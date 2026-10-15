/* C ground-truth reference port for examples/47-wide-input.sh */
#include "bc_example.h"
#include <stdio.h>

static void
cchars_to_str(const cchar_t *arr, int n, char *out, size_t sz)
{
    size_t o = 0;
    int i;
    for (i = 0; i < n; i++) {
	wchar_t w[8];
	attr_t a;
	short p;
	if (getcchar(&arr[i], w, &a, &p, NULL) == ERR)
	    break;
	if (w[0] == 0)
	    break;
	if (o + 1 < sz)
	    out[o++] = (char)w[0];
    }
    out[o] = '\0';
}

int
main(void)
{
    const char *msg = "waiting";
    char buf[256], sbuf[64];
    cchar_t c;
    cchar_t carr[64];
    wint_t wch;
    int key;

    bc_example_init(1);

    mvprintw(2, 0, "ABC");

    for (;;) {
	mvprintw(0, 0, "w wget_wch  g get_wch  m mvwget_wch  i win_wch  n win_wchnstr  s win_wchstr  u unget_wch  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'w':
	case 'W':
	    unget_wch(L'A');
	    if (wget_wch(stdscr, &wch) == OK)
		snprintf(buf, sizeof(buf), "wget_wch wch=%lc", (wchar_t)wch);
	    else
		snprintf(buf, sizeof(buf), "wget_wch ERR");
	    msg = buf;
	    break;
	case 'g':
	case 'G':
	    unget_wch(L'B');
	    if (get_wch(&wch) == OK)
		snprintf(buf, sizeof(buf), "get_wch wch=%lc", (wchar_t)wch);
	    else
		snprintf(buf, sizeof(buf), "get_wch ERR");
	    msg = buf;
	    break;
	case 'm':
	case 'M':
	    unget_wch(L'C');
	    if (mvwget_wch(stdscr, 3, 0, &wch) == OK)
		snprintf(buf, sizeof(buf), "mvwget_wch wch=%lc", (wchar_t)wch);
	    else
		snprintf(buf, sizeof(buf), "mvwget_wch ERR");
	    msg = buf;
	    break;
	case 'i':
	case 'I': {
	    wchar_t w[8];
	    attr_t a = 0;
	    short p = 0;
	    if (win_wch(stdscr, &c) == OK) {
		getcchar(&c, w, &a, &p, NULL);
		snprintf(buf, sizeof(buf), "win_wch wch=%lc attrs=%lu pair=%d",
			 w[0] ? w[0] : L'?', (unsigned long)a, p);
	    } else {
		snprintf(buf, sizeof(buf), "win_wch ERR");
	    }
	    msg = buf;
	    break;
	}
	case 'n':
	case 'N':
	    wmove(stdscr, 2, 0);
	    win_wchnstr(stdscr, carr, 3);
	    cchars_to_str(carr, 3, sbuf, sizeof(sbuf));
	    snprintf(buf, sizeof(buf), "win_wchnstr bc_str=%s", sbuf);
	    msg = buf;
	    break;
	case 's':
	case 'S':
	    wmove(stdscr, 2, 0);
	    win_wchstr(stdscr, carr);
	    cchars_to_str(carr, 3, sbuf, sizeof(sbuf));
	    snprintf(buf, sizeof(buf), "win_wchstr bc_str=%s", sbuf);
	    msg = buf;
	    break;
	case 'u':
	case 'U':
	    unget_wch(L'Z');
	    msg = "unget_wch Z; next wgetch should read it";
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

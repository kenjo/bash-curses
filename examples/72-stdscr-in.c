/* C ground-truth reference port for examples/72-stdscr-in.sh */
#include "bc_example.h"
#include <stdio.h>

static void
chtype_to_str(const chtype *arr, int n, char *out, size_t sz)
{
    size_t o = 0;
    int i;
    for (i = 0; i < n; i++) {
	chtype c = arr[i] & A_CHARTEXT;
	if (c == 0)
	    break;
	if (arr[i] & A_ALTCHARSET) {
	    const char *u;
	    switch (c) {
	    case 'l': u = "\xe2\x94\x8c"; break;
	    case 'k': u = "\xe2\x94\x90"; break;
	    case 'm': u = "\xe2\x94\x94"; break;
	    case 'j': u = "\xe2\x94\x98"; break;
	    case 't': u = "\xe2\x94\x9c"; break;
	    case 'u': u = "\xe2\x94\xa4"; break;
	    case 'v': u = "\xe2\x94\xb4"; break;
	    case 'w': u = "\xe2\x94\xac"; break;
	    case 'q': u = "\xe2\x94\x80"; break;
	    case 'x': u = "\xe2\x94\x82"; break;
	    case 0:   u = ""; break;
	    default:  u = NULL; break;
	    }
	    if (u) {
		while (*u && o + 1 < sz)
		    out[o++] = *u++;
		continue;
	    }
	}
	if (o + 1 < sz)
	    out[o++] = (char)c;
    }
    out[o] = 0;
}

int
main(void)
{
    WINDOW *win;
    const char *msg = "waiting";
    char sbuf[128];
    chtype carr[64], ch = 0;
    int key;

    bc_example_init(1);

    win = newwin(10, 40, 2, 2);
    box(win, 0, 0);
    mvwprintw(win, 2, 0, "abc");
    mvwprintw(bc_base, 2, 0, "xyz");
    wrefresh(win);
    wrefresh(bc_base);

    for (;;) {
	mvwprintw(bc_base, 0, 0,
		  "i inch  I winch  m mvwinch  n inchnstr  N mvwinchnstr  r mvwinchstr  s instr  t innstr  T mvwinnstr  u mvwinstr  q quit");
	wclrtoeol(bc_base);
	mvwprintw(bc_base, 1, 0, "%s", msg);
	wclrtoeol(bc_base);
	wrefresh(bc_base);

	if ((key = wgetch(bc_base)) == ERR)
	    break;
	switch (key) {
	case 'i':
	case 'I':
	    ch = winch(bc_base);
	    snprintf(sbuf, sizeof(sbuf), "inch wch=%c", (int)(ch & A_CHARTEXT));
	    msg = sbuf;
	    break;
	case '1':
	    ch = winch(win);
	    snprintf(sbuf, sizeof(sbuf), "winch wch=%c", (int)(ch & A_CHARTEXT));
	    msg = sbuf;
	    break;
	case 'm':
	case 'M':
	    ch = mvwinch(win, 2, 0);
	    snprintf(sbuf, sizeof(sbuf), "mvwinch win 2 0 wch=%c",
		     (int)(ch & A_CHARTEXT));
	    msg = sbuf;
	    break;
	case 'n':
	case 'N': {
	    char rb[64];
	    winchnstr(bc_base, carr, 3);
	    chtype_to_str(carr, 3, rb, sizeof(rb));
	    snprintf(sbuf, sizeof(sbuf), "inchnstr bc_str=%s", rb);
	    msg = sbuf;
	    break;
	}
	case '2': {
	    char rb[64];
	    mvwinchnstr(win, 2, 0, carr, 3);
	    chtype_to_str(carr, 3, rb, sizeof(rb));
	    snprintf(sbuf, sizeof(sbuf), "mvwinchnstr win 2 0 3 bc_str=%s", rb);
	    msg = sbuf;
	    break;
	}
	case 'r':
	case 'R': {
	    char rb[64];
	    mvwinchstr(win, 2, 0, carr);
	    chtype_to_str(carr, 10, rb, sizeof(rb));
	    snprintf(sbuf, sizeof(sbuf), "mvwinchstr win 2 0 bc_str=%s", rb);
	    msg = sbuf;
	    break;
	}
	case 's':
	case 'S': {
	    char rb[64];
	    winnstr(bc_base, rb, 3);
	    snprintf(sbuf, sizeof(sbuf), "instr stdscr 3 bc_str=%s", rb);
	    msg = sbuf;
	    break;
	}
	case 't':
	case 'T': {
	    char rb[64];
	    winnstr(bc_base, rb, 3);
	    snprintf(sbuf, sizeof(sbuf), "innstr stdscr 3 bc_str=%s", rb);
	    msg = sbuf;
	    break;
	}
	case '3': {
	    char rb[64];
	    mvwinnstr(win, 2, 0, rb, 3);
	    snprintf(sbuf, sizeof(sbuf), "mvwinnstr win 2 0 3 bc_str=%s", rb);
	    msg = sbuf;
	    break;
	}
	case 'u':
	case 'U': {
	    char rb[128];
	    mvwinchstr(win, 2, 0, carr);
	    chtype_to_str(carr, 40, rb, sizeof(rb));
	    snprintf(sbuf, sizeof(sbuf), "mvwinstr win 2 0 bc_str=%s", rb);
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

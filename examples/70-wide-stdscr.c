/* C ground-truth reference port for examples/70-wide-stdscr.sh */
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
mkwstr(cchar_t *arr, const char *s)
{
    int i;
    wchar_t z = 0;
    for (i = 0; s[i]; i++) {
	wchar_t w[2];
	w[0] = (wchar_t)(unsigned char)s[i];
	w[1] = 0;
	setcchar(&arr[i], w, A_NORMAL, 0, NULL);
    }
    setcchar(&arr[i], &z, A_NORMAL, 0, NULL);
}

/* ncurses has no wide ins_wchstr/ins_wchnstr; insert cchars one at a time. */
static int
ins_wchstr(const cchar_t *wstr)
{
    int i;
    for (i = 0; wstr[i].chars[0]; i++)
	if (ins_wch(&wstr[i]) == ERR)
	    return ERR;
    return OK;
}

static int
ins_wchnstr(const cchar_t *wstr, int n)
{
    int i;
    for (i = 0; i < n && wstr[i].chars[0]; i++)
	if (ins_wch(&wstr[i]) == ERR)
	    return ERR;
    return OK;
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
    const char *msg = "waiting";
    char sbuf[128];
    cchar_t wwide[8], wX, rin;
    cchar_t *rd;
    int key;

    bc_example_init(1);

    rd = malloc(sizeof(*rd) * (COLS + 2));

    mvprintw(2, 0, "abc");
    refresh();

    mkwstr(wwide, "wide");
    mkcch(&wX, L'X');

    for (;;) {
	mvprintw(0, 0,
		 "a add_wchnstr  A add_wchstr  m mvadd_wchnstr  M mvadd_wchstr  i in_wch  I in_wchnstr  S in_wchstr  n ins_wch  N ins_wchnstr  s ins_wchstr  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'a':
	case 'A':
	    add_wchnstr(wwide, 2);
	    msg = "add_wchnstr wide 2";
	    break;
	case '1':
	    add_wchstr(wwide);
	    msg = "add_wchstr wide";
	    break;
	case 'm':
	case 'M':
	    mvadd_wchnstr(3, 0, wwide, 2);
	    msg = "mvadd_wchnstr wide 2";
	    break;
	case '2':
	    mvadd_wchstr(4, 0, wwide);
	    msg = "mvadd_wchstr wide";
	    break;
	case 'i':
	case 'I':
	    in_wch(&rin);
	    snprintf(sbuf, sizeof(sbuf), "in_wch wch=%c", (int)rin.chars[0]);
	    msg = sbuf;
	    break;
	case '3': {
	    char rb[64];
	    in_wchnstr(rd, 3);
	    cchars_to_str(rd, 3, rb, sizeof(rb));
	    snprintf(sbuf, sizeof(sbuf), "in_wchnstr bc_str=%s", rb);
	    msg = sbuf;
	    break;
	}
	case '4': {
	    char rb[64];
	    in_wchstr(rd);
	    cchars_to_str(rd, COLS, rb, sizeof(rb));
	    snprintf(sbuf, sizeof(sbuf), "in_wchstr bc_str=%s", rb);
	    msg = sbuf;
	    break;
	}
	case 'n':
	case 'N':
	    ins_wch(&wX);
	    msg = "ins_wch X";
	    break;
	case '5':
	    ins_wchnstr(wwide, 2);
	    msg = "ins_wchnstr wide 2";
	    break;
	case 's':
	case 'S':
	    ins_wchstr(wwide);
	    msg = "ins_wchstr wide";
	    break;
	case 'q':
	case 'Q':
	    goto done;
	}
    }

done:
    free(rd);
    endwin();
    return 0;
}

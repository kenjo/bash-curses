/* C ground-truth reference port for examples/65-varargs-scanw.sh */
#include "bc_example.h"
#include <stdio.h>

static int
vwprintw_int(WINDOW *win, const char *fmt, ...)
{
    va_list ap;
    int rc;
    va_start(ap, fmt);
    rc = vwprintw(win, fmt, ap);
    va_end(ap);
    return rc;
}

static int
vw_printw_int(WINDOW *win, const char *fmt, ...)
{
    va_list ap;
    int rc;
    va_start(ap, fmt);
    rc = vw_printw(win, fmt, ap);
    va_end(ap);
    return rc;
}

static int
vwscanw_int(WINDOW *win, const char *fmt, ...)
{
    va_list ap;
    int rc;
    va_start(ap, fmt);
    rc = vwscanw(win, fmt, ap);
    va_end(ap);
    return rc;
}

static int
vw_scanw_int(WINDOW *win, const char *fmt, ...)
{
    va_list ap;
    int rc;
    va_start(ap, fmt);
    rc = vw_scanw(win, fmt, ap);
    va_end(ap);
    return rc;
}

int
main(void)
{
    const char *msg = "waiting";
    char buf[128];
    int n = 0, key;

    bc_example_init(1);
    echo();
    curs_set(1);

    for (;;) {
	mvprintw(0, 0,
		 "p wprintw  v vwprintw  V vw_printw  s wscanw  w vwscanw  W vw_scanw  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'p':
	case 'P':
	    wprintw(stdscr, " wprintw %d", 1);
	    msg = "wprintw";
	    break;
	case 'v':
	case 'V':
	    vwprintw_int(stdscr, " vwprintw %d", 2);
	    msg = "vwprintw";
	    break;
	case '1':
	    vw_printw_int(stdscr, " vw_printw %d", 3);
	    msg = "vw_printw";
	    break;
	case 's':
	case 'S':
	    mvprintw(3, 0, "wscanw: ");
	    clrtoeol();
	    if (wscanw(stdscr, "%d", &n) == 0) {
		snprintf(buf, sizeof(buf), "wscanw n=%d", n);
		msg = buf;
	    } else {
		msg = "wscanw failed";
	    }
	    break;
	case 'w':
	case 'W':
	    mvprintw(4, 0, "vwscanw: ");
	    clrtoeol();
	    if (vwscanw_int(stdscr, "%d", &n) == 0) {
		snprintf(buf, sizeof(buf), "vwscanw n=%d", n);
		msg = buf;
	    } else {
		msg = "vwscanw failed";
	    }
	    break;
	case '2':
	    mvprintw(5, 0, "vw_scanw: ");
	    clrtoeol();
	    if (vw_scanw_int(stdscr, "%d", &n) == 0) {
		snprintf(buf, sizeof(buf), "vw_scanw n=%d", n);
		msg = buf;
	    } else {
		msg = "vw_scanw failed";
	    }
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

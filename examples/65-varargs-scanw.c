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
    WINDOW *win;
    const char *msg = "waiting";
    char buf[128];
    int n = 0, key;

    bc_example_init(1);
    echo();
    curs_set(1);

    win = newwin(10, 30, 2, 2);
    box(win, 0, 0);
    wrefresh(win);

    for (;;) {
	mvprintw(0, 0,
		 "p wprintw  v vwprintw  w vw_printw  s wscanw  m mvscanw  x mvwscanw  V vwscanw  S vw_scanw  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'p':
	case 'P':
	    wprintw(stdscr, "wprintw %d", 42);
	    msg = "wprintw";
	    break;
	case 'v':
	    vwprintw_int(stdscr, "vwprintw %d", 42);
	    msg = "vwprintw";
	    break;
	case 'w':
	case 'W':
	    vw_printw_int(stdscr, "vw_printw %d", 42);
	    msg = "vw_printw";
	    break;
	case 's':
	    mvwprintw(win, 2, 0, "wscanw: ");
	    wscanw(win, "%d", &n);
	    snprintf(buf, sizeof(buf), "wscanw n=%d", n);
	    msg = buf;
	    break;
	case 'm':
	case 'M':
	    mvprintw(15, 0, "mvscanw: ");
	    mvscanw(15, 10, "%d", &n);
	    snprintf(buf, sizeof(buf), "mvscanw n=%d", n);
	    msg = buf;
	    break;
	case 'x':
	case 'X':
	    mvwprintw(win, 3, 0, "mvwscanw: ");
	    mvwscanw(win, 3, 10, "%d", &n);
	    snprintf(buf, sizeof(buf), "mvwscanw n=%d", n);
	    msg = buf;
	    break;
	case 'V':
	    vwscanw_int(win, "%d", &n);
	    snprintf(buf, sizeof(buf), "vwscanw n=%d", n);
	    msg = buf;
	    break;
	case 'S':
	    vw_scanw_int(win, "%d", &n);
	    snprintf(buf, sizeof(buf), "vw_scanw n=%d", n);
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

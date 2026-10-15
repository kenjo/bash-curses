#ifndef BC_EXAMPLE_H
#define BC_EXAMPLE_H

#include <ncursesw/ncurses.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <locale.h>

static WINDOW *bc_base;

static void
bc_example_init(int enable_keypad)
{
    setlocale(LC_ALL, "");
    initscr();
    cbreak();
    noecho();
    curs_set(0);
    bc_base = newwin(LINES, COLS, 0, 0);
    wrefresh(bc_base);
    if (enable_keypad) {
	keypad(stdscr, TRUE);
	keypad(bc_base, TRUE);
    }
}

/*
 * Composite the logical window's touched lines into the full-screen base
 * window, then repaint base.  This mirrors the bash library's model where a
 * window only repaints cells it actually dirtied, so stdscr-style writes never
 * erase untouched window cells.  base is the only window ever refreshed.
 */
static void
bc_composite(WINDOW *win)
{
    int wy = getbegy(win), wx = getbegx(win);
    int h, w;
    chtype savedbg = getbkgd(bc_base);
    int y, x;

    getmaxyx(win, h, w);

    wbkgdset(bc_base, ' ');
    for (y = 0; y < h; y++) {
	if (!is_linetouched(win, y))
	    continue;
	for (x = 0; x < w; x++)
	    mvwaddch(bc_base, wy + y, wx + x, mvwinch(win, y, x));
    }
    wbkgdset(bc_base, savedbg);
    untouchwin(win);
    wrefresh(bc_base);
}

static void
bc_example_status(int y, const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    mvwprintw(stdscr, y, 0, fmt, ap);
    va_end(ap);
    wclrtoeol(stdscr);
}

static void
bc_example_frame(const char *menu, const char *status)
{
    mvprintw(0, 0, "%s", menu);
    clrtoeol();
    mvprintw(1, 0, "%s", status);
    clrtoeol();
    refresh();
}

static void
bc_example_done(const char *status)
{
    mvprintw(1, 0, "%s", status);
    clrtoeol();
    refresh();
    endwin();
}

#endif

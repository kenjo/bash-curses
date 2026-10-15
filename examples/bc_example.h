#ifndef BC_EXAMPLE_H
#define BC_EXAMPLE_H

#include <ncursesw/ncurses.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <locale.h>

static void
bc_example_init(int enable_keypad)
{
    setlocale(LC_ALL, "");
    initscr();
    cbreak();
    noecho();
    if (enable_keypad)
	keypad(stdscr, TRUE);
    curs_set(0);
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

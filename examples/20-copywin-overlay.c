/* C ground-truth reference port for examples/20-copywin-overlay.sh */
#include <ncursesw/ncurses.h>
#include <stdlib.h>
#include <string.h>
#include <locale.h>

static void
fill_background(WINDOW *win)
{
    int h, ww, y, x;
    getmaxyx(win, h, ww);
    box(win, 0, 0);
    for (y = 1; y < h - 1; y++)
	for (x = 1; x < ww - 1; x++)
	    mvwaddch(win, y, x, '.');
}

static void
draw_source(WINDOW *win)
{
    int h, ww, y, x;
    getmaxyx(win, h, ww);
    for (y = 0; y < h; y++)
	for (x = 0; x < ww; x++)
	    mvwaddch(win, y, x, ((x + y) % 3 == 0) ? '#' : ' ');
}

int
main(void)
{
    WINDOW *src, *dst1, *dst2;
    int key;

    setlocale(LC_ALL, "");
    initscr();
    cbreak();
    noecho();
    curs_set(0);

    src = newwin(7, 20, 1, 1);
    draw_source(src);

    dst1 = newwin(9, 24, 10, 1);
    dst2 = newwin(9, 24, 10, 27);

    fill_background(dst1);
    fill_background(dst2);

    overlay(src, dst1);
    overwrite(src, dst2);

    mvprintw(0, 0, "overlay keeps destination blanks; overwrite replaces everything");
    mvprintw(9, 1, "overlay");
    mvprintw(9, 27, "overwrite");
    mvprintw(LINES - 1, 0, "q quit");
    clrtoeol();

    wrefresh(src);
    wrefresh(dst1);
    wrefresh(dst2);
    refresh();

    for (;;) {
	if ((key = wgetch(stdscr)) == ERR)
	    break;
	if (key == 'q' || key == 'Q')
	    break;
    }

    endwin();
    return 0;
}

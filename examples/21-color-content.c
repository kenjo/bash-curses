/* C ground-truth reference port for examples/21-color-content.sh */
#include <ncursesw/ncurses.h>
#include <stdlib.h>
#include <string.h>
#include <locale.h>

int
main(void)
{
    int c, n, key, pair;
    short r, g, b;

    setlocale(LC_ALL, "");
    initscr();
    cbreak();
    noecho();
    keypad(stdscr, TRUE);
    curs_set(0);

    if (!has_colors()) {
	mvprintw(0, 0, "This terminal reports no color support.");
	mvprintw(2, 0, "q quit");
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

    start_color();
    mvprintw(0, 0, "COLORS=%d  COLOR_PAIRS=%d", COLORS, COLOR_PAIRS);
    mvprintw(1, 0, "can_change_color=%s", can_change_color() ? "yes" : "no");

    n = COLORS;
    if (n > 16)
	n = 16;
    for (c = 0; c < n; c++) {
	color_content((short)c, &r, &g, &b);
	mvwaddch(stdscr, 3 + c, 0, '#' | COLOR_PAIR(c));
	mvwprintw(stdscr, 3 + c, 2, "color %02d: r=%d g=%d b=%d", c, r, g, b);
	wclrtoeol(stdscr);
    }

    if (can_change_color()) {
	init_color(1, 1000, 0, 0);
	color_content(1, &r, &g, &b);
	mvwprintw(stdscr, 3 + n, 0, "after init_color 1: r=%d g=%d b=%d", r, g, b);
	wclrtoeol(stdscr);
    }

    pair = alloc_pair(COLOR_RED, COLOR_BLUE);
    if (pair > 0) {
	wattron(stdscr, COLOR_PAIR(pair));
	mvwprintw(stdscr, LINES - 3, 0, "alloc_pair red/blue returned pair %d", pair);
	wattroff(stdscr, COLOR_PAIR(pair));
	wclrtoeol(stdscr);
	mvwprintw(stdscr, LINES - 2, 0, "find_pair red/blue returned pair %d",
		  find_pair(COLOR_RED, COLOR_BLUE));
	wclrtoeol(stdscr);
	free_pair(pair);
    }

    mvprintw(LINES - 1, 0, "q quit");
    clrtoeol();
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

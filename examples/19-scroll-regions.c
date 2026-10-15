/* C ground-truth reference port for examples/19-scroll-regions.sh */
#include <ncursesw/ncurses.h>
#include <stdlib.h>
#include <string.h>
#include <locale.h>

int
main(void)
{
    WINDOW *win;
    const char *status = "ready";
    int i, key;

    setlocale(LC_ALL, "");
    initscr();
    cbreak();
    noecho();
    curs_set(0);

    win = newwin(15, 60, 2, 5);
    keypad(win, TRUE);
    scrollok(win, TRUE);
    wsetscrreg(win, 1, 13);

    box(win, 0, 0);
    mvwprintw(win, 0, 2, " Scroll region: rows 1-13 ");
    mvwprintw(win, 14, 2, " arrows scroll, PgUp/PgDn jump, q quit ");

    for (i = 1; i <= 13; i++)
	mvwprintw(win, i, 2, "line %02d inside the scrolling region", i);
    wrefresh(win);

    for (;;) {
	mvprintw(0, 0, "wsetscrreg 1 13; wscrl: %s", status);
	clrtoeol();
	refresh();

	if ((key = wgetch(win)) == ERR)
	    break;
	switch (key) {
	case KEY_DOWN:
	    wscrl(win, 1);
	    status = "down 1";
	    break;
	case KEY_UP:
	    wscrl(win, -1);
	    status = "up 1";
	    break;
	case KEY_NPAGE:
	    wscrl(win, 5);
	    status = "down 5";
	    break;
	case KEY_PPAGE:
	    wscrl(win, -5);
	    status = "up 5";
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

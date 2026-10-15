/* C ground-truth reference port for examples/26-inserts.sh */
#include <ncursesw/ncurses.h>
#include <stdlib.h>
#include <string.h>
#include <locale.h>

int
main(void)
{
    WINDOW *win;
    const char *msg = "waiting";
    int key;

    setlocale(LC_ALL, "");
    initscr();
    cbreak();
    noecho();
    keypad(stdscr, TRUE);
    curs_set(0);

    win = newwin(12, 50, 2, 2);
    box(win, 0, 0);
    mvwprintw(win, 0, 2, " inserts ");
    mvwprintw(win, 2, 2, "abcdefghijklmnopqrstuvwxyz");
    wrefresh(win);

    for (;;) {
	mvprintw(0, 0, "i insch  n insnstr  s insstr  d deleteln  I insertln  D insdelln  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'i':
	    wmove(win, 2, 5);
	    winsch(win, 'X');
	    msg = "winsch inserted X at row 2 col 5";
	    break;
	case 'n':
	    wmove(win, 2, 5);
	    winsnstr(win, "123", 3);
	    msg = "winsnstr inserted 123 at row 2 col 5";
	    break;
	case 's':
	    wmove(win, 2, 5);
	    winsstr(win, "STR");
	    msg = "winsstr inserted STR at row 2 col 5";
	    break;
	case 'd':
	    wmove(win, 2, 5);
	    wdeleteln(win);
	    msg = "wdeleteln deleted row 2";
	    break;
	case 'I':
	    wmove(win, 2, 5);
	    winsertln(win);
	    msg = "winsertln inserted a blank row at row 2";
	    break;
	case 'D':
	    wmove(win, 2, 5);
	    winsdelln(win, -1);
	    msg = "winsdelln -1 deleted row 2";
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

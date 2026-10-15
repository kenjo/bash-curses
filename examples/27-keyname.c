/* C ground-truth reference port for examples/27-keyname.sh */
#include <ncursesw/ncurses.h>
#include <stdlib.h>
#include <string.h>
#include <locale.h>

int
main(void)
{
    int key;

    setlocale(LC_ALL, "");
    initscr();
    cbreak();
    noecho();
    keypad(stdscr, TRUE);
    curs_set(0);

    for (;;) {
	mvprintw(0, 0, "Press keys to see keyname(); q quits");
	clrtoeol();
	mvprintw(2, 0, "Try arrows, function keys, letters, and control keys.");
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	if (key == 'q' || key == 'Q')
	    break;

	mvprintw(4, 0, "key=%d", key);
	clrtoeol();
	mvprintw(5, 0, "keyname=%s", keyname(key));
	clrtoeol();
	mvprintw(6, 0, "has_key=%s", has_key(key) ? "yes" : "no");
	clrtoeol();
	refresh();
    }

    endwin();
    return 0;
}

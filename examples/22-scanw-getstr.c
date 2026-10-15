/* C ground-truth reference port for examples/22-scanw-getstr.sh */
#include <ncursesw/ncurses.h>
#include <stdlib.h>
#include <string.h>
#include <locale.h>

int
main(void)
{
    char name[64];
    char buf[21];
    int age, rc, key;

    setlocale(LC_ALL, "");
    initscr();
    cbreak();
    noecho();
    keypad(stdscr, TRUE);
    curs_set(0);

    for (;;) {
	mvprintw(0, 0, "s scanw  g getnstr  q quit");
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 's':
	case 'S':
	    mvprintw(2, 0, "Enter name and age: ");
	    clrtoeol();
	    name[0] = '\0';
	    age = 0;
	    rc = wscanw(stdscr, "%s %d", name, &age);
	    mvprintw(4, 0, "scanw returned %d", rc);
	    clrtoeol();
	    if (rc != ERR)
		mvprintw(5, 0, "name=%s age=%d", name, age);
	    else
		mvprintw(5, 0, "no conversions were performed");
	    clrtoeol();
	    break;
	case 'g':
	case 'G':
	    mvprintw(2, 0, "Enter text (max 20 chars): ");
	    clrtoeol();
	    buf[0] = '\0';
	    if (wgetnstr(stdscr, buf, 20) == OK)
		mvprintw(4, 0, "getnstr got: %s", buf);
	    else
		mvprintw(4, 0, "getnstr failed");
	    clrtoeol();
	    break;
	case 'q':
	case 'Q':
	    goto done;
	}
	clrtoeol();
	refresh();
    }

done:
    endwin();
    return 0;
}

/* C ground-truth reference port for examples/30-instr.sh */
#include <ncursesw/ncurses.h>
#include <stdlib.h>
#include <string.h>
#include <locale.h>
#include <stdio.h>

int
main(void)
{
    WINDOW *win;
    char msg[256];
    char buf[64];
    int key;

    setlocale(LC_ALL, "");
    initscr();
    cbreak();
    noecho();
    keypad(stdscr, TRUE);
    curs_set(0);

    win = newwin(10, 40, 2, 2);
    box(win, 0, 0);
    mvwprintw(win, 2, 2, "ABCDEFGHIJ");
    wrefresh(win);

    msg[0] = '\0';

    for (;;) {
	mvprintw(0, 0, "i instr  n innstr  m mvwinstr  b mvwinnstr  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'i':
	    wmove(win, 2, 2);
	    buf[0] = '\0';
	    winstr(win, buf);
	    snprintf(msg, sizeof(msg), "instr: %s", buf);
	    break;
	case 'n':
	    wmove(win, 2, 2);
	    buf[0] = '\0';
	    winnstr(win, buf, 5);
	    snprintf(msg, sizeof(msg), "innstr: %s", buf);
	    break;
	case 'm':
	    buf[0] = '\0';
	    mvwinstr(win, 2, 2, buf);
	    snprintf(msg, sizeof(msg), "mvwinstr: %s", buf);
	    break;
	case 'b':
	    buf[0] = '\0';
	    mvwinnstr(win, 2, 2, buf, 5);
	    snprintf(msg, sizeof(msg), "mvwinnstr: %s", buf);
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

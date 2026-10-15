/* C ground-truth reference port for examples/33-clip-printw.sh */
#include "bc_example.h"

int
main(void)
{
    WINDOW *win;
    const char *msg = "waiting";
    int key;

    bc_example_init(1);

    win = newwin(8, 20, 2, 2);
    box(win, 0, 0);
    wrefresh(win);

    for (;;) {
	mvprintw(0, 0, "a wprintw long string  b mvwprintw long string  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	refresh();
	if (win != NULL) { touchwin(win); wrefresh(win); }

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'a':
	case 'A':
	    wmove(win, 2, 2);
	    wprintw(win, "This is a very long string that should be clipped at the window edge");
	    msg = "wprintw wrote a long clipped string";
	    break;
	case 'b':
	case 'B':
	    mvwprintw(win, 4, 2, "mvwprintw long string that should also be clipped at the window edge");
	    msg = "mvwprintw wrote a long clipped string";
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

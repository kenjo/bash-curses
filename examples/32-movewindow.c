/* C ground-truth reference port for examples/32-movewindow.sh */
#include "bc_example.h"
#include <stdio.h>

int
main(void)
{
    WINDOW *parent, *child;
    const char *msg = "waiting";
    int key;

    bc_example_init(1);

    parent = newwin(10, 30, 2, 2);
    box(parent, 0, 0);
    mvwprintw(parent, 0, 2, " parent ");
    wrefresh(parent);

    child = subwin(parent, 5, 15, 4, 4);
    box(child, 0, 0);
    mvwprintw(child, 0, 2, " child ");
    wrefresh(child);

    for (;;) {
	mvprintw(0, 0, "p mvwin parent  c mvderwin child  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'p':
	case 'P':
	    mvwin(parent, 5, 5);
	    wrefresh(parent);
	    wrefresh(child);
	    msg = "mvwin parent to (5,5)";
	    break;
	case 'c':
	case 'C':
	    mvderwin(child, 2, 2);
	    wrefresh(parent);
	    wrefresh(child);
	    msg = "mvderwin child to parent-relative (2,2)";
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

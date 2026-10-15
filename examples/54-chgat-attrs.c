/* C ground-truth reference port for examples/54-chgat-attrs.sh */
#include "bc_example.h"

int
main(void)
{
    const char *msg = "waiting";
    int key;

    bc_example_init(1);

    for (;;) {
	mvprintw(0, 0,
		 "c chgat  w wchgat  m mvchgat  s attr_set  o attr_on  f attr_off  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'c':
	case 'C':
	    mvprintw(3, 0, "ABCDEFGHIJ");
	    chgat(5, A_BOLD, 0, NULL);
	    msg = "chgat 5 A_BOLD";
	    break;
	case 'w':
	case 'W':
	    mvprintw(4, 0, "ABCDEFGHIJ");
	    wchgat(stdscr, 5, A_REVERSE, 0, NULL);
	    msg = "wchgat 5 A_REVERSE";
	    break;
	case 'm':
	case 'M':
	    mvprintw(5, 0, "ABCDEFGHIJ");
	    mvchgat(5, 2, 4, A_BOLD, 0, NULL);
	    msg = "mvchgat y=5 x=2 n=4 A_BOLD";
	    break;
	case 's':
	case 'S':
	    attr_set(A_BOLD, 0, NULL);
	    mvprintw(6, 0, "attr_set bold");
	    attr_set(0, 0, NULL);
	    msg = "attr_set A_BOLD";
	    break;
	case 'o':
	case 'O':
	    attr_on(A_BOLD, NULL);
	    mvprintw(7, 0, "attr_on bold");
	    attr_off(A_BOLD, NULL);
	    msg = "attr_on A_BOLD";
	    break;
	case 'f':
	case 'F':
	    attr_off(A_BOLD, NULL);
	    mvprintw(8, 0, "attr_off bold");
	    msg = "attr_off A_BOLD";
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

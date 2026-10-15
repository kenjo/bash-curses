/* C ground-truth reference port for examples/80-copywin-clrtobot.sh */
#include "bc_example.h"

int
main(void)
{
    WINDOW *src, *dst;
    const char *msg = "waiting";
    int key;

    bc_example_init(1);

    src = newwin(10, 40, 2, 2);
    dst = newwin(10, 40, 14, 2);
    box(src, 0, 0);
    box(dst, 0, 0);
    mvwprintw(src, 2, 0, "source");
    mvwprintw(src, 3, 0, "data");
    mvwprintw(dst, 2, 0, "target");
    mvwprintw(dst, 3, 0, "base");
    wrefresh(src);
    wrefresh(dst);

    for (;;) {
	mvprintw(0, 0,
		 "c copywin  1 copywin overlay  2 overwrite  l clrtobot  i mvwinsnstr  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'c':
	case 'C':
	    copywin(src, dst, 2, 0, 2, 0, 5, 10, 0);
	    msg = "copywin overwrite";
	    break;
	case '1':
	    copywin(src, dst, 2, 0, 2, 0, 5, 10, 1);
	    msg = "copywin overlay";
	    break;
	case '2':
	    overwrite(src, dst);
	    msg = "overwrite";
	    break;
	case 'l':
	case 'L':
	    clrtobot();
	    msg = "clrtobot";
	    break;
	case 'i':
	case 'I':
	    mvwinsnstr(dst, 4, 0, "ins", 3);
	    msg = "mvwinsnstr dst 4 0 3 ins";
	    break;
	case 'q':
	case 'Q':
	    goto done;
	}
	wrefresh(dst);
    }

done:
    endwin();
    return 0;
}

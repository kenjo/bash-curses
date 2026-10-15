/* C ground-truth reference port for examples/44-vidattr.sh */
#include "bc_example.h"
#include <string.h>

static int
put_wrapper(int c)
{
    return putc(c, stdout);
}

int
main(void)
{
    const char *msg = "waiting";
    int key, put_plain = 0, pcol = 0;

    bc_example_init(1);

    for (;;) {
	mvprintw(0, 0, "a vidattr bold  p vidputs  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	if (put_plain) {
	    const char *s = "plain";
	    int i;
	    for (i = 0; s[i]; i++)
		mvaddch(1, pcol + i, (chtype)s[i] | A_BOLD);
	}
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'a':
	case 'A':
	    vidattr(A_BOLD);
	    mvprintw(2, 0, "bold text from vidattr");
	    vidattr(A_NORMAL);
	    msg = "vidattr A_BOLD then A_NORMAL";
	    break;
	case 'p':
	case 'P':
	    pcol = (int)strlen(msg);
	    put_plain = 1;
	    vidputs(A_BOLD, put_wrapper);
	    mvprintw(3, 0, "after vidputs");
	    vidputs(A_NORMAL, put_wrapper);
	    msg = "vidputs plain with A_BOLD";
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

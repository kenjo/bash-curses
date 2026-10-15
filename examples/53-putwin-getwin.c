/* C ground-truth reference port for examples/53-putwin-getwin.sh */
#include "bc_example.h"
#include <stdio.h>
#include <sys/stat.h>

static const char *WIN_FILE = "tmp/bc_example_putwin.win";

int
main(void)
{
    WINDOW *win;
    const char *msg = "waiting";
    char buf[256];
    int key;

    bc_example_init(1);
    mkdir("tmp", 0777);

    win = newwin(8, 30, 2, 2);
    box(win, 0, 0);
    mvwprintw(win, 0, 2, " win ");
    wrefresh(win);

    for (;;) {
	mvprintw(0, 0, "s putwin  l getwin  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 's':
	case 'S': {
	    FILE *fp = fopen(WIN_FILE, "wb");
	    if (fp != NULL) {
		if (putwin(win, fp) == OK)
		    snprintf(buf, sizeof(buf), "putwin saved %s", WIN_FILE);
		else
		    snprintf(buf, sizeof(buf), "putwin failed");
		fclose(fp);
	    } else {
		snprintf(buf, sizeof(buf), "putwin failed");
	    }
	    msg = buf;
	    break;
	}
	case 'l':
	case 'L': {
	    FILE *fp = fopen(WIN_FILE, "rb");
	    if (fp != NULL) {
		WINDOW *loaded = getwin(fp);
		fclose(fp);
		if (loaded != NULL) {
		    wrefresh(loaded);
		    snprintf(buf, sizeof(buf), "getwin loaded -> %p",
			     (void *)loaded);
		} else {
		    snprintf(buf, sizeof(buf), "getwin failed");
		}
	    } else {
		snprintf(buf, sizeof(buf), "getwin failed");
	    }
	    msg = buf;
	    break;
	}
	case 'q':
	case 'Q':
	    goto done;
	}
    }

done:
    endwin();
    return 0;
}

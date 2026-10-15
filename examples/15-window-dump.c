/* C ground-truth reference port for examples/15-window-dump.sh */
#include <ncursesw/ncurses.h>
#include <stdlib.h>
#include <string.h>
#include <locale.h>
#include <stdio.h>
#include <sys/stat.h>
#include <sys/types.h>

static const char *WIN_FILE = "tmp/bc_window.dump";

static void
draw_window(WINDOW *win, const char *label)
{
    box(win, 0, 0);
    mvwprintw(win, 0, 2, " %s ", label);
    mvwprintw(win, 2, 2, "This window was saved with putwin().");
    mvwprintw(win, 3, 2, "getwin() recreates it from the file.");
    mvwprintw(win, 4, 2, "dupwin() copies the live window.");
}

int
main(void)
{
    WINDOW *win;
    const char *status = "ready";
    int key;

    setlocale(LC_ALL, "");
    initscr();
    cbreak();
    noecho();
    keypad(stdscr, TRUE);
    curs_set(0);
    mkdir("tmp", 0777);

    win = newwin(10, 40, 2, 2);
    draw_window(win, "Original");
    wrefresh(win);

    for (;;) {
	mvprintw(0, 0, "WIN_FILE=%s  %s", WIN_FILE, status);
	clrtoeol();
	mvprintw(LINES - 1, 0, "g getwin  d dupwin  q quit");
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'g': {
	    FILE *fp = fopen(WIN_FILE, "rb");
	    if (fp != NULL) {
		WINDOW *w = getwin(fp);
		fclose(fp);
		if (w != NULL) {
		    win = w;
		    wrefresh(win);
		    status = "getwin restored a window";
		} else {
		    status = "getwin failed";
		}
	    } else {
		status = "getwin failed";
	    }
	    break;
	}
	case 'd':
	    if (win != NULL) {
		WINDOW *dup = dupwin(win);
		int by, bx;
		getbegyx(win, by, bx);
		mvwin(dup, by + 2, bx + 2);
		wrefresh(dup);
		status = "dupwin copied the window";
	    } else {
		status = "no live window to duplicate";
	    }
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

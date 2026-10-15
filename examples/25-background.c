/* C ground-truth reference port for examples/25-background.sh */
#include <ncursesw/ncurses.h>
#include <stdlib.h>
#include <string.h>
#include <locale.h>
#include <stdio.h>

int
main(void)
{
    const char *msg = "waiting";
    char buf[128];
    int colors;
    int key;

    setlocale(LC_ALL, "");
    initscr();
    cbreak();
    noecho();
    keypad(stdscr, TRUE);
    curs_set(0);

    colors = has_colors();
    if (colors) {
	start_color();
	init_pair(1, COLOR_YELLOW, COLOR_BLUE);
	init_pair(2, COLOR_BLACK, COLOR_CYAN);
    }

    for (;;) {
	mvprintw(0, 0, "b wbkgd  s wbkgdset  g getbkgrnd  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	mvprintw(3, 0, "Sample: abc def");
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'b':
	case 'B':
	    if (colors) {
		wbkgd(stdscr, '#' | COLOR_PAIR(1));
		msg = "wbkgd set background to '#' pair 1";
	    } else {
		wbkgd(stdscr, '#');
		msg = "wbkgd set background to '#'";
	    }
	    break;
	case 's':
	case 'S':
	    if (colors) {
		wbkgdset(stdscr, '+' | COLOR_PAIR(2));
		msg = "wbkgdset set background to '+' pair 2";
	    } else {
		wbkgdset(stdscr, '+');
		msg = "wbkgdset set background to '+'";
	    }
	    break;
	case 'g':
	case 'G': {
	    cchar_t bkg;
	    wchar_t wch;
	    attr_t attr;
	    short pair;
	    wgetbkgrnd(stdscr, &bkg);
	    getcchar(&bkg, &wch, &attr, &pair, NULL);
	    snprintf(buf, sizeof(buf), "getbkgrnd: ch=%lc attr=%ld pair=%d",
		     (wint_t)wch, (long)attr, (int)pair);
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

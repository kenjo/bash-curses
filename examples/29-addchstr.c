/* C ground-truth reference port for examples/29-addchstr.sh */
#include <ncursesw/ncurses.h>
#include <stdlib.h>
#include <string.h>
#include <locale.h>

static void
mkch(chtype *dst, const char *src)
{
    int i;
    for (i = 0; src[i] != '\0'; i++)
	dst[i] = (chtype)src[i];
    dst[i] = 0;
}

int
main(void)
{
    WINDOW *win;
    const char *msg = "waiting";
    chtype s1[16], s2[16], s3[16], s4[16];
    int key;

    setlocale(LC_ALL, "");
    initscr();
    cbreak();
    noecho();
    keypad(stdscr, TRUE);
    curs_set(0);

    mkch(s1, "ADDCHSTR");
    mkch(s2, "ADDCHNSTR");
    mkch(s3, "MVWADDCHSTR");
    mkch(s4, "MVWADDCHNSTR");

    win = newwin(10, 40, 2, 2);
    box(win, 0, 0);
    wrefresh(win);

    for (;;) {
	mvprintw(0, 0, "a waddchstr  n waddchnstr  m mvwaddchstr  b mvwaddchnstr  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'a':
	    wmove(win, 2, 2);
	    waddchstr(win, s1);
	    msg = "waddchstr wrote ADDCHSTR";
	    break;
	case 'n':
	    wmove(win, 2, 2);
	    waddchnstr(win, s2, 5);
	    msg = "waddchnstr wrote ADDCH";
	    break;
	case 'm':
	    mvwaddchstr(win, 3, 2, s3);
	    msg = "mvwaddchstr wrote MVWADDCHSTR";
	    break;
	case 'b':
	    mvwaddchnstr(win, 4, 2, s4, 7);
	    msg = "mvwaddchnstr wrote MVWADDC";
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

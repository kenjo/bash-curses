/* C ground-truth reference port for examples/28-inchs.sh */
#include <ncursesw/ncurses.h>
#include <stdlib.h>
#include <string.h>
#include <locale.h>
#include <stdio.h>

static void
chstr_to_text(const chtype *src, int n, char *dst)
{
    int i;
    for (i = 0; i < n; i++) {
	chtype c = src[i] & A_CHARTEXT;
	if (c == 0)
	    break;
	dst[i] = (char)c;
    }
    dst[i] = '\0';
}

int
main(void)
{
    WINDOW *win;
    char msg[256];
    chtype arr[64];
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
	mvprintw(0, 0, "i winch  n inchnstr  s inchstr  m mvwinch  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'i': {
	    chtype ch;
	    wmove(win, 2, 2);
	    ch = winch(win);
	    snprintf(msg, sizeof(msg), "winch: ch=%c attr=%ld pair=%d",
		     (int)(ch & A_CHARTEXT), (long)(ch & A_ATTRIBUTES),
		     (int)((ch & A_COLOR) >> 8));
	    break;
	}
	case 'n': {
	    int n;
	    char text[64];
	    wmove(win, 2, 2);
	    n = winchnstr(win, arr, 5);
	    chstr_to_text(arr, 5, text);
	    snprintf(msg, sizeof(msg), "inchnstr: %s count=%d", text, n);
	    break;
	}
	case 's': {
	    char text[64];
	    wmove(win, 2, 2);
	    winchstr(win, arr);
	    chstr_to_text(arr, 63, text);
	    snprintf(msg, sizeof(msg), "inchstr: %s", text);
	    break;
	}
	case 'm': {
	    chtype ch;
	    ch = mvwinch(win, 2, 3);
	    snprintf(msg, sizeof(msg), "mvwinch(2,3): ch=%c attr=%ld pair=%d",
		     (int)(ch & A_CHARTEXT), (long)(ch & A_ATTRIBUTES),
		     (int)((ch & A_COLOR) >> 8));
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

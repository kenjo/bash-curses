/* C ground-truth reference port for examples/18-pads.sh */
#include <ncursesw/ncurses.h>
#include <stdlib.h>
#include <string.h>
#include <locale.h>

#define PAD_H 40
#define PAD_W 100

static void
fill_pad(WINDOW *pad)
{
    int y, x;
    for (y = 0; y < PAD_H; y++) {
	mvwprintw(pad, y, 0, "pad row %02d:", y);
	for (x = 0; x < 20; x++)
	    wprintw(pad, " [%02d]", x);
    }
}

int
main(void)
{
    WINDOW *pad;
    int top = 0, left = 0, maxtop, maxleft, key;

    setlocale(LC_ALL, "");
    initscr();
    cbreak();
    noecho();
    keypad(stdscr, TRUE);
    curs_set(0);

    pad = newpad(PAD_H, PAD_W);
    fill_pad(pad);

    maxtop = PAD_H - LINES;
    maxleft = PAD_W - COLS;
    if (maxtop < 0)
	maxtop = 0;
    if (maxleft < 0)
	maxleft = 0;

    for (;;) {
	prefresh(pad, top, left, 0, 0, LINES - 1, COLS - 1);
	mvprintw(LINES - 1, 0, "top=%d left=%d  arrows scroll, q quit",
		 top, left);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case KEY_UP:
	    if (top > 0)
		top--;
	    break;
	case KEY_DOWN:
	    if (top < maxtop)
		top++;
	    break;
	case KEY_LEFT:
	    if (left > 0)
		left--;
	    break;
	case KEY_RIGHT:
	    if (left < maxleft)
		left++;
	    break;
	case KEY_PPAGE:
	    top -= 5;
	    if (top < 0)
		top = 0;
	    break;
	case KEY_NPAGE:
	    top += 5;
	    if (top > maxtop)
		top = maxtop;
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

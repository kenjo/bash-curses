/* C ground-truth reference port for examples/23-halfdelay.sh */
#include <ncursesw/ncurses.h>
#include <stdlib.h>
#include <string.h>
#include <locale.h>
#include <stdio.h>

int
main(void)
{
    int timeouts = 0;
    const char *msg = "waiting";
    char keymsg[64];
    int key;

    setlocale(LC_ALL, "");
    initscr();
    cbreak();
    noecho();
    keypad(stdscr, TRUE);
    curs_set(0);
    halfdelay(5);

    for (;;) {
	mvprintw(0, 0, "halfdelay 5 (0.5s); timeouts=%d; q quits", timeouts);
	clrtoeol();
	mvprintw(2, 0, "%s", msg);
	clrtoeol();
	refresh();

	key = wgetch(stdscr);
	if (key != ERR) {
	    if (key == 'q' || key == 'Q')
		break;
	    snprintf(keymsg, sizeof(keymsg), "got key: %d", key);
	    msg = keymsg;
	} else {
	    timeouts++;
	    msg = "wgetch returned ERR after halfdelay";
	    if (timeouts >= 5)
		break;
	}
    }

    endwin();
    return 0;
}

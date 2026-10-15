/* C ground-truth reference port for examples/40-defkey.sh */
#include "bc_example.h"
#include <stdio.h>

int
main(void)
{
    const char *msg = "waiting";
    char buf[128];
    int key;

    bc_example_init(1);

    for (;;) {
	mvprintw(0, 0, "d define_key  k key_defined  b keybound  o keyok  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'd':
	case 'D':
	    define_key("\033[99~", 400);
	    msg = "define_key \\E[99~ -> 400";
	    break;
	case 'k':
	case 'K':
	    snprintf(buf, sizeof(buf), "key_defined \\E[99~ -> %d",
		     key_defined("\033[99~"));
	    msg = buf;
	    break;
	case 'b':
	case 'B': {
	    char *def = keybound(400, 0);
	    snprintf(buf, sizeof(buf), "keybound 400 -> %s",
		     def ? def : "(none)");
	    msg = buf;
	    if (def)
		free(def);
	    break;
	}
	case 'o':
	case 'O': {
	    int prev = keyok(400, 0);
	    snprintf(buf, sizeof(buf), "keyok 400 disabled previous=%d", prev);
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

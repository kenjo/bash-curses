/* C ground-truth reference port for examples/50-mcprint.sh */
#include "bc_example.h"
#include <stdio.h>
#include <wchar.h>

int
main(void)
{
    const char *msg = "waiting";
    char buf[128];
    int key;

    bc_example_init(1);

    for (;;) {
	mvprintw(0, 0, "m mcprint  n napms  c setcchar/getcchar  w wcwidth  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'm':
	case 'M':
	    if (mcprint("hello", 5) == OK)
		msg = "mcprint ok";
	    else
		msg = "mcprint unsupported";
	    break;
	case 'n':
	case 'N':
	    napms(10);
	    msg = "napms 10";
	    break;
	case 'c':
	case 'C': {
	    cchar_t c;
	    wchar_t w[8];
	    attr_t a = 0;
	    short p = 0;
	    setcchar(&c, L"A", A_BOLD, 1, NULL);
	    getcchar(&c, w, &a, &p, NULL);
	    snprintf(buf, sizeof(buf), "getcchar wch=%lc attrs=%lu pair=%d",
		     w[0], (unsigned long)a, p);
	    msg = buf;
	    break;
	}
	case 'w':
	case 'W':
	    snprintf(buf, sizeof(buf), "wcwidth A rc=%d", wcwidth(L'A'));
	    msg = buf;
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

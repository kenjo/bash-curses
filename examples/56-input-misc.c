/* C ground-truth reference port for examples/56-input-misc.sh */
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
	mvprintw(0, 0, "m meta  e erasechar  k killchar  E erasewchar  K killwchar  i intrflush");
	clrtoeol();
	mvprintw(1, 0, "u qiflush  n noqiflush  d delay_output  f flushinp  b beep  l flash  c has_ic/has_il  q quit");
	clrtoeol();
	mvprintw(2, 0, "%s", msg);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'm':
	case 'M':
	    meta(stdscr, TRUE);
	    msg = "meta on";
	    break;
	case 'e':
	case 'E':
	    snprintf(buf, sizeof(buf), "erasechar=%d", (int)erasechar());
	    msg = buf;
	    break;
	case 'k':
	case 'K':
	    snprintf(buf, sizeof(buf), "killchar=%d", (int)killchar());
	    msg = buf;
	    break;
	case '1': {
	    wchar_t wc = 0;
	    erasewchar(&wc);
	    snprintf(buf, sizeof(buf), "erasewchar %ld", (long)wc);
	    msg = buf;
	    break;
	}
	case '2': {
	    wchar_t wc = 0;
	    killwchar(&wc);
	    snprintf(buf, sizeof(buf), "killwchar %ld", (long)wc);
	    msg = buf;
	    break;
	}
	case 'i':
	case 'I':
	    snprintf(buf, sizeof(buf), "intrflush rc=%d", intrflush(stdscr, TRUE));
	    msg = buf;
	    break;
	case 'u':
	case 'U':
	    qiflush();
	    msg = "qiflush";
	    break;
	case 'n':
	case 'N':
	    noqiflush();
	    msg = "noqiflush";
	    break;
	case 'd':
	case 'D':
	    delay_output(10);
	    msg = "delay_output 10";
	    break;
	case 'f':
	case 'F':
	    flushinp();
	    msg = "flushinp";
	    break;
	case 'b':
	case 'B':
	    beep();
	    msg = "beep";
	    break;
	case 'l':
	case 'L':
	    flash();
	    msg = "flash";
	    break;
	case 'c':
	case 'C':
	    if (has_ic() && has_il())
		msg = "has_ic and has_il yes";
	    else
		msg = "has_ic or has_il no";
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

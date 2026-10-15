/* C ground-truth reference port for examples/75-attr-bg-extra.sh */
#include "bc_example.h"
#include <stdio.h>

static void
mkcch(cchar_t *c, wchar_t w)
{
    wchar_t s[2];
    s[0] = w;
    s[1] = 0;
    setcchar(c, s, A_NORMAL, 0, NULL);
}

/* bash wbkgset maps to ncurses wbkgdset; no wbkgset in ncurses. */
static int
wbkgset(WINDOW *win, chtype ch)
{
    wbkgdset(win, ch);
    return OK;
}

/* bash use_screen always reports unsupported (no alt-screen switching). */
static int
use_screen_unsupported(void)
{
    return ERR;
}

int
main(void)
{
    WINDOW *win;
    const char *msg = "waiting";
    char sbuf[128];
    cchar_t cat;
    chtype bg = 0;
    int key;

    bc_example_init(1);

    win = newwin(10, 40, 2, 2);
    box(win, 0, 0);
    wrefresh(win);

    mkcch(&cat, L'@');

    for (;;) {
	mvwprintw(bc_base, 0, 0,
		  "a wattr_set  o wattr_on  f wattr_off  A attr_set  O attr_on  F attr_off  b bkgdset  B bkgrndset  k bkgrnd  K wbkgset  g getbkgd  p PAIR_NUMBER  v vid_attr  V vid_puts  u use_screen  t wtimeout  q quit");
	wclrtoeol(bc_base);
	mvwprintw(bc_base, 1, 0, "%s", msg);
	wclrtoeol(bc_base);
	wrefresh(bc_base);

	if ((key = wgetch(bc_base)) == ERR)
	    break;
	switch (key) {
	case 'a':
	case 'A':
	    wattr_set(win, A_BOLD, 0, NULL);
	    msg = "wattr_set win A_BOLD";
	    break;
	case 'o':
	case 'O':
	    wattr_on(win, A_BOLD, NULL);
	    msg = "wattr_on win A_BOLD";
	    break;
	case 'f':
	case 'F':
	    wattr_off(win, A_BOLD, NULL);
	    msg = "wattr_off win A_BOLD";
	    break;
	case '1':
	    wattr_set(bc_base, A_BOLD, 0, NULL);
	    msg = "attr_set A_BOLD";
	    break;
	case '2':
	    wattr_on(bc_base, A_BOLD, NULL);
	    msg = "attr_on A_BOLD";
	    break;
	case '3':
	    wattr_off(bc_base, A_BOLD, NULL);
	    msg = "attr_off A_BOLD";
	    break;
	case 'b':
	case 'B':
	    wbkgdset(bc_base, '@');
	    msg = "bkgdset @";
	    break;
	case '4':
	    wbkgdset(bc_base, '@');
	    msg = "bkgrndset stdscr @";
	    break;
	case 'k':
	case 'K':
	    wbkgdset(bc_base, '@');
	    msg = "bkgrnd stdscr @";
	    break;
	case '5':
	    wbkgset(win, '@');
	    msg = "wbkgset win @";
	    break;
	case 'g':
	case 'G':
	    bg = getbkgd(win);
	    snprintf(sbuf, sizeof(sbuf), "getbkgd win %c",
		     (int)(bg & A_CHARTEXT));
	    msg = sbuf;
	    break;
	case 'p':
	case 'P':
	    snprintf(sbuf, sizeof(sbuf), "PAIR_NUMBER 3 = %d",
		     PAIR_NUMBER((chtype)3));
	    msg = sbuf;
	    break;
	case 'v':
	case 'V':
	    vid_attr(A_BOLD, 0, NULL);
	    msg = "vid_attr A_BOLD";
	    break;
	case '6':
	    vid_puts(A_BOLD, 0, NULL, putchar);
	    msg = "vid_puts x A_BOLD";
	    break;
	case 'u':
	case 'U':
	    if (use_screen_unsupported() == OK)
		msg = "use_screen ok";
	    else
		msg = "use_screen unsupported";
	    break;
	case 't':
	case 'T':
	    wtimeout(win, 100);
	    msg = "wtimeout win 100";
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

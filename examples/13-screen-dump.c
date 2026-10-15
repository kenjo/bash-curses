/* C ground-truth reference port for examples/13-screen-dump.sh */
#include <ncursesw/ncurses.h>
#include <stdlib.h>
#include <string.h>
#include <locale.h>
#include <stdio.h>
#include <sys/stat.h>
#include <sys/types.h>

static const char *SCR_FILE = "tmp/bc_screen.dump";

static void
draw_a(void)
{
    clear();
    attron(A_BOLD);
    mvprintw(2, 2, "Screen A: this state was dumped to SCR_FILE.");
    attroff(A_BOLD);
    mvprintw(4, 2, "Press d to dump, r to restore, s to set, q to quit.");
}

static void
draw_b(void)
{
    clear();
    attron(A_REVERSE);
    mvprintw(6, 6, "Screen B: a different screen state.");
    attroff(A_REVERSE);
    mvprintw(8, 2, "Press d to dump, r to restore, s to set, q to quit.");
}

int
main(void)
{
    const char *status = "ready";
    FILE *fp;
    int key;

    setlocale(LC_ALL, "");
    initscr();
    cbreak();
    noecho();
    keypad(stdscr, TRUE);
    curs_set(0);

    mkdir("tmp", 0777);
    if ((fp = fopen(SCR_FILE, "wb")) != NULL)
	fclose(fp);

    draw_a();
    refresh();

    for (;;) {
	mvprintw(LINES - 1, 0, "SCR_FILE=%s  %s", SCR_FILE, status);
	clrtoeol();
	refresh();

	if ((key = wgetch(stdscr)) == ERR)
	    break;
	switch (key) {
	case 'd':
	    status = (scr_dump(SCR_FILE) == OK) ? "dumped current screen"
					       : "dump failed";
	    break;
	case 'r':
	    status = (scr_restore(SCR_FILE) == OK) ? "restored SCR_FILE"
						 : "restore failed";
	    break;
	case 's':
	    status = (scr_set(SCR_FILE) == OK) ? "set SCR_FILE" : "set failed";
	    break;
	case 'b':
	    draw_b();
	    status = "drew screen B";
	    break;
	case 'a':
	    draw_a();
	    status = "drew screen A";
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

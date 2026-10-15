/* C ground-truth reference port for examples/76-panel-bottom.sh */
#include "bc_example.h"
#include <panel.h>
#include <stdio.h>

static WINDOW *
init_wins(int color, int y, int x, int h, int w, const char *label)
{
    WINDOW *win = newwin(h, w, y, x);
    (void)color;
    if (win != NULL) {
	box(win, 0, 0);
	mvwprintw(win, 1, 2, "%s", label);
	wrefresh(win);
    }
    return win;
}

int
main(void)
{
    WINDOW *wins[3];
    PANEL *panels[3];
    const char *msg = "waiting";
    char buf[256];
    int i, y = 2, x = 10, key;

    bc_example_init(1);
    start_color();
    init_pair(1, COLOR_RED, COLOR_BLACK);
    init_pair(2, COLOR_GREEN, COLOR_BLACK);
    init_pair(3, COLOR_BLUE, COLOR_BLACK);
    init_pair(4, COLOR_CYAN, COLOR_BLACK);

    for (i = 0; i < 3; i++) {
	char label[32];
	snprintf(label, sizeof(label), "Window %d", i + 1);
	wins[i] = init_wins(i + 1, y, x, 10, 40, label);
	panels[i] = new_panel(wins[i]);
	y += 3;
	x += 7;
    }

    update_panels();
    doupdate();

    for (;;) {
	mvprintw(0, 0,
		 "b bottom_panel  t top_panel  h hide_panel  s show_panel  m move_panel  r replace_panel  w panel_window  u update_panels  q quit");
	clrtoeol();
	mvprintw(1, 0, "%s", msg);
	clrtoeol();
	refresh();
	update_panels();
	doupdate();

	if ((key = getch()) == ERR)
	    break;
	switch (key) {
	case 'b':
	case 'B':
	    bottom_panel(panels[0]);
	    msg = "bottom_panel panel0";
	    break;
	case 't':
	case 'T':
	    top_panel(panels[0]);
	    msg = "top_panel panel0";
	    break;
	case 'h':
	case 'H':
	    hide_panel(panels[1]);
	    msg = "hide_panel panel1";
	    break;
	case 's':
	case 'S':
	    show_panel(panels[1]);
	    msg = "show_panel panel1";
	    break;
	case 'm':
	case 'M':
	    move_panel(panels[2], 4, 20);
	    msg = "move_panel panel2 4 20";
	    break;
	case 'r':
	case 'R': {
	    WINDOW *temp_win = newwin(8, 30, 6, 6);
	    if (temp_win != NULL) {
		box(temp_win, 0, 0);
		mvwprintw(temp_win, 1, 2, "replaced");
		replace_panel(panels[2], temp_win);
	    }
	    msg = "replace_panel panel2";
	    break;
	}
	case 'w':
	case 'W':
	    snprintf(buf, sizeof(buf), "panel_window panel0 win=%p",
		     (void *)panel_window(panels[0]));
	    msg = buf;
	    break;
	case 'u':
	case 'U':
	    update_panels();
	    msg = "update_panels";
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

/* C ground-truth reference port for examples/76-panel-bottom.sh */
#include "bc_example.h"
#include <stdio.h>

static WINDOW *wins[3];
static int hidden[3];
static int order[3] = {0, 1, 2};   /* bottom -> top */

static void
init_win(int id, int y, int x, int h, int w, const char *label)
{
    WINDOW *win = newwin(h, w, y, x);
    wins[id] = win;
    if (win != NULL) {
	box(win, 0, 0);
	mvwprintw(win, 1, 2, "%s", label);
    }
}

static void
move_to_bottom(int p)
{
    int i, j, t[3];
    t[0] = p;
    j = 1;
    for (i = 0; i < 3; i++)
	if (order[i] != p)
	    t[j++] = order[i];
    for (i = 0; i < 3; i++)
	order[i] = t[i];
}

static void
move_to_top(int p)
{
    int i, j, t[3];
    j = 0;
    for (i = 0; i < 3; i++)
	if (order[i] != p)
	    t[j++] = order[i];
    t[j++] = p;
    for (i = 0; i < 3; i++)
	order[i] = t[i];
}

static void
composite(void)
{
    int i, id;
    touchwin(bc_base);
    wrefresh(bc_base);
    for (i = 0; i < 3; i++) {
	id = order[i];
	if (hidden[id] || wins[id] == NULL)
	    continue;
	touchwin(wins[id]);
	wrefresh(wins[id]);
    }
}

int
main(void)
{
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
	init_win(i, y, x, 10, 40, label);
	y += 3;
	x += 7;
    }

    for (;;) {
	mvwprintw(bc_base, 0, 0,
		  "b bottom_panel  t top_panel  h hide_panel  s show_panel  m move_panel  r replace_panel  w panel_window  u update_panels  q quit");
	wclrtoeol(bc_base);
	mvwprintw(bc_base, 1, 0, "%s", msg);
	wclrtoeol(bc_base);
	composite();

	if ((key = wgetch(bc_base)) == ERR)
	    break;
	switch (key) {
	case 'b':
	case 'B':
	    move_to_bottom(0);
	    msg = "bottom_panel panel0";
	    break;
	case 't':
	case 'T':
	    move_to_top(0);
	    msg = "top_panel panel0";
	    break;
	case 'h':
	case 'H':
	    hidden[1] = 1;
	    msg = "hide_panel panel1";
	    break;
	case 's':
	case 'S':
	    hidden[1] = 0;
	    msg = "show_panel panel1";
	    break;
	case 'm':
	case 'M':
	    mvwin(wins[2], 4, 20);
	    msg = "move_panel panel2 4 20";
	    break;
	case 'r':
	case 'R': {
	    WINDOW *temp_win = newwin(8, 30, 6, 6);
	    if (temp_win != NULL) {
		box(temp_win, 0, 0);
		mvwprintw(temp_win, 1, 2, "replaced");
		wins[2] = temp_win;
	    }
	    msg = "replace_panel panel2";
	    break;
	}
	case 'w':
	case 'W':
	    snprintf(buf, sizeof(buf), "panel_window panel0 win=%p",
		     (void *)wins[0]);
	    msg = buf;
	    break;
	case 'u':
	case 'U':
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

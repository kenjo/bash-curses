/* C ground-truth reference port for examples/81-sudoku.sh */
#include "bc_example.h"

#define GRID_LINES 19
#define GRID_COLS 37
#define GRID_Y 3
#define GRID_X 3
#define INFO_LINES 25
#define INFO_COLS 30
#define INFO_Y 3
#define INFO_X (GRID_X + GRID_COLS + 5)
#define GRID_NUMBER_START_Y 1
#define GRID_NUMBER_START_X 2
#define GRID_LINE_DELTA 4
#define GRID_COL_DELTA 2

static const char plain_board[] =
    "4.....8.5.3..........7......2.....6.....8.4......1.......6.3.7.5..2.....1.4......";
static char user_board[sizeof(plain_board)];

static int
check_board(const char *board)
{
    int r, c, br, bc;
    int seen[10];
    char ch;

    for (r = 0; r < 9; r++) {
	memset(seen, 0, sizeof(seen));
	for (c = 0; c < 9; c++) {
	    ch = board[r * 9 + c];
	    if (ch == '.')
		continue;
	    if (seen[ch - '0'])
		return 0;
	    seen[ch - '0'] = 1;
	}
    }

    for (c = 0; c < 9; c++) {
	memset(seen, 0, sizeof(seen));
	for (r = 0; r < 9; r++) {
	    ch = board[r * 9 + c];
	    if (ch == '.')
		continue;
	    if (seen[ch - '0'])
		return 0;
	    seen[ch - '0'] = 1;
	}
    }

    for (br = 0; br < 9; br += 3) {
	for (bc = 0; bc < 9; bc += 3) {
	    memset(seen, 0, sizeof(seen));
	    for (r = br; r < br + 3; r++) {
		for (c = bc; c < bc + 3; c++) {
		    ch = board[r * 9 + c];
		    if (ch == '.')
			continue;
		    if (seen[ch - '0'])
			return 0;
		    seen[ch - '0'] = 1;
		}
	    }
	}
    }

    return 1;
}

static void
draw_grid(WINDOW *w)
{
    int i, j, y, x;
    chtype ch;

    for (i = 0; i < 10; i++) {
	y = i * GRID_COL_DELTA;
	for (j = 0; j < 10; j++) {
	    x = j * GRID_LINE_DELTA;

	    if (i == 0 && j == 0)
		ch = ACS_ULCORNER;
	    else if (i == 0 && j == 9)
		ch = ACS_URCORNER;
	    else if (i == 9 && j == 9)
		ch = ACS_LRCORNER;
	    else if (i == 9 && j == 0)
		ch = ACS_LLCORNER;
	    else if (i == 0)
		ch = ACS_TTEE;
	    else if (i == 9)
		ch = ACS_BTEE;
	    else if (j == 0)
		ch = ACS_LTEE;
	    else if (j == 9)
		ch = ACS_RTEE;
	    else
		ch = ACS_PLUS;

	    wmove(w, y, x);
	    waddch(w, ch);

	    if (j < 9) {
		wmove(w, y, x + 1);
		waddch(w, ACS_HLINE);
		waddch(w, ACS_HLINE);
		waddch(w, ACS_HLINE);
	    }
	}

	if (i < 9) {
	    y = i * GRID_COL_DELTA + 1;
	    for (j = 0; j < 10; j++) {
		x = j * GRID_LINE_DELTA;
		wmove(w, y, x);
		waddch(w, ACS_VLINE);

		if (j < 9) {
		    wmove(w, y, x + 1);
		    waddch(w, ' ');
		    waddch(w, ' ');
		    waddch(w, ' ');
		}
	    }
	}
    }
}

static void
fill_grid(WINDOW *w)
{
    int row, col, y, x, idx;
    char c;

    for (row = 0; row < 9; row++) {
	y = GRID_NUMBER_START_Y + row * GRID_COL_DELTA;
	for (col = 0; col < 9; col++) {
	    x = GRID_NUMBER_START_X + col * GRID_LINE_DELTA;
	    idx = row * 9 + col;
	    c = user_board[idx];
	    if (c == '.')
		c = ' ';
	    mvwprintw(w, y, x, "%c", c);
	}
    }
}

static void
draw_info(WINDOW *w)
{
    mvwprintw(w, 0, 0, "sudoku demo");
    mvwprintw(w, 1, 0, "fixed puzzle");
    mvwprintw(w, 2, 0, "%s", "");
    mvwprintw(w, 3, 0, "Movement");
    mvwprintw(w, 4, 0, " h left");
    mvwprintw(w, 5, 0, " j down");
    mvwprintw(w, 6, 0, " k up");
    mvwprintw(w, 7, 0, " l right");
    mvwprintw(w, 8, 0, "%s", "");
    mvwprintw(w, 9, 0, "Commands");
    mvwprintw(w, 10, 0, " 1-9 enter");
    mvwprintw(w, 11, 0, " x delete");
    mvwprintw(w, 12, 0, " c check");
    mvwprintw(w, 13, 0, " r redraw");
    mvwprintw(w, 14, 0, " q quit");
}

int
main(void)
{
    WINDOW *grid, *info;
    const char *msg = "Ready";
    const char *help = "h j k l move  1-9 enter  x delete  c check  r redraw  q quit";
    int key, x, y, idx;

    bc_example_init(1);
    strcpy(user_board, plain_board);

    grid = newwin(GRID_LINES, GRID_COLS, GRID_Y, GRID_X);
    info = newwin(INFO_LINES, INFO_COLS, INFO_Y, INFO_X);

    draw_grid(grid);
    fill_grid(grid);
    draw_info(info);
    wrefresh(grid);
    wrefresh(info);

    x = GRID_NUMBER_START_X;
    y = GRID_NUMBER_START_Y;
    wmove(grid, y, x);

    for (;;) {
	mvwprintw(bc_base, 0, 0, "%s", help);
	wclrtoeol(bc_base);
	mvwprintw(bc_base, 1, GRID_X, "%s", msg);
	wclrtoeol(bc_base);
	wrefresh(bc_base);

	if ((key = wgetch(bc_base)) == ERR)
	    break;

	switch (key) {
	case 'h':
	case KEY_LEFT:
	    if (x <= GRID_NUMBER_START_X)
		x = GRID_NUMBER_START_X + GRID_LINE_DELTA * 8;
	    else
		x -= GRID_LINE_DELTA;
	    break;
	case 'l':
	case KEY_RIGHT:
	    if (x >= GRID_NUMBER_START_X + GRID_LINE_DELTA * 8)
		x = GRID_NUMBER_START_X;
	    else
		x += GRID_LINE_DELTA;
	    break;
	case 'k':
	case KEY_UP:
	    if (y <= GRID_NUMBER_START_Y)
		y = GRID_NUMBER_START_Y + GRID_COL_DELTA * 8;
	    else
		y -= GRID_COL_DELTA;
	    break;
	case 'j':
	case KEY_DOWN:
	    if (y >= GRID_NUMBER_START_Y + GRID_COL_DELTA * 8)
		y = GRID_NUMBER_START_Y;
	    else
		y += GRID_COL_DELTA;
	    break;
	case 'c':
	    if (check_board(user_board)) {
		if (strchr(user_board, '.') == NULL)
		    msg = "Solved";
		else
		    msg = "Correct so far";
	    } else {
		msg = "Not correct";
	    }
	    break;
	case 'r':
	    draw_grid(grid);
	    fill_grid(grid);
	    draw_info(info);
	    break;
	case 'x':
	case KEY_DC:
	case KEY_BACKSPACE:
	case 127:
	    idx = ((y - GRID_NUMBER_START_Y) / GRID_COL_DELTA) * 9 +
		  ((x - GRID_NUMBER_START_X) / GRID_LINE_DELTA);
	    if (plain_board[idx] == '.') {
		user_board[idx] = '.';
		fill_grid(grid);
	    }
	    break;
	case 'q':
	case 'Q':
	case 27:
	    goto done;
	default:
	    break;
	}

	if (key >= '1' && key <= '9') {
	    idx = ((y - GRID_NUMBER_START_Y) / GRID_COL_DELTA) * 9 +
		  ((x - GRID_NUMBER_START_X) / GRID_LINE_DELTA);
	    if (plain_board[idx] == '.') {
		user_board[idx] = key;
		fill_grid(grid);
	    }
	}

	wmove(grid, y, x);
	wrefresh(grid);
	wrefresh(info);
    }

done:
    endwin();
    return 0;
}

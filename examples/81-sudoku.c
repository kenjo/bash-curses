/* C ground-truth reference port for examples/81-sudoku.sh */
#include "bc_example.h"
#include <string.h>

static const char plain_board[] =
    "4.....8.5.3..........7......2.....6.....8.4......1.......6.3.7.5..2.....1.4......";
static char user_board[82];

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

#define GRID_LINE_PAIR 1
#define GRID_NODE_PAIR 2
#define USER_PAIR 3
#define HIGHLIGHT_PAIR 4
#define CURSOR_PAIR 5
#define USER_HIGHLIGHT_PAIR 6

static int use_highlights = 0;
static int use_colors = 0;
static int x_cursor = GRID_NUMBER_START_X;
static int y_cursor = GRID_NUMBER_START_Y;

static int undo_x[81], undo_y[81], undo_val[81];
static int undo_count = 0;

static int solve_b[81];

static void
draw_grid(WINDOW *w)
{
    int i, j, y, x;
    chtype node;
    int pair, attr;

    for (i = 0; i < 10; i++) {
        y = i * GRID_COL_DELTA;
        for (j = 0; j < 10; j++) {
            x = j * GRID_LINE_DELTA;
            if (i == 0 && j == 0)
                node = ACS_ULCORNER;
            else if (i == 0 && j == 9)
                node = ACS_URCORNER;
            else if (i == 9 && j == 9)
                node = ACS_LRCORNER;
            else if (i == 9 && j == 0)
                node = ACS_LLCORNER;
            else if (i == 0)
                node = ACS_TTEE;
            else if (i == 9)
                node = ACS_BTEE;
            else if (j == 0)
                node = ACS_LTEE;
            else if (j == 9)
                node = ACS_RTEE;
            else
                node = ACS_PLUS;

            if (use_colors && (i % 3 == 0 || j % 3 == 0)) {
                pair = GRID_NODE_PAIR; attr = A_BOLD;
            } else if (use_colors) {
                pair = GRID_LINE_PAIR; attr = 0;
            } else {
                pair = 0; attr = 0;
            }

            mvwaddch(w, y, x, node | attr | COLOR_PAIR(pair));

            if (j < 9) {
                if (use_colors) {
                    pair = GRID_LINE_PAIR; attr = 0;
                } else {
                    pair = 0; attr = 0;
                }
                mvwaddch(w, y, x + 1, ACS_HLINE | attr | COLOR_PAIR(pair));
                mvwaddch(w, y, x + 2, ACS_HLINE | attr | COLOR_PAIR(pair));
                mvwaddch(w, y, x + 3, ACS_HLINE | attr | COLOR_PAIR(pair));
            }
        }

        if (i < 9) {
            y = i * GRID_COL_DELTA + 1;
            for (j = 0; j < 10; j++) {
                x = j * GRID_LINE_DELTA;
                if (use_colors) {
                    pair = GRID_LINE_PAIR; attr = 0;
                } else {
                    pair = 0; attr = 0;
                }
                mvwaddch(w, y, x, ACS_VLINE | attr | COLOR_PAIR(pair));

                if (j < 9) {
                    mvwaddch(w, y, x + 1, ' ');
                    mvwaddch(w, y, x + 2, ' ');
                    mvwaddch(w, y, x + 3, ' ');
                }
            }
        }
    }
}

static void
fill_grid(WINDOW *w)
{
    int row, col, gy, gx, idx, is_user;
    int cur_row, cur_col, sel_idx, pair, attr;
    char c, sel;

    cur_row = (y_cursor - GRID_NUMBER_START_Y) / GRID_COL_DELTA;
    cur_col = (x_cursor - GRID_NUMBER_START_X) / GRID_LINE_DELTA;
    sel_idx = cur_row * 9 + cur_col;
    sel = user_board[sel_idx];
    if (sel == '.')
        sel = 0;

    for (row = 0; row < 9; row++) {
        gy = GRID_NUMBER_START_Y + row * GRID_COL_DELTA;
        for (col = 0; col < 9; col++) {
            gx = GRID_NUMBER_START_X + col * GRID_LINE_DELTA;
            idx = row * 9 + col;
            c = user_board[idx];
            is_user = 0;
            if (c == '.') {
                c = ' ';
            } else if (c != plain_board[idx]) {
                is_user = 1;
            }

            pair = 0; attr = 0;
            if (use_colors) {
                if (use_highlights && sel && c == sel) {
                    if (row == cur_row && col == cur_col)
                        pair = CURSOR_PAIR;
                    else if (is_user)
                        pair = USER_HIGHLIGHT_PAIR;
                    else
                        pair = HIGHLIGHT_PAIR;
                } else if (is_user) {
                    pair = USER_PAIR;
                }
            }

            mvwaddch(w, gy, gx, c | attr | COLOR_PAIR(pair));
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
    mvwprintw(w, 14, 0, " m highlight");
    mvwprintw(w, 15, 0, " u undo");
    mvwprintw(w, 16, 0, " H hint");
    mvwprintw(w, 17, 0, " q quit");
}

static int
check_board(void)
{
    int r, c, br, bc, idx;
    char n;
    int seen[10];

    for (r = 0; r < 9; r++) {
        memset(seen, 0, sizeof(seen));
        for (c = 0; c < 9; c++) {
            idx = r * 9 + c;
            n = user_board[idx];
            if (n == '.') continue;
            if (seen[n - '0']) return 0;
            seen[n - '0'] = 1;
        }
    }
    for (c = 0; c < 9; c++) {
        memset(seen, 0, sizeof(seen));
        for (r = 0; r < 9; r++) {
            idx = r * 9 + c;
            n = user_board[idx];
            if (n == '.') continue;
            if (seen[n - '0']) return 0;
            seen[n - '0'] = 1;
        }
    }
    for (br = 0; br < 9; br += 3) {
        for (bc = 0; bc < 9; bc += 3) {
            memset(seen, 0, sizeof(seen));
            for (r = br; r < br + 3; r++) {
                for (c = bc; c < bc + 3; c++) {
                    idx = r * 9 + c;
                    n = user_board[idx];
                    if (n == '.') continue;
                    if (seen[n - '0']) return 0;
                    seen[n - '0'] = 1;
                }
            }
        }
    }
    return 1;
}

static int
valid_at(int row, int col, int d)
{
    int r, c, br, bc;
    for (c = 0; c < 9; c++)
        if (solve_b[row * 9 + c] == d) return 0;
    for (r = 0; r < 9; r++)
        if (solve_b[r * 9 + col] == d) return 0;
    br = row / 3 * 3; bc = col / 3 * 3;
    for (r = br; r < br + 3; r++)
        for (c = bc; c < bc + 3; c++)
            if (solve_b[r * 9 + c] == d) return 0;
    return 1;
}

static int
solve_board(void)
{
    int pos = -1, i, row, col, d;
    for (i = 0; i < 81; i++)
        if (solve_b[i] == 0) { pos = i; break; }
    if (pos < 0) return 1;
    row = pos / 9; col = pos % 9;
    for (d = 1; d <= 9; d++) {
        if (valid_at(row, col, d)) {
            solve_b[pos] = d;
            if (solve_board()) return 1;
            solve_b[pos] = 0;
        }
    }
    return 0;
}

static int
do_hint(void)
{
    int i;
    for (i = 0; i < 81; i++)
        solve_b[i] = (user_board[i] == '.') ? 0 : user_board[i] - '0';
    if (solve_board()) {
        for (i = 0; i < 81; i++) {
            if (user_board[i] == '.') {
                user_board[i] = '0' + solve_b[i];
                return 1;
            }
        }
    }
    return 0;
}

static void
undo_push(int x, int y, int val)
{
    undo_x[undo_count] = x;
    undo_y[undo_count] = y;
    undo_val[undo_count] = val;
    undo_count++;
}

static int
undo_pop(int *x, int *y, int *val)
{
    if (undo_count <= 0) return 0;
    undo_count--;
    *x = undo_x[undo_count];
    *y = undo_y[undo_count];
    *val = undo_val[undo_count];
    return 1;
}

int
main(void)
{
    WINDOW *grid, *info;
    const char *help1 = "h j k l move  1-9 enter  x delete  c check  r redraw  q quit";
    const char *help2 = "m highlight  u undo  H hint";
    const char *msg = "Ready";
    int key, idx, prev, ux, uy, uval;

    bc_example_init(0);
    cbreak();
    noecho();
    keypad(stdscr, TRUE);
    curs_set(0);

    if (has_colors() && start_color() == OK) {
        use_colors = 1;
        use_default_colors();
        init_pair(GRID_LINE_PAIR, COLOR_GREEN, -1);
        init_pair(GRID_NODE_PAIR, COLOR_BLUE, -1);
        init_pair(USER_PAIR, COLOR_CYAN, -1);
        init_pair(HIGHLIGHT_PAIR, COLOR_BLACK, COLOR_WHITE);
        init_pair(CURSOR_PAIR, COLOR_BLACK, COLOR_MAGENTA);
        init_pair(USER_HIGHLIGHT_PAIR, COLOR_BLACK, COLOR_CYAN);
    }

    grid = newwin(GRID_LINES, GRID_COLS, GRID_Y, GRID_X);
    info = newwin(INFO_LINES, INFO_COLS, INFO_Y, INFO_X);

    draw_grid(grid);
    fill_grid(grid);
    draw_info(info);
    wnoutrefresh(grid);
    wnoutrefresh(info);
    doupdate();

    strcpy(user_board, plain_board);
    wmove(grid, y_cursor, x_cursor);

    for (;;) {
        mvprintw(0, 0, "%s", help1);
        clrtoeol();
        mvprintw(1, 0, "%s", help2);
        clrtoeol();
        mvprintw(2, GRID_X, "%s", msg);
        clrtoeol();
        wnoutrefresh(stdscr);
        wnoutrefresh(grid);
        wnoutrefresh(info);
        doupdate();

        if ((key = wgetch(grid)) == ERR)
            break;
        switch (key) {
        case 'h':
        case KEY_LEFT:
            if (x_cursor <= GRID_NUMBER_START_X)
                x_cursor = GRID_NUMBER_START_X + GRID_LINE_DELTA * 8;
            else
                x_cursor -= GRID_LINE_DELTA;
            break;
        case 'l':
        case KEY_RIGHT:
            if (x_cursor >= GRID_NUMBER_START_X + GRID_LINE_DELTA * 8)
                x_cursor = GRID_NUMBER_START_X;
            else
                x_cursor += GRID_LINE_DELTA;
            break;
        case 'k':
        case KEY_UP:
            if (y_cursor <= GRID_NUMBER_START_Y)
                y_cursor = GRID_NUMBER_START_Y + GRID_COL_DELTA * 8;
            else
                y_cursor -= GRID_COL_DELTA;
            break;
        case 'j':
        case KEY_DOWN:
            if (y_cursor >= GRID_NUMBER_START_Y + GRID_COL_DELTA * 8)
                y_cursor = GRID_NUMBER_START_Y;
            else
                y_cursor += GRID_COL_DELTA;
            break;
        case 'c':
            if (check_board()) {
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
        case 'm':
            if (use_highlights) {
                use_highlights = 0;
                msg = "Highlights off";
            } else {
                use_highlights = 1;
                msg = "Highlights on";
            }
            fill_grid(grid);
            break;
        case 'u':
            if (undo_pop(&ux, &uy, &uval)) {
                idx = (uy - GRID_NUMBER_START_Y) / GRID_COL_DELTA * 9 +
                      (ux - GRID_NUMBER_START_X) / GRID_LINE_DELTA;
                user_board[idx] = (char)uval;
                x_cursor = ux;
                y_cursor = uy;
                fill_grid(grid);
                msg = "Undone";
            } else {
                msg = "Nothing to undo";
            }
            break;
        case 'H':
            if (do_hint()) {
                fill_grid(grid);
                msg = "Hint";
            } else {
                msg = "No solution";
            }
            break;
        case 'x':
        case KEY_DC:
        case KEY_BACKSPACE:
        case 127:
            idx = (y_cursor - GRID_NUMBER_START_Y) / GRID_COL_DELTA * 9 +
                  (x_cursor - GRID_NUMBER_START_X) / GRID_LINE_DELTA;
            if (plain_board[idx] == '.') {
                undo_push(x_cursor, y_cursor, user_board[idx]);
                user_board[idx] = '.';
                fill_grid(grid);
            }
            break;
        case '1': case '2': case '3': case '4': case '5':
        case '6': case '7': case '8': case '9':
            idx = (y_cursor - GRID_NUMBER_START_Y) / GRID_COL_DELTA * 9 +
                  (x_cursor - GRID_NUMBER_START_X) / GRID_LINE_DELTA;
            if (plain_board[idx] == '.') {
                undo_push(x_cursor, y_cursor, user_board[idx]);
                user_board[idx] = (char)key;
                fill_grid(grid);
            }
            break;
        case 'q':
        case 'Q':
        case 27:
            goto done;
        }

        wmove(grid, y_cursor, x_cursor);
        wnoutrefresh(grid);
        wnoutrefresh(info);
        doupdate();
    }

done:
    endwin();
    return 0;
}

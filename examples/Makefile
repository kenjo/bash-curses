CC ?= cc
PKG_CFLAGS := $(shell pkg-config --cflags ncursesw)
PKG_LIBS := $(shell pkg-config --libs ncursesw)
CFLAGS ?= -std=gnu17 -O0 -g -D_XOPEN_SOURCE_EXTENDED=1 $(PKG_CFLAGS)
LDLIBS ?= $(PKG_LIBS)

SRCS := $(wildcard [0-9]*.c)
BINS := $(SRCS:.c=)
PANEL_SRCS := $(filter 16-panels-% 76-panel-bottom, $(SRCS))
PANEL_BINS := $(PANEL_SRCS:.c=)
NONPANEL_BINS := $(filter-out $(PANEL_BINS), $(BINS))

all: $(BINS)

$(NONPANEL_BINS): %: %.c
	$(CC) $(CFLAGS) -o $@ $< $(LDLIBS)

ifneq ($(PANEL_BINS),)
$(PANEL_BINS): %: %.c
	$(CC) $(CFLAGS) -o $@ $< $(LDLIBS) -lpanel
endif

clean:
	rm -f $(BINS) *.o

.PHONY: all clean

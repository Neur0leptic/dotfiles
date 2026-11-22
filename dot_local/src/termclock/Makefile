# termclock - terminal clock and countdown timer
PREFIX = $(HOME)/.local
CFLAGS = -std=c11 -pedantic -Wall -Wextra -O2
LDLIBS = -lm

all: termclock

termclock: termclock.c
	$(CC) $(CFLAGS) $(CPPFLAGS) $(LDFLAGS) -o $@ termclock.c $(LDLIBS)

install: termclock
	mkdir -p $(DESTDIR)$(PREFIX)/bin
	cp -f termclock $(DESTDIR)$(PREFIX)/bin/termclock
	chmod 755 $(DESTDIR)$(PREFIX)/bin/termclock
	ln -sf termclock $(DESTDIR)$(PREFIX)/bin/termtimer

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/termclock $(DESTDIR)$(PREFIX)/bin/termtimer

clean:
	rm -f termclock

.PHONY: all install uninstall clean

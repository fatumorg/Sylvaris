PREFIX ?= /usr/local
DESTDIR ?=
GREETER_USER ?= $(or $(shell sed -n 's/^user *= *"\(.*\)"/\1/p' /etc/greetd/config.toml 2>/dev/null | head -n1),greeter)
SHARE_GROUP ?= users

bindir = $(DESTDIR)$(PREFIX)/bin
build = build/sylstack
sharedir = $(DESTDIR)$(PREFIX)/share/sylvaris
greetdir = $(DESTDIR)/etc/sylvaris-greet
statedir = $(DESTDIR)/var/lib/sylvaris-greet

.PHONY: all sylstack install install-pam install-greeter uninstall

all: sylstack

sylstack:
	cmake -S stack -B $(build) -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$(PREFIX)
	cmake --build $(build) --parallel

install: sylstack
	DESTDIR=$(DESTDIR) cmake --install $(build)
	install -Dm755 bin/sylvaris $(bindir)/sylvaris
	rm -rf $(sharedir)
	mkdir -p $(sharedir)
	cp -r shell/. $(sharedir)/
	git rev-parse --short HEAD > $(sharedir)/COMMIT 2>/dev/null || echo unknown > $(sharedir)/COMMIT

install-pam:
	[ -e $(DESTDIR)/etc/pam.d/sylvaris ] || install -Dm644 dist/pam/sylvaris $(DESTDIR)/etc/pam.d/sylvaris

install-greeter: install
	install -Dm755 dist/greet/sylvaris-greet $(bindir)/sylvaris-greet
	mkdir -p $(greetdir)
	sed 's|@bindir@|$(PREFIX)/bin|' dist/greet/sway.conf > $(greetdir)/sway.conf
	mkdir -p $(greetdir)/sway.d
	[ -e $(greetdir)/sylvaris/config.json ] || install -Dm644 dist/greet/config.json $(greetdir)/sylvaris/config.json
	install -d -m755 -o $(GREETER_USER) $(statedir)
	install -d -m2775 -o $(GREETER_USER) -g $(SHARE_GROUP) $(statedir)/shared

uninstall:
	[ ! -f $(build)/install_manifest.txt ] || xargs rm -f < $(build)/install_manifest.txt
	rm -f $(bindir)/sylvaris $(bindir)/sylvaris-greet
	rm -rf $(sharedir)

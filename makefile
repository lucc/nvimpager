DESTDIR ?=
PREFIX ?= /usr/local
RUNTIME = $(PREFIX)/share/nvimpager/runtime
VERSION = $(lastword $(shell ./nvimpager -v))
DATE = $(shell git log -1 --format=format:'%aI' 2>/dev/null | cut -f 1 -d T)
BUSTED = busted

BENCHMARK_OPTS = --warmup 2 --min-runs 100

%.configured: %
	sed 's#^RUNTIME=.*$$#RUNTIME='"'$(RUNTIME)'"'#;s#version=.*$$#version=$(VERSION)#' < $< > $@
	chmod +x $@

install: nvimpager.configured nvimpager.1
	mkdir -p $(DESTDIR)$(PREFIX)/bin $(DESTDIR)$(RUNTIME)/lua \
	  $(DESTDIR)$(PREFIX)/share/man/man1 \
	  $(DESTDIR)$(PREFIX)/share/zsh/site-functions
	install nvimpager.configured $(DESTDIR)$(PREFIX)/bin/nvimpager
	install lua/nvimpager.lua $(DESTDIR)$(RUNTIME)/lua
	install nvimpager.1 $(DESTDIR)$(PREFIX)/share/man/man1
	install _nvimpager $(DESTDIR)$(PREFIX)/share/zsh/site-functions

metadata.man:
	@echo .TH \"NVIMPAGER\" \"1\" \"$(DATE)\" \"Version $(VERSION)\" \"General Commands Manual\" >metadata.man

nvimpager.1: metadata.man
	@cat metadata.man nvimpager.body.1 >nvimpager.1

test:
	@$(BUSTED) test
luacov.stats.out: nvimpager lua/nvimpager.lua test/nvimpager_spec.lua
	@$(BUSTED) --coverage test
luacov.report.out: luacov.stats.out
	luacov lua/nvimpager.lua

benchmark:
	@echo Starting benchmark for $$(./nvimpager -v) \($$(git rev-parse --abbrev-ref HEAD)\)
	@hyperfine $(BENCHMARK_OPTS) \
	  './nvimpager -c makefile' \
	  './nvimpager -c <makefile' \
	  './nvimpager -c test/fixtures/makefile' \
	  './nvimpager -c <test/fixtures/makefile' \
	  './nvimpager -c test/fixtures/conceal.tex' \
	  './nvimpager -c test/fixtures/conceal.tex.ansi' \
	  './nvimpager -p -- -c quit' \
	  './nvimpager -p -- makefile -c quit' \
	  './nvimpager -p test/fixtures/makefile -c quit'

clean:
	$(RM) nvimpager.configured metadata.man nvimpager.1 luacov.*
.PHONY: benchmark clean install test

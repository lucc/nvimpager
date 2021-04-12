DESTDIR ?=
PREFIX ?= /usr/local
RUNTIME = $(PREFIX)/share/nvimpager/runtime
VERSION = $(lastword $(shell ./nvimpager -v))
DATE = $(shell git log -1 --no-show-signature --pretty="%cs")
MARKDOWN_PROCESSOR = pandoc
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

ifeq ($(MARKDOWN_PROCESSOR),lowdown)
nvimpager.1: nvimpager.md
	lowdown -Tman -m "date: $(DATE)" -m "source: $(VERSION)" -s -o $@ $<
else # the default is pandoc
metadata.yaml:
	echo "---" > $@
	echo "footer: Version $(VERSION)" >> $@
	echo "date: $(DATE)" >> $@
	echo "..." >> $@
nvimpager.1: nvimpager.md metadata.yaml
	pandoc --standalone --to man --output $@ $^
endif

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
	$(RM) nvimpager.configured nvimpager.1 metadata.yaml luacov.*
.PHONY: benchmark clean install test

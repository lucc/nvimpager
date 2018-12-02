DESTDIR ?=
PREFIX ?= /usr/local
RUNTIME = $(PREFIX)/share/nvimpager/runtime
VERSION = $(lastword $(shell ./nvimpager -v))
BUSTED = busted
NVIM = nvim

PLUGIN_FILES = \
	       plugin/AnsiEscPlugin.vim \
	       plugin/cecutil.vim       \

BENCHMARK_OPTS = --warmup 2 --min-runs 100

%.configured: %
	sed 's#^RUNTIME=.*$$#RUNTIME='"'$(RUNTIME)'"'#;s#version=.*$$#version=$(VERSION)#' < $< > $@
	chmod +x $@

install: nvimpager.configured autoload/AnsiEsc.vim $(PLUGIN_FILES) nvimpager.1
	mkdir -p $(DESTDIR)$(PREFIX)/bin $(DESTDIR)$(RUNTIME)/autoload \
	  $(DESTDIR)$(RUNTIME)/plugin $(DESTDIR)$(RUNTIME)/lua \
	  $(DESTDIR)$(PREFIX)/share/man/man1
	install nvimpager.configured $(DESTDIR)$(PREFIX)/bin/nvimpager
	install autoload/AnsiEsc.vim $(DESTDIR)$(RUNTIME)/autoload
	install $(PLUGIN_FILES) $(DESTDIR)$(RUNTIME)/plugin
	install lua/nvimpager.lua $(DESTDIR)$(RUNTIME)/lua
	install nvimpager.1 $(DESTDIR)$(PREFIX)/share/man/man1

metadata.yaml:
	echo "---" > $@
	echo "footer: Version $(VERSION)" >> $@
	git log -1 --format=format:'date: %aI' 2>/dev/null | cut -f 1 -d T >> $@
	echo "..." >> $@
nvimpager.1: nvimpager.md metadata.yaml
	pandoc --standalone --to man --output $@ $^
AnsiEsc.vba:
	curl https://www.drchip.org/astronaut/vim/vbafiles/AnsiEsc.vba.gz | \
	  gunzip > $@

$(PLUGIN_FILES) autoload/AnsiEsc.vim: AnsiEsc.vba
	$(NVIM) -u NONE -i NONE -n --headless \
	  --cmd 'set rtp^=.' \
	  --cmd 'packadd vimball' \
	  --cmd 'runtime plugin/vimballPlugin.vim' \
	  -S AnsiEsc.vba \
	  -c quitall!

test:
	@$(BUSTED) test
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

cleanall: clean clean-ansiesc
clean:
	$(RM) nvimpager.configured nvimpager.1 metadata.yaml
clean-ansiesc:
	$(RM) -r autoload/AnsiEsc.vim plugin doc .VimballRecord AnsiEsc.vba
.PHONY: benchmark cleanall clean clean-ansiesc install test

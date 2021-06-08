DESTDIR ?=
PREFIX ?= /usr/local
RUNTIME = $(PREFIX)/share/nvimpager/runtime
VERSION = $(lastword $(shell ./nvimpager -v))
BUSTED = busted

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

nvimpager.1: SOURCE_DATE_EPOCH = $(shell git log -1 --no-show-signature --pretty="%ct" 2>/dev/null || echo 1623129416)
nvimpager.1: nvimpager.md
	sed '1cnvimpager(1) "nvimpager $(VERSION)"' $< | scdoc > $@

test:
	@$(BUSTED) test
luacov.stats.out: nvimpager lua/nvimpager.lua test/nvimpager_spec.lua
	@$(BUSTED) --coverage test
luacov.report.out: luacov.stats.out
	luacov lua/nvimpager.lua

version:
	sed -i 's/version=.*version=/version=/' nvimpager
	awk -i inplace -F '[v.]' '/version=/ { print $$1 "version=v" $$3 "." $$4+1; next } { print $$0 }' nvimpager
	sed -i "/SOURCE_DATE_EPOCH/s/[0-9]\{10,\}/$(shell date +%s)/" $(MAKEFILE_LIST)

clean:
	$(RM) nvimpager.configured nvimpager.1 luacov.*
.PHONY: clean install test version

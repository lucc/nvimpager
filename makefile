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
	install -m 644 lua/nvimpager.lua $(DESTDIR)$(RUNTIME)/lua
	install -m 644 nvimpager.1 $(DESTDIR)$(PREFIX)/share/man/man1
	install -m 644 _nvimpager $(DESTDIR)$(PREFIX)/share/zsh/site-functions
uninstall:
	$(RM) $(PREFIX)/bin/nvimpager $(RUNTIME)/lua/nvimpager.lua \
	  $(PREFIX)/share/man/man1/nvimpager.1 \
	  $(PREFIX)/share/zsh/site-functions/_nvimpager

nvimpager.1: SOURCE_DATE_EPOCH = $(shell git log -1 --no-show-signature --pretty="%ct" 2>/dev/null || echo 1665751677)
nvimpager.1: nvimpager.md
	sed '1s/$$/ "nvimpager $(VERSION)"/' $< | scdoc > $@

test:
	@$(BUSTED) test
luacov.stats.out: nvimpager lua/nvimpager.lua test/nvimpager_spec.lua
	@$(BUSTED) --coverage test
luacov.report.out: luacov.stats.out
	luacov lua/nvimpager.lua

TYPE = minor
version: OLD_VERSION = $(patsubst v%,%,$(lastword $(shell git tag --list --sort=version:refname 'v*')))
version: NEW_VERSION = $(shell echo $(OLD_VERSION) | awk -F . -v type=$(TYPE) \
	-e 'type == "major" { print $$1+1 ".0.0" }' \
	-e 'type == "minor" { print $$1 "." $$2+1 ".0" }' \
	-e 'type == "patch" { print $$1 "." $$2 "." $$3+1 }')
version:
	[ $(TYPE) = major ] || [ $(TYPE) = minor ] || [ $(TYPE) = patch ]
	git switch main
	git diff --quiet HEAD
	sed -i 's/version=[0-9.]*$$/version=$(NEW_VERSION)/' nvimpager
	sed -i '/SOURCE_DATE_EPOCH/s/[0-9]\{10,\}/$(shell date +%s)/' $(MAKEFILE_LIST)
	(printf '%s\n' 'Version $(NEW_VERSION)' '' 'Major changes:' 'Breaking changes:' 'Changes:'; \
	  git log v$(OLD_VERSION)..HEAD) \
	| sed -E '/^(commit|Merge:|Author:)/d; /^Date/{N;N; s/.*\n.*\n   /-/;}' \
	| git commit --edit --file - nvimpager makefile
	git tag --message="$$(git show --no-patch --format=format:%s%n%n%b)" \
	  v$(NEW_VERSION)

clean:
	$(RM) nvimpager.configured nvimpager.1 luacov.*
.PHONY: clean install test uninstall version

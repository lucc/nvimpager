DESTDIR ?=
PREFIX ?= /usr/local
RUNTIME = $(PREFIX)/share/nvimpager/runtime
VERSION = $(patsubst v%,%,$(shell git describe))

%: %.in
	sed 's#^RUNTIME=.*$$#RUNTIME='"'$(RUNTIME)'"'#;s#^version=.*$$#version=$(VERSION)#' < $< > $@
	chmod +x $@

install: nvimpager
	install -D --target-directory=$(DESTDIR)$(PREFIX)/bin nvimpager
	install -D --target-directory=$(DESTDIR)$(RUNTIME)/autoload autoload/pager.vim autoload/cat.vim

AnsiEsc.vba:
	curl http://www.drchip.org/astronaut/vim/vbafiles/AnsiEsc.vba.gz | \
	  gunzip > $@

install-ansiesc: AnsiEsc.vba
	nvim \
	  --headless \
	  --cmd 'set rtp^=.' \
	  --cmd 'set rtp+=/usr/share/nvim/runtime/pack/dist/opt/vimball' \
	  -S AnsiEsc.vba \
	  -c qa!

clean-ansiesc:
	$(RM) -r autoload/AnsiEsc.vim plugin doc .VimballRecord AnsiEsc.vba

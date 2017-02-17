DESTDIR ?=
PREFIX ?= /usr/local
RUNTIME = $(PREFIX)/share/nvimpager/runtime

nvimpager: nvimpager.in
	sed 's#^RUNTIME=.$$#RUNTIME='"'$(RUNTIME)'"'#' < $< > $@
	chmod +x $@

install: nvimpager
	install -D nvimpager $(DESTDIR)$(PREFIX)/bin
	install -D autoload/pager.vim $(DESTDIR)$(RUNTIME)/autoload

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

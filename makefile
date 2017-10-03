DESTDIR ?=
PREFIX ?= /usr/local
RUNTIME = $(PREFIX)/share/nvimpager/runtime

%: %.in
	sed 's#^RUNTIME=.$$#RUNTIME='"'$(RUNTIME)'"'#' < $< > $@
	chmod +x $@

install: nvimpager nvimcat
	install -D nvimpager nvimcat $(DESTDIR)$(PREFIX)/bin
	install -D autoload/pager.vim autoload/cat.vim $(DESTDIR)$(RUNTIME)/autoload

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

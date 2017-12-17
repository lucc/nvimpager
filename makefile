DESTDIR ?=
PREFIX ?= /usr/local
RUNTIME = $(PREFIX)/share/nvimpager/runtime
VERSION = $(patsubst v%,%,$(shell git describe))

AUTOLOAD_FILES = \
		 autoload/AnsiEsc.vim \
		 autoload/cat.vim     \
		 autoload/pager.vim   \

PLUGIN_FILES = \
	       plugin/AnsiEscPlugin.vim \
	       plugin/cecutil.vim       \

%.configured: %
	sed 's#^RUNTIME=.*$$#RUNTIME='"'$(RUNTIME)'"'#;s#^version=.*$$#version=$(VERSION)#' < $< > $@
	chmod +x $@

install: nvimpager.configured $(AUTOLOAD_FILES) $(PLUGIN_FILES)
	install -D nvimpager.configured $(DESTDIR)$(PREFIX)/bin/nvimpager
	install -D --target-directory=$(DESTDIR)$(RUNTIME)/autoload $(AUTOLOAD_FILES)
	install -D --target-directory=$(DESTDIR)$(RUNTIME)/plugin $(PLUGIN_FILES)

AnsiEsc.vba:
	curl http://www.drchip.org/astronaut/vim/vbafiles/AnsiEsc.vba.gz | \
	  gunzip > $@

$(PLUGIN_FILES) autoload/AnsiEsc.vim: AnsiEsc.vba
	nvim -u NONE --headless \
	  --cmd 'set rtp^=.' \
	  --cmd 'packadd vimball' \
	  --cmd 'runtime plugin/vimballPlugin.vim' \
	  -S AnsiEsc.vba \
	  -c quitall!

cleanall: clean clean-ansiesc
clean:
	$(RM) nvimpager.configured
clean-ansiesc:
	$(RM) -r autoload/AnsiEsc.vim plugin doc .VimballRecord AnsiEsc.vba
.PHONY: cleanall clean clean-ansiesc

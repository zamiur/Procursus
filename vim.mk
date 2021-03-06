ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS += vim
# Per homebrew, vim should only be updated every 50 releases on multiples of 50
VIM_VERSION := 8.2.0700
DEB_VIM_V   ?= $(VIM_VERSION)

vim-setup: setup
	wget -q -nc -P $(BUILD_SOURCE) https://github.com/vim/vim/archive/v$(VIM_VERSION).tar.gz
	$(call EXTRACT_TAR,v$(VIM_VERSION).tar.gz,vim-$(VIM_VERSION),vim)

ifneq ($(wildcard $(BUILD_WORK)/vim/.build_complete),)
vim:
	@echo "Using previously built vim."
else
vim: .SHELLFLAGS=-O extglob -c
vim: vim-setup ncurses gettext
	$(SED) -i 's/AC_TRY_LINK(\[]/AC_TRY_LINK(\[#include <termcap.h>]/g' $(BUILD_WORK)/vim/src/configure.ac # This is so stupid, I cannot believe this is necessary.
	cd $(BUILD_WORK)/vim/src && autoconf -f
	cd $(BUILD_WORK)/vim && ./configure -C \
		--host=$(GNU_HOST_TRIPLE) \
		--prefix=/usr \
		--enable-gui=no \
		--with-tlib=ncursesw \
		--without-x \
		--disable-darwin \
		vim_cv_toupper_broken=no \
		vim_cv_terminfo=yes \
		vim_cv_tgetent=zero \
		vim_cv_tty_group=4 \
		vim_cv_tty_mode=0620 \
		vim_cv_getcwd_broken=no \
		vim_cv_stat_ignores_slash=no \
		vim_cv_memmove_handles_overlap=yes
	+$(MAKE) -C $(BUILD_WORK)/vim
	+$(MAKE) -C $(BUILD_WORK)/vim install \
		DESTDIR="$(BUILD_STAGE)/vim"
	rm -f $(BUILD_STAGE)/vim/usr/bin/!(vim|vimtutor|xxd)
	mv $(BUILD_STAGE)/vim/usr/bin/vim $(BUILD_STAGE)/vim/usr/bin/vim.basic
	rm -rf $(BUILD_STAGE)/vim/usr/share/man/*{ISO*,UTF*,KOI*}
	find $(BUILD_STAGE)/vim/usr/share/man -type f ! -name "vim.1" ! -name "vimtutor.1" ! -name "xxd.1" -delete
	find $(BUILD_STAGE)/vim/usr/share/man -type l -delete
	touch $(BUILD_WORK)/vim/.build_complete
endif
vim-package: vim-stage
	# vim.mk Package Structure
	rm -rf $(BUILD_DIST)/{vim,xxd}
	mkdir -p $(BUILD_DIST)/{vim,xxd}/usr/{bin,share}
	
	# vim.mk Prep vim
	cp -a $(BUILD_STAGE)/vim/usr/bin/vim{.basic,tutor} $(BUILD_DIST)/vim/usr/bin
	cp -a $(BUILD_STAGE)/vim/usr/share/{vim,man} $(BUILD_DIST)/vim/usr/share
	find $(BUILD_DIST)/vim/usr/share/man -type f -name "xxd.1" -delete

	# vim.mk Prep xxd
	cp -a $(BUILD_STAGE)/vim/usr/bin/xxd $(BUILD_DIST)/xxd/usr/bin
	cp -a $(BUILD_STAGE)/vim/usr/share/man $(BUILD_DIST)/xxd/usr/share
	find $(BUILD_DIST)/xxd/usr/share/man -type f ! -name "xxd.1" -delete
	
	# vim.mk Sign
	$(call SIGN,vim,general.xml)
	$(call SIGN,xxd,general.xml)
	
	# vim.mk Make .debs
	$(call PACK,vim,DEB_VIM_V)
	$(call PACK,xxd,DEB_VIM_V)
	
	# vim.mk Build cleanup
	rm -rf $(BUILD_DIST)/{vim,xxd}

.PHONY: vim vim-package

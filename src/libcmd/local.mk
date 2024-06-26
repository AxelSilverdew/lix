libraries += libcmd

libcmd_NAME = libnixcmd

libcmd_DIR := $(d)

libcmd_SOURCES := $(wildcard $(d)/*.cc)

libcmd_CXXFLAGS += -I src/libutil -I src/libstore -I src/libexpr -I src/libmain -I src/libfetchers

libcmd_LDFLAGS = $(EDITLINE_LIBS) $(LOWDOWN_LIBS) $(NIXDOC_LIBS) -pthread

libcmd_LIBS = libstore libutil libexpr libmain libfetchers

$(eval $(call install-file-in, $(buildprefix)$(d)/nix-cmd.pc, $(libdir)/pkgconfig, 0644))

$(d)/repl.cc: $(d)/repl-overlays.nix.gen.hh

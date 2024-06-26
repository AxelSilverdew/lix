programs += test-repl-characterization

test-repl-characterization_DIR := $(d)

# do not install
test-repl-characterization_INSTALL_DIR :=

test-repl-characterization_SOURCES := \
  $(wildcard $(d)/*.cc) \

test-repl-characterization_CXXFLAGS += -I src/libutil -I tests/unit/libutil-support -DNIX_BIN_DIR="\"$(bindir)\""

test-repl-characterization_LIBS = libutil libutil-test-support

test-repl-characterization_LDFLAGS = $(THREAD_LDFLAGS) $(SODIUM_LIBS) $(EDITLINE_LIBS) $(BOOST_LDFLAGS) $(LOWDOWN_LIBS) $(GTEST_LIBS)

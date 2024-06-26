check: libexpr-tests_RUN

programs += libexpr-tests

libexpr-tests_NAME := libnixexpr-tests

libexpr-tests_ENV := _NIX_TEST_UNIT_DATA=$(d)/data

libexpr-tests_DIR := $(d)

libexpr-tests_INSTALL_DIR :=

libexpr-tests_SOURCES := \
    $(wildcard $(d)/*.cc) \
    $(wildcard $(d)/value/*.cc)

libexpr-tests_EXTRA_INCLUDES = \
    -I tests/unit/libexpr-support \
    -I tests/unit/libstore-support \
    -I tests/unit/libutil-support \
    -I src/libexpr \
    -I src/libfetchers \
    -I src/libstore \
    -I src/libutil

libexpr-tests_CXXFLAGS += $(libexpr-tests_EXTRA_INCLUDES)

libexpr-tests_LIBS = \
    libexpr-test-support libstore-test-support libutils-test-support \
    libexpr libfetchers libstore libutil

libexpr-tests_LDFLAGS := -lrapidcheck $(GTEST_LIBS) -lgmock

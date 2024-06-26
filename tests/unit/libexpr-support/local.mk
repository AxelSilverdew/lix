libraries += libexpr-test-support

libexpr-test-support_NAME = libnixexpr-test-support

libexpr-test-support_DIR := $(d)

libexpr-test-support_INSTALL_DIR :=

libexpr-test-support_SOURCES := \
    $(wildcard $(d)/tests/*.cc) \
    $(wildcard $(d)/tests/value/*.cc)

libexpr-test-support_CXXFLAGS += $(libexpr-tests_EXTRA_INCLUDES)

libexpr-test-support_LIBS = \
    libstore-test-support libutil-test-support \
    libexpr libstore libutil

libexpr-test-support_LDFLAGS := -pthread -lrapidcheck

# Build the simtime runtime dylib for the iOS Simulator.
#
# Targets iPhoneSimulator SDK, fat (arm64 + x86_64) so it works on both
# Apple Silicon and Intel Macs. Output: libsimtime.dylib in this directory.
#
# Usage:
#   make            - build fat dylib
#   make clean      - remove build output
#   make install    - copy to ../.build/runtime/libsimtime.dylib for the CLI

SDK := iphonesimulator
MIN_VERSION := 15.0
SRCS := simtime_state.m simtime_hooks.m
OUT  := libsimtime.dylib
INSTALL_DIR := ../.build/runtime

CFLAGS  := -fobjc-arc -fmodules -Wall -Wno-unused-function -O2 -I include \
           -mios-simulator-version-min=$(MIN_VERSION)
LDFLAGS := -dynamiclib -framework Foundation -framework CoreFoundation

XCRUN := xcrun --sdk $(SDK)
CLANG := $(XCRUN) clang
ISYSROOT := $(shell $(XCRUN) --show-sdk-path)

.PHONY: all clean install test-clock

all: $(OUT)

test-clock: test_clock
test_clock: test_clock.m
	@echo "→ building test_clock binary for iOS Sim"
	$(CLANG) -arch arm64 -isysroot $(ISYSROOT) \
		-fobjc-arc -fmodules -Wall \
		-mios-simulator-version-min=$(MIN_VERSION) \
		-framework Foundation -framework CoreFoundation \
		-o test_clock test_clock.m

$(OUT): $(SRCS) include/simtime_runtime.h simtime_state.h
	@echo "→ building $@ for arm64+x86_64 (iOS Sim SDK $(MIN_VERSION)+)"
	$(CLANG) -arch arm64 -arch x86_64 -isysroot $(ISYSROOT) \
		$(CFLAGS) $(LDFLAGS) -o $@ $(SRCS)
	@echo "→ $$( file $(OUT) )"

clean:
	rm -f $(OUT)

install: $(OUT)
	mkdir -p $(INSTALL_DIR)
	cp $(OUT) $(INSTALL_DIR)/
	@echo "→ installed to $(INSTALL_DIR)/$(OUT)"

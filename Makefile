FPC      ?= fpc
FPCFLAGS ?= -O2
BUILD    := build
TARGET   := $(BUILD)/mklabels
SRC      := src/mklabels.pas
PREFIX   ?= /usr/local

.PHONY: all clean install uninstall

all: $(TARGET)

$(TARGET): $(SRC) src/layouts.inc
	@mkdir -p $(BUILD)
	$(FPC) $(FPCFLAGS) -FE$(BUILD) -FU$(BUILD) $(SRC)

clean:
	rm -f $(BUILD)/*.o $(BUILD)/*.ppu $(TARGET)

install: $(TARGET)
	install -D -m 755 $(TARGET) $(DESTDIR)$(PREFIX)/bin/mklabels

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/mklabels

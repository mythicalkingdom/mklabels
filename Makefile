FPC      ?= fpc
FPCFLAGS ?= -O2
BUILD    := build
TARGET   := $(BUILD)/mklabels
SRC      := src/mklabels.pas
PREFIX   ?= /usr/local

.PHONY: all gui clean install uninstall

all: $(TARGET)

$(TARGET): $(SRC) src/layouts.inc
	@mkdir -p $(BUILD)
	$(FPC) $(FPCFLAGS) -FE$(BUILD) -FU$(BUILD) $(SRC)

# the GUI needs Lazarus with BGRABitmap and BGRAControls, see gui/README.md
gui: $(TARGET)
	mkdir -p $(BUILD)/gui-units
	lazbuild --ws=gtk2 gui/mklabelsgui.lpi

clean:
	rm -f $(BUILD)/*.o $(BUILD)/*.ppu $(TARGET) $(BUILD)/mklabelsgui
	rm -rf $(BUILD)/gui-units

install: $(TARGET)
	install -D -m 755 $(TARGET) $(DESTDIR)$(PREFIX)/bin/mklabels
	@if [ -x $(BUILD)/mklabelsgui ]; then install -m 755 $(BUILD)/mklabelsgui $(DESTDIR)$(PREFIX)/bin/mklabelsgui; echo installed mklabelsgui; fi

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/mklabels $(DESTDIR)$(PREFIX)/bin/mklabelsgui

FPC      ?= fpc
FPCFLAGS ?= -O2
BUILD    := build
TARGET   := $(BUILD)/mklabels
SRC      := src/mklabels.pas
PREFIX   ?= /usr/local

.PHONY: all gui deb clean install uninstall

all: $(TARGET)

$(TARGET): $(SRC) src/layouts.inc
	@mkdir -p $(BUILD)
	$(FPC) $(FPCFLAGS) -FE$(BUILD) -FU$(BUILD) $(SRC)

deb: $(TARGET)
	tools/mkdeb.sh

# the GUI needs Lazarus with BGRABitmap and BGRAControls, see gui/README.md
gui: $(TARGET)
	mkdir -p $(BUILD)/gui-units
	lazbuild --ws=gtk2 gui/mklabelsgui.lpi

clean:
	rm -f $(BUILD)/*.deb $(BUILD)/*.o $(BUILD)/*.ppu $(TARGET) $(BUILD)/mklabelsgui
	rm -rf $(BUILD)/gui-units

install: $(TARGET)
	install -D -m 755 $(TARGET) $(DESTDIR)$(PREFIX)/bin/mklabels
	@if [ -x $(BUILD)/mklabelsgui ]; then install -m 755 $(BUILD)/mklabelsgui $(DESTDIR)$(PREFIX)/bin/mklabelsgui; \
	install -D -m 644 tools/mklabelsgui.desktop $(DESTDIR)$(PREFIX)/share/applications/mklabelsgui.desktop; \
	install -D -m 644 icons/mklabels-256.png $(DESTDIR)$(PREFIX)/share/icons/hicolor/256x256/apps/mklabels.png; \
	echo installed mklabelsgui; fi
	install -D -m 644 README.md LICENSE -t $(DESTDIR)$(PREFIX)/share/doc/mklabels

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/mklabels $(DESTDIR)$(PREFIX)/bin/mklabelsgui
	rm -f $(DESTDIR)$(PREFIX)/share/applications/mklabelsgui.desktop $(DESTDIR)$(PREFIX)/share/icons/hicolor/256x256/apps/mklabels.png
	rm -rf $(DESTDIR)$(PREFIX)/share/doc/mklabels

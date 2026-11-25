#!/bin/sh
# Build a Debian package:  tools/mkdeb.sh  (or make deb)
#   build/mklabels_<version>_<arch>.deb with mklabels, the documents and, if build/mklabelsgui exists
#   (make gui), the GUI with its menu entry.
set -e
cd "$(dirname "$0")/.."
make -s build/mklabels
VERSION=$(sed -n "s/^ *Version = '\(.*\)';/\1/p" src/mklabels.pas | head -1)
ARCH=$(dpkg --print-architecture)
STAGE=build/deb-stage
OUT=build/mklabels_${VERSION}_${ARCH}.deb
rm -rf "$STAGE"
make -s install DESTDIR="$STAGE" PREFIX=/usr > /dev/null
for f in "$STAGE"/usr/bin/*; do strip --strip-unneeded "$f"; done
DOC="$STAGE/usr/share/doc/mklabels"
# Debian wants a copyright file next to the documents
cat > "$DOC/copyright" <<EOT
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: mklabels
Source: https://github.com/mythicalkingdom/mklabels

Files: *
Copyright: 2026 mythicalkingdom
License: GPL-3+
 This program is free software: you can redistribute it and/or modify it under the terms of the GNU General
 Public License as published by the Free Software Foundation, either version 3 of the License, or (at your
 option) any later version.
 .
 On Debian systems the full text of the GNU General Public License version 3 is in
 /usr/share/common-licenses/GPL-3.

Files: src/layouts.inc
Copyright: the gLabels authors
License: GPL-3+
 The Avery sheet layouts were generated from the gLabels template database.
EOT
rm -f "$DOC/LICENSE"
MAINT="${DEBFULLNAME:-mklabels} <${DEBEMAIL:-noreply@users.noreply.github.com}>"
cat > "$DOC/changelog" <<EOT
mklabels ($VERSION) unstable; urgency=low

  * Release $VERSION. History: github.com/mythicalkingdom/mklabels

 -- $MAINT  $(date -R)
EOT
gzip -9n "$DOC/changelog"
DEPS="libc6"
REC="poppler-utils"
DESC="Tile an image onto a PDF page for printing label sheets"
if [ -x "$STAGE/usr/bin/mklabelsgui" ]; then
  DEPS="$DEPS, libgtk2.0-0t64 | libgtk2.0-0"
  DESC="$DESC, with a GUI"
fi
SIZE=$(du -sk "$STAGE" | cut -f1)
mkdir -p "$STAGE/DEBIAN"
cat > "$STAGE/DEBIAN/control" <<EOT
Package: mklabels
Version: $VERSION
Section: graphics
Priority: optional
Architecture: $ARCH
Depends: $DEPS
Recommends: $REC
Installed-Size: $SIZE
Maintainer: $MAINT
Homepage: https://github.com/mythicalkingdom/mklabels
Description: $DESC
 mklabels tiles an image onto a PDF page, as many times as it fits, using the
 margins and spacing you give. It knows the sheet layouts of about 300 Avery
 US Letter label products (mklabels --layout 5160), and can save and load its
 settings as JSON. The optional mklabelsgui shows the generated PDF.
EOT
find "$STAGE" -type d -exec chmod 755 {} +
find "$STAGE/usr/share" -type f -exec chmod 644 {} +
fakeroot dpkg-deb --build --root-owner-group "$STAGE" "$OUT" > /dev/null
rm -rf "$STAGE"
echo "$OUT"
dpkg-deb --info "$OUT" | grep -E "Package|Version|Architecture|Depends|Installed|Size"

# mklabelsgui - a simple GUI for mklabels

Set the mklabels parameters, press **Generate**, and the PDF that `mklabels` wrote is shown on the right.
It uses the same toolkit and look as `mkbiblegui`: Lazarus / LCL (GTK2) with BGRABitmap and BGRAControls,
light and dark themes (the Dark / Light button), HiDPI scaling, and `key = value` settings in
`~/.config/mklabels/mklabels.cfg` (`%APPDATA%\\mklabels` on Windows), which remember the last values.

The GUI does not contain any layout code. It runs the `mklabels` command line program (found next to
`mklabelsgui`, or in the PATH) and shows the result, rendered with `pdftoppm` (poppler-utils).
**Open in viewer** opens the PDF in your default PDF viewer.

## Fields

An empty field is not passed to `mklabels`, so its default (or the layout's value) is used.

| Field | mklabels option |
|---|---|
| Image | `-i` (the ... button browses) |
| Avery layout | `-L`; type a part number such as `5160`, or pick one from the list; `(none)` for manual settings |
| Left / Top margin, Horizontal / Vertical space | `-l -t -h -v` |
| Label width / height | `-w -H` |
| Units | `-u`, for numbers typed without a unit (a value like `12mm` always keeps its own unit) |
| Orientation, Page size | `-p`, `-s` (both are fixed by a layout, so they are disabled while one is chosen) |
| Image DPI | `-d` |
| Output PDF | `-o` (default: `labels.pdf` next to the image) |

Keys: Ctrl+Enter or F5 generates.  Options for trying it out: `--dark`, `--light`, `--generate` (generate at
start), and an image path to preload.

## Build

Needs Lazarus 4 and its LCL for GTK2, plus BGRABitmap and BGRAControls (see the mkbible `gui/README.md` for
how to install those packages):

    make gui          # build/mklabelsgui, also builds build/mklabels

`make install` installs `mklabelsgui` too when it has been built.

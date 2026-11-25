# mklabels

Tiles an image onto a PDF page as many times as it fits, using the margins and
spacing you specify. Useful for printing sheets of labels.

## Build

Requires Free Pascal (fpc 3.2+).

```
make
```

This is equivalent to `fpc -O2 -FEbuild -FUbuild src/mklabels.pas`. Other
targets: `make clean`, and `make install` (to `/usr/local/bin`; override with
`PREFIX=~/.local`).

The binary is written to `build/mklabels`.

## Usage

```
build/mklabels -i image [options]
```

| Option | Meaning |
|---|---|
| `-i file` | Input image (png, jpg, bmp, gif, tif, pnm, tga, pcx) |
| `-o file` | Output PDF (default `tiled.pdf`) |
| `-l len` | Left margin (default 0) |
| `-t len` | Top margin (default 0) |
| `-h len` | Horizontal spacing between tiles (default 0) |
| `-v len` | Vertical spacing between tiles (default 0) |
| `-w len` | Tile width. If only `-w` is given, aspect ratio is kept |
| `-H len` | Tile height. If only `-H` is given, aspect ratio is kept |
| `-d dpi` | DPI used for the natural size when no `-w`/`-H` (default 300) |
| `-p orient` | `portrait` (default) or `landscape` |
| `-s WxH` | Page size (default `8.5x11in`) |
| `-S file`, `--save file` | Save the parameters to a JSON file |
| `-j file`, `--load file` | Load parameters from a JSON file; options given on the command line override it |
| `-L part`, `--layout part` | Use a built-in Avery US Letter sheet layout (see below) |
| `--list-layouts [text]` | List the built-in layouts, optionally filtered by text |
| `-u unit` | Default unit for lengths without a suffix (default `in`) |

Lengths accept the suffixes `in`, `mm`, `cm` and `pt`, e.g. `0.5in`, `12mm`.

Only tiles that fit completely on the page are drawn. If none fit, the
program exits with an error. Transparent areas are composited onto white.

## Examples

A sample 2.5 x 1.25 in label is in `samples/label.png`; try:

```
build/mklabels -i samples/label.png -l 0.5in -t 0.5in -h 0.25in -v 0.25in -o sample.pdf
```

Other examples:

Tile a label 2.5 in wide (height follows the aspect ratio) with half-inch
margins, 0.25 in horizontal and 10 mm vertical spacing:

```
build/mklabels -i label.png -w 2.5in -l 0.5in -t 0.5in -h 0.25in -v 10mm -o sheet.pdf
```

Same layout on a landscape page, unitless values read as inches:

```
build/mklabels -i label.jpg -w 2.5 -l 0.5 -t 0.5 -h 0.25 -v 0.25 -p landscape -o sheet.pdf
```

A4 page with metric measurements:

```
build/mklabels -i label.png -s 210x297mm -u mm -w 60 -H 30 -l 10 -t 15 -h 5 -v 5 -o a4.pdf
```

Use the image's natural size at a given DPI (a 600 px wide image at 300 dpi
is 2 in wide):

```
build/mklabels -i label.png -d 300 -o sheet.pdf
```

Fixed width and height (the image is stretched to fit):

```
build/mklabels -i label.png -w 4in -H 2in -o sheet.pdf
```

## Avery layouts

`--layout` sets the page size, margins, spacing, label size and grid for a
standard Avery US Letter sheet, so you only supply the image:

```
build/mklabels --list-layouts address        # find a part number
build/mklabels -i label.png --layout 5160 -o sheet.pdf
build/mklabels -i label.png -L "Avery 5163" -o shipping.pdf
```

295 part numbers are built in (5160, 5163, 5167, 8160 and many more,
including the equivalent look-alike numbers). Part numbers are matched
ignoring case, spaces and the word "Avery". The image is stretched to the
label size, so prepare artwork with the same aspect ratio as the label.
Other options given with `--layout` override its values (e.g. `-l 0.2in` to
nudge the left margin for your printer). Layouts are portrait only, and the
grid is limited to the sheet's real number of labels.

The layout data comes from the [gLabels](https://sources.debian.org/src/glabels/3.4.1-6/templates)
template database (GPL-3.0-or-later) and is generated into `src/layouts.inc`
by `tools/gen_layouts.py`; see the header of that script for the source file.
Print a test sheet on plain paper and compare it against a real label sheet
before using real stock, since printers add their own offsets.

## Saving and loading parameters

Save the settings for a label sheet once, then reuse them:

```
build/mklabels -i label.png -w 2.5in -l 0.5in -t 0.5in -h 0.25in -v 10mm -p landscape -o sheet.pdf --save avery.json
build/mklabels --load avery.json
```

Override individual settings, e.g. a different image and output while keeping
the layout:

```
build/mklabels --load avery.json -i other.png -o other.pdf
```

A ready-made file is in `samples/label.json`; run it from the repository root:

```
build/mklabels --load samples/label.json
```

The JSON file is plain text and can be edited by hand. Keys: `image`,
`output`, `left`, `top`, `hspace`, `vspace`, `width`, `height`, `dpi`,
`orientation`, `pagesize`. Lengths are saved with explicit units:

```json
{
  "image" : "label.png",
  "output" : "sheet.pdf",
  "left" : "0.5in",
  "top" : "0.5in",
  "hspace" : "0.25in",
  "vspace" : "10mm",
  "width" : "2.5in",
  "orientation" : "landscape"
}
```

On success it prints the grid size and tile count, e.g.
`Wrote sheet.pdf: 3 x 6 = 18 tiles (2.50 x 1.25 in each) on 8.50 x 11.00 in page`.

## License

GPL-3.0-or-later. See [LICENSE](LICENSE).

# mklabels

Tiles an image onto a PDF page as many times as it fits, using the margins and
spacing you specify. Useful for printing sheets of labels.

## Build

Requires Free Pascal (fpc 3.2+).

```
fpc -O2 -FEbuild -FUbuild src/mklabels.pas
```

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
| `-u unit` | Default unit for lengths without a suffix (default `in`) |

Lengths accept the suffixes `in`, `mm`, `cm` and `pt`, e.g. `0.5in`, `12mm`.

Only tiles that fit completely on the page are drawn. If none fit, the
program exits with an error. Transparent areas are composited onto white.

## Examples

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

On success it prints the grid size and tile count, e.g.
`Wrote sheet.pdf: 3 x 6 = 18 tiles (2.50 x 1.25 in each) on 8.50 x 11.00 in page`.

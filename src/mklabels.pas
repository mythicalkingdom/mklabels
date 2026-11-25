{ mklabels - tile an image onto a PDF page.
  Copyright (C) 2026 mythicalkingdom

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <https://www.gnu.org/licenses/>.

  Usage: mklabels -i image [-o out.pdf] [-l left] [-t top] [-h hspace]
                  [-v vspace] [-p portrait|landscape] [-w width] [-H height]
                  [-s pagewidth x pageheight] [-u unit]

  Lengths accept a unit suffix: in, mm, cm, pt (default unit set by -u,
  initially inches).  The image is drawn at its natural size (pixels at
  its stored DPI, or 300 dpi if unknown) unless -w / -H are given. }
program mklabels;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, Math, zstream, fpjson, jsonparser,
  FPImage, FPReadPNG, FPReadJPEG, FPReadBMP, FPReadGIF, FPReadTiff,
  FPReadPNM, FPReadTGA, FPReadPCX;

const
  PtPerInch = 72.0;

type
  { A label sheet layout; all lengths in points, page is US Letter portrait. }
  TLayout = record
    Part, Desc: string;
    Cols, Rows: Integer;
    W, H, Left, Top, HSpace, VSpace: Double;
  end;

{$I layouts.inc}

var
  MaxCols, MaxRows: Integer;   { > 0 when a --layout limits the grid }
  ImageFile, OutFile: string;
  DefUnit: string = 'in';
  Left, Top, HSpace, VSpace: Double;
  ImgW, ImgH: Double;          { in points; 0 = take from image }
  PageW, PageH: Double;        { points, portrait orientation }
  Landscape: Boolean;
  DPI: Double = 300;

procedure Usage;
begin
  WriteLn('Usage: mklabels -i image [options]');
  WriteLn('  -i file     input image (png, jpg, bmp, gif, tif, pnm, tga, pcx)');
  WriteLn('  -o file     output pdf (default: tiled.pdf)');
  WriteLn('  -l len      left margin   (default 0)');
  WriteLn('  -t len      top margin    (default 0)');
  WriteLn('  -h len      horizontal spacing between tiles (default 0)');
  WriteLn('  -v len      vertical spacing between tiles   (default 0)');
  WriteLn('  -w len      tile width  (default: image pixels at --dpi)');
  WriteLn('  -H len      tile height (default: keep aspect, or from dpi)');
  WriteLn('  -d dpi      dpi to assume for natural size (default 300)');
  WriteLn('  -p orient   portrait (default) or landscape');
  WriteLn('  -s WxH      page size (default 8.5x11in; e.g. 210x297mm)');
  WriteLn('  -L part     use a label sheet layout, e.g. 5160 (--layout); sets page,');
  WriteLn('              margins, spacing, tile size and grid; later options override');
  WriteLn('  --list-layouts [text]   list the built-in Avery Letter layouts');
  WriteLn('  -u unit     default unit for lengths: in, mm, cm, pt (default in)');
  WriteLn('  -S file     save the parameters to a JSON file (--save)');
  WriteLn('  -j file     load parameters from a JSON file (--load); other options override it');
  WriteLn('Lengths may carry a suffix, e.g. 0.5in, 12mm, 1.5cm, 36pt.');
  Halt(1);
end;

procedure Die(const Msg: string);
begin
  WriteLn(StdErr, 'Error: ', Msg);
  Halt(2);
end;

{ Parse a length like "12mm", "0.5", "1in" into points. }
function ParseLen(S: string; const Unit_: string): Double;
var
  i: Integer;
  Num, U: string;
  V: Double;
  FS: TFormatSettings;
begin
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  S := Trim(LowerCase(S));
  i := Length(S);
  while (i > 0) and not (S[i] in ['0'..'9', '.']) do Dec(i);
  Num := Copy(S, 1, i);
  U := Trim(Copy(S, i + 1, MaxInt));
  if U = '' then U := Unit_;
  if not TryStrToFloat(Num, V, FS) then Die('bad length: ' + S);
  case U of
    'in', 'inch', 'inches', '"': Result := V * PtPerInch;
    'mm': Result := V / 25.4 * PtPerInch;
    'cm': Result := V / 2.54 * PtPerInch;
    'pt', 'point', 'points': Result := V;
  else
    Die('unknown unit: ' + U);
  end;
end;

procedure ParsePage(const S: string);
var
  p: Integer;
  A, B, U, T: string;
  i: Integer;
begin
  T := LowerCase(S);
  p := Pos('x', T);
  if p = 0 then Die('page size must be WxH, e.g. 8.5x11in');
  A := Copy(T, 1, p - 1);
  B := Copy(T, p + 1, MaxInt);
  { unit suffix may be on either part; apply trailing unit of B to A too }
  i := Length(B);
  while (i > 0) and not (B[i] in ['0'..'9', '.']) do Dec(i);
  U := Copy(B, i + 1, MaxInt);
  if U = '' then U := DefUnit;
  PageW := ParseLen(A, U);
  PageH := ParseLen(B, U);
end;

function FmtF(V: Double): string;
var
  FS: TFormatSettings;
begin
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  Result := FormatFloat('0.####', V, FS);
end;

var
  Norm: TStringList;   { normalized option name=value, saved to JSON }

const
  JsonKeys: array[0..12] of string = ('layout', 'image', 'output', 'left', 'top',
    'hspace', 'vspace', 'width', 'height', 'dpi', 'orientation', 'pagesize',
    'unit');

{ Normalize a part number: lower case, without the brand name or spaces. }
function NormPart(const S: string): string;
begin
  Result := StringReplace(LowerCase(S), 'avery', '', [rfReplaceAll]);
  Result := StringReplace(Result, ' ', '', [rfReplaceAll]);
end;

function FindLayout(const Part: string): Integer;
var
  i: Integer;
  N: string;
begin
  N := NormPart(Part);
  for i := 0 to LayoutCount - 1 do
    if NormPart(Layouts[i].Part) = N then Exit(i);
  Result := -1;
end;

procedure ListLayouts(const Filter: string);
var
  i, n: Integer;
  F, Line: string;
begin
  F := LowerCase(Filter);
  n := 0;
  WriteLn(Format('%-9s %-7s %-17s %s', ['Part', 'Grid', 'Label size (in)', 'Description']));
  for i := 0 to LayoutCount - 1 do
  begin
    with Layouts[i] do
    begin
      Line := Format('%-9s %-7s %-17s %s', [Part,
        IntToStr(Cols) + 'x' + IntToStr(Rows),
        Format('%.3f x %.3f', [W / PtPerInch, H / PtPerInch]), Desc]);
    end;
    if (F = '') or (Pos(F, LowerCase(Line)) > 0) then
    begin
      WriteLn(Line);
      Inc(n);
    end;
  end;
  WriteLn(n, ' layout(s). Sheet size: US Letter, portrait.');
end;

{ Give a length string an explicit unit so saved files do not depend on -u. }
function WithUnit(const S: string): string;
var
  T: string;
begin
  T := Trim(LowerCase(S));
  if (T <> '') and (T[Length(T)] in ['0'..'9', '.']) then T := T + DefUnit;
  Result := T;
end;

{ Apply one option (by JSON key name).  Used by both the command line and
  the JSON loader. }
procedure ApplyOption(const Key, V: string);
var
  L: string;
  i: Integer;
begin
  case Key of
    'image': begin ImageFile := V; Norm.Values[Key] := V; end;
    'output': begin OutFile := V; Norm.Values[Key] := V; end;
    'left': begin L := WithUnit(V); Left := ParseLen(L, DefUnit); Norm.Values[Key] := L; end;
    'top': begin L := WithUnit(V); Top := ParseLen(L, DefUnit); Norm.Values[Key] := L; end;
    'hspace': begin L := WithUnit(V); HSpace := ParseLen(L, DefUnit); Norm.Values[Key] := L; end;
    'vspace': begin L := WithUnit(V); VSpace := ParseLen(L, DefUnit); Norm.Values[Key] := L; end;
    'width': begin L := WithUnit(V); ImgW := ParseLen(L, DefUnit); Norm.Values[Key] := L; end;
    'height': begin L := WithUnit(V); ImgH := ParseLen(L, DefUnit); Norm.Values[Key] := L; end;
    'dpi': begin DPI := StrToFloatDef(V, 300, DefaultFormatSettings); Norm.Values[Key] := V; end;
    'pagesize': begin ParsePage(V); Norm.Values[Key] := V; end;
    'layout': begin
      i := FindLayout(V);
      if i < 0 then
        Die('unknown layout: ' + V + ' (see --list-layouts)');
      Left := Layouts[i].Left; Top := Layouts[i].Top;
      HSpace := Layouts[i].HSpace; VSpace := Layouts[i].VSpace;
      ImgW := Layouts[i].W; ImgH := Layouts[i].H;
      MaxCols := Layouts[i].Cols; MaxRows := Layouts[i].Rows;
      PageW := 8.5 * PtPerInch; PageH := 11 * PtPerInch;
      Norm.Values['layout'] := Layouts[i].Part;
    end;
    'unit': DefUnit := LowerCase(V);   { only affects unitless values after it }
    'orientation': begin
      L := LowerCase(V);
      if (L = 'l') or (L = 'landscape') then Landscape := True
      else if (L = 'p') or (L = 'portrait') then Landscape := False
      else Die('orientation must be portrait or landscape');
      if Landscape then Norm.Values[Key] := 'landscape'
      else Norm.Values[Key] := 'portrait';
    end;
  else
    Die('unknown option in JSON file: ' + Key);
  end;
end;

procedure LoadJson(const FN: string);
var
  FS: TFileStream;
  D: TJSONData;
  O: TJSONObject;
  i: Integer;
begin
  if not FileExists(FN) then Die('json file not found: ' + FN);
  FS := TFileStream.Create(FN, fmOpenRead or fmShareDenyWrite);
  try
    try
      D := GetJSON(FS);
    except
      on E: Exception do Die('cannot parse ' + FN + ': ' + E.Message);
    end;
  finally
    FS.Free;
  end;
  try
    if not (D is TJSONObject) then Die('json file must contain an object');
    O := TJSONObject(D);
    { a saved file is self-contained: its lengths already carry units }
    { the layout sets many values at once, so apply it before the rest }
    i := O.IndexOfName('layout');
    if i >= 0 then ApplyOption('layout', O.Items[i].AsString);
    for i := 0 to O.Count - 1 do
      if O.Names[i] <> 'layout' then
        ApplyOption(O.Names[i], O.Items[i].AsString);
  finally
    D.Free;
  end;
end;

procedure SaveJson(const FN: string);
var
  O: TJSONObject;
  i: Integer;
  K: string;
  SL: TStringList;
begin
  O := TJSONObject.Create;
  try
    for i := 0 to High(JsonKeys) do
    begin
      K := JsonKeys[i];
      if (K <> 'unit') and (Norm.IndexOfName(K) >= 0) then
        O.Add(K, Norm.Values[K]);
    end;
    SL := TStringList.Create;
    try
      SL.Text := O.FormatJSON;
      SL.SaveToFile(FN);
    finally
      SL.Free;
    end;
  finally
    O.Free;
  end;
  WriteLn('Saved parameters to ', FN);
end;

procedure ParseArgs;
var
  i: Integer;
  A, V, SaveFile, Key: string;
  procedure Need;
  begin
    if i >= ParamCount then Usage;
    Inc(i);
    V := ParamStr(i);
  end;
begin
  ImageFile := '';
  OutFile := 'tiled.pdf';
  Left := 0; Top := 0; HSpace := 0; VSpace := 0;
  ImgW := 0; ImgH := 0;
  PageW := 8.5 * PtPerInch; PageH := 11 * PtPerInch;
  Landscape := False;
  MaxCols := 0; MaxRows := 0;
  SaveFile := '';
  Norm := TStringList.Create;

  { first pass: -u applies to everything regardless of order, and --load
    is applied before the command line so the command line overrides it }
  i := 1;
  while i <= ParamCount do
  begin
    if ParamStr(i) = '-u' then
    begin
      Need;
      DefUnit := LowerCase(V);
    end
    else if (ParamStr(i) = '-j') or (ParamStr(i) = '--load') then
    begin
      Need;
      LoadJson(V);
    end
    else if ParamStr(i) = '--list-layouts' then
    begin
      V := '';
      if (i < ParamCount) and (Copy(ParamStr(i + 1), 1, 1) <> '-') then
        V := ParamStr(i + 1);
      ListLayouts(V);
      Halt(0);
    end;
    Inc(i);
  end;

  { second pass: a layout sets many values at once, so apply it before the
    individual options, which can then override it }
  i := 1;
  while i <= ParamCount do
  begin
    if (ParamStr(i) = '-L') or (ParamStr(i) = '--layout') then
    begin
      Need;
      ApplyOption('layout', V);
    end;
    Inc(i);
  end;

  i := 1;
  while i <= ParamCount do
  begin
    A := ParamStr(i);
    Key := '';
    case A of
      '-i': Key := 'image';
      '-o': Key := 'output';
      '-l': Key := 'left';
      '-t': Key := 'top';
      '-h': Key := 'hspace';
      '-v': Key := 'vspace';
      '-w': Key := 'width';
      '-H': Key := 'height';
      '-d': Key := 'dpi';
      '-s': Key := 'pagesize';
      '-p': Key := 'orientation';
      '-u', '-j', '--load', '-L', '--layout': Need;   { handled earlier }
      '-S', '--save': begin Need; SaveFile := V; end;
      '-?', '--help': Usage;
    else
      if Copy(A, 1, 1) <> '-' then
        ApplyOption('image', A)
      else Usage;
    end;
    if Key <> '' then
    begin
      Need;
      ApplyOption(Key, V);
    end;
    Inc(i);
  end;
  if ImageFile = '' then Usage;
  if SaveFile <> '' then SaveJson(SaveFile);
end;

{ ---- PDF writer ---- }

var
  PDF: TMemoryStream;
  Offsets: array of Int64;

procedure W(const S: string);
begin
  if S <> '' then PDF.WriteBuffer(S[1], Length(S));
end;

procedure BeginObj(N: Integer);
begin
  if Length(Offsets) <= N then SetLength(Offsets, N + 1);
  Offsets[N] := PDF.Position;
  W(IntToStr(N) + ' 0 obj' + #10);
end;

procedure EndObj;
begin
  W('endobj' + #10);
end;

function LoadImage(const FN: string; out Img: TFPMemoryImage): Boolean;
var
  Reader: TFPCustomImageReader;
  Ext: string;
begin
  Result := False;
  Ext := LowerCase(ExtractFileExt(FN));
  case Ext of
    '.png': Reader := TFPReaderPNG.Create;
    '.jpg', '.jpeg', '.jpe', '.jfif': Reader := TFPReaderJPEG.Create;
    '.bmp': Reader := TFPReaderBMP.Create;
    '.gif': Reader := TFPReaderGIF.Create;
    '.tif', '.tiff': Reader := TFPReaderTiff.Create;
    '.pbm', '.pgm', '.ppm', '.pnm': Reader := TFPReaderPNM.Create;
    '.tga': Reader := TFPReaderTarga.Create;
    '.pcx': Reader := TFPReaderPCX.Create;
  else
    Die('unsupported image extension: ' + Ext);
  end;
  Img := TFPMemoryImage.Create(0, 0);
  try
    Img.LoadFromFile(FN, Reader);
    Result := True;
  finally
    Reader.Free;
  end;
end;

var
  Img: TFPMemoryImage;
  PW, PH: Double;
  PxW, PxH, x, y, Cols, Rows, r, c, ObjCount: Integer;
  Raw, Comp: TMemoryStream;
  CS: TCompressionStream;
  Row: array of Byte;
  Col: TFPColor;
  Content, XRef: string;
  Cx, Cy, Alpha: Double;
  A, R8, G8, B8: Double;
  StartXRef: Int64;
  Fn: TFileStream;
  Count: Integer;
begin
  ParseArgs;
  if not FileExists(ImageFile) then Die('file not found: ' + ImageFile);
  LoadImage(ImageFile, Img);
  PxW := Img.Width; PxH := Img.Height;
  if (PxW = 0) or (PxH = 0) then Die('empty image');

  { tile size in points }
  if (ImgW > 0) and (ImgH > 0) then begin PW := ImgW; PH := ImgH; end
  else if ImgW > 0 then begin PW := ImgW; PH := ImgW * PxH / PxW; end
  else if ImgH > 0 then begin PH := ImgH; PW := ImgH * PxW / PxH; end
  else begin PW := PxW / DPI * PtPerInch; PH := PxH / DPI * PtPerInch; end;

  if Landscape then
  begin
    { swap so width is the long side }
    if PageW < PageH then begin Alpha := PageW; PageW := PageH; PageH := Alpha; end;
  end
  else if PageW > PageH then
  begin
    Alpha := PageW; PageW := PageH; PageH := Alpha;
  end;

  if (MaxCols > 0) and Landscape then
    Die('layouts are for portrait pages; remove -p landscape');

  { count tiles that fit completely }
  Cols := 0;
  if PageW - Left >= PW - 1e-6 then
    Cols := 1 + Floor((PageW - Left - PW + 1e-6) / (PW + HSpace));
  Rows := 0;
  if PageH - Top >= PH - 1e-6 then
    Rows := 1 + Floor((PageH - Top - PH + 1e-6) / (PH + VSpace));
  if MaxCols > 0 then Cols := Min(Cols, MaxCols);
  if MaxRows > 0 then Rows := Min(Rows, MaxRows);
  if (Cols < 1) or (Rows < 1) then
    Die('image does not fit on the page with these margins');

  { image data: RGB, composite alpha on white }
  Raw := TMemoryStream.Create;
  SetLength(Row, PxW * 3);
  for y := 0 to PxH - 1 do
  begin
    for x := 0 to PxW - 1 do
    begin
      Col := Img.Colors[x, y];
      A := Col.alpha / 65535.0;
      R8 := Col.red / 257.0; G8 := Col.green / 257.0; B8 := Col.blue / 257.0;
      Row[x * 3]     := Round(R8 * A + 255 * (1 - A));
      Row[x * 3 + 1] := Round(G8 * A + 255 * (1 - A));
      Row[x * 3 + 2] := Round(B8 * A + 255 * (1 - A));
    end;
    Raw.WriteBuffer(Row[0], Length(Row));
  end;
  Raw.Position := 0;
  Comp := TMemoryStream.Create;
  CS := TCompressionStream.Create(clDefault, Comp);
  CS.CopyFrom(Raw, Raw.Size);
  CS.Free;

  { content stream }
  Content := 'q' + #10;
  Count := 0;
  for r := 0 to Rows - 1 do
    for c := 0 to Cols - 1 do
    begin
      Cx := Left + c * (PW + HSpace);
      Cy := PageH - Top - r * (PH + VSpace) - PH;  { PDF origin is bottom-left }
      Content := Content + 'q ' + FmtF(PW) + ' 0 0 ' + FmtF(PH) + ' ' +
        FmtF(Cx) + ' ' + FmtF(Cy) + ' cm /Im0 Do Q' + #10;
      Inc(Count);
    end;
  Content := Content + 'Q' + #10;

  PDF := TMemoryStream.Create;
  W('%PDF-1.4' + #10);
  BeginObj(1); W('<< /Type /Catalog /Pages 2 0 R >>' + #10); EndObj;
  BeginObj(2); W('<< /Type /Pages /Kids [3 0 R] /Count 1 >>' + #10); EndObj;
  BeginObj(3);
  W('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ' + FmtF(PageW) + ' ' +
    FmtF(PageH) + '] /Resources << /XObject << /Im0 5 0 R >> >> /Contents 4 0 R >>' + #10);
  EndObj;
  BeginObj(4);
  W('<< /Length ' + IntToStr(Length(Content)) + ' >>' + #10 + 'stream' + #10);
  W(Content);
  W('endstream' + #10);
  EndObj;
  BeginObj(5);
  W('<< /Type /XObject /Subtype /Image /Width ' + IntToStr(PxW) + ' /Height ' +
    IntToStr(PxH) + ' /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /FlateDecode /Length ' +
    IntToStr(Comp.Size) + ' >>' + #10 + 'stream' + #10);
  PDF.WriteBuffer(Comp.Memory^, Comp.Size);
  W(#10 + 'endstream' + #10);
  EndObj;
  ObjCount := 6;

  StartXRef := PDF.Position;
  XRef := 'xref' + #10 + '0 ' + IntToStr(ObjCount) + #10 + '0000000000 65535 f ' + #10;
  for r := 1 to ObjCount - 1 do
    XRef := XRef + Format('%.10d 00000 n ', [Offsets[r]]) + #10;
  W(XRef);
  W('trailer' + #10 + '<< /Size ' + IntToStr(ObjCount) + ' /Root 1 0 R >>' + #10);
  W('startxref' + #10 + IntToStr(StartXRef) + #10 + '%%EOF' + #10);

  Fn := TFileStream.Create(OutFile, fmCreate);
  try
    Fn.CopyFrom(PDF, 0);
  finally
    Fn.Free;
  end;

  WriteLn(Format('Wrote %s: %d x %d = %d tiles (%.2f x %.2f in each) on %.2f x %.2f in page',
    [OutFile, Cols, Rows, Count, PW / PtPerInch, PH / PtPerInch,
     PageW / PtPerInch, PageH / PtPerInch]));
end.

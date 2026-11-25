unit uTheme;
{$mode objfpc}{$H+}
{ colors, the screen scale and the flat button style shared by the main window and the dialogs }

interface

uses
  Classes, SysUtils, Graphics, Forms, Math, BGRABitmapTypes, BCButton, BCTypes;

type
  TTheme = record
    Bg, Panel, Text, Muted, Accent, AccentSoft, Red, Line, Hover, Mark: TColor;
    SansName: String;
  end;

var
  Sc: Double = 1.0;          { screen scale: PixelsPerInch / 96 (HiDPI) }

function S_(N: Integer): Integer;          { a size in 96 dpi pixels, scaled to this screen }
function Pix(C: TColor): TBGRAPixel;
function LightTheme: TTheme;
function DarkTheme: TTheme;
procedure StyleBtn(B: TBCButton; const Th: TTheme; Accent: Boolean);

implementation

function S_(N: Integer): Integer;
begin
  Result := Round(N * Sc);
end;

function Pix(C: TColor): TBGRAPixel;
begin
  Result := ColorToBGRA(ColorToRGB(C));
end;

function LightTheme: TTheme;
begin
  Result.Bg := RGBToColor($FD, $FC, $F9);
  Result.Panel := RGBToColor($F3, $F1, $EC);
  Result.Text := RGBToColor($26, $26, $2B);
  Result.Muted := RGBToColor($8B, $87, $7E);
  Result.Accent := RGBToColor($3B, $5B, $C9);
  Result.AccentSoft := RGBToColor($E3, $E9, $FB);
  Result.Red := RGBToColor($B0, $2A, $2A);
  Result.Line := RGBToColor($E4, $E0, $D8);
  Result.Hover := RGBToColor($EA, $E7, $E0);
  Result.Mark := RGBToColor($FF, $E8, $8A);
  Result.SansName := 'sans';
end;

function DarkTheme: TTheme;
begin
  Result.Bg := RGBToColor($1B, $1C, $20);
  Result.Panel := RGBToColor($23, $24, $29);
  Result.Text := RGBToColor($DC, $DA, $D3);
  Result.Muted := RGBToColor($86, $85, $80);
  Result.Accent := RGBToColor($8C, $A8, $FF);
  Result.AccentSoft := RGBToColor($2C, $34, $52);
  Result.Red := RGBToColor($FF, $8A, $80);
  Result.Line := RGBToColor($33, $34, $3A);
  Result.Hover := RGBToColor($2C, $2D, $33);
  Result.Mark := RGBToColor($6B, $5A, $10);
  Result.SansName := 'sans';
end;

procedure StyleBtn(B: TBCButton; const Th: TTheme; Accent: Boolean);
begin
  B.Rounding.RoundX := S_(10);
  B.Rounding.RoundY := S_(10);
  B.StateNormal.Border.Style := bboNone;
  B.StateHover.Border.Style := bboNone;
  B.StateClicked.Border.Style := bboNone;
  B.StateNormal.Background.Style := bbsColor;
  B.StateHover.Background.Style := bbsColor;
  B.StateClicked.Background.Style := bbsColor;
  if Accent then B.StateNormal.Background.Color := Th.AccentSoft else B.StateNormal.Background.Color := Th.Panel;
  B.StateHover.Background.Color := Th.Hover;
  B.StateClicked.Background.Color := Th.Line;
  B.StateNormal.FontEx.Color := Th.Text;
  B.StateHover.FontEx.Color := Th.Text;
  B.StateClicked.FontEx.Color := Th.Text;
  B.StateNormal.FontEx.Name := Th.SansName;
  B.StateHover.FontEx.Name := Th.SansName;
  B.StateClicked.FontEx.Name := Th.SansName;
  B.StateNormal.FontEx.Shadow := False;
  B.StateHover.FontEx.Shadow := False;
  B.StateClicked.FontEx.Shadow := False;
  B.StateNormal.FontEx.Height := S_(15);
  B.StateHover.FontEx.Height := S_(15);
  B.StateClicked.FontEx.Height := S_(15);
  B.Invalidate;
end;

end.

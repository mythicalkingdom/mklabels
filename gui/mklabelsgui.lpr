program mklabelsgui;
{$mode objfpc}{$H+}
{ mklabelsgui - a simple GUI for mklabels (Lazarus / LCL, BGRABitmap and BGRAControls): set the parameters,
  press Generate, and the PDF made by mklabels is shown.  Same look and settings style as mkbiblegui. }
uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms, bgracontrols, uMain;

begin
  RequireDerivedFormResource := False;
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.

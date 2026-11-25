unit uMain;
{$mode objfpc}{$H+}
{ The main window of mklabelsgui: a sidebar with the mklabels parameters, a Generate button that runs the
  mklabels command line program, and a preview of the PDF it wrote (rendered with pdftoppm). }

interface

uses
  Classes, SysUtils, Graphics, Forms, Controls, StdCtrls, ExtCtrls, Math, LCLType, LCLIntf, Dialogs, Process,
  BGRABitmap, BGRABitmapTypes, BGRAVirtualScreen, BCButton, uTheme;

type
  { TMainForm }
  TMainForm = class(TForm)
  private
    Cfg: TStringList;          { key = value settings, ~/.config/mklabels/mklabels.cfg }
    Theme: TTheme;
    Dark, AutoGen: Boolean;
    SansName: String;
    Top_, Side: TPanel;
    Pane: TBGRAVirtualScreen;
    TitleLbl, StatusLbl: TLabel;
    BtnGen, BtnView, BtnTheme, BtnImg, BtnOut: TBCButton;
    RowLbl: array of TLabel;
    RowCtl: array of TControl;
    EdImage, EdLeft, EdTop, EdHS, EdVS, EdW, EdH, EdDpi, EdOut: TEdit;
    CbLayout, CbUnit, CbOrient, CbPage: TComboBox;
    Preview, PrevScaled: TBGRABitmap;
    ScaledW, ScaledH: Integer;
    PdfFile: String;
    function GetSetting(const Key, Default: String): String;
    procedure PutSetting(const Key, Value: String);
    procedure LoadConfig;
    procedure SaveConfig;
    function PickFont(const Wanted: array of String; const Fallback: String): String;
    function MakeBtn(const Cap: String; W: Integer; Owner_: TWinControl; Handler: TNotifyEvent): TBCButton;
    function MakeEdit(const Cap: String; const AHint: String): TEdit;
    function MakeCombo(const Cap: String; Style: TComboBoxStyle): TComboBox;
    procedure BuildUI;
    procedure FillLayouts;
    procedure ApplyTheme;
    procedure DoResize(Sender: TObject);
    procedure FormKey(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure PaneRedraw(Sender: TObject; Bitmap: TBGRABitmap);
    procedure ImgClick(Sender: TObject);
    procedure OutClick(Sender: TObject);
    procedure GenClick(Sender: TObject);
    procedure ViewClick(Sender: TObject);
    procedure ThemeClick(Sender: TObject);
    procedure LayoutChange(Sender: TObject);
    procedure ShowOnce(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    function CurLayout: String;
    function FindTool(const ExeName: String): String;
    function RunCapture(const Exe: String; Args: TStrings; out Outp: String): Integer;
    procedure SetStatus(const Msg: String; IsError: Boolean);
    procedure ShowPdf(const Pdf: String);
    procedure ReadFields;
    procedure SaveFields;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  MainForm: TMainForm;

implementation

const
  SideW = 400;

{ ---- settings: simple "key = value" lines, like mkbible.cfg ---- }

function ConfigDir: String;
begin
  Result := IncludeTrailingPathDelimiter(GetEnvironmentVariable('HOME')) + '.config/mklabels';
{$IFDEF WINDOWS}
  Result := IncludeTrailingPathDelimiter(GetEnvironmentVariable('APPDATA')) + 'mklabels';
{$ENDIF}
end;

function ConfigFile: String;
begin
  Result := IncludeTrailingPathDelimiter(ConfigDir) + 'mklabels.cfg';
end;

function TMainForm.GetSetting(const Key, Default: String): String;
var
  i, P: Integer;
  L: String;
begin
  Result := Default;
  for i := 0 to Cfg.Count - 1 do
  begin
    L := Cfg[i];
    P := Pos('=', L);
    if (P > 0) and (Trim(Copy(L, 1, P - 1)) = Key) then
    begin
      Result := Trim(Copy(L, P + 1, MaxInt));
      Exit;
    end;
  end;
end;

procedure TMainForm.PutSetting(const Key, Value: String);
var
  i, P: Integer;
  L: String;
begin
  for i := 0 to Cfg.Count - 1 do
  begin
    L := Cfg[i];
    P := Pos('=', L);
    if (P > 0) and (Trim(Copy(L, 1, P - 1)) = Key) then
    begin
      Cfg[i] := Key + ' = ' + Value;
      Exit;
    end;
  end;
  Cfg.Add(Key + ' = ' + Value);
end;

procedure TMainForm.LoadConfig;
begin
  if FileExists(ConfigFile) then
    try
      Cfg.LoadFromFile(ConfigFile);
    except
    end;
end;

procedure TMainForm.SaveConfig;
begin
  try
    ForceDirectories(ConfigDir);
    Cfg.SaveToFile(ConfigFile);
  except
  end;
end;

{ ---- construction ---- }

function TMainForm.PickFont(const Wanted: array of String; const Fallback: String): String;
var
  i: Integer;
begin
  Result := Fallback;
  for i := 0 to High(Wanted) do
    if Screen.Fonts.IndexOf(Wanted[i]) >= 0 then begin Result := Wanted[i]; Exit; end;
end;

function TMainForm.MakeBtn(const Cap: String; W: Integer; Owner_: TWinControl; Handler: TNotifyEvent): TBCButton;
begin
  Result := TBCButton.Create(Self);
  Result.Parent := Owner_;
  Result.Caption := Cap;
  Result.Width := W;
  Result.Height := S_(34);
  Result.OnClick := Handler;
end;

function TMainForm.MakeEdit(const Cap: String; const AHint: String): TEdit;
var
  L: TLabel;
begin
  L := TLabel.Create(Self);
  L.Parent := Side;
  L.Caption := Cap;
  Result := TEdit.Create(Self);
  Result.Parent := Side;
  Result.TextHint := AHint;
  SetLength(RowLbl, Length(RowLbl) + 1); RowLbl[High(RowLbl)] := L;
  SetLength(RowCtl, Length(RowCtl) + 1); RowCtl[High(RowCtl)] := Result;
end;

function TMainForm.MakeCombo(const Cap: String; Style: TComboBoxStyle): TComboBox;
var
  L: TLabel;
begin
  L := TLabel.Create(Self);
  L.Parent := Side;
  L.Caption := Cap;
  Result := TComboBox.Create(Self);
  Result.Parent := Side;
  Result.Style := Style;
  SetLength(RowLbl, Length(RowLbl) + 1); RowLbl[High(RowLbl)] := L;
  SetLength(RowCtl, Length(RowCtl) + 1); RowCtl[High(RowCtl)] := Result;
end;

procedure TMainForm.BuildUI;
begin
  Top_ := TPanel.Create(Self);
  Top_.Parent := Self;
  Top_.Align := alTop;
  Top_.Height := S_(56);
  Top_.BevelOuter := bvNone;
  Side := TPanel.Create(Self);
  Side.Parent := Self;
  Side.Align := alLeft;
  Side.Width := S_(SideW);
  Side.BevelOuter := bvNone;
  Pane := TBGRAVirtualScreen.Create(Self);
  Pane.Parent := Self;
  Pane.Align := alClient;
  Pane.OnRedraw := @PaneRedraw;

  TitleLbl := TLabel.Create(Self);
  TitleLbl.Parent := Top_;
  TitleLbl.AutoSize := True;
  TitleLbl.Caption := 'mklabels';
  BtnTheme := MakeBtn('Dark', S_(72), Top_, @ThemeClick);
  BtnView := MakeBtn('Open in viewer', S_(140), Top_, @ViewClick);

  { rows, top to bottom }
  EdImage := MakeEdit('Image', 'png, jpg, bmp, gif ...');
  CbLayout := MakeCombo('Avery layout', csDropDown);
  CbLayout.OnChange := @LayoutChange;
  EdLeft := MakeEdit('Left margin', '');
  EdTop := MakeEdit('Top margin', '');
  EdHS := MakeEdit('Horizontal space', '');
  EdVS := MakeEdit('Vertical space', '');
  EdW := MakeEdit('Label width', '');
  EdH := MakeEdit('Label height', '');
  CbUnit := MakeCombo('Units', csDropDownList);
  CbUnit.Items.CommaText := 'in,mm,cm,pt';
  CbOrient := MakeCombo('Orientation', csDropDownList);
  CbOrient.Items.CommaText := 'Portrait,Landscape';
  CbPage := MakeCombo('Page size', csDropDown);
  CbPage.Items.Add('8.5x11in');
  CbPage.Items.Add('8.5x14in');
  CbPage.Items.Add('210x297mm');
  CbPage.Items.Add('148x210mm');
  EdDpi := MakeEdit('Image DPI', '300');
  EdOut := MakeEdit('Output PDF', 'labels.pdf next to the image');
  BtnImg := MakeBtn('…', S_(40), Side, @ImgClick);
  BtnOut := MakeBtn('…', S_(40), Side, @OutClick);
  BtnGen := MakeBtn('Generate', S_(200), Side, @GenClick);
  StatusLbl := TLabel.Create(Self);
  StatusLbl.Parent := Side;
  StatusLbl.WordWrap := True;
  StatusLbl.AutoSize := False;
end;

procedure TMainForm.FillLayouts;
var
  Tool, Outp: String;
  Args: TStringList;
  Lines: TStringList;
  i, j: Integer;
  Desc: String;
  T: TStringList;
begin
  CbLayout.Items.Clear;
  CbLayout.Items.Add('(none)');
  Tool := FindTool('mklabels');
  if Tool = '' then Exit;
  Args := TStringList.Create;
  Lines := TStringList.Create;
  T := TStringList.Create;
  try
    Args.Add('--list-layouts');
    if RunCapture(Tool, Args, Outp) <> 0 then Exit;
    Lines.Text := Outp;
    { header line, then "part grid W x H desc", then a count line }
    for i := 1 to Lines.Count - 2 do
    begin
      T.Clear;
      T.Delimiter := ' ';
      T.StrictDelimiter := True;
      T.DelimitedText := Trim(Lines[i]);
      { drop empty tokens from the column padding }
      while T.IndexOf('') >= 0 do T.Delete(T.IndexOf(''));
      if T.Count < 5 then Continue;
      Desc := '';
      for j := 5 to T.Count - 1 do Desc := Desc + ' ' + T[j];
      CbLayout.Items.Add(T[0] + '   ' + T[1] + '   ' + T[2] + ' x ' + T[4] + ' in  ' + Trim(Desc));
    end;
  finally
    T.Free;
    Lines.Free;
    Args.Free;
  end;
end;

constructor TMainForm.Create(TheOwner: TComponent);
var
  i: Integer;
begin
  inherited CreateNew(TheOwner);
  PrevScaled := nil;
  AutoGen := False;
  Cfg := TStringList.Create;
  LoadConfig;
  Caption := 'mklabels';
  Sc := Max(1.0, Screen.PixelsPerInch / 96);
  Width := S_(1180); Height := S_(780);
  Position := poScreenCenter;
  KeyPreview := True;
  OnKeyDown := @FormKey;
  OnResize := @DoResize;
  OnCloseQuery := @FormCloseQuery;
  SansName := PickFont(['Lato', 'Segoe UI', 'Cantarell', 'Noto Sans', 'DejaVu Sans', 'Arial'], 'sans');
  Dark := GetSetting('gui.dark', '0') = '1';
  for i := 1 to ParamCount do
    if ParamStr(i) = '--generate' then AutoGen := True
    else if ParamStr(i) = '--dark' then Dark := True
    else if ParamStr(i) = '--light' then Dark := False;
  BuildUI;
  FillLayouts;
  ReadFields;
  { an image given on the command line wins over the remembered one }
  for i := 1 to ParamCount do
    if Copy(ParamStr(i), 1, 1) <> '-' then EdImage.Text := ExpandFileName(ParamStr(i));
  ApplyTheme;
  LayoutChange(nil);
  SetStatus('Choose an image, set the parameters and press Generate (Ctrl+Enter).', False);
  DoResize(nil);
  OnShow := @ShowOnce;
end;

procedure TMainForm.ShowOnce(Sender: TObject);
begin
  OnShow := nil;
  if AutoGen then GenClick(nil);   { option --generate, for trying it out }
end;

destructor TMainForm.Destroy;
begin
  Preview.Free;
  PrevScaled.Free;
  Cfg.Free;
  inherited Destroy;
end;

{ ---- fields <-> settings ---- }

procedure TMainForm.ReadFields;
var
  i: Integer;
  Lay: String;
begin
  EdImage.Text := GetSetting('image', '');
  EdLeft.Text := GetSetting('left', '');
  EdTop.Text := GetSetting('top', '');
  EdHS.Text := GetSetting('hspace', '');
  EdVS.Text := GetSetting('vspace', '');
  EdW.Text := GetSetting('width', '');
  EdH.Text := GetSetting('height', '');
  EdDpi.Text := GetSetting('dpi', '');
  EdOut.Text := GetSetting('output', '');
  CbUnit.ItemIndex := Max(0, CbUnit.Items.IndexOf(GetSetting('unit', 'in')));
  CbOrient.ItemIndex := Ord(GetSetting('orientation', 'portrait') = 'landscape');
  CbPage.Text := GetSetting('pagesize', '8.5x11in');
  CbLayout.ItemIndex := 0;
  Lay := GetSetting('layout', '');
  if Lay <> '' then
    for i := 1 to CbLayout.Items.Count - 1 do
      if Pos(Lay + ' ', CbLayout.Items[i]) = 1 then begin CbLayout.ItemIndex := i; Break; end;
end;

procedure TMainForm.SaveFields;
begin
  PutSetting('gui.dark', IntToStr(Ord(Dark)));
  PutSetting('image', Trim(EdImage.Text));
  PutSetting('layout', CurLayout);
  PutSetting('left', Trim(EdLeft.Text));
  PutSetting('top', Trim(EdTop.Text));
  PutSetting('hspace', Trim(EdHS.Text));
  PutSetting('vspace', Trim(EdVS.Text));
  PutSetting('width', Trim(EdW.Text));
  PutSetting('height', Trim(EdH.Text));
  PutSetting('dpi', Trim(EdDpi.Text));
  PutSetting('output', Trim(EdOut.Text));
  PutSetting('unit', CbUnit.Text);
  if CbOrient.ItemIndex = 1 then PutSetting('orientation', 'landscape')
  else PutSetting('orientation', 'portrait');
  PutSetting('pagesize', Trim(CbPage.Text));
  SaveConfig;
end;

procedure TMainForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  SaveFields;
  CanClose := True;
end;

{ the part number typed or chosen in the layout box, '' for none }
function TMainForm.CurLayout: String;
var
  S: String;
  P: Integer;
begin
  S := Trim(CbLayout.Text);
  P := Pos(' ', S);
  if P > 0 then S := Copy(S, 1, P - 1);
  if (S = '') or (LowerCase(S) = '(none)') then S := '';
  Result := S;
end;

procedure TMainForm.LayoutChange(Sender: TObject);
var
  Lay: Boolean;
begin
  Lay := CurLayout <> '';
  { a layout fixes the page (US Letter, portrait); the margin and size fields then only override it }
  CbOrient.Enabled := not Lay;
  CbPage.Enabled := not Lay;
  if Lay then CbOrient.ItemIndex := 0;
  if Lay then
  begin
    EdLeft.TextHint := 'from layout'; EdTop.TextHint := 'from layout';
    EdHS.TextHint := 'from layout'; EdVS.TextHint := 'from layout';
    EdW.TextHint := 'from layout'; EdH.TextHint := 'from layout';
  end
  else
  begin
    EdLeft.TextHint := '0'; EdTop.TextHint := '0';
    EdHS.TextHint := '0'; EdVS.TextHint := '0';
    EdW.TextHint := 'image size'; EdH.TextHint := 'keep aspect';
  end;
end;

{ ---- theme and layout ---- }

procedure TMainForm.ApplyTheme;
var
  i: Integer;
begin
  if Dark then Theme := DarkTheme else Theme := LightTheme;
  Theme.SansName := SansName;
  Color := Theme.Bg;
  Top_.Color := Theme.Bg;
  Side.Color := Theme.Bg;
  TitleLbl.Font.Name := SansName;
  TitleLbl.Font.Size := 15;
  TitleLbl.Font.Style := [fsBold];
  TitleLbl.Font.Color := Theme.Text;
  for i := 0 to High(RowLbl) do
  begin
    RowLbl[i].Font.Name := SansName;
    RowLbl[i].Font.Size := 10;
    RowLbl[i].Font.Color := Theme.Muted;
  end;
  for i := 0 to High(RowCtl) do
  begin
    if RowCtl[i] is TEdit then
    begin
      { the native entry keeps its system colors (the theme colors are not applied by GTK2) }
      TEdit(RowCtl[i]).Font.Name := SansName;
      TEdit(RowCtl[i]).Font.Size := 10;
    end
    else if RowCtl[i] is TComboBox then
    begin
      { the native drop-down lists ignore the colors, so keep their system colors }
      if TComboBox(RowCtl[i]).Style = csDropDown then
      begin
        TComboBox(RowCtl[i]).Color := Theme.Panel;
        TComboBox(RowCtl[i]).Font.Color := Theme.Text;
      end
      else
      begin
        TComboBox(RowCtl[i]).Color := clDefault;
        TComboBox(RowCtl[i]).Font.Color := clDefault;
      end;
      TComboBox(RowCtl[i]).Font.Name := SansName;
      TComboBox(RowCtl[i]).Font.Size := 10;
    end;
  end;
  StatusLbl.Font.Name := SansName;
  StatusLbl.Font.Size := 10;
  StyleBtn(BtnGen, Theme, True);
  StyleBtn(BtnView, Theme, False);
  StyleBtn(BtnTheme, Theme, False);
  StyleBtn(BtnImg, Theme, False);
  StyleBtn(BtnOut, Theme, False);
  if Dark then BtnTheme.Caption := 'Light' else BtnTheme.Caption := 'Dark';
  Pane.RedrawBitmap;
end;

procedure TMainForm.DoResize(Sender: TObject);
var
  i, Y, X, W, RowH, Gap: Integer;
begin
  RowH := S_(30);
  Gap := S_(38);
  X := S_(130);
  W := Side.ClientWidth - X - S_(16);
  Y := S_(16);
  for i := 0 to High(RowCtl) do
  begin
    RowLbl[i].Left := S_(16);
    RowLbl[i].Top := Y + (RowH - RowLbl[i].Height) div 2;
    RowCtl[i].SetBounds(X, Y, W, RowH);
    if (RowCtl[i] = EdImage) or (RowCtl[i] = EdOut) then
      RowCtl[i].Width := W - S_(46);
    Inc(Y, Gap);
  end;
  BtnImg.SetBounds(X + W - S_(40), EdImage.Top, S_(40), RowH);
  BtnOut.SetBounds(X + W - S_(40), EdOut.Top, S_(40), RowH);
  BtnGen.SetBounds(S_(16), Y + S_(8), Side.ClientWidth - S_(32), S_(42));
  StatusLbl.SetBounds(S_(16), Y + S_(60), Side.ClientWidth - S_(32), Max(S_(40), Side.ClientHeight - Y - S_(76)));
  TitleLbl.Left := S_(16);
  TitleLbl.Top := (Top_.Height - TitleLbl.Height) div 2;
  BtnTheme.SetBounds(Top_.ClientWidth - S_(16) - BtnTheme.Width, (Top_.Height - S_(34)) div 2, BtnTheme.Width, S_(34));
  BtnView.SetBounds(BtnTheme.Left - S_(8) - BtnView.Width, BtnTheme.Top, BtnView.Width, S_(34));
end;

procedure TMainForm.FormKey(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if ((Key = VK_RETURN) and (ssCtrl in Shift)) or (Key = VK_F5) then
  begin
    Key := 0;
    GenClick(nil);
  end;
end;

procedure TMainForm.ThemeClick(Sender: TObject);
begin
  Dark := not Dark;
  ApplyTheme;
end;

{ ---- running the tools ---- }

function TMainForm.FindTool(const ExeName: String): String;
begin
  Result := ExtractFilePath(ParamStr(0)) + ExeName;
  if FileExists(Result) then Exit;
  Result := FileSearch(ExeName, GetEnvironmentVariable('PATH'));
end;

function TMainForm.RunCapture(const Exe: String; Args: TStrings; out Outp: String): Integer;
var
  P: TProcess;
  S: TStringStream;
  Buf: array[0..4095] of Byte;
  N: Integer;
begin
  Outp := '';
  Result := -1;
  P := TProcess.Create(nil);
  S := TStringStream.Create('');
  try
    P.Executable := Exe;
    P.Parameters.AddStrings(Args);
    P.Options := [poUsePipes, poStderrToOutput, poNoConsole];
    try
      P.Execute;
    except
      on E: Exception do begin Outp := E.Message; Exit; end;
    end;
    repeat
      N := P.Output.Read(Buf, SizeOf(Buf));
      if N > 0 then S.Write(Buf, N);
    until N <= 0;
    P.WaitOnExit;
    Result := P.ExitStatus;
    Outp := Trim(S.DataString);
  finally
    S.Free;
    P.Free;
  end;
end;

procedure TMainForm.SetStatus(const Msg: String; IsError: Boolean);
begin
  StatusLbl.Caption := Msg;
  if IsError then StatusLbl.Font.Color := Theme.Red else StatusLbl.Font.Color := Theme.Muted;
end;

procedure TMainForm.ImgClick(Sender: TObject);
var
  D: TOpenDialog;
begin
  D := TOpenDialog.Create(Self);
  try
    D.Title := 'Choose the label image';
    D.Filter := 'Images|*.png;*.jpg;*.jpeg;*.bmp;*.gif;*.tif;*.tiff;*.pbm;*.pgm;*.ppm;*.tga;*.pcx|All files|*';
    D.FileName := EdImage.Text;
    if D.Execute then EdImage.Text := D.FileName;
  finally
    D.Free;
  end;
end;

procedure TMainForm.OutClick(Sender: TObject);
var
  D: TSaveDialog;
begin
  D := TSaveDialog.Create(Self);
  try
    D.Title := 'Output PDF';
    D.Filter := 'PDF|*.pdf';
    D.DefaultExt := 'pdf';
    D.FileName := EdOut.Text;
    if D.Execute then EdOut.Text := D.FileName;
  finally
    D.Free;
  end;
end;

procedure TMainForm.GenClick(Sender: TObject);
var
  Args: TStringList;
  Tool, Img, OutF, Outp: String;
  Code: Integer;

  procedure Opt(const Flag, V: String);
  begin
    if Trim(V) <> '' then begin Args.Add(Flag); Args.Add(Trim(V)); end;
  end;

begin
  Tool := FindTool('mklabels');
  if Tool = '' then
  begin
    SetStatus('The mklabels program was not found. Build it with make, and keep it next to mklabelsgui or in the PATH.', True);
    Exit;
  end;
  Img := Trim(EdImage.Text);
  if Img = '' then begin SetStatus('Choose an image first.', True); Exit; end;
  if not FileExists(Img) then begin SetStatus('Image not found: ' + Img, True); Exit; end;
  OutF := Trim(EdOut.Text);
  if OutF = '' then OutF := ExtractFilePath(ExpandFileName(Img)) + 'labels.pdf';
  EdOut.Text := OutF;
  Args := TStringList.Create;
  try
    Opt('-i', Img);
    Opt('-o', OutF);
    Opt('-u', CbUnit.Text);
    if CurLayout <> '' then Opt('-L', CurLayout)
    else
    begin
      if CbOrient.ItemIndex = 1 then Opt('-p', 'landscape');
      Opt('-s', CbPage.Text);
    end;
    Opt('-l', EdLeft.Text);
    Opt('-t', EdTop.Text);
    Opt('-h', EdHS.Text);
    Opt('-v', EdVS.Text);
    Opt('-w', EdW.Text);
    Opt('-H', EdH.Text);
    Opt('-d', EdDpi.Text);
    SetStatus('Generating ...', False);
    Application.ProcessMessages;
    Code := RunCapture(Tool, Args, Outp);
  finally
    Args.Free;
  end;
  SaveFields;
  if Code <> 0 then
  begin
    SetStatus(Outp, True);
    Exit;
  end;
  SetStatus(Outp, False);
  PdfFile := OutF;
  ShowPdf(OutF);
end;

procedure TMainForm.ShowPdf(const Pdf: String);
var
  Tool, Base, Outp: String;
  Args: TStringList;
begin
  Tool := FindTool('pdftoppm');
  if Tool = '' then
  begin
    SetStatus(StatusLbl.Caption + LineEnding + 'No preview: pdftoppm (poppler-utils) is not installed. Use Open in viewer.', False);
    Exit;
  end;
  Base := IncludeTrailingPathDelimiter(GetTempDir) + 'mklabelsgui-preview';
  Args := TStringList.Create;
  try
    Args.Add('-r'); Args.Add('150');
    Args.Add('-png'); Args.Add('-singlefile');
    Args.Add(Pdf); Args.Add(Base);
    if RunCapture(Tool, Args, Outp) <> 0 then
    begin
      SetStatus('Could not render the preview: ' + Outp, True);
      Exit;
    end;
  finally
    Args.Free;
  end;
  FreeAndNil(Preview);
  FreeAndNil(PrevScaled);
  try
    Preview := TBGRABitmap.Create(Base + '.png');
  except
    on E: Exception do SetStatus('Could not load the preview: ' + E.Message, True);
  end;
  Pane.RedrawBitmap;
end;

procedure TMainForm.ViewClick(Sender: TObject);
begin
  if (PdfFile = '') or not FileExists(PdfFile) then
  begin
    SetStatus('Generate a PDF first.', True);
    Exit;
  end;
  OpenDocument(PdfFile);
end;

{ ---- preview ---- }

procedure TMainForm.PaneRedraw(Sender: TObject; Bitmap: TBGRABitmap);
var
  Pad, AW, AH, DW, DH, X, Y: Integer;
  K: Double;
begin
  Bitmap.Fill(Pix(Theme.Panel));
  Bitmap.FontQuality := fqFineAntialiasing;
  if Preview = nil then
  begin
    Bitmap.FontName := SansName;
    Bitmap.FontHeight := S_(20);
    Bitmap.TextOut(Pane.Width div 2, Pane.Height div 2 - S_(12), 'The PDF appears here after Generate', Pix(Theme.Muted), taCenter);
    Exit;
  end;
  Pad := S_(24);
  AW := Max(10, Bitmap.Width - 2 * Pad);
  AH := Max(10, Bitmap.Height - 2 * Pad);
  K := Min(AW / Preview.Width, AH / Preview.Height);
  DW := Max(1, Round(Preview.Width * K));
  DH := Max(1, Round(Preview.Height * K));
  if (PrevScaled = nil) or (ScaledW <> DW) or (ScaledH <> DH) then
  begin
    FreeAndNil(PrevScaled);
    PrevScaled := Preview.Resample(DW, DH, rmFineResample) as TBGRABitmap;
    ScaledW := DW; ScaledH := DH;
  end;
  X := (Bitmap.Width - DW) div 2;
  Y := (Bitmap.Height - DH) div 2;
  Bitmap.FillRect(X + S_(4), Y + S_(5), X + DW + S_(4), Y + DH + S_(5), BGRA(0, 0, 0, 60), dmDrawWithTransparency);
  Bitmap.PutImage(X, Y, PrevScaled, dmSet);
  Bitmap.Rectangle(X, Y, X + DW, Y + DH, Pix(Theme.Line), dmDrawWithTransparency);
end;

end.

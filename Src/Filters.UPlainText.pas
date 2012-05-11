unit Filters.UPlainText;

interface

uses
  SysUtils, Classes,
  Engine.UPattern, UStructs;

type

  TPlainTextReader = class(TObject)
  strict private
    var
      fPattern: TPattern;
      fLines: TStringList;
    procedure Parse;
    procedure ParseCommentLines(var LineIdx: Integer);
    procedure ParsePatternLines(var LineIdx: Integer);
    function CalculateGridSize(const StartLineIdx: Integer): TSizeEx;
    procedure SetDefaults;
  public
    constructor Create;
    destructor Destroy; override;
    procedure LoadFromFile(const APattern: TPattern;
      const AFileName: TFileName);
    procedure LoadFromStream(const APattern: TPattern; const AStream: TStream);
  end;

  TPlainTextWriter = class(TObject)
  strict private
    var
      fPattern: TPattern;
      fLines: TStringList;
    procedure Generate;
    procedure GenerateCommentLines;
    procedure GeneratePatternLines;
  public
    constructor Create;
    destructor Destroy; override;
    procedure SaveToFile(APattern: TPattern;
      const AFileName: TFileName);
    procedure SaveToStream(const APattern: TPattern; const AStream: TStream);
  end;

  EPlainText = class(Exception);

implementation

{
  Implementation notes for reader
  ===============================

  Specification does not define line end characters: we accept LF, CR and CRLF.

  File is expected to be in ASCII format, per specification.

  Any blank lines are treated as part of pattern except that blank lines after
  last non-blank line are ignored.

  Duplicate !Name: and !Author comments are accepted: subsequent lines overwrite
  earlier ones.

  Empty ! comment lines are ignored.

  In pattern any 'O' (captial 'o') represents an ON cell, per specification,
  but any other character, not just '.', can be used for OFF cells.

  Implementation notes for writer
  ===============================

  !Name: and !Author are output only if pattern has Name / Author fields
  respectively

  Other ! lines are used for each line of pattern description, but blank lines
  are skipped.

  Comments are ended with a ! on its own, but only if there have actually been
  any comments.

  Minimal forms of pattern lines are used: i.e. they are truncated after last
  alive cell.
}

uses
  StrUtils, Math,
  Engine.UCommon, UUtils;

{ TPlainTextReader }

function TPlainTextReader.CalculateGridSize(const StartLineIdx: Integer):
  TSizeEx;
var
  LineIdx: Integer;
begin
  Result := TSizeEx.Create(0, fLines.Count - StartLineIdx);
  for LineIdx := StartLineIdx to Pred(fLines.Count) do
    Result.CX := Max(Result.CX, Length(Trim(fLines[LineIdx])));
end;

constructor TPlainTextReader.Create;
begin
  inherited Create;
  fLines := TStringList.Create;
end;

destructor TPlainTextReader.Destroy;
begin
  fLines.Free;
  inherited;
end;

procedure TPlainTextReader.LoadFromFile(const APattern: TPattern;
  const AFileName: TFileName);
var
  Stm: TFileStream;
begin
  Stm := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    LoadFromStream(APattern, Stm);
  finally
    Stm.Free;
  end;
end;

procedure TPlainTextReader.LoadFromStream(const APattern: TPattern;
  const AStream: TStream);
var
  Bytes: TBytes;
begin
  Assert(Assigned(APattern));
  Assert(Assigned(AStream));
  fPattern := APattern;
  SetLength(Bytes, AStream.Size);
  if AStream.Size > 0 then
    AStream.ReadBuffer(Pointer(Bytes)^, AStream.Size);
  fLines.Text := DOSLineBreaks(
    Trim( // trimming is important to ensure no blank line at end of grid
      TEncoding.ASCII.GetString(Bytes)
    )
  );
  Parse;
end;

procedure TPlainTextReader.Parse;
var
  LineIdx: Integer;
begin
  SetDefaults;
  LineIdx := 0;
  ParseCommentLines(LineIdx);
  if LineIdx = fLines.Count then
    raise EPlainText.Create('No pattern data found');
  ParsePatternLines(LineIdx);
end;

procedure TPlainTextReader.ParseCommentLines(var LineIdx: Integer);
const
  NameId = '!Name:';
  AuthorId = '!Author:';
var
  Line: string;
begin
  while (LineIdx < fLines.Count) do
  begin
    Line := fLines[LineIdx];
    if not StartsText('!', Line) then
      Exit;
    if StartsText(NameId, Line) then
      fPattern.Name := Trim(RightStr(Line, Length(Line) - Length(NameId)))
    else if StartsText(AuthorId, Line) then
      fPattern.Author := Trim(RightStr(Line, Length(Line) - Length(AuthorId)))
    else if Trim(Line) <> '!' then  // skip empty comment lines
      fPattern.Description.Add(
        Trim(RightStr(Line, Length(Line) - Length('!')))
      );
    Inc(LineIdx);
  end;
end;

procedure TPlainTextReader.ParsePatternLines(var LineIdx: Integer);
var
  X, Y: Integer;
  Line: string;
begin
  fPattern.Grid.Size := CalculateGridSize(LineIdx);
  Y := 0;
  while LineIdx < fLines.Count do
  begin
    Line := Trim(fLines[LineIdx]);
    for X := 0 to Pred(Length(Line)) do
      if Line[X + 1] = 'O' then
        fPattern.Grid[X, Y] := csOn;
    Inc(Y);
    Inc(LineIdx);
  end;
end;

procedure TPlainTextReader.SetDefaults;
begin
  fPattern.Rule := nil;           // No rule ever specified
  fPattern.Name := '';            // No name unless !Name specified
  fPattern.Author := '';          // No author unless !Author specified
  fPattern.Description.Clear;     // No description without ! line
  fPattern.Origin := poCentre;    // No offset ever specified
  fPattern.Grid.Initialise;       // Just in case parsing fails
end;

{ TPlainTextWriter }

constructor TPlainTextWriter.Create;
begin
  inherited Create;
  fLines := TStringList.Create;
end;

destructor TPlainTextWriter.Destroy;
begin
  fLines.Free;
  inherited;
end;

procedure TPlainTextWriter.Generate;
begin
  fLines.Clear;
  GenerateCommentLines;
  GeneratePatternLines;
end;

procedure TPlainTextWriter.GenerateCommentLines;
var
  HaveComments: Boolean;

  procedure WriteLine(const Prefix, Line: string);
  begin
    if Trim(Line) = '' then
      Exit;
    fLines.Add(Prefix + Line);
    HaveComments := True;
  end;

var
  Comment: string;
begin
  HaveComments := False;
  WriteLine('!Name: ', fPattern.Name);
  WriteLine('!Author: ', fPattern.Author);
  for Comment in fPattern.Description do
    WriteLine('!', Comment);
  if HaveComments then
    fLines.Add('!');
end;

procedure TPlainTextWriter.GeneratePatternLines;
var
  X, Y: Integer;
  LastX: Integer;
  Line: string;
begin
  for Y := 0 to Pred(fPattern.Grid.Size.CY) do
  begin
    LastX := Pred(fPattern.Grid.Size.CX);
    while (LastX >= 0) and (fPattern.Grid[LastX, Y] = csOff) do
      Dec(LastX);
    SetLength(Line, LastX + 1);
    for X := 0 to LastX do
    begin
      if fPattern.Grid[X, Y] = csOn then
        Line[X + 1] := 'O'
      else
        Line[X + 1] := '.';
    end;
    fLines.Add(Line);
  end;
end;

procedure TPlainTextWriter.SaveToFile(APattern: TPattern;
  const AFileName: TFileName);
var
  Stm: TFileStream;
begin
  Stm := TFileStream.Create(AFileName, fmCreate);
  try
    SaveToStream(APattern, Stm);
  finally
    Stm.Free;
  end;
end;

procedure TPlainTextWriter.SaveToStream(const APattern: TPattern;
  const AStream: TStream);
var
  Bytes: TBytes;
begin
  fPattern := APattern;
  Generate;
  Bytes := TEncoding.ASCII.GetBytes(Trim(fLines.Text));
  if Length(Bytes) > 0 then
    AStream.WriteBuffer(Pointer(Bytes)^, Length(Bytes));
end;

end.

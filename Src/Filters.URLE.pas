unit Filters.URLE;

interface

uses
  SysUtils, Classes, Types, Generics.Collections,
  Engine.UCommon, Engine.UPattern, Engine.UGrid;

type

  TRLEReader = class(TObject)
  strict private
    var
      fPattern: TPattern;
      fLines: TStringList;
    procedure Parse;
    procedure SetDefaults;
    procedure SkipEmptyLines(var Idx: Integer);
    procedure ParseHashLines(var Idx: Integer);
    procedure ParseHashLineComment(const S: string);
    procedure ParseHashLineName(const S: string);
    procedure ParseHashLineAuthor(const S: string);
    procedure ParseHashLineRelOffset(const S: string);
    procedure ParseHashLineRule(const S: string);
    function ParseHashLineCoord(const S: string; out Coord: TPoint): Boolean;
    procedure ParseHeaderLine(var Idx: Integer);
    procedure ExtractHeaderData(const Header: string;
      const Data: TDictionary<string,string>
    );
    function ParseRuleString(const RS: string): Boolean;
    procedure SplitPatternFromComments(var Idx: Integer;
      out Pattern, Comments: string);
    procedure ParsePattern(const EncodedPattern: string);
    procedure ParseComments(const Comments: string);
  public
    constructor Create;
    destructor Destroy; override;
    procedure LoadFromFile(const APattern: TPattern;
      const AFileName: TFileName);
    procedure LoadFromStream(const APattern: TPattern; const AStream: TStream);
  end;

  TRLEWriter = class(TObject)
  strict private
    const
      MaxLineLength = 70;
      EOLTag = '$';
      AliveTag = 'o';
      DeadTag = 'b';
      TerminalTag = '!';
  strict private
    type
      TCompressionEntity = record
        Tag: Char;
        Count: UInt16;
        constructor Create(ATag: Char; ACount: UInt16);
        function ToString: string;
      end;
    type
      TPatternCompressor = class(TObject)
      strict private
        var
          fData: TList<TCompressionEntity>;
          fGrid: TGrid;
        function ValueToChar(const Value: Int8): Char;
        function IsItemAtTopOfList(const Value: Int8): Boolean;
        function CompressValueCount(const Value: Int8): UInt16;
        procedure UpdateCount(const Value: Int8);
      public
        constructor Create(Grid: TGrid; Data: TList<TCompressionEntity>);
        procedure Execute;
      end;
  strict private
    var
      fPattern: TPattern;
      fLines: TStringList;
    procedure Generate;
    procedure GenerateHashLines;
    procedure GenerateCommentLines(const Comment: string);
    procedure GenerateHeaderLine;
    procedure GeneratePatternLines;
    procedure WriteLineRestricted(const Line: string);
  public
    constructor Create;
    destructor Destroy; override;
    procedure SaveToFile(APattern: TPattern;
      const AFileName: TFileName);
    procedure SaveToStream(const APattern: TPattern; const AStream: TStream);
  end;

  ERLEFilter = class(Exception);

implementation

uses
  StrUtils, Math,
  Engine.UCompressedGrid, Engine.URules, UComparers, UStructs, UUtils;

{
  Implementation notes for reader
  ===============================

  RLE file spec does not specify file encoding. It is probably ASCII, but we
  will assume default ANSI encoding.

  File spec prohibits lines longer than 70 character, but we will handle any
  line length.

  File spec requires S/B type rule string in #r hash line and B/S style in
  header line. We support either style in both cases.

  # lines
  -------

  * # lines section may be empty

  * Blank lines in # line section are permitted and ignored

  * # character MUST be the first character on the line

  * Empty #C, #c, #N and #O commands are permitted but ignored.

  * Where multiple occurences of a # command are found, the last one is used
    unless:
    - command is #N or #O when last non-empty command is used
    - command is #C or #c when line is added as a new line in comments unless it
      is empty

  * #P seems to make sense only to the XLife program and it is ignored here.

  * #R is recorded as a hint for when pattern is placed on game grid, but has
    no effect on size of pattern's grid - this is always size of smallest
    bounding box.

  * If #r is specified AND there is a rule clause in header line, #r rule is
    ignored.

  Header line
  -----------

  File spec specifies items come in order x, y, rule (if specified). We accept
  these items in any order and with any amount of white space. All items must be
  on same line.

  Pattern lines
  -------------

  Any white space is ignored, even if between run-count and related tag. File
  spec prohibits space between run-count and tag, but recommends readers allow
  for it.

  Text after closing !
  --------------------

  Any text after closing ! is appended to any comments specified in #C or #c
  lines. Blank lines and any leading line break are ignored.

  Implementation notes for writer
  ===============================

  Output is written in default ANSI encoding.
  70 character line limit is imposed.

  Hash lines
  ----------

  * Pattern name is stored in #N hash line (first line in output).
  * Pattern author in #O hash line (2nd line in output).
  * Pattern description is recorded in zero or more #C hash lines.
  * Pattern offset stored in #P line only if pattern is centre-offset.

  No other hash lines are used

  Header line
  -----------

  Standard header line is used. Rule component will be included only if pattern
  defines a rule.

  Pattern lines
  -------------

  Whole of pattern grid is written with maximum possible compression with no
  EOLs at end.

  Text after closing !
  --------------------

  The closing ! tag is the last in the output. The is no following EOL or text.
}

{ TRLEReader }

constructor TRLEReader.Create;
begin
  inherited Create;
  fLines := TStringList.Create;
end;

destructor TRLEReader.Destroy;
begin
  fLines.Free;
  inherited;
end;

procedure TRLEReader.ExtractHeaderData(const Header: string;
  const Data: TDictionary<string,string>);
var
  Parts: TStringList;
  Part: string;
  Name, Value: string;
begin
  Parts := TStringList.Create;
  try
    ExplodeStr(Header, ',', Parts, True, True);
    for Part in Parts do
    begin
      if Part = '' then
        raise ERLEFilter.CreateFmt('Invalid header line format "%s"', [Header]);
      SplitStr(Part, '=', Name, Value);
      Name := Trim(Name);
      Value := Trim(Value);
      if (Name = '') or (Value = '') then
        raise ERLEFilter.CreateFmt('Invalid header line format "%s"', [Header]);
      Data.Add(Name, Value);
    end;
  finally
    Parts.Free;
  end;
  // Check for correct keys
  if (Data.Count < 2) or (Data.Count > 3) then
    raise ERLEFilter.CreateFmt('Invalid header line format "%s"', [Header]);
  if not Data.ContainsKey('x') then
    raise ERLEFilter.CreateFmt(
      'Width not specified in header line "%s"', [Header]
    );
  if not Data.ContainsKey('y') then
    raise ERLEFilter.CreateFmt(
      'Height not specified in header line "%s"', [Header]
    );
  if (Data.Count = 3) and not Data.ContainsKey('rule') then
    raise ERLEFilter.CreateFmt(
      'Unknown specifier in header line "%s"', [Header]
    );
end;

procedure TRLEReader.LoadFromFile(const APattern: TPattern;
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

procedure TRLEReader.LoadFromStream(const APattern: TPattern;
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
    Trim(
      TEncoding.Default.GetString(Bytes)
    )
  );
  Parse;
end;

procedure TRLEReader.Parse;
var
  Idx: Integer;
  PatternText: string;
  CommentText: string;
begin
  SetDefaults;
  if fLines.Count = 0 then
    raise ERLEFilter.Create('Empty file');
  Idx := 0;
  SkipEmptyLines(Idx);
  ParseHashLines(Idx);  // skips over trailing blank lines
  ParseHeaderLine(Idx);
  SkipEmptyLines(Idx);
  SplitPatternFromComments(Idx, PatternText, CommentText);
  ParseComments(CommentText);
  ParsePattern(RemoveWhiteSpace(PatternText));
end;

procedure TRLEReader.ParseComments(const Comments: string);
var
  Lines: TStringList;
  Line: string;
begin
  Lines := TStringList.Create;
  try
    Lines.Text := Comments;
    for Line in Lines do
      if Trim(Line) <> '' then
        fPattern.Description.Add(Trim(Line));
  finally
    Lines.Free;
  end;
end;

procedure TRLEReader.ParseHashLineAuthor(const S: string);
begin
  if S <> '' then
    fPattern.Author := S;
end;

procedure TRLEReader.ParseHashLineComment(const S: string);
begin
  if S <> '' then
    fPattern.Description.Add(S);
end;

function TRLEReader.ParseHashLineCoord(const S: string; out Coord: TPoint):
  Boolean;
var
  XS, YS: string;
begin
  SplitStr(S, ' ', XS, YS);
  XS := Trim(XS);
  YS := Trim(YS);
  Result:= TryStrToInt(XS, Coord.X) and TryStrToInt(YS, Coord.Y);
end;

procedure TRLEReader.ParseHashLineName(const S: string);
begin
  if S <> '' then
    fPattern.Name := S;
end;

procedure TRLEReader.ParseHashLineRelOffset(const S: string);
var
  Coord: TPoint;
begin
  if S = '' then
    raise ERLEFilter.Create('No coordinates on #R hash line');
  if not ParseHashLineCoord(S, Coord) then
    raise ERLEFilter.Create('Invalid coordinates on #R hash line');
  fPattern.Offset := Coord;
  fPattern.Origin := poCentreOffset;
end;

procedure TRLEReader.ParseHashLineRule(const S: string);
begin
  if not ParseRuleString(S) then
    raise ERLEFilter.CreateFmt('Invalid rule string "%s" on #r hash line', [S]);
end;

procedure TRLEReader.ParseHashLines(var Idx: Integer);
var
  Line: string;
  Code: string;
  Content: string;
begin
  while (Idx < fLines.Count) do
  begin
    Line := fLines[Idx];
    if Trim(Line) = '' then
    begin
      Inc(Idx);
      Continue; // permits blank lines
    end;
    if Line[1] <> '#' then
      // end of # lines
      Exit;
    Inc(Idx);
    SplitStr(Line, ' ', Code, Content);
    if Length(Code) = 1 then
      raise ERLEFilter.CreateFmt(
        'No code letter provided on hash line "%s"', [Line]
      );
    Content := Trim(Content);
    if Content = '' then
      raise Exception.CreateFmt('No content on hash line "%s"', [Line]);
    case Line[2] of
      'C', 'c': ParseHashLineComment(Content);
      'N': ParseHashLineName(Content);
      'O': ParseHashLineAuthor(Content);
      'P': ; // #P is ignored
      'R': ParseHashLineRelOffset(Content);
      'r': ParseHashLineRule(Content);
      else
        raise ERLEFilter.CreateFmt(
          'Invalid hash line type: %s', ['#' + Line[2]]
        );
    end;
  end;
end;

procedure TRLEReader.ParseHeaderLine(var Idx: Integer);
var
  Line: string;
  Data: TDictionary<string,string>;
  Size: TSizeEx;
begin
  if Idx = fLines.Count then
    raise ERLEFilter.Create('Header line missing');
  Line := Trim(fLines[Idx]);
  Assert(Line <> '');
  Inc(Idx);
  Data := TDictionary<string,string>.Create(TTextEqualityComparer.Create);
  try
    ExtractHeaderData(Line, Data);

    if not TryStrToInt(Data['x'], Size.CX) then
      raise ERLEFilter.CreateFmt(
        'Invalid width in header line "%s"', [Line]
      );
    if not TryStrToInt(Data['y'], Size.CY) then
      raise ERLEFilter.CreateFmt(
        'Invalid height in header line "%s"', [Line]
      );
    fPattern.Grid.Size := Size;

    if Data.ContainsKey('rule') then
    begin
      if not ParseRuleString(Data['rule']) then
        raise ERLEFilter.CreateFmt(
          'Invalid rule string in header line "%s"', [Line]
        );
    end;
  finally
    Data.Free;
  end;
end;

procedure TRLEReader.ParsePattern(const EncodedPattern: string);

  procedure SetGrid(X, Y: UInt16; State: TCellState);
  begin
    if X >= fPattern.Grid.Size.CX then
      raise ERLEFilter.Create('X grid coordinate out of bounds');
    if Y >= fPattern.Grid.Size.CY then
      raise ERLEFilter.Create('Y grid coordinate out of bounds');
    fPattern.Grid[X,Y] := State;
  end;

const
  DeadCell = 'b';
  LiveCell = 'o';
  EndOfLine = '$';
var
  CharIdx: Integer;
  I: Integer;
  Digits: string;
  Count: Integer;
  X, Y: UInt16;
begin
  CharIdx := 1;
  Count := 1;
  X := 0;
  Y := 0;
  fPattern.Grid.Initialise;
  while CharIdx <= Length(EncodedPattern) do
  begin
    case EncodedPattern[CharIdx] of
      '0'..'9':
      begin
        Digits := '';
        repeat
          Digits := Digits + EncodedPattern[CharIdx];
          Inc(CharIdx);
        until (CharIdx > Length(EncodedPattern))
          or not CharInSet(EncodedPattern[CharIdx], ['0'..'9']);
        if not TryStrToInt(Digits, Count) then
          raise ERLEFilter.Create('Invalid run count');
      end;
      DeadCell:
      begin
        Inc(X, Count);
        Count := 1;
        Inc(CharIdx);
      end;
      LiveCell:
      begin
        for I := 1 to Count do
        begin
          SetGrid(X, Y, csOn);
          Inc(X);
        end;
        Count := 1;
        Inc(CharIdx);
      end;
      EndOfLine:
      begin
        Inc(Y, Count);
        X := 0;
        Count := 1;
        Inc(CharIdx);
      end;
    end;
  end;
end;

function TRLEReader.ParseRuleString(const RS: string): Boolean;
begin
  try
    fPattern.Rule := TRule.Create(RS);
    Result := True;
  except
    on E: EConvertError do
      Result := False;
    on E: Exception do
      raise;
  end;
end;

procedure TRLEReader.SetDefaults;
begin
  fPattern.Rule := TRule.Create([3], [2,3]);  // Conway life is default
  fPattern.Name := '';            // No name unless #N specified
  fPattern.Author := '';          // No author unless #O specified
  fPattern.Description.Clear;     // No description without #C/#c or after !
  fPattern.Origin := poCentre;    // No offset unless #R specified in file
  fPattern.Grid.Initialise;       // In case parsing fails
end;

procedure TRLEReader.SkipEmptyLines(var Idx: Integer);
begin
  while (Idx < fLines.Count) and (Trim(fLines[Idx]) = '') do
    Inc(Idx);
end;

procedure TRLEReader.SplitPatternFromComments(var Idx: Integer; out Pattern,
  Comments: string);
var
  SB: TStringBuilder;
begin
  if Idx = fLines.Count then
    raise ERLEFilter.Create('Pattern lines missing');
  SB := TStringBuilder.Create;
  try
    while Idx < fLines.Count do
    begin
      SB.AppendLine(fLines[Idx]);
      Inc(Idx);
    end;
    SplitStr(SB.ToString, '!', Pattern, Comments);
  finally
    SB.Free;
  end;
end;

{ TRLEWriter }

constructor TRLEWriter.Create;
begin
  inherited Create;
  fLines := TStringList.Create;
end;

destructor TRLEWriter.Destroy;
begin
  fLines.Free;
  inherited;
end;

procedure TRLEWriter.Generate;
begin
  fLines.Clear;
  GenerateHashLines;
  GenerateHeaderLine;
  GeneratePatternLines;
end;

procedure TRLEWriter.GenerateCommentLines(const Comment: string);
var
  Comments: TStringList;
  Line: string;
begin
  Comments := TStringList.Create;
  try
    Comments.Text := TextWrap(Trim(Comment), MaxLineLength - Length('#C '), 0);
    for Line in Comments do
      WriteLineRestricted('#C ' + Line);
  finally
    Comments.Free;
  end;
end;

procedure TRLEWriter.GenerateHashLines;
var
  Comment: string;
begin
  if Trim(fPattern.Name) <> '' then
    WriteLineRestricted('#N ' + Trim(fPattern.Name));
  if Trim(fPattern.Author) <> '' then
    WriteLineRestricted('#O ' + Trim(fPattern.Author));
  if Trim(fPattern.Description.Text) <> '' then
  begin
    for Comment in fPattern.Description do
      GenerateCommentLines(Comment);
  end;
  if fPattern.Origin = poCentreOffset then
    fLines.Add(Format('#R %d %d', [fPattern.Offset.X, fPattern.Offset.Y]));
end;

procedure TRLEWriter.GenerateHeaderLine;
var
  Line: string;
begin
  Line := Format(
    'x = %d, y = %d', [fPattern.Grid.Size.CX, fPattern.Grid.Size.CY]
  );
  if not fPattern.Rule.IsNull then
    Line := Line + ', rule = ' + fPattern.Rule.ToString;
  fLines.Add(Line);
end;

procedure TRLEWriter.GeneratePatternLines;
var
  Entities: TList<TCompressionEntity>;
  Entity: TCompressionEntity;
  Compressor: TPatternCompressor;
  Line: string;

  procedure AppendToOutput(const Text: string);
  begin
    if Length(Text) + Length(Line) > MaxLineLength then
    begin
      fLines.Add(Line);
      Line := Text;
    end
    else
      Line := Line + Text;
  end;

begin
  Entities := TList<TCompressionEntity>.Create;
  try
    Compressor := TPatternCompressor.Create(fPattern.Grid, Entities);
    try
      Compressor.Execute;
    finally
      Compressor.Free;
    end;
    Line := '';
    for Entity in Entities do
      AppendToOutput(Entity.ToString);
    AppendToOutput(TerminalTag);
    fLines.Add(Line);
  finally
    Entities.Free;
  end;
end;

procedure TRLEWriter.SaveToFile(APattern: TPattern; const AFileName: TFileName);
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

procedure TRLEWriter.SaveToStream(const APattern: TPattern;
  const AStream: TStream);
var
  Bytes: TBytes;
begin
  fPattern := APattern;
  Generate;
  Bytes := TEncoding.Default.GetBytes(Trim(fLines.Text));
  if Length(Bytes) > 0 then
    AStream.WriteBuffer(Pointer(Bytes)^, Length(Bytes));
end;

procedure TRLEWriter.WriteLineRestricted(const Line: string);
const
  Ellipsis = '...';
begin
  if Length(Line) <= MaxLineLength then
    fLines.Add(Line)
  else
    fLines.Add(LeftStr(Line, MaxLineLength - Length(Ellipsis)) + Ellipsis);
end;

{ TRLEWriter.TPatternCompressor }

function TRLEWriter.TPatternCompressor.CompressValueCount(
  const Value: Int8): UInt16;
begin
  if Sign(Value) = NegativeValue then
    Result := -Value
  else if Sign(Value) = PositiveValue then
    Result := Value
  else // ZeroValue
    Result := 1;
end;

constructor TRLEWriter.TPatternCompressor.Create(Grid: TGrid;
  Data: TList<TCompressionEntity>);
begin
  inherited Create;
  fGrid := Grid;
  fData := Data;
end;

procedure TRLEWriter.TPatternCompressor.Execute;
var
  CompGrid: TCompressedGrid;
  CGItem: Int8;
begin
  fData.Clear;
  CompGrid := TCompressedGrid.Create;
  try
    CompGrid.Compress(fGrid);
    for CGItem in CompGrid.State do
    begin
      if IsItemAtTopOfList(CGItem) then
        UpdateCount(CGItem)
      else
      begin
        fData.Add(
          TCompressionEntity.Create(
            ValueToChar(CGItem),
            CompressValueCount(CGItem))
        );
      end;
    end;
    if (fData.Count > 0) and (fData.Last.Tag = EOLTag) then
      fData.Delete(Pred(fData.Count));
  finally
    CompGrid.Free;
  end;
end;

function TRLEWriter.TPatternCompressor.IsItemAtTopOfList(
  const Value: Int8): Boolean;
begin
  if fData.Count = 0 then
    Exit(False);
  Result := ValueToChar(Value) = fData.Last.Tag;
end;

procedure TRLEWriter.TPatternCompressor.UpdateCount(const Value: Int8);
begin
  Assert(fData.Count > 0);
  fData[Pred(fData.Count)] := TCompressionEntity.Create(
    fData.Last.Tag, fData.Last.Count + CompressValueCount(Value)
  );
end;

function TRLEWriter.TPatternCompressor.ValueToChar(const Value: Int8): Char;
begin
  if Sign(Value) = NegativeValue then
    Result := DeadTag
  else if Sign(Value) = PositiveValue then
    Result := AliveTag
  else // ZeroValue
    Result := EOLTag;
end;

{ TRLEWriter.TCompressionEntity }

constructor TRLEWriter.TCompressionEntity.Create(ATag: Char; ACount: UInt16);
begin
  Assert(ACount > 0);
  Tag := ATag;
  Count := ACount;
end;

function TRLEWriter.TCompressionEntity.ToString: string;
begin
  if Count = 1 then
    Result := Tag
  else
    Result := IntToStr(Count) + Tag;
end;

end.


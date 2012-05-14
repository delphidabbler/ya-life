unit Filters.ULife105;

interface

uses
  SysUtils, Classes, Types, Generics.Collections,
  Engine.UGrid, Engine.UPattern, UStructs;

type
  TLife105Reader = class(TObject)
  strict private
    type
      TCellBlock = class(TObject)
      strict private
        var
          fBounds: TPatternBounds;
          fRows: TStringList;
      public
        constructor Create(const Offset: TPoint);
        destructor Destroy; override;
        procedure AddRow(const Row: string);
        procedure UpdateGrid(const Grid: TGrid; const TopLeft: TPoint);
        property Bounds: TPatternBounds read fBounds;
      end;
  strict private
    var
      fPattern: TPattern;
      fLines: TStringList;
      fCellBlocks: TObjectList<TCellBlock>;
    procedure Parse;
    procedure ParseInfoLine(const Line: string);
    procedure ParseCellBlocks(var LineIdx: Integer);
    procedure ParseCellBlock(const CellBlock: TCellBlock; var LineIdx: Integer);
    function ParsePatternLine(const Line: string): TPoint;
    function CalculateBounds: TPatternBounds;
    procedure UpdatePattern;
    procedure SetDefaults;
    procedure SetRule(const RuleStr: string);
  public
    constructor Create;
    destructor Destroy; override;
    procedure LoadFromFile(const APattern: TPattern;
      const AFileName: TFileName);
    procedure LoadFromStream(const APattern: TPattern; const AStream: TStream);
  end;

  TLife105Writer = class(TObject)
  strict private
    const
      MaxLineLength = 80;
      MaxCommentLines = 22;
  strict private
    var
      fPattern: TPattern;
      fLines: TStringList;
      fCommentCount: Integer;
    procedure Generate;
    procedure GenerateCommentLines(const Comment: string);
    procedure GenerateRuleLine;
    procedure GeneratePatternLines;
    procedure WriteCommentLine(const Line: string);
    procedure WriteLineRestricted(const Line: string);
  public
    constructor Create;
    destructor Destroy; override;
    procedure SaveToFile(APattern: TPattern;
      const AFileName: TFileName);
    procedure SaveToStream(const APattern: TPattern; const AStream: TStream);
  end;

  ELife105Filter = class(Exception);

implementation

uses
  StrUtils, Math,
  Engine.UCommon, Engine.URules, UUtils;

{ TLife105Reader }

function TLife105Reader.CalculateBounds: TPatternBounds;
var
  CellBlock: TCellBlock;
  BoundsRect: TRect;
begin
  BoundsRect := Rect(MaxInt, MaxInt, -MaxInt, -MaxInt);
  for CellBlock in fCellBlocks do
  begin
    BoundsRect.Left := Min(BoundsRect.Left, CellBlock.Bounds.TopLeft.X);
    BoundsRect.Top := Min(BoundsRect.Top, CellBlock.Bounds.TopLeft.Y);
    BoundsRect.Right := Max(
      BoundsRect.Right,
      CellBlock.Bounds.TopLeft.X + CellBlock.Bounds.Size.CX - 1
    );
    BoundsRect.Bottom := Max(
      BoundsRect.Bottom,
      CellBlock.Bounds.TopLeft.Y + CellBlock.Bounds.Size.CY - 1
    );
  end;
  Result := TPatternBounds.Create(BoundsRect);
end;

constructor TLife105Reader.Create;
begin
  inherited Create;
  fLines := TStringList.Create;
  fCellBlocks := TObjectList<TCellBlock>.Create(True);
end;

destructor TLife105Reader.Destroy;
begin
  fCellBlocks.Free;   // frees owned TCellBlock objects
  fLines.Free;
  inherited;
end;

procedure TLife105Reader.LoadFromFile(const APattern: TPattern;
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

procedure TLife105Reader.LoadFromStream(const APattern: TPattern;
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
  fLines.Text := DOSLineBreaks( // should be DOS EOLs, but allow any
    Trim( // trimming is important to ensure no blank line at end of grid
      TEncoding.ASCII.GetString(Bytes)
    )
  );
  Parse;
end;

procedure TLife105Reader.Parse;
var
  LineIdx: Integer;
begin
  SetDefaults;
  fCellBlocks.Clear;
  if (fLines.Count = 0) or not SameText(Trim(fLines[0]), '#Life 1.05') then
    raise ELife105Filter.Create('Not a Life 1.05 file');
  LineIdx := 1;   // line after header
  while (LineIdx < fLines.Count) and not StartsStr('#P', fLines[LineIdx]) do
  begin
    ParseInfoLine(fLines[LineIdx]);
    Inc(LineIdx);
  end;
  if LineIdx = fLines.Count then
    raise ELife105Filter.Create('No pattern data found');
  ParseCellBlocks(LineIdx);
  UpdatePattern;
end;

procedure TLife105Reader.ParseCellBlock(const CellBlock: TCellBlock;
  var LineIdx: Integer);
var
  Line: string;
begin
  while (LineIdx < fLines.Count) and not (StartsStr('#P', fLines[LineIdx])) do
  begin
    Line := Trim(fLines[LineIdx]);
    if Line <> '' then
      CellBlock.AddRow(Line);
    Inc(LineIdx);
  end;
end;

procedure TLife105Reader.ParseCellBlocks(var LineIdx: Integer);
var
  Offset: TPoint;
  CellBlock: TCellBlock;
begin
  while (LineIdx < fLines.Count) and (StartsStr('#P', fLines[LineIdx])) do
  begin
    Offset := ParsePatternLine(fLines[LineIdx]);
    CellBlock := TCellBlock.Create(Offset);
    Inc(LineIdx);
    ParseCellBlock(CellBlock, LineIdx);
    fCellBlocks.Add(CellBlock);
  end;
end;

procedure TLife105Reader.ParseInfoLine(const Line: string);
const
  Life105DescTag = '#D';
  XLife20DescTag = '#C';
  RuleSpecTag = '#R';
  ConwayTag = '#N';
  ConwayRule = '23/3';
begin
  if StartsStr(Life105DescTag, Line) then
    fPattern.Description.Add(
      Trim(RightStr(Line, Length(Line) - Length(Life105DescTag)))
    )
  else if StartsStr(XLife20DescTag, Line) then
    fPattern.Description.Add(
      Trim(RightStr(Line, Length(Line) - Length(XLife20DescTag)))
    )
  else if StartsStr(RuleSpecTag, Line) then
    SetRule(Trim(RightStr(Line, Length(Line) - Length(RuleSpecTag))))
  else if StartsStr(ConwayTag, Line) then
    SetRule(ConwayRule)
  else if Trim(Line) = '' then
    // Do nothing: skipping blank line
  else
    raise ELife105Filter.CreateFmt(
      'Invalid information line: "%s"', [Trim(Line)]
    );
end;

function TLife105Reader.ParsePatternLine(const Line: string): TPoint;
var
  CoordStr: string;
  XStr, YStr: string;
begin
  CoordStr := Trim(RightStr(Line, Length(Line) - Length('#P')));
  SplitStr(CoordStr, ' ', XStr, YStr);
  if not TryStrToInt(XStr, Result.X) or not TryStrToInt(YStr, Result.Y) then
    raise ELife105Filter.CreateFmt(
      'Invalid offset coordinates in line "%s"', [Line]
    );
end;

procedure TLife105Reader.SetDefaults;
begin
  fPattern.Rule := nil;               // Default if no #R or #N lines
  fPattern.Name := '';                // No name ever specified
  fPattern.Author := '';              // No author ever specified
  fPattern.Description.Clear;         // Default if no #D / #C lines
  fPattern.Origin := poCentre;        // Grid always fits data (file written
                                      // relative to grid centre)
  fPattern.Grid.Initialise;           // Just in case parsing fails
end;

procedure TLife105Reader.SetRule(const RuleStr: string);
var
  Rule: TRule;
begin
  try
    Rule := TRule.Create(RuleStr);
    try
      fPattern.Rule := Rule;
    finally
      Rule.Free;
    end;
  except
    on E: EConvertError do
      raise ELife105Filter.CreateFmt('Invalid rule string "%s"', [RuleStr]);
    on E: Exception do
      raise;
  end;
end;

procedure TLife105Reader.UpdatePattern;
var
  Bounds: TPatternBounds;
  CellBlock: TCellBlock;
  Offset: TPoint;         // offset of block in grid coordinates
begin
  Bounds := CalculateBounds;
  fPattern.Grid.Size := Bounds.Size;
  for CellBlock in fCellBlocks do
  begin
    Offset := Point(
      CellBlock.Bounds.TopLeft.X - Bounds.TopLeft.X,
      CellBlock.Bounds.TopLeft.Y - Bounds.TopLeft.Y
    );
    CellBlock.UpdateGrid(fPattern.Grid, Offset);
  end;
end;

{ TLife105Reader.TCellBlock }

procedure TLife105Reader.TCellBlock.AddRow(const Row: string);
begin
  Inc(fBounds.Size.CY);
  if fBounds.Size.CX < Length(Row) then
    fBounds.Size.CX := Length(Row);
  fRows.Add(Row);
end;

constructor TLife105Reader.TCellBlock.Create(const Offset: TPoint);
begin
  inherited Create;
  fBounds := TPatternBounds.Create(Offset, TSizeEx.Create(0, 0));
  fRows := TStringList.Create;
end;

destructor TLife105Reader.TCellBlock.Destroy;
begin
  fRows.Free;
  inherited;
end;

procedure TLife105Reader.TCellBlock.UpdateGrid(const Grid: TGrid;
  const TopLeft: TPoint);
var
  X, Y: Integer;
  Row: string;
begin
  for Y := 0 to Pred(fRows.Count) do
  begin
    Row := fRows[Y];
    for X := 0 to Pred(Length(Row)) do
    begin
      if Row[X + 1] = '*' then
      begin
        // not using TGrid.UniverseToGridCoord here because same assumptions
        // about location of grid origin may not have been applied by program
        // that wrote the data
        Grid[X + TopLeft.X, Y + TopLeft.Y] := csOn;
      end;
    end;
  end;
end;

{ TLife105Writer }

constructor TLife105Writer.Create;
begin
  inherited Create;
  fLines := TStringList.Create;
end;

destructor TLife105Writer.Destroy;
begin
  fLines.Free;
  inherited;
end;

procedure TLife105Writer.Generate;
var
  Comment: string;
begin
  fCommentCount := 0;
  fLines.Clear;
  fLines.Add('#Life 1.05');
  if Trim(fPattern.Name) <> '' then
    WriteCommentLine('Name: ' + Trim(fPattern.Name));
  if Trim(fPattern.Author) <> '' then
    WriteCommentLine('Author: ' + Trim(fPattern.Author));
  for Comment in fPattern.Description do
    GenerateCommentLines(Comment);
  GenerateRuleLine;
  GeneratePatternLines;
end;

procedure TLife105Writer.GenerateCommentLines(const Comment: string);
var
  Comments: TStringList;
  Line: string;
begin
  Comments := TStringList.Create;
  try
    Comments.Text := TextWrap(Trim(Comment), MaxLineLength - Length('#D '), 0);
    for Line in Comments do
      WriteCommentLine(Line);
  finally
    Comments.Free;
  end;
end;

procedure TLife105Writer.GeneratePatternLines;
var
  XOffsets: TList<Integer>;
  UniversalOffset: TPoint;
  X, Y: Integer;
  XOffset: Integer;
  LastX: Integer;
  Row: string;
begin
  // NOTE: We always write the whole grid. If minimum bounding box is required,
  // caller must create a pattern containing this first and pass that to this
  // method.

  // Split grid into 80 column wide sections & any number of rows
  // use grid coords
  XOffsets := TList<Integer>.Create;
  try
    X := 0;
    while X < fPattern.Grid.Size.CX do
    begin
      XOffsets.Add(X);
      Inc(X, MaxLineLength);
    end;
    // Write cells for each section, with offsets relative to grid origin
    for XOffset in XOffsets do
    begin
      UniversalOffset := fPattern.Grid.GridToUniverseCoord(Point(XOffset, 0));
      fLines.Add(Format('#P %d %d', [UniversalOffset.X, UniversalOffset.Y]));
      for Y := 0 to Pred(fPattern.Grid.Size.CY) do
      begin
        LastX := Min(XOffset + MaxLineLength, fPattern.Grid.Size.CX) - 1;
        while (LastX >= XOffset) and (fPattern.Grid[LastX, Y] = csOff) do
          Dec(LastX);
        SetLength(Row, LastX - XOffset + 1);
        if Length(Row) >= 1 then
        begin
          for X := 0 to LastX - XOffset do
          begin
            if fPattern.Grid[X + XOffset, Y] = csOn then
              Row[X + 1] := '*'
            else
              Row[X + 1] := '.';
          end;
        end
        else
          Row := '.';
        fLines.Add(Row);
      end;
    end;
    fLines.Add(''); // blank line after chunk
    fLines.Add(''); // blank line after chunk
    fLines.Add(''); // blank line after chunk
  finally
    XOffsets.Free;
  end;
end;

procedure TLife105Writer.GenerateRuleLine;
begin
  // TODO: consider adding HasRule method to TPattern
  if not Assigned(fPattern.Rule) then
    Exit;
  // TODO: consider adding IsConwayLife method to TRule
  if (fPattern.Rule.BirthCriteria = [3])
    and (fPattern.Rule.SurvivalCriteria = [2,3]) then
    fLines.Add('#N')
  else
    fLines.Add('#R ' + fPattern.Rule.ToString);
end;

procedure TLife105Writer.SaveToFile(APattern: TPattern;
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

procedure TLife105Writer.SaveToStream(const APattern: TPattern;
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

procedure TLife105Writer.WriteCommentLine(const Line: string);
begin
  if Trim(Line) = '' then
    Exit;
  if fCommentCount = MaxCommentLines then
    Exit;
  WriteLineRestricted('#D ' + Trim(Line));
  Inc(fCommentCount);
end;

procedure TLife105Writer.WriteLineRestricted(const Line: string);
// TODO: extract this and similar from TRLEWriter and generalise in UUtils
const
  Ellipsis = '...';
begin
  if Length(Line) <= MaxLineLength then
    fLines.Add(Line)
  else
    fLines.Add(LeftStr(Line, MaxLineLength - Length(Ellipsis)) + Ellipsis);
end;

end.


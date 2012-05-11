unit Filters.ULife106;

interface

uses
  SysUtils, Classes, Types, Generics.Collections,
  Engine.UGrid, Engine.UPattern, UStructs;

type
  TLife106Reader = class(TObject)
  strict private
    var
      fPattern: TPattern;
      fLines: TStringList;
    procedure Parse;
    procedure SetDefaults;
    procedure ParseCoordinates(const Coords: TList<TPoint>);
    function CalculateBounds(const Coords: TList<TPoint>): TPatternBounds;
    procedure UpdatePattern(const Bounds: TPatternBounds;
      const Coords: TList<TPoint>);
  public
    constructor Create;
    destructor Destroy; override;
    procedure LoadFromFile(const APattern: TPattern;
      const AFileName: TFileName);
    procedure LoadFromStream(const APattern: TPattern; const AStream: TStream);
  end;

  TLife106Writer = class(TObject)
  strict private
    var
      fPattern: TPattern;
      fLines: TStringList;
    procedure Generate;
  public
    constructor Create;
    destructor Destroy; override;
    procedure SaveToFile(APattern: TPattern;
      const AFileName: TFileName);
    procedure SaveToStream(const APattern: TPattern; const AStream: TStream);
  end;

  ELife106 = class(Exception);

implementation

uses
  Math,
  Engine.UCommon, UUtils;

{ TLife106Reader }

function TLife106Reader.CalculateBounds(const Coords: TList<TPoint>):
  TPatternBounds;
var
  BoundsRect: TRect;
  Coord: TPoint;
begin
  Assert(Coords.Count > 0);
  BoundsRect := Rect(MaxInt, MaxInt, -MaxInt, -MaxInt);
  for Coord in Coords do
  begin
    BoundsRect.Left := Min(BoundsRect.Left, Coord.X);
    BoundsRect.Top := Min(BoundsRect.Top, Coord.Y);
    BoundsRect.Right := Max(BoundsRect.Right, Coord.X);
    BoundsRect.Bottom := Max(BoundsRect.Bottom, Coord.Y);
  end;
  Result := TPatternBounds.Create(BoundsRect);
end;

constructor TLife106Reader.Create;
begin
  inherited Create;
  fLines := TStringList.Create;
end;

destructor TLife106Reader.Destroy;
begin
  fLines.Free;
  inherited;
end;

procedure TLife106Reader.LoadFromFile(const APattern: TPattern;
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

procedure TLife106Reader.LoadFromStream(const APattern: TPattern;
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

procedure TLife106Reader.Parse;
var
  Coords: TList<TPoint>;
  Bounds: TPatternBounds;
begin
  SetDefaults;
  if (fLines.Count = 0) or not SameText(Trim(fLines[0]), '#Life 1.06') then
    raise ELife106.Create('Not a Life 1.06 file');
  Coords := TList<TPoint>.Create;
  try
    ParseCoordinates(Coords);
    Bounds := CalculateBounds(Coords);
    UpdatePattern(Bounds, Coords);
  finally
    Coords.Free;
  end;
end;

procedure TLife106Reader.ParseCoordinates(const Coords: TList<TPoint>);
var
  LineIdx: Integer;
  XS, YS: string;
  Coord: TPoint;
begin
  if fLines.Count <= 1 then
    raise ELife106.Create('No coordinates found');
  // Coords begin immediately after header line
  for LineIdx := 1 to Pred(fLines.Count) do
  begin
    SplitStr(Trim(fLines[LineIdx]), ' ', XS, YS);
    if not TryStrToInt(XS, Coord.X) or not TryStrToInt(YS, Coord.Y) then
      raise ELife106.CreateFmt('Invalid coordinates "%s"', [fLines[LineIdx]]);
    Coords.Add(Coord);
  end;
end;

procedure TLife106Reader.SetDefaults;
begin
  fPattern.Rule := nil;               // No rule ever specified
  fPattern.Name := '';                // No name ever specified
  fPattern.Author := '';              // No author ever specified
  fPattern.Description.Clear;         // No description ever specified
  fPattern.Origin := poCentre;        // Grid always fits data (file written
                                      // relative to grid centre)
  fPattern.Grid.Initialise;           // Just in case parsing fails
end;

procedure TLife106Reader.UpdatePattern(const Bounds: TPatternBounds;
  const Coords: TList<TPoint>);
var
  FileCoord: TPoint;
  GridCoord: TPoint;
begin
  fPattern.Offset := Bounds.TopLeft;
  fPattern.Grid.Size := Bounds.Size;
  for FileCoord in Coords do
  begin
    // not using TGrid.UniverseToGridCoord here because same assumptions about
    // location of grid origin may not have been applied by program that wrote
    // the data
    GridCoord := Point(
      FileCoord.X - Bounds.TopLeft.X,
      FileCoord.Y - Bounds.TopLeft.Y
    );
    fPattern.Grid[GridCoord.X, GridCoord.Y] := csOn;
  end;
end;

{ TLife106Writer }

constructor TLife106Writer.Create;
begin
  inherited Create;
  fLines := TStringList.Create;
end;

destructor TLife106Writer.Destroy;
begin
  fLines.Free;
  inherited;
end;

procedure TLife106Writer.Generate;
var
  X, Y: Integer;
  Coord: TPoint;
begin
  fLines.Clear;
  fLines.Add('#Life 1.06');
  // write with Y varying slowest
  for Y := 0 to Pred(fPattern.Grid.Size.CY) do
    for X := 0 to Pred(fPattern.Grid.Size.CX) do
    begin
      // coordinates are relative to grid origin
      if fPattern.Grid[X, Y] = csOn then
      begin
        Coord := fPattern.Grid.GridToUniverseCoord(Point(X, Y));
        fLines.Add(Format('%d %d', [Coord.X, Coord.Y]));
      end;
    end;
end;

procedure TLife106Writer.SaveToFile(APattern: TPattern;
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

procedure TLife106Writer.SaveToStream(const APattern: TPattern;
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

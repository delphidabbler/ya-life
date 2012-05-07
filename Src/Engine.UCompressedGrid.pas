unit Engine.UCompressedGrid;

interface

uses
  // Delphi
  Types, Classes, Generics.Collections,
  // Project
  Engine.UCommon, Engine.UGrid, UStructs;

type
  TCompressedGrid = class(TObject)
  strict private
    type
      TPatternCompressor = class(TObject)
      strict private
        const
          MaxRunCount = 127;
      strict private
        var
          fGrid: TGrid;
          fRegion: TRect;
          fRunCount: Int8;
          fCellState: TCellState;
          fData: TList<Int8>;
        procedure DoEndOfLine;
        procedure IncRunCount;
        procedure WriteRunCount;
      public
        constructor Create(Grid: TGrid; Region: TRect; Data: TList<Int8>);
        procedure Execute;
      end;
      TPatternInflator = class(TObject)
      strict private
        var
          fGrid: TGrid;
          fRegion: TRect;
          fData: TList<Int8>;
        procedure DecodeSequence(Encoding: Int8; var Pt: TPoint);
        procedure EndRow(var Pt: TPoint);
      public
        constructor Create(Grid: TGrid; const Region: TRect; Data: TList<Int8>);
        procedure Execute;
      end;
  strict private
    var
      fSize: TSizeEx;
      fPatternBounds: TPatternBounds;
      fState: TList<Int8>;
    function GetState: TArray<Int8>;
    function PatternRegion: TRect;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Compress(Grid: TGrid);
    procedure UnCompress(Grid: TGrid);
    procedure SaveToStream(const Stm: TStream);
    procedure LoadFromStream(const Stm: TStream);
    function IsEqual(const Another: TCompressedGrid): Boolean;
    property State: TArray<Int8> read GetState;
    property PatternBounds: TPatternBounds read fPatternBounds;
    property Size: TSizeEx read fSize;
  end;

implementation

{ TCompressedGrid }

procedure TCompressedGrid.Compress(Grid: TGrid);
var
  Compressor: TPatternCompressor;
begin
  fState.Clear;
  fSize := Grid.Size;
  // Get PatternBounds of pattern on grid
  fPatternBounds := Grid.PatternBounds;
  if fPatternBounds.IsEmpty then
    Exit;
  Compressor := TPatternCompressor.Create(Grid, PatternRegion, fState);
  try
    Compressor.Execute;
  finally
    Compressor.Free;
  end;
end;

constructor TCompressedGrid.Create;
begin
  inherited Create;
  fState := TList<Int8>.Create;
  fPatternBounds := TPatternBounds.CreateEmpty;
  fSize := TSizeEx.Create(0, 0);
end;

destructor TCompressedGrid.Destroy;
begin
  fState.Free;
  inherited;
end;

function TCompressedGrid.GetState: TArray<Int8>;
var
  Idx: Integer;
begin
  SetLength(Result, fState.Count);
  for Idx := 0 to Pred(fState.Count) do
    Result[Idx] := fState[Idx];
end;

function TCompressedGrid.IsEqual(const Another: TCompressedGrid): Boolean;
var
  Idx: Integer;
begin
  if fPatternBounds <> Another.fPatternBounds then
    Exit(False);
  if fState.Count <> Another.fState.Count then
    Exit(False);
  for Idx := 0 to Pred(fState.Count) do
    if fState[Idx] <> Another.fState[Idx] then
      Exit(False);
  Result := True;
end;

procedure TCompressedGrid.LoadFromStream(const Stm: TStream);
begin

end;

function TCompressedGrid.PatternRegion: TRect;
begin
  Result := fPatternBounds.BoundsRect;
end;

procedure TCompressedGrid.SaveToStream(const Stm: TStream);
begin

end;

procedure TCompressedGrid.UnCompress(Grid: TGrid);
var
  Inflator: TPatternInflator;
begin
  Grid.Size := fSize;
  if fPatternBounds.IsEmpty then
    Exit;
  Inflator := TPatternInflator.Create(Grid, PatternRegion, fState);
  try
    Inflator.Execute;
  finally
    Inflator.Free;
  end;
end;

{ TCompressedGrid.TPatternCompressor }

constructor TCompressedGrid.TPatternCompressor.Create(Grid: TGrid;
  Region: TRect; Data: TList<Int8>);
begin
  inherited Create;
  fGrid := Grid;
  fRegion := Region;
  fData := Data;
end;

procedure TCompressedGrid.TPatternCompressor.DoEndOfLine;
begin
  // trim any trailing csOff states from list: eol replaces them
  while (fData.Count > 0) and (fData.Last < 0) do
    fData.Delete(Pred(fData.Count));
  fData.Add(0);
end;

procedure TCompressedGrid.TPatternCompressor.Execute;
var
  X, Y: UInt16;
begin
  fData.Clear;
  for Y := fRegion.Top to fRegion.Bottom do
  begin
    fCellState := fGrid[fRegion.Left, Y];
    fRunCount := 0;
    for X := fRegion.Left to fRegion.Right do
    begin
      if fGrid[X, Y] <> fCellState then
      begin
        WriteRunCount;
        fRunCount := 0;
        fCellState := fGrid[X, Y];
      end;
      IncRunCount;
    end;
    WriteRunCount;
    DoEndOfLine;
  end;
end;

procedure TCompressedGrid.TPatternCompressor.IncRunCount;
begin
  if fRunCount = MaxRunCount then
    WriteRunCount;
  Inc(fRunCount);
end;

procedure TCompressedGrid.TPatternCompressor.WriteRunCount;
begin
  if fRunCount = 0 then
    Exit;
  case fCellState of
    csOn: fData.Add(fRunCount);
    csOff: fData.Add(-fRunCount);
  end;
  fRunCount := 0;
end;

{ TCompressedGrid.TPatternInflator }

constructor TCompressedGrid.TPatternInflator.Create(Grid: TGrid;
  const Region: TRect; Data: TList<Int8>);
begin
  inherited Create;
  fGrid := Grid;
  fData := Data;
  fRegion := Region;
end;

procedure TCompressedGrid.TPatternInflator.DecodeSequence(Encoding: Int8;
  var Pt: TPoint);
var
  CellState: TCellState;
  I: Int8;
begin
  if Encoding < 0 then
    CellState := csOff
  else
    CellState := csOn;
  for I := 1 to Abs(Encoding) do
  begin
    fGrid[Pt.X, Pt.Y] := CellState;
    Inc(Pt.X);
  end;
end;

procedure TCompressedGrid.TPatternInflator.EndRow(var Pt: TPoint);
begin
  while Pt.X <= fRegion.Right do
  begin
    fGrid[Pt.X, Pt.Y] := csOff;
    Inc(Pt.X);
  end;
  Inc(Pt.Y);
  Pt.X := fRegion.Left;
end;

procedure TCompressedGrid.TPatternInflator.Execute;
var
  CurrentCell: TPoint;
  Encoding: Int8;
begin
  CurrentCell := fRegion.TopLeft;
  for Encoding in fData do
  begin
    if Encoding <> 0 then
      DecodeSequence(Encoding, CurrentCell)
    else
      EndRow(CurrentCell);
  end;
end;

end.

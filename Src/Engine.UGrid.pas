unit Engine.UGrid;

interface

uses
  Types,
  Engine.UCommon, UStructs;

type
  TPatternBounds = record
  public
    TopLeft: TPoint;
    Size: TSizeEx;
    constructor Create(const ATopLeft: TPoint; const ASize: TSizeEx); overload;
    constructor Create(const ARect: TRect); overload;
    class function CreateEmpty: TPatternBounds; static;
    class operator Equal(const PB1, PB2: TPatternBounds): Boolean;
    class operator NotEqual(const PB1, PB2: TPatternBounds): Boolean;
    function BoundsRect: TRect;
    function IsEmpty: Boolean;
  end;

type
  TGrid = class(TObject)
  strict private
    var
      fSize: TSizeEx;
      fState: array of array of TCellState;
      fPopulation: UInt32;
      fRowCounts: array of UInt16;
      fColCounts: array of UInt16;
    procedure ChangeSize(const NewSize: TSizeEx);
    procedure SetSize(const NewSize: TSizeEx);
    function GetState(X, Y: UInt16): TCellState;
    procedure SetState(X, Y: UInt16; NewState: TCellState);
    function GetStateByPt(const Pt: TPoint): TCellState;
    procedure SetStateByPt(const Pt: TPoint; NewState: TCellState);
  public
    constructor Create;
    function Origin: TPoint;
    function GridToUniverseCoord(const GridCoord: TPoint): TPoint;
    function UniverseToGridCoord(const UniverseCoord: TPoint): TPoint;
    procedure Initialise;
    function IsEqual(const AGrid: TGrid): Boolean;
    procedure Assign(const AGrid: TGrid);
    function Population: UInt32;
    function PatternBounds: TPatternBounds;
    property State[X, Y: UInt16]: TCellState read GetState write SetState;
      default;
    property StateByPt[const Pt: TPoint]: TCellState
      read GetStateByPt write SetStateByPt;
    property Size: TSizeEx read fSize write SetSize;
  end;

implementation

uses
  Math;

{ TGrid }

procedure TGrid.Assign(const AGrid: TGrid);
var
  X, Y: Integer;
begin
  Assert(Assigned(AGrid));
  ChangeSize(AGrid.fSize);
  fPopulation := AGrid.fPopulation;
  fColCounts := Copy(AGrid.fColCounts);
  fRowCounts := Copy(AGrid.fRowCounts);
  for X := 0 to Pred(fSize.CX) do
    for Y := 0 to Pred(fSize.CY) do
      fState[X,Y] := AGrid.fState[X,Y];
end;

procedure TGrid.ChangeSize(const NewSize: TSizeEx);
begin
  fSize := NewSize;
  SetLength(fState, fSize.CX, fSize.CY);
  SetLength(fColCounts, fSize.CX);
  SetLength(fRowCounts, fSize.CY);
end;

constructor TGrid.Create;
begin
  inherited Create;
end;

function TGrid.GetState(X, Y: UInt16): TCellState;
begin
  Assert((X < fSize.CX) and (Y < fSize.CY));
  Result := fState[X, Y];
end;

function TGrid.GetStateByPt(const Pt: TPoint): TCellState;
begin
  Assert((Pt.X >= 0) and (Pt.Y >= 0));
  Result := GetState(Pt.X, Pt.Y);
end;

function TGrid.GridToUniverseCoord(const GridCoord: TPoint): TPoint;
var
  O: TPoint;
begin
  O := Origin;
  Result := Point(GridCoord.X - O.X, GridCoord.Y - O.Y);
end;

procedure TGrid.Initialise;
var
  X, Y: Integer;  // loop control: don't use UInt16
begin
  for X := 0 to Pred(fSize.CX) do
    for Y := 0 to Pred(fSize.CY) do
      fState[X, Y] := csOff;
  fPopulation := 0;
  for X := 0 to Pred(fSize.CX) do
    fColCounts[X] := 0;
  for Y := 0 to Pred(fSize.CY) do
    fRowCounts[Y] := 0;
end;

function TGrid.IsEqual(const AGrid: TGrid): Boolean;
var
  X, Y: Integer;
begin
  if fSize <> AGrid.fSize then
    Exit(False);
  for X := 0 to Pred(fSize.CX) do
    for Y := 0 to Pred(fSize.CY) do
      if fState[X,Y] <> AGrid.fState[X,Y] then
        Exit(False);
  Result := True;
  // Populations should match: they redundant information so not tested above
  Assert(fPopulation = AGrid.fPopulation);
end;

function TGrid.Origin: TPoint;
begin
  Assert(not Size.IsZero);
  Result := Point(fSize.CX div 2, fSize.CY div 2);
end;

function TGrid.PatternBounds: TPatternBounds;
var
  BoundsRect: TRect;  // bounding rectangle built using approximations
begin
  BoundsRect.Left := 0;
  while (BoundsRect.Left < fSize.CX)
    and (fColCounts[BoundsRect.Left] = 0) do
    Inc(BoundsRect.Left);
  if BoundsRect.Left = fSize.CX then
  begin
    Result := TPatternBounds.CreateEmpty;
    Exit;
  end;
  BoundsRect.Right := Pred(fSize.CX);
  while (BoundsRect.Right > BoundsRect.Left)
    and (fColCounts[BoundsRect.Right] = 0) do
    Dec(BoundsRect.Right);
  BoundsRect.Top := 0;
  while (BoundsRect.Top < fSize.CY)
    and (fRowCounts[BoundsRect.Top] = 0) do
    Inc(BoundsRect.Top);
  BoundsRect.Bottom := Pred(fSize.CY);
  while (BoundsRect.Bottom > BoundsRect.Top)
    and (fRowCounts[BoundsRect.Bottom] = 0) do
    Dec(BoundsRect.Bottom);
  Result := TPatternBounds.Create(BoundsRect);
end;

function TGrid.Population: UInt32;
begin
  Result := fPopulation;
end;

procedure TGrid.SetSize(const NewSize: TSizeEx);
begin
  Assert((NewSize.CX >= 0) and (NewSize.CY >= 0));
  if NewSize <> fSize then
    ChangeSize(NewSize);
  Initialise;
end;

procedure TGrid.SetState(X, Y: UInt16; NewState: TCellState);
begin
  Assert((X < fSize.CX) and (Y < fSize.CY));
  case NewState of
    csOn:
      if fState[X, Y] = csOff then
      begin
        Inc(fPopulation);
        Inc(fColCounts[X]);
        Inc(fRowCounts[Y]);
      end;
    csOff:
      if fState[X, Y] = csOn then
      begin
        Dec(fPopulation);
        Dec(fColCounts[X]);
        Dec(fRowCounts[Y]);
      end;
  end;
  fState[X, Y] := NewState;
end;

procedure TGrid.SetStateByPt(const Pt: TPoint; NewState: TCellState);
begin
  Assert((Pt.X >= 0) and (Pt.Y >= 0));
  SetState(Pt.X, Pt.Y, NewState);
end;

function TGrid.UniverseToGridCoord(const UniverseCoord: TPoint): TPoint;
var
  O: TPoint;
begin
  O := Origin;
  Result := Point(UniverseCoord.X + O.X, UniverseCoord.Y + O.Y);
end;

{ TPatternBounds }

function TPatternBounds.BoundsRect: TRect;
begin
  Result.TopLeft := TopLeft;
  Result.BottomRight := Point(TopLeft.X + Size.CX - 1, TopLeft.Y + Size.CY - 1);
end;

constructor TPatternBounds.Create(const ARect: TRect);
begin
  Create(
    ARect.TopLeft,
    TSizeEx.Create(RectWidth(ARect) + 1, RectHeight(ARect) + 1)
  );
end;

constructor TPatternBounds.Create(const ATopLeft: TPoint; const ASize: TSizeEx);
begin
  TopLeft := ATopLeft;
  Size := ASize;
end;

class function TPatternBounds.CreateEmpty: TPatternBounds;
begin
  Result := TPatternBounds.Create(Point(-1, -1), TSizeEx.Create(0, 0));
end;

class operator TPatternBounds.Equal(const PB1, PB2: TPatternBounds): Boolean;
begin
  Result := (PB1.Size = PB2.Size)
    and (PB1.TopLeft.X = PB2.TopLeft.X)
    and (PB1.TopLeft.Y = PB2.TopLeft.Y);
end;

function TPatternBounds.IsEmpty: Boolean;
begin
  Result := Size.IsZero;
end;

class operator TPatternBounds.NotEqual(const PB1, PB2: TPatternBounds): Boolean;
begin
  Result := not (PB1 = PB2);
end;

end.


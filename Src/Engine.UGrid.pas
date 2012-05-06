unit Engine.UGrid;

interface

uses
  Types,
  Engine.UCommon;

type
  TPatternBounds = record
    TopLeft: TPoint;
    Size: TSize;
  end;

type
  TGrid = class(TObject)
  strict private
    var
      fSize: TSize;
      fState: array of array of TCellState;
      fPopulation: UInt32;
  public
    constructor Create;
    function GetSize: TSize;
    procedure SetSize(const NewSize: TSize);
    function GetState(X, Y: UInt16): TCellState;
    procedure SetState(X, Y: UInt16; NewState: TCellState);
    procedure Initialise;
    function Population: UInt32;
    function PatternBounds: TPatternBounds;
    property State[X, Y: UInt16]: TCellState read GetState write SetState;
      default;
    // TODO: permit setting of size to 0 (but not -ve)
    property Size: TSize read GetSize write SetSize;
  end;

implementation

uses
  Math;

{ TGrid }

constructor TGrid.Create;
begin
  inherited Create;
end;

function TGrid.GetSize: TSize;
begin
  Result := fSize;
end;

function TGrid.GetState(X, Y: UInt16): TCellState;
begin
  Assert((X < fSize.cx) and (Y < fSize.cy));
  Result := fState[X, Y];
end;

procedure TGrid.Initialise;
var
  X, Y: UInt16;
begin
  for X := 0 to Pred(fSize.cx) do
    for Y := 0 to Pred(fSize.cy) do
      fState[X, Y] := csOff;
  fPopulation := 0;
end;

function TGrid.PatternBounds: TPatternBounds;
var
  BoundsRect: TRect;  // bounding rectangle built using approximations

  // Following routines must be called in order: they build on each other

  function FindLeftMost: Boolean;
  var
    X, Y: Integer;  // loops thru grid - optimisation related bug if UInt16
  begin
    for X := 0 to Pred(fSize.cx) do
      for Y := 0 to Pred(fSize.cy) do
        if fState[X,Y] = csOn then
        begin
          // found left-most
          BoundsRect.Left := X;
          // do estimates for others
          BoundsRect.Right := X;  // right-most can be left of found X value
          BoundsRect.Top := Y;    // topm-ost can't be lower than found Y value
          BoundsRect.Bottom := Y; // bottom-most can't be above found Y value
          Exit(True);
        end;
    Result := False;
  end;

  procedure FindRightMost;
  var
    X, Y: Integer;      // loops thru grid - optimisation related bug if UInt16
    MinRight: Integer;  // minimum possible right value
  begin
    MinRight := BoundsRect.Right + 1;
    for X := Pred(fSize.cx) downto MinRight do
      for Y := 0 to Pred(fSize.cy) do
        if fState[X,Y] = csOn then
        begin
          // found a better right-most
          BoundsRect.Right := X;
          // try to improve on estimates for top and bottom
          BoundsRect.Top := Min(Y, BoundsRect.Top);
          BoundsRect.Bottom := Max(Y, BoundsRect.Bottom);
          Exit;
        end;
  end;

  procedure FindTopMost;
  var
    X, Y: Integer;    // loops thru grid - optimisation related bug if UInt16
    MaxTop: Integer;  // maximum possible top value
  begin
    MaxTop := BoundsRect.Top - 1;
    for Y := 0 to MaxTop do
      // We know there are no "On" cells to left of BoundsRect.Left or to right
      // of BoundsRects.Right.
      for X := BoundsRect.Left to BoundsRect.Right do
        if fState[X,Y] = csOn then
        begin
          // found a better top-most
          BoundsRect.Top := Y;
          Exit;
        end;
  end;

  procedure FindBottomMost;
  var
    X, Y: Integer;      // loops thru grid - optimisation related bug if UInt16
    MinBottom: Integer; // minimum possible bottom value
  begin
    MinBottom := BoundsRect.Bottom + 1;
    for Y := Pred(fSize.cy) downto MinBottom do
      // We know there are no "On" cells to left of BoundsRect.Left or to right
      // of BoundsRects.Right.
      for X := BoundsRect.Left to BoundsRect.Right do
        if fState[X,Y] = csOn then
        begin
          // found a better bottom-most
          BoundsRect.Bottom := Y;
          Exit;
        end;
  end;

begin
  BoundsRect := Rect(fSize.cx, fSize.cy, -1, -1); // worst approximation
  if not FindLeftMost then
  begin
    Result.TopLeft := Point(-1, -1);
    Result.Size.cx := 0;
    Result.Size.cy := 0;
    Exit;
  end;
  FindRightMost;
  FindTopMost;
  FindBottomMost;
  Result.TopLeft := BoundsRect.TopLeft;
  Result.Size.cx := RectWidth(BoundsRect) + 1;
  Result.Size.cy := RectHeight(BoundsRect) + 1;
end;

function TGrid.Population: UInt32;
begin
  Result := fPopulation;
end;

procedure TGrid.SetSize(const NewSize: TSize);
begin
  Assert((NewSize.cx > 0) and (NewSize.cy > 0));

  if (NewSize.cx <> fSize.cx) or (NewSize.cy <> fSize.cy) then
  begin
    fSize := NewSize;
    SetLength(fState, fSize.cx, fSize.cy);
  end;
  Initialise;
end;

procedure TGrid.SetState(X, Y: UInt16; NewState: TCellState);
begin
  Assert((X < fSize.cx) and (Y < fSize.cy));
  case NewState of
    csOn:
      if fState[X, Y] = csOff then
        Inc(fPopulation);
    csOff:
      if fState[X, Y] = csOn then
        Dec(fPopulation);
  end;
  fState[X, Y] := NewState;
end;

end.


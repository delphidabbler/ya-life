unit Engine.UGrid;

interface

uses
  Types,
  Engine.UCommon, UStructs;

type
  TPatternBounds = record
    TopLeft: TPoint;
    Size: TSizeEx;
  end;

type
  TGrid = class(TObject)
  strict private
    var
      fSize: TSizeEx;
      fState: array of array of TCellState;
      fPopulation: UInt32;
    procedure ChangeSize(const NewSize: TSizeEx);
  public
    constructor Create;
    procedure SetSize(const NewSize: TSizeEx);
    function GetState(X, Y: UInt16): TCellState;
    procedure SetState(X, Y: UInt16; NewState: TCellState);
    procedure Initialise;
    function Population: UInt32;
    function PatternBounds: TPatternBounds;
    property State[X, Y: UInt16]: TCellState read GetState write SetState;
      default;
    property Size: TSizeEx read fSize write SetSize;
  end;

implementation

uses
  Math;

{ TGrid }

procedure TGrid.ChangeSize(const NewSize: TSizeEx);
begin
  fSize := NewSize;
  SetLength(fState, fSize.CX, fSize.CY);
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

procedure TGrid.Initialise;
var
  X, Y: Integer;  // loop control: don't use UInt16
begin
  for X := 0 to Pred(fSize.CX) do
    for Y := 0 to Pred(fSize.CY) do
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
    for X := 0 to Pred(fSize.CX) do
      for Y := 0 to Pred(fSize.CY) do
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
    for X := Pred(fSize.CX) downto MinRight do
      for Y := 0 to Pred(fSize.CY) do
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
    for Y := Pred(fSize.CY) downto MinBottom do
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
  BoundsRect := Rect(fSize.CX, fSize.CY, -1, -1); // worst approximation
  if not FindLeftMost then
  begin
    Result.TopLeft := Point(-1, -1);
    Result.Size := TSizeEx.Create(0, 0);
    Exit;
  end;
  FindRightMost;
  FindTopMost;
  FindBottomMost;
  Result.TopLeft := BoundsRect.TopLeft;
  Result.Size := TSizeEx.Create(
    RectWidth(BoundsRect) + 1, RectHeight(BoundsRect) + 1
  );
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
        Inc(fPopulation);
    csOff:
      if fState[X, Y] = csOn then
        Dec(fPopulation);
  end;
  fState[X, Y] := NewState;
end;

end.


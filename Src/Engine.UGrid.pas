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
  IGrid = interface
    ['{E47F37D0-0C3E-4055-8CE0-1B9E65E5A074}']
    function GetSize: TSize;
    procedure SetSize(const NewSize: TSize);
    property Size: TSize read GetSize write SetSize;
    function GetState(X, Y: UInt16): TCellState;
    procedure SetState(X, Y: UInt16; NewState: TCellState);
    property State[X, Y: UInt16]: TCellState read GetState write SetState;
      default;
    procedure Initialise;
    function Population: UInt32;
    function PatternOffset: TPoint;
//    function PatternBounds: TPatternBounds;
  end;

type
  TGrid = class(TInterfacedObject, IGrid)
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
    function PatternOffset: TPoint;
//    function PatternBounds: TPatternBounds;
  end;

implementation

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

function TGrid.PatternOffset: TPoint;
var
  X, Y: UInt16;
  FoundY: Boolean;
begin
  Result := Point(-1, -1);
  // Find left-most cell containing part of pattern: this is Result.X. If that
  // is found then it also gives us a first approximation to Result.Y.
  X := 0;
  while (X < fSize.cx) and (Result.X = -1) do
  begin
    Y := 0;
    while (Y < fSize.cy) and (Result.X = -1) do
    begin
      if fState[X, Y] = csOn then
      begin
        Result.X := X;
        Result.Y := Y;
      end
      else
        Inc(Y);
    end;
    Inc(X);
  end;
  if Result.X = -1 then
    Exit;
  // We have found Result.X and a highest value for Result.Y. Now search area to
  // left of Result.X and below Result.Y to see if there's a better value for
  // Result.Y
  FoundY := False;
  Y := 0;
  while (Y < Result.Y) and not FoundY do
  begin
    X := Result.X;
    while (X < fSize.cx) and not FoundY do
    begin
      if fState[X, Y] = csOn then
      begin
        Result.Y := Y;
        FoundY := True;
      end
      else
        Inc(X);
    end;
    Inc(Y);
  end;
  Assert(Result.Y >= 0);  // if we found X we must find Y
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

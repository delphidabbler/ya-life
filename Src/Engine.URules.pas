unit Engine.URules;

interface

uses
  Engine.UCommon;

type
  TRule = class(TObject)
  strict private
    var
      fBirthCriteria: TNeighbourCounts;
      fSurvivalCriteria: TNeighbourCounts;
    function RuleSetToString(const RuleSet: TNeighbourCounts): string;
    function RuleStringToSet(const RuleString: string): TNeighbourCounts;
  public
    ///  <summary>Constructs a rule from given birth and survival rule sets.
    ///  </summary>
    constructor Create(const BirthCriteria, SurvivalCriteria: TNeighbourCounts);
      overload;
    ///  <summary>Constructs a rule from a given rule string</summary>
    ///  <remarks>Rule must use either S/B or "B"{list}/"S"{list} format.
    ///  See http://www.conwaylife.com/wiki/Rulestring#Rules.</remarks>
    constructor Create(const RuleString: string); overload;
    ///  <summary>Applies rule for given cell state and neighbour count and
    ///  returns new cell state.</summary>
    function Apply(const CellState: TCellState;
      const Neighbours: TNeighbourCount): TCellState;
    ///  <summary>Returns rule as a string in the common S/B notation.
    ///  </summary>
    function ToString: string; override;
    ///  <summary>Returns rule as a string in the alternative
    ///  "B"{list}/"S"{list} notation.</summary>
    function ToBSString: string;
    ///  <summary>The birth criteria of the rule.</summary>
    property BirthCriteria: TNeighbourCounts read fBirthCriteria;
    ///  <summary>The survival criteria of the rule.</summary>
    property SurvivalCriteria: TNeighbourCounts read fSurvivalCriteria;
  end;

implementation

uses
  SysUtils, StrUtils,
  UUtils;

{ TRule }

function TRule.Apply(const CellState: TCellState;
  const Neighbours: TNeighbourCount): TCellState;
begin
  Result := CellState;    // assume no change
  case CellState of
    csOn:
    begin
      if not (Neighbours in fSurvivalCriteria) then
        Result := csOff
    end;
    csOff:
    begin
      if Neighbours in fBirthCriteria then
        Result := csOn;
    end;
  end;
end;

constructor TRule.Create(const RuleString: string);
var
  Part1, Part2: string;
  BirthRuleString, SurvivalRuleString: string;
begin
  inherited Create;
  SplitStr(RuleString, '/', Part1, Part2);
  Part1 := Trim(Part1);
  Part2 := Trim(Part2);
  if StartsText('B', Part1) then
  begin
    if (Part2 <> '') and not StartsText('S', Part2) then
      raise EConvertError.CreateFmt(
        '"%s" is not a valid rule string', [RuleString]
      );
    BirthRuleString := RightStr(Part1, Length(Part1) - 1);
    if Part2 <> '' then
      SurvivalRuleString := RightStr(Part2, Length(Part2) - 1)
    else
      SurvivalRuleString := '';
  end
  else
  begin
    SurvivalRuleString := Part1;
    BirthRuleString := Part2;
  end;
  fBirthCriteria := RuleStringToSet(BirthRuleString);
  fSurvivalCriteria := RuleStringToSet(SurvivalRuleString);
end;

constructor TRule.Create(const BirthCriteria, SurvivalCriteria:
  TNeighbourCounts);
begin
  inherited Create;
  fBirthCriteria := BirthCriteria;
  fSurvivalCriteria := SurvivalCriteria;
end;

function TRule.RuleSetToString(const RuleSet: TNeighbourCounts): string;
var
  N: TNeighbourCount;
begin
  Result := '';
  for N in RuleSet do
    Result := Result + IntToStr(N);
end;

function TRule.RuleStringToSet(const RuleString: string): TNeighbourCounts;
var
  Ch: Char;
  I: Integer;
begin
  Result := [];
  for Ch in RuleString do
  begin
    if not TryStrToInt(Ch, I)
      or (I < Low(TNeighbourCount))
      or (I > High(TNeighbourCount)) then
      raise EConvertError.CreateFmt(
        '"%s" is not a valid rule string character', [Ch])
      ;
    Include(Result, TNeighbourCount(I));
  end;
end;

function TRule.ToBSString: string;
begin
  Result := 'B' + RuleSetToString(fBirthCriteria)
    + '/S' + RuleSetToString(fSurvivalCriteria);
end;

function TRule.ToString: string;
begin
  Result := RuleSetToString(fSurvivalCriteria)
    + '/' + RuleSetToString(fBirthCriteria);
end;

end.

unit TestNativeFilter;
{

  Delphi DUnit Test Case
  ----------------------
  This unit contains a skeleton test case class generated by the Test Case Wizard.
  Modify the generated code to correctly setup and call the methods from the unit 
  being tested.

}

interface

uses
  TestFramework, Engine.UPattern, Engine.UGrid, Generics.Collections, Types,
  Classes, SysUtils, Filters.UNative, UStructs, Engine.UCommon, Engine.URules;

type
  // Test methods for class TNativeReader
  TestTNativeReader = class(TTestCase)
  strict private
    fReader: TNativeReader;
    fPattern: TPattern;
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestLoadFromFile;
    procedure TestLoadFromStream;
  end;

  // Test methods for class TNativeWriter
  TestTNativeWriter = class(TTestCase)
  strict private
    fWriter: TNativeWriter;
    fPattern: TPattern;
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestSaveToStream;
  end;

implementation

const
  TestGrid: array[0..10] of string = (
    '...........................',
    '...........................',
    '.....OO.OO.OOO.OO.OO.......',
    '.....OOOOOOO...O...OOOOOO..',
    '...............O...........',
    '...........................',
    '.....OOOOOOOOOOOOOOOOOOOO..',
    '...........OO...OO.........',
    '...........................',
    '...........................',
    '...........................'
  );

  TestGridSize: TSizeEx = (CX: 27; CY: 11);

  SinglePatternOffset: TPoint = (X: 5; Y: 2);
  SinglePatternSize: TSizeEx = (CX: 20; CY: 5);
  SinglePatternContent: array[0..8] of string = (
    '== ya-life 1 ==',
    '!Name Single Pattern Test',
    '!Author John Smith',
    '! A test pattern',
    '! Single pattern',
    '!Rule default',
    '!Size 27 11',
    '5 2',
    '2*.2*.3*.2*.2*#7*3.*3.6*#A.*2#14*#6.2*3.2*'
  );

  MultiPattern1Offset: TPoint = (X: 5; Y: 2);
  MultiPattern1Size: TSizeEx = (CX: 9; CY: 2);
  MultiPattern2Offset: TPoint = (X: 15; Y: 2);
  MultiPattern2Size: TSizeEx = (CX: 10; CY: 3);
  MultiPattern3Offset: TPoint = (X: 5; Y: 6);
  MultiPattern3Size: TSizeEx = (CX: 20; CY: 2);
  MultiPatternContent: array[0..17] of string = (
    '== ya-life 1 ==',
    '',
    '!Rule B3/S23',
    '',
    '',
    '!Size 27 11',
    '',
    '5 2',
    '2*.2*.3*#7*',
    '15 2',
    '2*.2*#*3.6*#*',
    '',
    '',
    '',
    '5 6',
    '14*#6.2*3.2*',
    '',
    ''
  );

  QuadPoleGrid: array[0..6] of string = (
    'OO.....',
    'O.O....',
    '.......',
    '..O.O..',
    '.......',
    '....O.O',
    '.....OO'
  );
  QuadPoleGridSize: TSizeEx = (CX: 7; CY: 7);

function GridToStr(const G: TGrid): string;
var
  X, Y: Integer;
begin
  Result := '';
  for Y := 0 to Pred(G.Size.CY) do
  begin
    for X := 0 to Pred(G.Size.CX) do
    begin
      if G[X,Y] = csOn then
        Result := Result + '1'
      else
        Result := Result + '0';
    end;
    Result := Result + #13#10;
  end;
end;

procedure SetupGrid(const G: TGrid; Pat: array of string);
var
  X, Y: Integer;
begin
  G.Initialise;
  for Y := 0 to Pred(G.Size.CY) do
    for X := 0 to Pred(G.Size.CX) do
      if Pat[Y, X+1] = 'O' then
        G[X, Y] := csOn;
end;

procedure StrArrayToStream(const A: array of string; const Stm: TStream);
var
  SL: TStringList;
  S: string;
begin
  SL := TStringList.Create;
  try
    for S in A do
      SL.Add(S);
    SL.SaveToStream(Stm, TEncoding.UTF8);
    Stm.Position := 0;
  finally
    SL.Free;
  end;
end;

{ TestTNativeReader }

procedure TestTNativeReader.SetUp;
begin
  fReader := TNativeReader.Create;
  fPattern := TPattern.Create;
end;

procedure TestTNativeReader.TearDown;
begin
  fPattern.Free;
  fReader.Free;
end;

procedure TestTNativeReader.TestLoadFromFile;
var
  FileName: TFileName;
  G: TGrid;
begin
  FileName := ExtractFilePath(ParamStr(0)) + '..\Files\quadpole.yal';
  fReader.LoadFromFile(fPattern, FileName);
  G := TGrid.Create;
  try
    G.Size := QuadPoleGridSize;
    SetupGrid(G, QuadPoleGrid);
    CheckTrue(G.IsEqual(fPattern.Grid), 'Test 1: Grid');
    CheckEquals('QuadPole', fPattern.Name, 'Test 1: Name');
    CheckEquals(1, fPattern.Description.Count, 'Test 1: Description.Count');
    CheckEquals(
      'The barberpole of length 4 and thus a period 2 oscillator.',
      fPattern.Description[0], 'Test 1: Description[0]'
    );
    CheckEquals('1357/1357', fPattern.Rule.ToString, 'Test 1: Rule');
  finally
    G.Free;
  end;
end;

procedure TestTNativeReader.TestLoadFromStream;
var
  Stm: TStream;
  G: TGrid;
begin
  Stm := TMemoryStream.Create;
  try
    StrArrayToStream(SinglePatternContent, Stm);
    fReader.LoadFromStream(fPattern, Stm);
    G := TGrid.Create;
    try
      G.Size := TestGridSize;
      SetupGrid(G, TestGrid);
      CheckTrue(G.IsEqual(fPattern.Grid), 'Test 1: Grid');
      CheckEquals('Single Pattern Test', fPattern.Name, 'Test 1: Name');
      CheckEquals('John Smith', fPattern.Author, 'Test 1: Author');
      CheckEquals(2, fPattern.Description.Count, 'Test 1: Description.Count');
      CheckEquals(
        'A test pattern',
        fPattern.Description[0], 'Test 1: Description[0]'
      );
      CheckEquals(
        'Single pattern',
        fPattern.Description[1], 'Test 1: Description[1]'
      );
      CheckFalse(Assigned(fPattern.Rule), 'Test 1: Rule');
    finally
      G.Free;
    end;
  finally
    Stm.Free;
  end;

  Stm := TMemoryStream.Create;
  try
    StrArrayToStream(MultiPatternContent, Stm);
    fReader.LoadFromStream(fPattern, Stm);
    G := TGrid.Create;
    try
      G.Size := TestGridSize;
      SetupGrid(G, TestGrid);
      CheckTrue(G.IsEqual(fPattern.Grid), 'Test 2: Grid');
      CheckEquals('', fPattern.Name, 'Test 2: Name');
      CheckEquals('', fPattern.Author, 'Test 2: Author');
      CheckEquals(0, fPattern.Description.Count, 'Test 2: Description.Count');
      CheckEquals('23/3', fPattern.Rule.ToString, 'Test 2: Rule');
    finally
      G.Free;
    end;
  finally
    Stm.Free;
  end;
end;

{ TestTNativeWriter }

procedure TestTNativeWriter.SetUp;
begin
  fWriter := TNativeWriter.Create;
  fPattern := TPattern.Create;
end;

procedure TestTNativeWriter.TearDown;
begin
  fPattern.Free;
  fWriter.Free;
end;

procedure TestTNativeWriter.TestSaveToStream;
var
  Stm: TStringStream;
  Lines: TStringList;
  Rule: TRule;
begin
  fPattern.Grid.Size := TestGridSize;
  SetupGrid(fPattern.Grid, TestGrid);
  fPattern.Name := 'Single Pattern Test';
  fPattern.Author := 'John Smith';
  fPattern.Description.Add('A test pattern');
  fPattern.Description.Add('Single pattern');
  fPattern.Rule := nil;
  Stm := TStringStream.Create('', TEncoding.UTF8);
  try
    Lines := TStringList.Create;
    try
      fWriter.SaveToStream(fPattern, Stm);
      Stm.Position := 0;
      Lines.LoadFromStream(Stm, TEncoding.UTF8);
      CheckTrue(Lines.Count >= 9, 'Test 1: Line count');
      CheckEquals('== ya-life 1 ==', Lines[0], 'Test 1: Header');
      CheckEquals('!Name Single Pattern Test', Lines[1], 'Test 1: Name');
      CheckEquals('!Author John Smith', Lines[2], 'Test 1: Author');
      CheckEquals('! A test pattern', Lines[3], 'Test 1: Description 1');
      CheckEquals('! Single pattern', Lines[4], 'Test 1: Description 2');
      CheckEquals('!Rule default', Lines[5], 'Test 1: Rule');
      CheckEquals('!Size 27 11', Lines[6], 'Test 1: Size');
      CheckEquals('5 2', Lines[7], 'Test 1: Offset');
      CheckEquals(
        '2*.2*.3*.2*.2*#7*3.*3.6*#A.*2#14*#6.2*3.2*', Lines[8],
        'Test 1: Encoded data'
      );
      Stm.Size := 0;
      Lines.Clear;
      Rule := TRule.Create('1357/1357');
      try
        fPattern.Rule := Rule;
      finally
        Rule.Free;
      end;
      fWriter.SaveToStream(fPattern, Stm);
      Stm.Position := 0;
      Lines.LoadFromStream(Stm, TEncoding.UTF8);
      CheckEquals('!Rule 1357/1357', Lines[5], 'Test 2: Rule');
      Stm.Size := 0;
      Lines.Clear;
      fPattern.Grid[0, 0] := csOn;
      fWriter.SaveToStream(fPattern, Stm);
      Stm.Position := 0;
      Lines.LoadFromStream(Stm, TEncoding.UTF8);
      CheckEquals(
        '*2#5.2*.2*.3*.2*.2*#5.7*3.*3.6*#F.*2#5.14*#B.2*3.2*',
        Lines[8], 'Test 3: Encoded data'
      );
    finally
      Lines.Free;
    end;
  finally
    Stm.Free;
  end;
end;

initialization
  // Register any test cases with the test runner
  RegisterTest(TestTNativeReader.Suite);
  RegisterTest(TestTNativeWriter.Suite);
end.

unit TestStructs;

interface

uses
  TestFramework, Types, UStructs;

type
  TestTSizeEx = class(TTestCase)
  strict private
    SZ1, SZ2, SZ3, S1a, S1b, S2, S3: TSizeEx;
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestConstructor;
    procedure TestIsZero;
    procedure TestImplicit;
    procedure TestEqual;
    procedure TestNotEqual;
  end;

implementation

function MakeSize(CX, CY: Integer): TSize;
begin
  Result.cx := CX;
  Result.cy := CY;
end;

{ TestTSizeEx }

procedure TestTSizeEx.SetUp;
begin
  SZ1 := TSizeEx.Create(0, 0);
  SZ2 := TSizeEx.Create(0, -3);
  SZ3 := TSizeEx.Create(4, 0);
  S1a := TSizeEx.Create(5, 7);
  S1b := TSizeEx.Create(5, 7);
  S2 := TSizeEx.Create(-12, 13);
  S3 := TSizeEx.Create(7, 9);
end;

procedure TestTSizeEx.TearDown;
begin
end;

procedure TestTSizeEx.TestConstructor;
begin
  CheckEquals(0, SZ1.CX, 'Test 1 cx');
  CheckEquals(0, SZ1.CY, 'Test 1 cy');
  CheckEquals(-12, S2.CX, 'Test 2 cx');
  CheckEquals(13, S2.CY, 'Test 2 cy');
end;

procedure TestTSizeEx.TestEqual;
var
  S: TSize;
begin
  CheckTrue(SZ1 = SZ2, 'Test 1');
  CheckTrue(SZ1 = SZ3, 'Test 2');
  CheckTrue(SZ2 = SZ3, 'Test 3');
  CheckTrue(S1a = S1b, 'Test 4');
  CheckTrue(S2 = S2, 'Test 5');
  CheckFalse(S2 = S3, 'Test 6');
  CheckFalse(S2 = SZ1, 'Test 7');
  CheckFalse(S2 = SZ2, 'Test 8');
  S := MakeSize(7, 9);
  CheckFalse(S = S2, 'Test 9');
  CheckFalse(S2 = S, 'Test 10');
  CheckTrue(S = S3, 'Test 11');
  CheckTrue(S3 = S, 'Test 12');
end;

procedure TestTSizeEx.TestImplicit;
var
  Size: TSize;
  SizeEx: TSizeEx;
begin
  Size := MakeSize(1, 12);
  SizeEx := Size;
  CheckEquals(Size.cx, SizeEx.CX, 'Test TSize => TSizeEx cx');
  CheckEquals(Size.cy, SizeEx.CY, 'Test TSize => TSizeEx cy');

  Size := S3;
  CheckEquals(S3.CX, Size.cx, 'Test TSizeEx => TSize cx');
  CheckEquals(S3.CY, Size.cy, 'Test TSizeEx => TSize cy');
end;

procedure TestTSizeEx.TestIsZero;
begin
  CheckTrue(SZ1.IsZero, 'Test 1');
  CheckTrue(SZ2.IsZero, 'Test 2');
  CheckTrue(SZ3.IsZero, 'Test 3');
  CheckFalse(S1a.IsZero, 'Test 4');
  CheckFalse(S1b.IsZero, 'Test 5');
  CheckFalse(S2.IsZero, 'Test 6');
  CheckFalse(S3.IsZero, 'Test 7');
end;

procedure TestTSizeEx.TestNotEqual;
var
  S: TSize;
begin
  CheckFalse(SZ1 <> SZ2, 'Test 1');
  CheckFalse(SZ1 <> SZ3, 'Test 2');
  CheckFalse(SZ2 <> SZ3, 'Test 3');
  CheckFalse(S1a <> S1b, 'Test 4');
  CheckFalse(S2 <> S2, 'Test 5');
  CheckTrue(S2 <> S3, 'Test 6');
  CheckTrue(S2 <> SZ1, 'Test 7');
  CheckTrue(S2 <> SZ2, 'Test 8');
  S := MakeSize(7, 9);
  CheckTrue(S <> S2, 'Test 9');
  CheckTrue(S2 <> S, 'Test 10');
  CheckFalse(S <> S3, 'Test 11');
  CheckFalse(S3 <> S, 'Test 12');
end;

initialization
  // Register any test cases with the test runner
  RegisterTest(TestTSizeEx.Suite);

end.

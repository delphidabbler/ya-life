program YaLifeTests;
{

  Delphi DUnit Test Project
  -------------------------
  This project contains the DUnit test framework and the GUI/Console test runners.
  Add "CONSOLE_TESTRUNNER" to the conditional defines entry in the project options
  to use the console test runner.  Otherwise the GUI test runner will be used by
  default.

}

{$IFDEF CONSOLE_TESTRUNNER}
{$APPTYPE CONSOLE}
{$ENDIF}

uses
  Forms,
  TestFramework,
  GUITestRunner,
  TextTestRunner,
  TestRules in 'TestRules.pas',
  Engine.URules in '..\..\..\Src\Engine.URules.pas',
  Engine.UCommon in '..\..\..\Src\Engine.UCommon.pas',
  UUtils in '..\..\..\Src\UUtils.pas',
  Engine.UGrid in '..\..\..\Src\Engine.UGrid.pas',
  TestGrid in 'TestGrid.pas',
  Engine.UCompressedGrid in '..\..\..\Src\Engine.UCompressedGrid.pas',
  TestCompressedGrid in 'TestCompressedGrid.pas',
  UStructs in '..\..\..\Src\UStructs.pas',
  TestStructs in 'TestStructs.pas',
  Engine.UPattern in '..\..\..\Src\Engine.UPattern.pas',
  TestPattern in 'TestPattern.pas',
  Filters.URLE in '..\..\..\Src\Filters.URLE.pas',
  UComparers in '..\..\..\Src\UComparers.pas',
  TestRLEFilter in 'TestRLEFilter.pas',
  Filters.UPlainText in '..\..\..\Src\Filters.UPlainText.pas',
  TestPlainTextFilter in 'TestPlainTextFilter.pas',
  Filters.ULife106 in '..\..\..\Src\Filters.ULife106.pas',
  TestLife106Filter in 'TestLife106Filter.pas',
  Filters.ULife105 in '..\..\..\Src\Filters.ULife105.pas',
  TestLife105Filter in 'TestLife105Filter.pas',
  Filters.UNative in '..\..\..\Src\Filters.UNative.pas',
  TestNativeFilter in 'TestNativeFilter.pas';

{$R *.RES}

begin
  Application.Initialize;
  if IsConsole then
    with TextTestRunner.RunRegisteredTests do
      Free
  else
    GUITestRunner.RunRegisteredTests;
end.


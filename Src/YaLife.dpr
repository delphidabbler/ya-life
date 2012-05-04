program YaLife;

uses
  Forms;

begin
  ReportMemoryLeaksOnShutdown := DebugHook <> 0;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.ModalPopupMode := pmAuto;
  Application.Run;
end.
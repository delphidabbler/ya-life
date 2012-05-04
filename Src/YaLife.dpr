program YaLife;

uses
  Forms;

{$Resource Resources.res}
{$Resource Version.res}

begin
  ReportMemoryLeaksOnShutdown := DebugHook <> 0;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.ModalPopupMode := pmAuto;
  Application.Run;
end.
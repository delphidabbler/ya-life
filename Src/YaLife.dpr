program YaLife;

uses
  Forms,
  UI.Forms.FmBase in 'UI.Forms.FmBase.pas' {BaseForm},
  UI.Frames.FrBase in 'UI.Frames.FrBase.pas' {BaseFrame: TFrame};

{$Resource Resources.res}
{$Resource Version.res}

begin
  ReportMemoryLeaksOnShutdown := DebugHook <> 0;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.ModalPopupMode := pmAuto;
  Application.Run;
end.
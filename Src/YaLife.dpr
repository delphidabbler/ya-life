program YaLife;

uses
  Forms,
  UI.Forms.FmBase in 'UI.Forms.FmBase.pas' {BaseForm},
  UI.Frames.FrBase in 'UI.Frames.FrBase.pas' {BaseFrame: TFrame},
  UI.Forms.FmMain in 'UI.Forms.FmMain.pas' {MainForm},
  UUtils in 'UUtils.pas';

{$Resource Resources.res}
{$Resource Version.res}

begin
  ReportMemoryLeaksOnShutdown := DebugHook <> 0;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.ModalPopupMode := pmAuto;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
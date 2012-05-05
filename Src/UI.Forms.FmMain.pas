unit UI.Forms.FmMain;

interface

uses
  UI.Forms.FmBase, Classes, ActnList, StdActns, Controls, ToolWin, ActnMan,
  ActnCtrls, ActnMenus, ImgList, PlatformDefaultStyleActnCtrls, ComCtrls, Forms,
  ExtCtrls, StdCtrls;

type
  TMainForm = class(TBaseForm)
    actionManager: TActionManager;
    enabledImages: TImageList;
    disabledImages: TImageList;
    mainMenu: TActionMainMenuBar;
    actExit: TFileExit;
    statusBar: TStatusBar;
    pnlLibrary: TPanel;
    splitterLibrary: TSplitter;
    pnlRight: TPanel;
    splitterTools: TSplitter;
    scrollBoxGrid: TScrollBox;
    paintBoxGrid: TPaintBox;
    mainToolbar: TActionToolBar;
    lblLibrary: TLabel;
    pnlGroupLibrary: TCategoryPanelGroup;
    catPanel1: TCategoryPanel;
    catPanel2: TCategoryPanel;
    catPanel3: TCategoryPanel;
  end;

var
  MainForm: TMainForm;

implementation


{$R *.dfm}

end.

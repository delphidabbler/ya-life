unit Engine.UPattern;

interface

uses
  Types, Classes,
  Engine.UGrid, Engine.URules;

type

  // Optional capabilities of a pattern
  TPatternCapability = (
    pcHasRule
  );

type
  ///  <summary>Describes how pattern is placed onto the life grid.</summary>
  TPatternOrigin = (
    poTopLeftOffset,  // Offset from top left of grid
    poCentre,         // Centre on grid centre
    poCentreOffset    // Offset from grid centre
  );

type

  TPattern = class(TObject)
  strict private
    var
      fGrid: TGrid;
      fName: string;
      fDescription: TStringList;
      fAuthor: string;
      fRule: TRule;
      fOffset: TPoint;
      fOrigin: TPatternOrigin;
    procedure SetName(const AName: string);
    procedure SetAuthor(const AAuthor: string);
    procedure SetDescription(const D: TStringList);
    procedure SetRule(const ARule: TRule);
    procedure SetGrid(const AGrid: TGrid);
  public
    constructor Create;
    destructor Destroy; override;
    property Name: string read fName write SetName;
    property Description: TStringList read fDescription write SetDescription;
    property Author: string read fAuthor write SetAuthor;
    property Rule: TRule read fRule write SetRule;
    property Offset: TPoint read fOffset write fOffset;
    property Origin: TPatternOrigin read fOrigin write fOrigin;
    property Grid: TGrid read fGrid write SetGrid;
  end;

implementation

uses
  SysUtils,
  UUtils;

{ TPattern }

constructor TPattern.Create;
begin
  inherited Create;
  fGrid := TGrid.Create;
  fRule := TRule.CreateNull;
  fOrigin := poCentre;
  fOffset := Point(0, 0);
  fDescription := TStringList.Create;
end;

destructor TPattern.Destroy;
begin
  fDescription.Free;
  fGrid.Free;
  inherited;
end;

procedure TPattern.SetAuthor(const AAuthor: string);
begin
  fAuthor := Trim(StripEOL(AAuthor));
end;

procedure TPattern.SetDescription(const D: TStringList);
begin
  Assert(Assigned(D));
  fDescription.Assign(D);
end;

procedure TPattern.SetGrid(const AGrid: TGrid);
begin
  Assert(Assigned(AGrid));
  fGrid.Assign(AGrid);
end;

procedure TPattern.SetName(const AName: string);
begin
  fName := Trim(StripEOL(AName));
end;

procedure TPattern.SetRule(const ARule: TRule);
begin
  fRule := ARule;
end;

end.


unit Filters.UNative;

interface

uses
  SysUtils, Classes, Types, Generics.Collections,

  Engine.UGrid, Engine.UPattern;

type

  TNativeReader = class(TObject)
  strict private
    var
      fPattern: TPattern;
      fLines: TStringList;
    procedure Parse;
    procedure ParseHeader(var LineIdx: Integer);
    procedure ParseCommands(var LineIdx: Integer);
    procedure ParsePatternData(var LineIdx: Integer);
    function ParseOffsetLine(const Line: string): TPoint;
    procedure ParseEncodedData(const EncodedData: string; const Offset: TPoint);
    procedure SetDefaults;
    procedure SetRule(const RuleStr: string);
    procedure SetSize(const SizePair: string);
  public
    constructor Create;
    destructor Destroy; override;
    procedure LoadFromFile(const APattern: TPattern;
      const AFileName: TFileName);
    procedure LoadFromStream(const APattern: TPattern; const AStream: TStream);
  end;

  TNativeWriter = class(TObject)
  strict private
    const
      EOLTag = '#';
      AliveTag = '*';
      DeadTag = '.';
  strict private
    type
      TCompressionEntity = record
        Tag: Char;
        Count: UInt16;
        constructor Create(ATag: Char; ACount: UInt16);
        function ToString: string;
      end;
    type
      TPatternCompressor = class(TObject)
      strict private
        var
          fData: TList<TCompressionEntity>;
          fGrid: TGrid;
        function ValueToChar(const Value: Int8): Char;
        function IsItemAtTopOfList(const Value: Int8): Boolean;
        function CompressValueCount(const Value: Int8): UInt16;
        procedure UpdateCount(const Value: Int8);
      public
        constructor Create(Grid: TGrid; Data: TList<TCompressionEntity>);
        function Execute: TPoint;
      end;
  strict private
    var
      fPattern: TPattern;
      fLines: TStringList;
    procedure Generate;
    procedure GenerateHeader;
    procedure GenerateCommands;
    procedure GenerateCommand(const Cmd, Text: string);
    procedure GeneratePatterns;
  public
    constructor Create;
    destructor Destroy; override;
    procedure SaveToFile(APattern: TPattern;
      const AFileName: TFileName);
    procedure SaveToStream(const APattern: TPattern; const AStream: TStream);
  end;

  ENativeFilter = class(Exception);

implementation

uses
  StrUtils, Math,
  Engine.UCommon, Engine.UCompressedGrid, Engine.URules, UStructs, UUtils;

{ TNativeReader }

constructor TNativeReader.Create;
begin
  inherited Create;
  fLines := TStringList.Create;
end;

destructor TNativeReader.Destroy;
begin
  fLines.Free;
  inherited;
end;

procedure TNativeReader.LoadFromFile(const APattern: TPattern;
  const AFileName: TFileName);
var
  Stm: TFileStream;
begin
  Stm := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    LoadFromStream(APattern, Stm);
  finally
    Stm.Free;
  end;
end;

procedure TNativeReader.LoadFromStream(const APattern: TPattern;
  const AStream: TStream);
begin
  Assert(Assigned(APattern));
  Assert(Assigned(AStream));
  fPattern := APattern;
  fLines.LoadFromStream(AStream, TEncoding.UTF8);
  fLines.Text := DOSLineBreaks( // any EOL allowed: converted to DOS
    Trim( // trimming is important to ensure no blank line at end of grid
      fLines.Text
    )
  );
  Parse;
end;

procedure TNativeReader.Parse;
var
  LineIdx: Integer;
begin
  SetDefaults;
  if fLines.Count = 0 then
    raise ENativeFilter.Create('Empty file');
  LineIdx := 0;
  ParseHeader(LineIdx);
  ParseCommands(LineIdx);
  if fPattern.Grid.Size.IsZero then
    raise ENativeFilter.Create('No size specified');
  ParsePatternData(LineIdx);
end;

procedure TNativeReader.ParseCommands(var LineIdx: Integer);
var
  Line: string;
  Command: string;
  Value: string;
begin
  while (LineIdx < fLines.Count) do
  begin
    Line := Trim(fLines[LineIdx]);
    if StartsText('!', Line) then
    begin
      SplitStr(Line, ' ', Command, Value);
      Command := Trim(Command);
      Value := Trim(Value);
      if Command = '!' then
      begin
        if Value <> '' then
          fPattern.Description.Add(Value);
      end
      else if SameText('!Name', Command) then
        fPattern.Name := Value
      else if SameText('!Author', Command) then
        fPattern.Author := Value
      else if SameText('!Rule', Command) then
      begin
        if SameText('default', Value) then
          fPattern.Rule := TRule.CreateNull
        else
          SetRule(Value);
      end
      else if SameText('!Size', Command) then
        SetSize(Value)
      else
        raise ENativeFilter.CreateFmt('Unrecognised command "%s"', [Command]);
    end
    else if Line <> '' then
      Exit;
    // else we have blank line & ignore it
    Inc(LineIdx);
  end;
end;

procedure TNativeReader.ParseEncodedData(const EncodedData: string;
  const Offset: TPoint);

  procedure SetGrid(X, Y: UInt16; State: TCellState);
  begin
    if X >= fPattern.Grid.Size.CX then
      raise ENativeFilter.Create('X grid coordinate out of bounds');
    if Y >= fPattern.Grid.Size.CY then
      raise ENativeFilter.Create('Y grid coordinate out of bounds');
    fPattern.Grid[X,Y] := State;
  end;

const
  DeadCell = '.';
  LiveCell = '*';
  EndOfLine = '#';
  HexChars = ['0'..'9', 'a'..'f', 'A'..'F'];
var
  CharIdx: Integer;
  I: Integer;
  Digits: string;
  Count: Integer;
  X, Y: UInt16;
begin
  CharIdx := 1;
  Count := 1;
  X := Offset.X;
  Y := Offset.Y;
  while CharIdx <= Length(EncodedData) do
  begin
    case EncodedData[CharIdx] of
      '0'..'9', 'a'..'f', 'A'..'F':
      begin
        Digits := '';
        repeat
          Digits := Digits + EncodedData[CharIdx];
          Inc(CharIdx);
        until (CharIdx > Length(EncodedData))
          or not CharInSet(EncodedData[CharIdx], HexChars);
        if not TryStrToInt('$' + Digits, Count) then
          raise ENativeFilter.Create('Invalid run count');
      end;
      DeadCell:
      begin
        Inc(X, Count);
        Count := 1;
        Inc(CharIdx);
      end;
      LiveCell:
      begin
        for I := 1 to Count do
        begin
          SetGrid(X, Y, csOn);
          Inc(X);
        end;
        Count := 1;
        Inc(CharIdx);
      end;
      EndOfLine:
      begin
        Inc(Y, Count);
        X := Offset.X;
        Count := 1;
        Inc(CharIdx);
      end;
    end;
  end;
end;

procedure TNativeReader.ParseHeader(var LineIdx: Integer);
begin
  if fLines[LineIdx] <> '== ya-life 1 ==' then
    raise ENativeFilter.Create('Invalid file format');
  Inc(LineIdx);
end;

function TNativeReader.ParseOffsetLine(const Line: string): TPoint;
var
  XStr, YStr: string;
begin
  SplitStr(Line, ' ', XStr, YStr);
  XStr := Trim(XStr);
  YStr := Trim(YStr);
  if not TryStrToInt(XStr, Result.X) or not TryStrToInt(YStr, Result.Y) then
    raise ENativeFilter.CreateFmt('Invalid pattern offset', [Line]);
end;

procedure TNativeReader.ParsePatternData(var LineIdx: Integer);

  procedure SkipBlankLines;
  begin
    while (LineIdx < fLines.Count) and (Trim(fLines[LineIdx]) = '') do
      Inc(LineIdx);
  end;

var
  Offset: TPoint;
begin
  SkipBlankLines;
  while LineIdx < fLines.Count do
  begin
    Offset := ParseOffsetLine(Trim(fLines[LineIdx]));
    Inc(LineIdx);
    SkipBlankLines;
    ParseEncodedData(Trim(fLines[LineIdx]), Offset);
    Inc(LineIdx);
    SkipBlankLines;
  end;
end;

procedure TNativeReader.SetDefaults;
begin
  fPattern.Rule := TRule.CreateNull;          // Default rule is no rule
  fPattern.Name := '';                        // Empty unless !Name command
  fPattern.Author := '';                      // Empty unless !Author command
  fPattern.Description.Clear;                 // Empty unles ! command(s)
  fPattern.Origin := poCentre;                // Grid always fits data
  fPattern.Grid.Initialise;                   // Just in case parsing fails
  fPattern.Grid.Size := TSizeEx.Create(0, 0); // To check if !Size specified
end;

procedure TNativeReader.SetRule(const RuleStr: string);
begin
  try
    fPattern.Rule := TRule.Create(RuleStr);
  except
    on E: EConvertError do
      raise ENativeFilter.CreateFmt('Invalid rule string "%s"', [RuleStr]);
    on E: Exception do
      raise;
  end;
end;

procedure TNativeReader.SetSize(const SizePair: string);
var
  CXStr, CYStr: string;
  CX, CY: Integer;
  Size: TSizeEx;
begin
  SplitStr(SizePair, ' ', CXStr, CYStr);
  CXStr := Trim(CXStr);
  CYStr := Trim(CYStr);
  if not TryStrToInt(CXStr, CX) or not TryStrToInt(CYStr, CY) then
    raise ENativeFilter.CreateFmt('Invalid size', [SizePair]);
  Size := TSizeEx.Create(CX, CY);
  if Size.IsZero then
    raise ENativeFilter.Create('Size cannot be zero');
  fPattern.Grid.Size := Size;
end;

{ TNativeWriter }

constructor TNativeWriter.Create;
begin
  inherited Create;
  fLines := TStringList.Create;
end;

destructor TNativeWriter.Destroy;
begin
  fLines.Free;
  inherited;
end;

procedure TNativeWriter.Generate;
begin
  if fPattern.Grid.Size.IsZero then
    raise ENativeFilter.Create('Empty pattern');
  fLines.Clear;
  GenerateHeader;
  GenerateCommands;
  GeneratePatterns;
end;

procedure TNativeWriter.GenerateCommand(const Cmd, Text: string);
begin
  if Trim(Text) = '' then
    Exit;
  fLines.Add(Format('!%s %s', [Cmd, Trim(Text)]));
end;

procedure TNativeWriter.GenerateCommands;
var
  Desc: string;
begin
  GenerateCommand('Name', fPattern.Name);
  GenerateCommand('Author', fPattern.Author);
  for Desc in fPattern.Description do
    GenerateCommand('', Desc);
  if not fPattern.Rule.IsNull then
    GenerateCommand('Rule', fPattern.Rule.ToString)
  else
    GenerateCommand('Rule', 'default');
  GenerateCommand(
    'Size', Format('%d %d', [fPattern.Grid.Size.CX, fPattern.Grid.Size.CY])
  );
end;

procedure TNativeWriter.GenerateHeader;
begin
  fLines.Add('== ya-life 1 ==');
end;

procedure TNativeWriter.GeneratePatterns;
var
  Entities: TList<TCompressionEntity>;
  Entity: TCompressionEntity;
  Compressor: TPatternCompressor;
  Offset: TPoint;
  RLEData: TStringBuilder;
begin
  Assert(not fPattern.Grid.Size.IsZero);
  // Although file format supports multiple patterns, we only use the one at
  // present.
  Entities := TList<TCompressionEntity>.Create;
  try
    Compressor := TPatternCompressor.Create(fPattern.Grid, Entities);
    try
      Offset := Compressor.Execute;
    finally
      Compressor.Free;
    end;
    fLines.Add(Format('%d %d', [Offset.X, Offset.Y]));
    RLEData := TStringBuilder.Create;
    try
      for Entity in Entities do
        RLEData.Append(Entity.ToString);
      fLines.Add(RLEData.ToString);
    finally
      RLEData.Free;
    end;
  finally
    Entities.Free;
  end;
end;

procedure TNativeWriter.SaveToFile(APattern: TPattern;
  const AFileName: TFileName);
var
  Stm: TFileStream;
begin
  Stm := TFileStream.Create(AFileName, fmCreate);
  try
    SaveToStream(APattern, Stm);
  finally
    Stm.Free;
  end;
end;

procedure TNativeWriter.SaveToStream(const APattern: TPattern;
  const AStream: TStream);
var
  Preamble, Bytes: TBytes;
begin
  fPattern := APattern;
  Generate;
  Preamble := TEncoding.UTF8.GetPreamble;
  if Length(Preamble) > 0 then
    AStream.WriteBuffer(Pointer(Preamble)^ , Length(Preamble));
  Bytes := TEncoding.UTF8.GetBytes(Trim(fLines.Text));
  if Length(Bytes) > 0 then
    AStream.WriteBuffer(Pointer(Bytes)^, Length(Bytes));
end;

{ TNativeWriter.TPatternCompressor }

function TNativeWriter.TPatternCompressor.CompressValueCount(
  const Value: Int8): UInt16;
begin
  if Sign(Value) = NegativeValue then
    Result := -Value
  else if Sign(Value) = PositiveValue then
    Result := Value
  else // ZeroValue
    Result := 1;
end;

constructor TNativeWriter.TPatternCompressor.Create(Grid: TGrid;
  Data: TList<TCompressionEntity>);
begin
  inherited Create;
  fGrid := Grid;
  fData := Data;
end;

function TNativeWriter.TPatternCompressor.Execute: TPoint;
var
  CompGrid: TCompressedGrid;
  CGItem: Int8;
begin
  fData.Clear;
  CompGrid := TCompressedGrid.Create;
  try
    CompGrid.Compress(fGrid);
    for CGItem in CompGrid.State do
    begin
      if IsItemAtTopOfList(CGItem) then
        UpdateCount(CGItem)
      else
      begin
        fData.Add(
          TCompressionEntity.Create(
            ValueToChar(CGItem),
            CompressValueCount(CGItem))
        );
      end;
    end;
    if (fData.Count > 0) and (fData.Last.Tag = EOLTag) then
      fData.Delete(Pred(fData.Count));
    Result := CompGrid.PatternBounds.TopLeft;
  finally
    CompGrid.Free;
  end;
end;

function TNativeWriter.TPatternCompressor.IsItemAtTopOfList(
  const Value: Int8): Boolean;
begin
  if fData.Count = 0 then
    Exit(False);
  Result := ValueToChar(Value) = fData.Last.Tag;
end;

procedure TNativeWriter.TPatternCompressor.UpdateCount(const Value: Int8);
begin
  Assert(fData.Count > 0);
  fData[Pred(fData.Count)] := TCompressionEntity.Create(
    fData.Last.Tag, fData.Last.Count + CompressValueCount(Value)
  );
end;

function TNativeWriter.TPatternCompressor.ValueToChar(const Value: Int8): Char;
begin
  if Sign(Value) = NegativeValue then
    Result := DeadTag
  else if Sign(Value) = PositiveValue then
    Result := AliveTag
  else // ZeroValue
    Result := EOLTag;
end;

{ TNativeWriter.TCompressionEntity }

constructor TNativeWriter.TCompressionEntity.Create(ATag: Char; ACount: UInt16);
begin
  Assert(ACount > 0);
  Tag := ATag;
  Count := ACount;
end;

function TNativeWriter.TCompressionEntity.ToString: string;
begin
  if Count = 1 then
    Result := Tag
  else
    Result := Format('%X', [Count]) + Tag;
end;

end.

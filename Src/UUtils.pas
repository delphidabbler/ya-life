unit UUtils;

interface

uses
  Classes, Character;

function SplitStr(const S, Delim: string; out S1, S2: string): Boolean;

function ExplodeStr(S, Delim: string; const List: TStrings;
  const AllowEmpty: Boolean = True; const Trim: Boolean = False): Integer;

function StripEOL(const S: string): string;

function RemoveWhiteSpace(const S: string): string;

function DOSLineBreaks(const S: string): string;

function TextWrap(const Text: string; const Width, Margin: Integer): string;

implementation

uses
  // Delphi
  SysUtils, StrUtils;

function SplitStr(const S, Delim: string; out S1, S2: string): Boolean;
var
  DelimPos: Integer;  // position of delimiter in source string
begin
  // Find position of first occurence of delimiter in string
  DelimPos := AnsiPos(Delim, S);
  if DelimPos > 0 then
  begin
    // Delimiter found: split and return True
    S1 := Copy(S, 1, DelimPos - 1);
    S2 := Copy(S, DelimPos + Length(Delim), MaxInt);
    Result := True;
  end
  else
  begin
    // Delimiter not found: return false and set S1 to whole string
    S1 := S;
    S2 := '';
    Result := False;
  end;
end;

function ExplodeStr(S, Delim: string; const List: TStrings;
  const AllowEmpty: Boolean = True; const Trim: Boolean = False): Integer;
var
  Item: string;       // current delimited text
  Remainder: string;  // remaining un-consumed part of string

  // ---------------------------------------------------------------------------
  procedure AddItem;
  begin
    // Adds optionally trimmed item to list if required
    if (Trim) then
      Item := SysUtils.Trim(Item);
    if (Item <> '') or AllowEmpty then
      List.Add(Item);
  end;
  // ---------------------------------------------------------------------------

begin
  // Clear the list
  List.Clear;
  // Check we have some entries in the string
  if S <> '' then
  begin
    // Repeatedly split string until we have no more entries
    while SplitStr(S, Delim, Item, Remainder) do
    begin
      AddItem;
      S := Remainder;
    end;
    // Add any remaining item
    AddItem;
  end;
  Result := List.Count;
end;

function StripEOL(const S: string): string;
begin
  Result := ReplaceStr(S, #13#10, ' ');
  Result := ReplaceStr(Result, #13, ' ');
  Result := ReplaceStr(Result, #10, ' ');
end;

function RemoveWhiteSpace(const S: string): string;
var
  Idx: Integer;      // loops thru all characters in string
  ResCount: Integer; // counts number of characters in result string
  PRes: PChar;       // pointer to characters in result string
begin
  // Set length of result to length of source string and set pointer to it
  SetLength(Result, Length(S));
  PRes := PChar(Result);
  // Reset count of characters in result string
  ResCount := 0;
  // Loop thru characters of source string
  Idx := 1;
  while Idx <= Length(S) do
  begin
    if TCharacter.IsWhiteSpace(S[Idx]) then
    begin
      // Current char is white space: skip it and any following white space
      Inc(Idx);
      while TCharacter.IsWhiteSpace(S[Idx]) do
        Inc(Idx);
    end
    else
    begin
      // Current char is not white space: copy it literally and count it
      PRes^ := S[Idx];
      Inc(PRes);
      Inc(ResCount);
      Inc(Idx);
    end;
  end;
  // Reduce length of result string if it is shorter than source string
  if ResCount < Length(S) then
    SetLength(Result, ResCount);
end;

function DOSLineBreaks(const S: string): string;
begin
  // need to replace DOS line ends with LF to start with so as not to replace
  // CRLF twice
  Result := ReplaceStr(S, #13#10, #10);
  Result := ReplaceStr(Result, #13, #10);
  Result := ReplaceStr(Result, #10, #13#10);
end;

function TextWrap(const Text: string; const Width, Margin: Integer): string;
var
  Word: string;       // next word in input text
  Line: string;       // current output line
  Words: TStringList; // list of words in input text
  I: Integer;         // loops thru all words in input text

  // -------------------------------------------------------------------------
  procedure AddLine(const Line: string);
  begin
    // Adds line of text to output, offsetting line by width of margin
    if Result <> '' then    // not first line: insert new line
      Result := Result + #13#10;
    Result := Result + StringOfChar(' ', Margin) + Line;
  end;
  // -------------------------------------------------------------------------

begin
  // Get all words in text
  Words := TStringList.Create;
  try
    ExplodeStr(Text, ' ', Words);
    Result := '';
    Line := '';
    // Loop for each word in text
    for I := 0 to Pred(Words.Count) do
    begin
      Word := Words[I];
      if Length(Line) + Length(Word) + 1 <= Width then
      begin
        // Word fits on current line: add it
        if Line = '' then
          Line := Word  // 1st word on line
        else
          Line := Line + ' ' + Word;
      end
      else
      begin
        // Word doesn't fit on line
        AddLine(Line);  // output line
        Line := Word;   // store word as first on next line
      end;
    end;
    if Line <> '' then
      // Residual line after end of loop: add to output
      AddLine(Line);
  finally
    Words.Free;
  end;
end;

end.

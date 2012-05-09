unit UUtils;

interface

function SplitStr(const S, Delim: string; out S1, S2: string): Boolean;

function StripEOL(const S: string): string;

function DOSLineBreaks(const S: string): string;

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

function StripEOL(const S: string): string;
begin
  Result := ReplaceStr(S, #13#10, ' ');
  Result := ReplaceStr(Result, #13, ' ');
  Result := ReplaceStr(Result, #10, ' ');
end;

function DOSLineBreaks(const S: string): string;
begin
  // need to replace DOS line ends with LF to start with so as not to replace
  // CRLF twice
  Result := ReplaceStr(S, #13#10, #10);
  Result := ReplaceStr(Result, #13, #10);
  Result := ReplaceStr(Result, #10, #13#10);
end;

end.

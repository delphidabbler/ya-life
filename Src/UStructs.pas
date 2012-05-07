unit UStructs;

interface

uses
  Types;

type
  TSizeEx = record
  public
    CX: Integer;
    CY: Integer;
    constructor Create(ACX, ACY: Integer);
    class operator Implicit(S: TSize): TSizeEx;
    class operator Implicit(S: TSizeEx): TSize;
    class operator Equal(S1, S2: TSizeEx): Boolean;
    class operator NotEqual(S1, S2: TSizeEx): Boolean;
    function IsZero: Boolean;
  end;

implementation

{ TSizeEx }

constructor TSizeEx.Create(ACX, ACY: Integer);
begin
  CX := ACX;
  CY := ACY;
end;

class operator TSizeEx.Equal(S1, S2: TSizeEx): Boolean;
begin
  // zero records are special: can be zero when only one of CX or CY is zero
  if S1.IsZero and S2.IsZero then
    Exit(True);
  Result := (S1.CX = S1.CX) and (S1.CY = S2.CY);
end;

class operator TSizeEx.Implicit(S: TSize): TSizeEx;
begin
  Result.CX := S.cx;
  Result.CY := S.cy;
end;

class operator TSizeEx.Implicit(S: TSizeEx): TSize;
begin
  Result.cx := S.CX;
  Result.cy := S.CY;
end;

function TSizeEx.IsZero: Boolean;
begin
  Result := (CX = 0) or (CY = 0);
end;

class operator TSizeEx.NotEqual(S1, S2: TSizeEx): Boolean;
begin
  Result := not (S1 = S2);
end;

end.

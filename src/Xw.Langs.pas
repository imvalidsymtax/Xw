unit Xw.Langs;

interface

uses
  System.Generics.Collections,
  Xw.Contracts;

type
  TXwLangBase = class abstract(TInterfacedObject, IXwLang)
    strict private
      FLetters: string;
      FMinChar, FMaxChar: Word;
      FIndexMap: TArray<SmallInt>;
    protected
      procedure RegisterVariants(const AMap: TDictionary<Char, Integer>); virtual;
      function GetMinLength: Integer; virtual;
      function GetMaxLength: Integer; virtual;
      function GetName: string; virtual; abstract;
    public
      constructor Create(const ALetters: string);
      function GetLetterCount: Integer;
      function LetterAt(const AIndex: Integer): Char;
      function IndexOf(const ALetter: Char): Integer;
      function Normalize(const AWord: string): string; overload; virtual;
      function Normalize(const ALetter: Char): Char; overload; virtual;
      function IsValid(const AWord: string; out AMessage: string): Boolean; virtual;
      function TryPrepare(const ARaw: string; out AWord, AMessage: string): Boolean;
  end;

  TXwLangPL = class(TXwLangBase)
    strict private const
      CNAME    = 'PL';
      CLETTERS = 'AĄBCĆDEĘFGHIJKLŁMNŃOÓPQRSŚTUVWXYZŹŻ';
    strict private
      FDiacritics: Boolean;
    protected
      function GetName: string; override;
      procedure RegisterVariants(const AMap: TDictionary<Char, Integer>); override;
    public
      constructor Create(const ADiacritics: Boolean = True);
  end;

implementation

uses
  System.SysUtils, System.Character;

constructor TXwLangBase.Create(const ALetters: string);
var
  LMap: TDictionary<Char, Integer>;
  LPair: TPair<Char, Integer>;
  I: Integer;
begin
  inherited Create;
  Assert(ALetters <> '', 'TXwLangBase.Create: pusty alfabet');
  FLetters := ALetters;

  LMap := TDictionary<Char, Integer>.Create;
  try
    for I := 1 to Length(FLetters) do
    begin
      LMap.AddOrSetValue(FLetters[I], I - 1);
      LMap.AddOrSetValue(FLetters[I].ToLower, I - 1);
    end;
    RegisterVariants(LMap);

    FMinChar := High(Word);
    FMaxChar := 0;
    for LPair in LMap do
    begin
      if Ord(LPair.Key) < FMinChar then FMinChar := Ord(LPair.Key);
      if Ord(LPair.Key) > FMaxChar then FMaxChar := Ord(LPair.Key);
    end;

    SetLength(FIndexMap, FMaxChar - FMinChar + 1);
    for I := 0 to High(FIndexMap) do
      FIndexMap[I] := -1;
    for LPair in LMap do
      FIndexMap[Ord(LPair.Key) - FMinChar] := LPair.Value;
  finally
    LMap.Free;
  end;
end;

function TXwLangBase.IndexOf(const ALetter: Char): Integer;
var
  LOrd: Word;
begin
  LOrd := Ord(ALetter);
  if (LOrd < FMinChar) or (LOrd > FMaxChar) then
    Exit(-1);
  Result := FIndexMap[LOrd - FMinChar];
end;

function TXwLangBase.Normalize(const ALetter: Char): Char;
var
  LIndex: Integer;
begin
  LIndex := IndexOf(ALetter);
  if LIndex < 0 then
    Exit(ALetter);
  Result := FLetters[LIndex + 1];
end;

procedure TXwLangBase.RegisterVariants(const AMap: TDictionary<Char, Integer>);
begin
end;

function TXwLangBase.Normalize(const AWord: string): string;
var
  I: Integer;
begin
  Result := AWord.Trim
    .Replace(' ', '', [rfReplaceAll])
    .Replace('-', '', [rfReplaceAll]);
  for I := 1 to Length(Result) do
    Result[I] := Normalize(Result[I]);
end;

function TXwLangBase.IsValid(const AWord: string; out AMessage: string): Boolean;
var
  LChar: Char;
begin
  AMessage := '';
  if (Length(AWord) < GetMinLength) or (Length(AWord) > GetMaxLength) then
  begin
    AMessage := Format('Fraza "%s": długość poza zakresem %d..%d.',
      [AWord, GetMinLength, GetMaxLength]);
    Exit(False);
  end;
  for LChar in AWord do
    if IndexOf(LChar) < 0 then
    begin
      AMessage := Format('Fraza "%s": niedozwolony znak "%s".', [AWord, LChar]);
      Exit(False);
    end;
  Result := True;
end;

function TXwLangBase.GetLetterCount: Integer;
begin
  Result := Length(FLetters);
end;

function TXwLangBase.LetterAt(const AIndex: Integer): Char;
begin
  if (AIndex < 0) or (AIndex >= Length(FLetters)) then
    raise EXwError.CreateFmt(
      'TXwLangBase.LetterAt: Out of bounds [0..%d]', [Length(FLetters) - 1]);
  Result := FLetters[AIndex + 1];
end;

function TXwLangBase.GetMinLength: Integer;
begin
  Result := 2;
end;

function TXwLangBase.GetMaxLength: Integer;
begin
  Result := 30;
end;

function TXwLangBase.TryPrepare(const ARaw: string; out AWord, AMessage: string): Boolean;
begin
  AWord := Normalize(ARaw);
  Result := IsValid(AWord, AMessage);
end;

function TXwLangPL.GetName: string;
begin
  Result := CNAME;
end;

constructor TXwLangPL.Create(const ADiacritics: Boolean = True);
begin
  FDiacritics := ADiacritics;
  inherited Create(CLETTERS);
end;

procedure TXwLangPL.RegisterVariants(const AMap: TDictionary<Char, Integer>);
const
  CDIACRITICS = 'ĄĆĘŁŃÓŚŹŻ';
  CBASE       = 'ACELNOSZZ';
var
  I, LOrd: Integer;
begin
  inherited;

  if FDiacritics then Exit;

  for I := 1 to Length(CDIACRITICS) do
  begin
    if not AMap.TryGetValue(CBASE[I], LOrd) then
      raise EXwError.CreateFmt(
        'TXwLangPL: brak litery bazowej "%s" w alfabecie', [CBASE[I]]);

    AMap.AddOrSetValue(CDIACRITICS[I], LOrd);
    AMap.AddOrSetValue(CDIACRITICS[I].ToLower, LOrd);
  end;
end;

end.

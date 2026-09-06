unit Xw.Word;

interface

uses
  Xw.Contracts;

type
  TXwWord = class(TInterfacedObject, IXwWord)

    strict private type

      TXwWordLetters = TArray<IXwLetter>;

    strict private
      FLength: Integer;

      FDescription: string;
      FWord: string;

      FLetters: TXwWordLetters;

      FCrossed: TXwWordLetters;

      FGuessed: Boolean;
      FCheck: Boolean;
    public
      constructor Create(const AWord, ADescription: string);

      function IsGuessed: Boolean;
      procedure CrossAt(const APosition: Integer; const ALetter: IXwLetter);

      function GetDescription: string;
      function GetWord: string;
      function GetLength: Integer;
      function GetLetter(const APosition: Integer): IXwLetter; inline;

      procedure Rebuild;
      procedure Reset;
  end;

  TXwWordFactory = class(TInterfacedObject, IXwWordFactory)
    private
      FLang: IXwLang;
    public
      constructor Create(const ALang: IXwLang);
      function CreateWord(const AWord, ADescription: string): IXwWord;
  end;

implementation

uses
  Xw.Letter;

{ TXwWord }

constructor TXwWord.Create(const AWord, ADescription: string);
var
  I: Integer;
begin
  FWord := AWord;
  FDescription := ADescription;

  FLength := Length(FWord);

  FGuessed := False;
  FCheck := False;

  SetLength(FLetters, FLength);
  SetLength(FCrossed, FLength);

  for I := 0 to FLength - 1 do begin
    FLetters[I] := TXwLetter.Create(FWord[I+1], procedure begin FCheck := True end);
  end;
end;

procedure TXwWord.CrossAt(const APosition: Integer; const ALetter: IXwLetter);
var
  LLeft, LRight: Char;
begin
  if (APosition < 1) or (APosition > FLength) then
    raise EXwError.CreateFmt('TXwWord.CrossAt: Out of bounds [1..%d]', [FLength]);

  LLeft := GetLetter(APosition).Original;
  LRight := ALetter.Original;
  if LLeft <> LRight then
    raise EXwError.CreateFmt('TXwWord.CrossAt: Cannot cross with different letters: %s x %s', [LLeft, LRight]);

  // zapisuje podmienian¹ literke
  FCrossed[APosition-1] := GetLetter(APosition);
  FLetters[APosition-1] := ALetter;
end;

function TXwWord.GetDescription: string;
begin
  Result := FDescription;
end;

function TXwWord.GetLength: Integer;
begin
  Result := FLength;
end;

function TXwWord.GetLetter(const APosition: Integer): IXwLetter;
begin
  if (APosition < 1) or (APosition > FLength) then
    raise EXwError.CreateFmt('TXwWord.GetLetter: Out of bounds [1..%d]', [FLength]);
  Result := FLetters[APosition - 1];
end;

function TXwWord.GetWord: string;
begin
  Result := FWord;
end;

function TXwWord.IsGuessed: Boolean;
var
  I: Integer;
begin
  if not FCheck then Exit(FGuessed);
  FCheck := False;

  Result := False;
  FGuessed := False;

  for I := 0 to FLength - 1 do begin
    if not FLetters[I].IsGuessed then Exit;
  end;

  FGuessed := True;
  Result := FGuessed;
end;

procedure TXwWord.Rebuild;
var
  I: Integer;
begin
  FGuessed := False;
  FCheck := False;

  for I := 0 to FLength -1 do begin
    if FCrossed[I] <> nil then
      FLetters[I] := FCrossed[I];
    FLetters[I].Rebuild;
  end;
end;

procedure TXwWord.Reset;
var
  I: Integer;
begin
  FGuessed := False;
  FCheck := False;

  for I := 0 to FLength - 1 do
    FLetters[I].Reset;
end;

{ TXwWordFactory }

constructor TXwWordFactory.Create(const ALang: IXwLang);
begin
  FLang := ALang;
end;

function TXwWordFactory.CreateWord(const AWord, ADescription: string): IXwWord;
var
  Normalized, ErrorMsg: string;
begin
  Normalized := FLang.Normalize(AWord);
  if not FLang.IsValid(Normalized, ErrorMsg) then
    raise EXwError.Create(ErrorMsg);
  Result := TXwWord.Create(Normalized, ADescription);
end;

end.

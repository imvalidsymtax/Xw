unit Xw.Anchors;

interface

uses
  System.Generics.Collections, Xw.Contracts;

type
  TXwAnchorIndex = class
  strict private
    FLang: IXwLang;
    FBuckets: TArray<TArray<Integer>>;
    FCounts: TArray<Integer>;
  public
    constructor Create(const ALang: IXwLang);

    procedure Add(const ALetter: Char; const AGridIndex: Integer);

    function SlotOf(const ALetter: Char): Integer; inline;
    function CountAt(const ASlot: Integer): Integer; inline;
    function GridAt(const ASlot, AIndex: Integer): Integer; inline;
    procedure DropAt(const ASlot, AIndex: Integer); inline;

    function CountOf(const ALetter: Char): Integer;
    function PositionAt(const ALetter: Char; const AIndex: Integer): Integer;
    procedure RemoveAt(const ALetter: Char; const AIndex: Integer);

    function TotalCount: Integer;
    procedure Clear;
  end;

implementation

uses
  System.SysUtils;

constructor TXwAnchorIndex.Create(const ALang: IXwLang);
begin
  inherited Create;
  FLang := ALang;
  SetLength(FBuckets, FLang.LetterCount);
  SetLength(FCounts, FLang.LetterCount);
end;

function TXwAnchorIndex.SlotOf(const ALetter: Char): Integer;
begin
  Result := FLang.IndexOf(ALetter);
  if Result < 0 then
    raise EXwError.CreateFmt(
      'TXwAnchorIndex: character "%s" out of alphabet %s', [ALetter, FLang.Name]);
end;

procedure TXwAnchorIndex.Add(const ALetter: Char; const AGridIndex: Integer);
var
  LSlot: Integer;
begin
  LSlot := SlotOf(ALetter);
  if FCounts[LSlot] = Length(FBuckets[LSlot]) then
    if FCounts[LSlot] = 0 then
      SetLength(FBuckets[LSlot], 8)
    else
      SetLength(FBuckets[LSlot], FCounts[LSlot] * 2);

  FBuckets[LSlot][FCounts[LSlot]] := AGridIndex;
  Inc(FCounts[LSlot]);
end;

function TXwAnchorIndex.CountAt(const ASlot: Integer): Integer;
begin
  Result := FCounts[ASlot];
end;

function TXwAnchorIndex.GridAt(const ASlot, AIndex: Integer): Integer;
begin
  Result := FBuckets[ASlot][AIndex];
end;

procedure TXwAnchorIndex.DropAt(const ASlot, AIndex: Integer);
begin
  Dec(FCounts[ASlot]);
  FBuckets[ASlot][AIndex] := FBuckets[ASlot][FCounts[ASlot]];
end;

function TXwAnchorIndex.CountOf(const ALetter: Char): Integer;
begin
  Result := FCounts[SlotOf(ALetter)];
end;

function TXwAnchorIndex.PositionAt(const ALetter: Char; const AIndex: Integer): Integer;
var
  LSlot: Integer;
begin
  LSlot := SlotOf(ALetter);
  if (AIndex < 0) or (AIndex >= FCounts[LSlot]) then
    raise EXwError.CreateFmt('TXwAnchorIndex.PositionAt: Out of bounds [0..%d]',
      [FCounts[LSlot] - 1]);
  Result := FBuckets[LSlot][AIndex];
end;

procedure TXwAnchorIndex.RemoveAt(const ALetter: Char; const AIndex: Integer);
var
  LSlot: Integer;
begin
  LSlot := SlotOf(ALetter);
  if (AIndex < 0) or (AIndex >= FCounts[LSlot]) then
    raise EXwError.CreateFmt('TXwAnchorIndex.RemoveAt: Out of bounds [0..%d]',
      [FCounts[LSlot] - 1]);
  DropAt(LSlot, AIndex);
end;

function TXwAnchorIndex.TotalCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(FCounts) do
    Inc(Result, FCounts[I]);
end;

procedure TXwAnchorIndex.Clear;
var
  I: Integer;
begin
  for I := 0 to High(FCounts) do
    FCounts[I] := 0;
end;

end.

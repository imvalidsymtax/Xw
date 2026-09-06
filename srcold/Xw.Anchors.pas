unit Xw.Anchors;

interface

uses
  System.Generics.Collections, Xw.Contracts;

type
  TXwAnchorIndex = class
  strict private
    FLang: IXwLang;
    FBuckets: TArray<TList<Integer>>;
    FMarks: TArray<Integer>;
    function BucketOf(const ALetter: Char): TList<Integer>;
  public
    constructor Create(const ALang: IXwLang);
    destructor Destroy; override;

    procedure Add(const ALetter: Char; const AGridIndex: Integer);
    function Positions(const ALetter: Char): TList<Integer>;
    function CountOf(const ALetter: Char): Integer;

    procedure Mark;
    procedure Rollback;
    procedure Clear;
  end;

implementation

uses
  System.SysUtils;

constructor TXwAnchorIndex.Create(const ALang: IXwLang);
var
  I: Integer;
begin
  inherited Create;
  FLang := ALang;
  SetLength(FBuckets, FLang.LetterCount);
  SetLength(FMarks, FLang.LetterCount);
  for I := 0 to High(FBuckets) do
    FBuckets[I] := TList<Integer>.Create;
end;

destructor TXwAnchorIndex.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(FBuckets) do
    FBuckets[I].Free;
  inherited;
end;

function TXwAnchorIndex.BucketOf(const ALetter: Char): TList<Integer>;
var
  LIndex: Integer;
begin
  LIndex := FLang.IndexOf(ALetter);
  if LIndex < 0 then
    raise EXwError.CreateFmt(
      'TXwAnchorIndex: character "%s" out of alphabet %s', [ALetter, FLang.Name]);
  Result := FBuckets[LIndex];
end;

procedure TXwAnchorIndex.Add(const ALetter: Char; const AGridIndex: Integer);
begin
  BucketOf(ALetter).Add(AGridIndex);
end;

function TXwAnchorIndex.Positions(const ALetter: Char): TList<Integer>;
begin
  Result := BucketOf(ALetter);
end;

function TXwAnchorIndex.CountOf(const ALetter: Char): Integer;
begin
  Result := BucketOf(ALetter).Count;
end;

procedure TXwAnchorIndex.Mark;
var
  I: Integer;
begin
  for I := 0 to High(FBuckets) do
    FMarks[I] := FBuckets[I].Count;
end;

procedure TXwAnchorIndex.Rollback;
var
  I: Integer;
begin
  for I := 0 to High(FBuckets) do
    FBuckets[I].Count := FMarks[I];
end;

procedure TXwAnchorIndex.Clear;
var
  I: Integer;
begin
  for I := 0 to High(FBuckets) do
  begin
    FBuckets[I].Clear;
    FMarks[I] := 0;
  end;
end;

end.

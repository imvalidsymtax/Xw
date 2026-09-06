unit Xw.Anchors;

interface

uses
  System.Generics.Collections, Xw.Contracts;

type
  TXwAnchorIndex = class
  strict private
    FLang: IXwLang;
    FBuckets: TArray<TList<Integer>>;
    function BucketOf(const ALetter: Char): TList<Integer>; inline;
  public
    constructor Create(const ALang: IXwLang);
    destructor Destroy; override;

    procedure Add(const ALetter: Char; const AGridIndex: Integer);
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
var
  I: Integer;
begin
  inherited Create;
  FLang := ALang;
  SetLength(FBuckets, FLang.LetterCount);
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

function TXwAnchorIndex.CountOf(const ALetter: Char): Integer;
begin
  Result := BucketOf(ALetter).Count;
end;

function TXwAnchorIndex.PositionAt(const ALetter: Char; const AIndex: Integer): Integer;
begin
  Result := BucketOf(ALetter)[AIndex];
end;

procedure TXwAnchorIndex.RemoveAt(const ALetter: Char; const AIndex: Integer);
var
  LBucket: TList<Integer>;
  LLast: Integer;
begin
  LBucket := BucketOf(ALetter);
  LLast := LBucket.Count - 1;
  if (AIndex < 0) or (AIndex > LLast) then
    raise EXwError.CreateFmt('TXwAnchorIndex.RemoveAt: Out of bounds [0..%d]', [LLast]);
  LBucket[AIndex] := LBucket[LLast];
  LBucket.Count := LLast;
end;

function TXwAnchorIndex.TotalCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(FBuckets) do
    Inc(Result, FBuckets[I].Count);
end;

procedure TXwAnchorIndex.Clear;
var
  I: Integer;
begin
  for I := 0 to High(FBuckets) do
    FBuckets[I].Clear;
end;

end.

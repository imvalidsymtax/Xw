unit Xw.Grid;

{$B-}

interface

type

  TXwFreeValueProc<T> = reference to procedure(var AValue: T);

  TXwCellCharFunc<T> = reference to function(const AValue: T; const H, V: Integer; var CDLeft, CDRight: Char): Char;

  TXwGrid<T> = class
    strict private
      FData: TArray<T>;
      FHSize: Integer;
      FVSize: Integer;
      FFlatSize: Integer;
      FOwnsValues: Boolean;
      FOnFreeValue: TXwFreeValueProc<T>;
      function GetCell(const H, V: Integer): T; inline;
      procedure SetCell(const H, V: Integer; const Value: T);
      procedure FreeValue(var AValue: T);
      function GetFlat(const AIndex: Integer): T; inline;
      procedure SetFlat(const AIndex: Integer; const Value: T); inline;
    public
      constructor Create(const AHSize, AVSize: Integer;
        const AOwnsValues: Boolean = False;
        const AOnFreeValue: TXwFreeValueProc<T> = nil);
      destructor Destroy; override;
      procedure Clear;
      procedure FreeCell(const H, V: Integer);
      function Extract(const H, V: Integer): T;
      function IndexOf(const H, V: Integer): Integer; inline;
      procedure CoordsOf(const Index: Integer; out H, V: Integer); inline;
      function InBounds(const H, V: Integer): Boolean; inline;
      function FlatInBounds(const AIndex: Integer): Boolean; inline;
      property Cells[const H, V: Integer]: T read GetCell write SetCell; default;
      property Flat[const AIndex: Integer]: T read GetFlat write SetFlat;
      property HSize: Integer read FHSize;
      property VSize: Integer read FVSize;
      property FlatSize: Integer read FFlatSize;
      property OwnsValues: Boolean read FOwnsValues write FOwnsValues;
      property OnFreeValue: TXwFreeValueProc<T> read FOnFreeValue write FOnFreeValue;
      function IsOccupied(const AIndex: Integer): Boolean; inline;
      procedure Dump(const AGetChar: TXwCellCharFunc<T> = nil);
  end;

  PObject = ^TObject;

implementation

uses
  System.SysUtils;

constructor TXwGrid<T>.Create(const AHSize, AVSize: Integer;
  const AOwnsValues: Boolean; const AOnFreeValue: TXwFreeValueProc<T>);
begin
  inherited Create;
  if (AHSize <= 0) or (AVSize <= 0) then
    raise EArgumentOutOfRangeException.Create('TXwGrid: size must be a positive number');
  FHSize := AHSize;
  FVSize := AVSize;
  FFlatSize := FHSize * FVSize;
  FOwnsValues := AOwnsValues;
  FOnFreeValue := AOnFreeValue;
  SetLength(FData, FFlatSize);
end;

destructor TXwGrid<T>.Destroy;
begin
  if FOwnsValues then
    Clear;
  inherited;
end;

procedure TXwGrid<T>.Dump(const AGetChar: TXwCellCharFunc<T>);
var
  H, V: Integer;
  LChar, CDLeft, CDRight: Char;
  LLine: string;
begin
  for V := 0 to FVSize - 1 do
  begin
    LLine := '';
    for H := 0 to FHSize - 1 do
    begin
      CDLeft := '[';
      CDRight := ']';
      if Assigned(AGetChar) then
        LChar := AGetChar(FData[V * FHSize + H], H, V, CDLeft, CDRight)
      else
        LChar := ' ';

      if LLine <> '' then
        LLine := LLine + ' ';
      LLine := LLine + CDLeft + LChar + CDRight;
    end;
    Writeln(LLine);
  end;
end;

procedure TXwGrid<T>.FreeValue(var AValue: T);
begin
  if Assigned(FOnFreeValue) then
    FOnFreeValue(AValue)
  else if GetTypeKind(T) = tkClass then
    PObject(@AValue)^.Free
  else
    raise EInvalidOpException.Create(
      'TXwGrid: OwnsValues=True needs OnFreeValue for non-class types');
  AValue := Default(T);
end;

procedure TXwGrid<T>.Clear;
var
  I: Integer;
begin
  for I := 0 to High(FData) do
  begin
    if FOwnsValues and (PPointer(@FData[I])^ <> nil) then
      FreeValue(FData[I])
    else
      FData[I] := Default(T);
  end;
end;

function TXwGrid<T>.IndexOf(const H, V: Integer): Integer;
begin
  Result := V * FHSize + H;
end;

function TXwGrid<T>.IsOccupied(const AIndex: Integer): Boolean;
begin
  Result := (Cardinal(AIndex) < Cardinal(FFlatSize))
    and (PPointer(@FData[AIndex])^ <> nil);
end;

procedure TXwGrid<T>.CoordsOf(const Index: Integer; out H, V: Integer);
begin
  H := Index mod FHSize;
  V := Index div FHSize;
end;

function TXwGrid<T>.InBounds(const H, V: Integer): Boolean;
begin
  Result := (Cardinal(H) < Cardinal(FHSize)) and (Cardinal(V) < Cardinal(FVSize));
end;

function TXwGrid<T>.FlatInBounds(const AIndex: Integer): Boolean;
begin
  Result := Cardinal(AIndex) < Cardinal(FFlatSize);
end;

function TXwGrid<T>.GetCell(const H, V: Integer): T;
begin
  {$IFOPT R+}
  if not InBounds(H, V) then
    raise ERangeError.CreateFmt('TXwGrid.GetCell: (%d, %d) out of bounds', [H, V]);
  {$ENDIF}
  Result := FData[V * FHSize + H];
end;

function TXwGrid<T>.GetFlat(const AIndex: Integer): T;
begin
  {$IFOPT R+}
  if not FlatInBounds(AIndex) then
    raise ERangeError.CreateFmt('TXwGrid.GetFlat: %d out of bounds [0..%d]', [AIndex, FFlatSize - 1]);
  {$ENDIF}
  Result := FData[AIndex];
end;

procedure TXwGrid<T>.SetFlat(const AIndex: Integer; const Value: T);
begin
  {$IFOPT R+}
  if not FlatInBounds(AIndex) then
    raise ERangeError.CreateFmt('TXwGrid.SetFlat: %d out of bounds [0..%d]', [AIndex, FFlatSize - 1]);
  {$ENDIF}
  FData[AIndex] := Value;
end;

procedure TXwGrid<T>.FreeCell(const H, V: Integer);
var
  Idx: Integer;
begin
  if not InBounds(H, V) then
    raise ERangeError.CreateFmt('TXwGrid.FreeCell: (%d, %d) out of bounds', [H, V]);
  Idx := V * FHSize + H;
  if PPointer(@FData[Idx])^ <> nil then
    FreeValue(FData[Idx]);
end;

function TXwGrid<T>.Extract(const H, V: Integer): T;
var
  Idx: Integer;
begin
  if not InBounds(H, V) then
    raise ERangeError.CreateFmt('TXwGrid.Extract: (%d, %d) out of bounds', [H, V]);
  Idx := V * FHSize + H;
  Result := FData[Idx];
  FData[Idx] := Default(T);
end;

procedure TXwGrid<T>.SetCell(const H, V: Integer; const Value: T);
var
  Idx: Integer;
begin
  {$IFOPT R+}
  if not InBounds(H, V) then
    raise ERangeError.CreateFmt('TXwGrid.SetCell: (%d, %d) out of bounds', [H, V]);
  {$ENDIF}
  Idx := V * FHSize + H;
  if FOwnsValues and (PPointer(@FData[Idx])^ <> nil)
    and (PPointer(@FData[Idx])^ <> PPointer(@Value)^) then
    FreeValue(FData[Idx]);
  FData[Idx] := Value;
end;

end.

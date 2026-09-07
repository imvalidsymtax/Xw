unit Xw.Present;

interface

uses
  Xw.Contracts;

type

  TXwPrintCell = record
    H, V: Integer;
    Letter: Char;
    Number: Integer;
    SolutionOrder: Integer;
    Crossed: Boolean;
  end;

  TXwPrintEntry = record
    Number: Integer;
    Direction: TXwWordDirection;
    H, V: Integer;
    Text: string;
    Description: string;
    Length: Integer;
  end;

  TXwPrintBoard = record
    Width: Integer;
    Height: Integer;
    Cells: TArray<TXwPrintCell>;
    Entries: TArray<TXwPrintEntry>;
    Solution: string;
  end;

  IXwPlayCell = interface
    ['{2C9A1B44-5E70-4C1E-9F2A-1D6B0A7C4E31}']
    function GetH: Integer;
    function GetV: Integer;
    function GetNumber: Integer;
    function GetSolutionOrder: Integer;
    function GetGuess: Char;
    procedure SetGuess(const AValue: Char);

    function IsFilled: Boolean;
    function IsHinted: Boolean;
    function IsCrossed: Boolean;
    procedure ClearGuess;

    property H: Integer read GetH;
    property V: Integer read GetV;
    property Number: Integer read GetNumber;
    property SolutionOrder: Integer read GetSolutionOrder;
    property Guess: Char read GetGuess write SetGuess;
  end;

  IXwPlayEntry = interface
    ['{7F3D2E18-9A46-4B0C-8E15-3C2A6D9B4F70}']
    function GetNumber: Integer;
    function GetDirection: TXwWordDirection;
    function GetDescription: string;
    function GetLength: Integer;
    function GetCell(const AIndex: Integer): IXwPlayCell;

    function IsSolved: Boolean;
    function TryHint: Boolean;

    property Number: Integer read GetNumber;
    property Direction: TXwWordDirection read GetDirection;
    property Description: string read GetDescription;
    property Length: Integer read GetLength;
    property Cells[const AIndex: Integer]: IXwPlayCell read GetCell; default;
  end;

  IXwPlayBoard = interface
    ['{5B81C0A2-46DF-4E93-A7C8-2E0F5A1D3B69}']
    function GetWidth: Integer;
    function GetHeight: Integer;
    function CellAt(const AH, AV: Integer): IXwPlayCell;

    function GetEntryCount: Integer;
    function GetEntry(const AIndex: Integer): IXwPlayEntry;

    function GetSolution: string;
    function IsSolved: Boolean;

    function TryHint: Boolean;
    function GetHintsUsed: Integer;
    function GetHintsLeft: Integer;

    procedure Reset;

    property Width: Integer read GetWidth;
    property Height: Integer read GetHeight;
    property EntryCount: Integer read GetEntryCount;
    property Entries[const AIndex: Integer]: IXwPlayEntry read GetEntry;
    property Solution: string read GetSolution;
    property HintsUsed: Integer read GetHintsUsed;
    property HintsLeft: Integer read GetHintsLeft;
  end;

  TXwRenderMode = (
    rmLetters,
    rmBlank,
    rmNumbers,
    rmSolution
  );

function XwBuildPrint(const ABoard: IXwBoard): TXwPrintBoard;
function XwBuildPlay(const ABoard: IXwBoard; const AMaxHints: Integer): IXwPlayBoard;

function XwRenderBoard(const APrint: TXwPrintBoard;
  const AMode: TXwRenderMode = rmLetters): TArray<string>;
function XwRenderClues(const APrint: TXwPrintBoard): TArray<string>;
function XwRenderPlay(const APlay: IXwPlayBoard): TArray<string>;
function XwRenderPlayNumbered(const APlay: IXwPlayBoard): TArray<string>;
procedure XwWriteLines(const ALines: TArray<string>);

implementation

uses
  System.SysUtils,
  System.Character,
  System.Generics.Collections,
  System.Generics.Defaults;

type

  TXwPlayCell = class(TInterfacedObject, IXwPlayCell)
  strict private
    FLetter: IXwLetter;
    FLang: IXwLang;
    FH, FV: Integer;
    FNumber: Integer;
    FSolutionOrder: Integer;
    FCrossed: Boolean;
  public
    constructor Create(const ALetter: IXwLetter; const ALang: IXwLang;
      const AH, AV, ANumber, ASolutionOrder: Integer; const ACrossed: Boolean);

    function GetH: Integer;
    function GetV: Integer;
    function GetNumber: Integer;
    function GetSolutionOrder: Integer;
    function GetGuess: Char;
    procedure SetGuess(const AValue: Char);

    function IsFilled: Boolean;
    function IsHinted: Boolean;
    function IsCrossed: Boolean;
    procedure ClearGuess;

    procedure Reveal;
    procedure ForceClear;
    function CanHint: Boolean;
  end;

  TXwPlayBoard = class;

  TXwPlayEntry = class(TInterfacedObject, IXwPlayEntry)
  strict private
    FOwner: TXwPlayBoard;
    FWord: IXwWord;
    FNumber: Integer;
    FDirection: TXwWordDirection;
    FCells: TArray<IXwPlayCell>;
    FObjects: TArray<TXwPlayCell>;
  public
    constructor Create(const AOwner: TXwPlayBoard; const AWord: IXwWord;
      const ANumber: Integer; const ADirection: TXwWordDirection;
      const ACells: TArray<IXwPlayCell>; const AObjects: TArray<TXwPlayCell>);

    function GetNumber: Integer;
    function GetDirection: TXwWordDirection;
    function GetDescription: string;
    function GetLength: Integer;
    function GetCell(const AIndex: Integer): IXwPlayCell;

    function IsSolved: Boolean;
    function TryHint: Boolean;
  end;

  TXwPlayBoard = class(TInterfacedObject, IXwPlayBoard)
  strict private
    FWidth, FHeight: Integer;
    FGrid: TArray<Integer>;
    FCells: TArray<IXwPlayCell>;
    FObjects: TArray<TXwPlayCell>;
    FEntries: TArray<IXwPlayEntry>;
    FSolution: string;
    FMaxHints: Integer;
    FHintsUsed: Integer;
  public
    constructor Create(const ABoard: IXwBoard; const AMaxHints: Integer);

    function GetWidth: Integer;
    function GetHeight: Integer;
    function CellAt(const AH, AV: Integer): IXwPlayCell;

    function GetEntryCount: Integer;
    function GetEntry(const AIndex: Integer): IXwPlayEntry;

    function GetSolution: string;
    function IsSolved: Boolean;

    function TryHint: Boolean;
    function GetHintsUsed: Integer;
    function GetHintsLeft: Integer;

    procedure Reset;

    function TakeHint(const ACandidates: TArray<TXwPlayCell>): Boolean;
  end;

constructor TXwPlayCell.Create(const ALetter: IXwLetter; const ALang: IXwLang;
  const AH, AV, ANumber, ASolutionOrder: Integer; const ACrossed: Boolean);
begin
  inherited Create;
  FLetter := ALetter;
  FLang := ALang;
  FH := AH;
  FV := AV;
  FNumber := ANumber;
  FSolutionOrder := ASolutionOrder;
  FCrossed := ACrossed;
end;

function TXwPlayCell.GetH: Integer;
begin
  Result := FH;
end;

function TXwPlayCell.GetV: Integer;
begin
  Result := FV;
end;

function TXwPlayCell.GetNumber: Integer;
begin
  Result := FNumber;
end;

function TXwPlayCell.GetSolutionOrder: Integer;
begin
  Result := FSolutionOrder;
end;

function TXwPlayCell.GetGuess: Char;
begin
  Result := FLetter.Matched;
end;

procedure TXwPlayCell.SetGuess(const AValue: Char);
begin
  if FLetter.IsHinted then Exit;
  if AValue = #0 then
  begin
    FLetter.Reset;
    Exit;
  end;
  FLetter.Match(FLang.Normalize(AValue));
end;

procedure TXwPlayCell.ClearGuess;
begin
  if FLetter.IsHinted then Exit;
  FLetter.Reset;
end;

function TXwPlayCell.IsFilled: Boolean;
begin
  Result := FLetter.Matched <> #0;
end;

function TXwPlayCell.IsHinted: Boolean;
begin
  Result := FLetter.IsHinted;
end;

function TXwPlayCell.IsCrossed: Boolean;
begin
  Result := FCrossed;
end;

procedure TXwPlayCell.Reveal;
begin
  FLetter.Reveal;
end;

procedure TXwPlayCell.ForceClear;
begin
  FLetter.Reset;
end;

function TXwPlayCell.CanHint: Boolean;
begin
  Result := (FSolutionOrder = 0) and (FLetter.Matched = #0);
end;

constructor TXwPlayEntry.Create(const AOwner: TXwPlayBoard; const AWord: IXwWord;
  const ANumber: Integer; const ADirection: TXwWordDirection;
  const ACells: TArray<IXwPlayCell>; const AObjects: TArray<TXwPlayCell>);
begin
  inherited Create;
  FOwner := AOwner;
  FWord := AWord;
  FNumber := ANumber;
  FDirection := ADirection;
  FCells := ACells;
  FObjects := AObjects;
end;

function TXwPlayEntry.GetNumber: Integer;
begin
  Result := FNumber;
end;

function TXwPlayEntry.GetDirection: TXwWordDirection;
begin
  Result := FDirection;
end;

function TXwPlayEntry.GetDescription: string;
begin
  Result := FWord.Description;
end;

function TXwPlayEntry.GetLength: Integer;
begin
  Result := System.Length(FCells);
end;

function TXwPlayEntry.GetCell(const AIndex: Integer): IXwPlayCell;
begin
  if (AIndex < 0) or (AIndex >= System.Length(FCells)) then
    raise EXwError.CreateFmt('IXwPlayEntry: Out of bounds [0..%d]',
      [System.Length(FCells) - 1]);
  Result := FCells[AIndex];
end;

function TXwPlayEntry.IsSolved: Boolean;
begin
  Result := FWord.IsGuessed;
end;

function TXwPlayEntry.TryHint: Boolean;
begin
  Result := FOwner.TakeHint(FObjects);
end;

constructor TXwPlayBoard.Create(const ABoard: IXwBoard; const AMaxHints: Integer);
var
  LBounds: TXwBounds;
  LPlaced: TXwPlacedWord;
  LEntryCells: TArray<IXwPlayCell>;
  LEntryObjects: TArray<TXwPlayCell>;
  LCell: TXwPlayCell;
  I, K, H, V, LCount, LStepH, LStepV, LAt: Integer;
begin
  inherited Create;

  FMaxHints := AMaxHints;
  FHintsUsed := 0;
  FSolution := ABoard.Solution;

  LBounds := ABoard.Bounds;
  FWidth := LBounds.Width;
  FHeight := LBounds.Height;

  SetLength(FGrid, FWidth * FHeight);
  for I := 0 to High(FGrid) do
    FGrid[I] := -1;

  SetLength(FCells, FWidth * FHeight);
  SetLength(FObjects, FWidth * FHeight);
  LCount := 0;

  for V := LBounds.MinV to LBounds.MaxV do
    for H := LBounds.MinH to LBounds.MaxH do
    begin
      if ABoard.CellState(H, V) = 0 then Continue;

      LCell := TXwPlayCell.Create(
        ABoard.LetterAt(H, V),
        ABoard.Lang,
        H - LBounds.MinH,
        V - LBounds.MinV,
        ABoard.NumberAt(H, V),
        ABoard.SolutionAt(H, V),
        ABoard.CellState(H, V) = 3);

      FObjects[LCount] := LCell;
      FCells[LCount] := LCell;
      FGrid[(V - LBounds.MinV) * FWidth + (H - LBounds.MinH)] := LCount;
      Inc(LCount);
    end;

  SetLength(FCells, LCount);
  SetLength(FObjects, LCount);

  SetLength(FEntries, ABoard.WordCount);
  for I := 0 to ABoard.WordCount - 1 do
  begin
    LPlaced := ABoard.PlacedWords[I];

    if LPlaced.Placement.Direction = wdHorizontal then
    begin
      LStepH := 1;
      LStepV := 0;
    end
    else
    begin
      LStepH := 0;
      LStepV := 1;
    end;

    SetLength(LEntryCells, LPlaced.Word.Length);
    SetLength(LEntryObjects, LPlaced.Word.Length);

    H := LPlaced.Placement.H - LBounds.MinH;
    V := LPlaced.Placement.V - LBounds.MinV;

    for K := 0 to LPlaced.Word.Length - 1 do
    begin
      LAt := FGrid[V * FWidth + H];
      LEntryCells[K] := FCells[LAt];
      LEntryObjects[K] := FObjects[LAt];
      Inc(H, LStepH);
      Inc(V, LStepV);
    end;

    FEntries[I] := TXwPlayEntry.Create(Self, LPlaced.Word,
      ABoard.WordNumber(I), LPlaced.Placement.Direction,
      Copy(LEntryCells), Copy(LEntryObjects));
  end;
end;

function TXwPlayBoard.GetWidth: Integer;
begin
  Result := FWidth;
end;

function TXwPlayBoard.GetHeight: Integer;
begin
  Result := FHeight;
end;

function TXwPlayBoard.CellAt(const AH, AV: Integer): IXwPlayCell;
var
  LAt: Integer;
begin
  if (AH < 0) or (AV < 0) or (AH >= FWidth) or (AV >= FHeight) then
    Exit(nil);
  LAt := FGrid[AV * FWidth + AH];
  if LAt < 0 then
    Exit(nil);
  Result := FCells[LAt];
end;

function TXwPlayBoard.GetEntryCount: Integer;
begin
  Result := Length(FEntries);
end;

function TXwPlayBoard.GetEntry(const AIndex: Integer): IXwPlayEntry;
begin
  if (AIndex < 0) or (AIndex >= Length(FEntries)) then
    raise EXwError.CreateFmt('IXwPlayBoard: Out of bounds [0..%d]',
      [Length(FEntries) - 1]);
  Result := FEntries[AIndex];
end;

function TXwPlayBoard.GetSolution: string;
begin
  Result := FSolution;
end;

function TXwPlayBoard.IsSolved: Boolean;
var
  I: Integer;
begin
  for I := 0 to High(FEntries) do
    if not FEntries[I].IsSolved then
      Exit(False);
  Result := True;
end;

function TXwPlayBoard.GetHintsUsed: Integer;
begin
  Result := FHintsUsed;
end;

function TXwPlayBoard.GetHintsLeft: Integer;
begin
  Result := FMaxHints - FHintsUsed;
  if Result < 0 then Result := 0;
end;

function TXwPlayBoard.TakeHint(const ACandidates: TArray<TXwPlayCell>): Boolean;
var
  I: Integer;
  LPick: TXwPlayCell;
begin
  if FHintsUsed >= FMaxHints then Exit(False);

  LPick := nil;

  for I := 0 to High(ACandidates) do
    if ACandidates[I].CanHint and ACandidates[I].IsCrossed then
    begin
      LPick := ACandidates[I];
      Break;
    end;

  if LPick = nil then
    for I := 0 to High(ACandidates) do
      if ACandidates[I].CanHint then
      begin
        LPick := ACandidates[I];
        Break;
      end;

  if LPick = nil then Exit(False);

  LPick.Reveal;
  Inc(FHintsUsed);
  Result := True;
end;

function TXwPlayBoard.TryHint: Boolean;
begin
  Result := TakeHint(FObjects);
end;

procedure TXwPlayBoard.Reset;
var
  I: Integer;
begin
  for I := 0 to High(FObjects) do
    FObjects[I].ForceClear;
  FHintsUsed := 0;
end;

function XwBuildPrint(const ABoard: IXwBoard): TXwPrintBoard;
var
  LBounds: TXwBounds;
  LPlaced: TXwPlacedWord;
  I, H, V, LCount: Integer;
begin
  Result := Default(TXwPrintBoard);

  LBounds := ABoard.Bounds;
  Result.Width := LBounds.Width;
  Result.Height := LBounds.Height;
  Result.Solution := ABoard.Solution;

  SetLength(Result.Cells, Result.Width * Result.Height);
  LCount := 0;

  for V := LBounds.MinV to LBounds.MaxV do
    for H := LBounds.MinH to LBounds.MaxH do
    begin
      if ABoard.CellState(H, V) = 0 then Continue;

      Result.Cells[LCount].H := H - LBounds.MinH;
      Result.Cells[LCount].V := V - LBounds.MinV;
      Result.Cells[LCount].Letter := ABoard.CellChar(H, V);
      Result.Cells[LCount].Number := ABoard.NumberAt(H, V);
      Result.Cells[LCount].SolutionOrder := ABoard.SolutionAt(H, V);
      Result.Cells[LCount].Crossed := ABoard.CellState(H, V) = 3;
      Inc(LCount);
    end;

  SetLength(Result.Cells, LCount);

  SetLength(Result.Entries, ABoard.WordCount);
  for I := 0 to ABoard.WordCount - 1 do
  begin
    LPlaced := ABoard.PlacedWords[I];
    Result.Entries[I].Number := ABoard.WordNumber(I);
    Result.Entries[I].Direction := LPlaced.Placement.Direction;
    Result.Entries[I].H := LPlaced.Placement.H - LBounds.MinH;
    Result.Entries[I].V := LPlaced.Placement.V - LBounds.MinV;
    Result.Entries[I].Text := LPlaced.Word.Word;
    Result.Entries[I].Description := LPlaced.Word.Description;
    Result.Entries[I].Length := LPlaced.Word.Length;
  end;

  TArray.Sort<TXwPrintEntry>(Result.Entries,
    TComparer<TXwPrintEntry>.Construct(
      function(const L, R: TXwPrintEntry): Integer
      begin
        Result := L.Number - R.Number;
        if Result = 0 then
          Result := Ord(L.Direction) - Ord(R.Direction);
      end));
end;

function XwBuildPlay(const ABoard: IXwBoard; const AMaxHints: Integer): IXwPlayBoard;
begin
  Result := TXwPlayBoard.Create(ABoard, AMaxHints);
end;

function XwRenderBoard(const APrint: TXwPrintBoard;
  const AMode: TXwRenderMode): TArray<string>;
var
  LMap: TArray<Integer>;
  LCell: TXwPrintCell;
  LLine: string;
  I, H, V: Integer;
begin
  SetLength(Result, APrint.Height);
  if (APrint.Width = 0) or (APrint.Height = 0) then Exit;

  SetLength(LMap, APrint.Width * APrint.Height);
  for I := 0 to High(LMap) do
    LMap[I] := -1;
  for I := 0 to High(APrint.Cells) do
    LMap[APrint.Cells[I].V * APrint.Width + APrint.Cells[I].H] := I;

  for V := 0 to APrint.Height - 1 do
  begin
    LLine := '';
    for H := 0 to APrint.Width - 1 do
    begin
      I := LMap[V * APrint.Width + H];

      if I < 0 then
      begin
        LLine := LLine + '   ';
        Continue;
      end;

      LCell := APrint.Cells[I];
      case AMode of
        rmLetters:
          LLine := LLine + '  ' + LCell.Letter;
        rmBlank:
          LLine := LLine + '  .';
        rmNumbers:
          if LCell.Number > 0 then
            LLine := LLine + Format('%3d', [LCell.Number])
          else
            LLine := LLine + '  .';
        rmSolution:
          if LCell.SolutionOrder > 0 then
            LLine := LLine + Format('%3d', [LCell.SolutionOrder])
          else
            LLine := LLine + '  .';
      end;
    end;
    Result[V] := LLine;
  end;
end;

function XwRenderClues(const APrint: TXwPrintBoard): TArray<string>;
var
  LDir: TXwWordDirection;
  I, LCount: Integer;
begin
  SetLength(Result, System.Length(APrint.Entries) + 2);
  LCount := 0;

  for LDir := wdHorizontal to wdVertical do
  begin
    if LDir = wdHorizontal then
      Result[LCount] := 'POZIOMO'
    else
      Result[LCount] := 'PIONOWO';
    Inc(LCount);

    for I := 0 to High(APrint.Entries) do
      if APrint.Entries[I].Direction = LDir then
      begin
        Result[LCount] := Format('  %d. %s (%d)',
          [APrint.Entries[I].Number,
           APrint.Entries[I].Description,
           APrint.Entries[I].Length]);
        Inc(LCount);
      end;
  end;

  SetLength(Result, LCount);
end;

function XwRenderPlay(const APlay: IXwPlayBoard): TArray<string>;
var
  LCell: IXwPlayCell;
  LLine: string;
  H, V: Integer;
  LChar: Char;
begin
  SetLength(Result, APlay.Height);

  for V := 0 to APlay.Height - 1 do
  begin
    LLine := '';
    for H := 0 to APlay.Width - 1 do
    begin
      LCell := APlay.CellAt(H, V);

      if LCell = nil then
        LLine := LLine + '   '
      else if not LCell.IsFilled then
        LLine := LLine + '  .'
      else
      begin
        LChar := LCell.Guess;
        if LCell.IsHinted then
          LChar := LChar.ToLower;
        LLine := LLine + '  ' + LChar;
      end;
    end;
    Result[V] := LLine;
  end;
end;

function XwRenderPlayNumbered(const APlay: IXwPlayBoard): TArray<string>;
var
  LCell: IXwPlayCell;
  LLine, LNumber: string;
  H, V: Integer;
  LChar: Char;
begin
  SetLength(Result, APlay.Height);

  for V := 0 to APlay.Height - 1 do
  begin
    LLine := '';
    for H := 0 to APlay.Width - 1 do
    begin
      LCell := APlay.CellAt(H, V);

      if LCell = nil then
      begin
        LLine := LLine + '    ';
        Continue;
      end;

      if LCell.Number > 0 then
        LNumber := Format('%2d', [LCell.Number])
      else
        LNumber := '  ';

      if not LCell.IsFilled then
        LChar := '.'
      else if LCell.IsHinted then
        LChar := LCell.Guess.ToLower
      else
        LChar := LCell.Guess;

      LLine := LLine + LNumber + LChar + ' ';
    end;
    Result[V] := LLine;
  end;
end;

procedure XwWriteLines(const ALines: TArray<string>);
var
  I: Integer;
begin
  for I := 0 to High(ALines) do
    Writeln(ALines[I]);
end;

end.

unit Xw.Board;

{$B-}

interface

uses
  System.Generics.Collections,
  System.SysUtils,
  Xw.Anchors,
  Xw.Contracts,
  Xw.Grid;

type

  TXwBoard = class(TInterfacedObject, IXwBoard)
    strict private
      FWordCross: TList<Integer>;
      FCellWord: TArray<Integer>;

      FWords: TList<TXwPlacedWord>;
      FMatrix: TXwGrid<IXwLetter>;
      FAnchors: TXwAnchorIndex;
      FTouched: TList<Integer>;

      FOriginH: Integer;
      FOriginV: Integer;

      FDominantDirection: TXwWordDirection;
      FStrategy: TXwStrategy;

      FBounds: TXwBounds;
      FLetterCount: Integer;
      FCrossingCount: Integer;

      FWeightCrossing: Double;
      FWeightArea: Double;
      FWeightRescue: Double;

      FScoreCrossing: Double;
      FScoreWord: Double;
      FScoreDensity: Double;
      FScoreOrphan: Double;

      function GetHSize: Integer;
      function GetVSize: Integer;
      function GetOriginH: Integer;
      function GetOriginV: Integer;

      procedure ExpandBounds(const AH, AV: Integer); inline;
      function BoundsAfter(const AWord: IXwWord;
        const APlacement: TXwWordPlacement): TXwBounds;

      procedure PlaceWord(const AWord: IXwWord; const APlacement: TXwWordPlacement);
      function PlaceFirst(const AWord: IXwWord): Boolean;

      function CanPlaceWord(const AWord: IXwWord; var APlacement: TXwWordPlacement): Boolean;

      function EnumeratePlacements(const AWord: IXwWord): TArray<TXwWordPlacement>;
      function ScorePlacement(const AWord: IXwWord; const APlacement: TXwWordPlacement): Double;
      function ChoosePlacement(const AVariants: TArray<TXwWordPlacement>): Integer;

      function GetStrategy: TXwStrategy;
      procedure SetStrategy(const Value: TXwStrategy);
      function GetWeightRescue: Double;
      procedure SetWeightRescue(const Value: Double);

    public
      constructor Create(const AHSize, AVSize: Integer; const ALang: IXwLang);
      destructor Destroy; override;

      function TryPlaceWord(const AWord: IXwWord): Boolean;

      function SeedPlacement(const AWord: IXwWord; const ADirection: TXwWordDirection;
        out APlacement: TXwWordPlacement): Boolean;
      function Candidates(const AWord: IXwWord): TArray<TXwWordPlacement>;
      function Revalidate(const AWord: IXwWord; var APlacement: TXwWordPlacement): Boolean;
      function ScoreOf(const AWord: IXwWord; const APlacement: TXwWordPlacement): Double;
      procedure Commit(const AWord: IXwWord; const APlacement: TXwWordPlacement);

      function GetBounds: TXwBounds;
      function Evaluate: TXwBoardScore;

      procedure PrintToConsole(const ShowOriginal: Boolean = False);

      function GetPlacedWord(const AIndex: Integer): TXwPlacedWord;
      function GetWordCount: Integer;
      function IsOccupied(const AH, AV: Integer): Boolean;
      function LetterAt(const AH, AV: Integer): IXwLetter;

      function AnchorCount: Integer;

      property Strategy: TXwStrategy read GetStrategy write SetStrategy;
      property DominantDirection: TXwWordDirection
        read FDominantDirection write FDominantDirection;

      property OriginH: Integer read FOriginH;
      property OriginV: Integer read FOriginV;

      property WeightCrossing: Double read FWeightCrossing write FWeightCrossing;
      property WeightArea: Double read FWeightArea write FWeightArea;
      property WeightRescue: Double read GetWeightRescue write SetWeightRescue;
      property ScoreCrossing: Double read FScoreCrossing write FScoreCrossing;
      property ScoreWord: Double read FScoreWord write FScoreWord;
      property ScoreDensity: Double read FScoreDensity write FScoreDensity;
      property ScoreOrphan: Double read FScoreOrphan write FScoreOrphan;

      procedure Clear;
      procedure Reset;
  end;

implementation

uses
  System.Math;

const
  XW_MAX_RESCUE = 32;

constructor TXwBoard.Create(const AHSize, AVSize: Integer; const ALang: IXwLang);
var
  I: Integer;
begin
  inherited Create;

  FMatrix := TXwGrid<IXwLetter>.Create(AHSize, AVSize);

  FWords := TList<TXwPlacedWord>.Create;
  FWordCross := TList<Integer>.Create;

  SetLength(FCellWord, FMatrix.FlatSize);
  for I := 0 to High(FCellWord) do
    FCellWord[I] := -1;

  FTouched := TList<Integer>.Create;
  FAnchors := TXwAnchorIndex.Create(ALang);

  FOriginH := AHSize div 2;
  FOriginV := AVSize div 2;

  FDominantDirection := wdHorizontal;
  FStrategy := stBestScore;

  FBounds := TXwBounds.CreateEmpty;

  FLetterCount := 0;
  FCrossingCount := 0;

  FWeightCrossing := 10.0;
  FWeightArea     := 1.0;
  FWeightRescue   := 8.0;

  FScoreCrossing := 10.0;
  FScoreWord     := 5.0;
  FScoreDensity  := 100.0;
  FScoreOrphan   := 8.0;
end;

destructor TXwBoard.Destroy;
begin
  Clear;
  FMatrix.Free;
  FWords.Free;
  FWordCross.Free;
  FAnchors.Free;
  FTouched.Free;
  inherited;
end;

function TXwBoard.LetterAt(const AH, AV: Integer): IXwLetter;
begin
  if not FMatrix.InBounds(AH, AV) then
    Exit(nil);
  Result := FMatrix[AH, AV];
end;

function TXwBoard.IsOccupied(const AH, AV: Integer): Boolean;
begin
  Result := FMatrix.InBounds(AH, AV)
    and FMatrix.IsOccupied(FMatrix.IndexOf(AH, AV));
end;

function TXwBoard.GetWeightRescue: Double;
begin
  Result := FWeightRescue;
end;

function TXwBoard.GetWordCount: Integer;
begin
  Result := FWords.Count;
end;

function TXwBoard.AnchorCount: Integer;
begin
  Result := FAnchors.TotalCount;
end;

function TXwBoard.GetPlacedWord(const AIndex: Integer): TXwPlacedWord;
begin
  if (AIndex < 0) or (AIndex >= FWords.Count) then
    raise EXwError.CreateFmt(
      'TXwBoard.GetPlacedWord: Out of bounds [0..%d]', [FWords.Count - 1]);
  Result := FWords[AIndex];
end;

function TXwBoard.GetStrategy: TXwStrategy;
begin
  Result := FStrategy;
end;

function TXwBoard.GetBounds: TXwBounds;
begin
  Result := FBounds;
end;

function TXwBoard.GetHSize: Integer;
begin
  Result := FMatrix.HSize;
end;

function TXwBoard.GetVSize: Integer;
begin
  Result := FMatrix.VSize;
end;

function TXwBoard.GetOriginH: Integer;
begin
  Result := FOriginH;
end;

function TXwBoard.GetOriginV: Integer;
begin
  Result := FOriginV;
end;

function TXwBoard.CanPlaceWord(const AWord: IXwWord; var APlacement: TXwWordPlacement): Boolean;
var
  LStep, LPerp: Integer;
  LStart, LIdx, I, J: Integer;
  LHasBefore, LHasAfter: Boolean;
  LHasPerpLo, LHasPerpHi: Boolean;
  LCell: IXwLetter;
  LOwner: Integer;
  LRescued: array [0 .. XW_MAX_RESCUE - 1] of Integer;
  LRescuedCount: Integer;
  LKnown: Boolean;
  LRun: Integer;
begin
  APlacement.Rescue := 0;
  APlacement.Crossings := 0;
  APlacement.StartIndex := -1;
  APlacement.MaxRun := 0;
  APlacement.CrossMask := 0;
  APlacement.Score := 0;
  LRescuedCount := 0;
  LRun := 0;

  if AWord.Length < 2 then Exit(False);
  if (APlacement.H < 0) or (APlacement.V < 0)
    or (APlacement.H >= FMatrix.HSize) or (APlacement.V >= FMatrix.VSize) then
    Exit(False);

  if APlacement.Direction = wdHorizontal then
  begin
    if APlacement.H + AWord.Length > FMatrix.HSize then Exit(False);
    LStep := 1;
    LPerp := FMatrix.HSize;
    LHasBefore := APlacement.H > 0;
    LHasAfter  := APlacement.H + AWord.Length < FMatrix.HSize;
    LHasPerpLo := APlacement.V > 0;
    LHasPerpHi := APlacement.V < FMatrix.VSize - 1;
  end
  else
  begin
    if APlacement.V + AWord.Length > FMatrix.VSize then Exit(False);
    LStep := FMatrix.HSize;
    LPerp := 1;
    LHasBefore := APlacement.V > 0;
    LHasAfter  := APlacement.V + AWord.Length < FMatrix.VSize;
    LHasPerpLo := APlacement.H > 0;
    LHasPerpHi := APlacement.H < FMatrix.HSize - 1;
  end;

  LStart := APlacement.V * FMatrix.HSize + APlacement.H;
  APlacement.StartIndex := LStart;

  if LHasBefore and FMatrix.IsOccupied(LStart - LStep) then Exit(False);
  if LHasAfter and FMatrix.IsOccupied(LStart + LStep * AWord.Length) then Exit(False);

  LIdx := LStart;
  for I := 1 to AWord.Length do
  begin
    if FMatrix.IsOccupied(LIdx) then
    begin
      LCell := FMatrix.Flat[LIdx];
      if LCell.Original <> AWord.GetLetter(I).Original then Exit(False);
      if APlacement.Direction in LCell.UsedDirections then Exit(False);
      Inc(APlacement.Crossings);
      if I <= 32 then
        APlacement.CrossMask := APlacement.CrossMask or (UInt32(1) shl (I - 1));
      LRun := 0;

      LOwner := FCellWord[LIdx];
      if (LOwner >= 0) and (FWordCross[LOwner] <= 1) then
      begin
        LKnown := False;
        for J := 0 to LRescuedCount - 1 do
          if LRescued[J] = LOwner then
          begin
            LKnown := True;
            Break;
          end;
        if (not LKnown) and (LRescuedCount < XW_MAX_RESCUE) then
        begin
          LRescued[LRescuedCount] := LOwner;
          Inc(LRescuedCount);
          Inc(APlacement.Rescue);
        end;
      end;
    end
    else
    begin
      if LHasPerpLo and FMatrix.IsOccupied(LIdx - LPerp) then Exit(False);
      if LHasPerpHi and FMatrix.IsOccupied(LIdx + LPerp) then Exit(False);
      Inc(LRun);
      if LRun > APlacement.MaxRun then APlacement.MaxRun := LRun;
    end;

    Inc(LIdx, LStep);
  end;

  Result := APlacement.Crossings > 0;
end;

procedure TXwBoard.PrintToConsole(const ShowOriginal: Boolean);
begin
  FMatrix.Dump(
    function (const AValue: IXwLetter; const H, V: Integer; var CDLeft, CDRight: Char): Char
    begin
      if AValue = nil then
      begin
        Result := ' ';
        Exit;
      end;

      if ShowOriginal then
        Result := AValue.Original
      else
        Result := AValue.Matched;

      if AValue.IsFirst[wdHorizontal] and AValue.IsFirst[wdVertical] then
        CDRight := '/'
      else if AValue.IsFirst[wdHorizontal] then
        CDRight := '>'
      else if AValue.IsFirst[wdVertical] then
        CDRight := 'V';

      if Result = #0 then Result := '?';
    end
  );
end;

procedure TXwBoard.Clear;
var
  LWord: TXwPlacedWord;
  LIdx: Integer;
begin
  FBounds := TXwBounds.CreateEmpty;

  FLetterCount := 0;
  FCrossingCount := 0;

  for LWord in FWords do
    LWord.Word.Rebuild;

  FWords.Clear;
  FAnchors.Clear;
  FWordCross.Clear;

  for LIdx in FTouched do
  begin
    FMatrix.Flat[LIdx] := nil;
    FCellWord[LIdx] := -1;
  end;

  FTouched.Clear;
end;

procedure TXwBoard.Reset;
var
  LWord: TXwPlacedWord;
begin
  for LWord in FWords do
    LWord.Word.Reset;
end;

procedure TXwBoard.PlaceWord(const AWord: IXwWord; const APlacement: TXwWordPlacement);
var
  I, LIdx, LStep, LNewIndex, LOwner: Integer;
  LCell, LLetter: IXwLetter;
  LPlaced: TXwPlacedWord;
  LPosition: TXwLetterPosition;
begin
  case APlacement.Direction of
    wdHorizontal: LStep := 1;
    wdVertical:   LStep := FMatrix.HSize;
    else raise EXwError.Create('TXwBoard.PlaceWord: Unknown direction.');
  end;

  LNewIndex := FWords.Count;
  LIdx := FMatrix.IndexOf(APlacement.H, APlacement.V);

  for I := 1 to AWord.Length do
  begin
    if I = 1 then
      LPosition := lpFirst
    else if I = AWord.Length then
      LPosition := lpLast
    else
      LPosition := lpMiddle;

    LCell := FMatrix.Flat[LIdx];

    if LCell <> nil then
    begin
      AWord.CrossAt(I, LCell);
      LCell.AddDirection(APlacement.Direction, LPosition);

      LOwner := FCellWord[LIdx];
      if LOwner >= 0 then
      begin
        Assert(LOwner < LNewIndex, 'TXwBoard.PlaceWord: slowo krzyzuje samo siebie');
        FWordCross[LOwner] := FWordCross[LOwner] + 1;
      end;
    end
    else
    begin
      LLetter := AWord[I];
      FMatrix.Flat[LIdx] := LLetter;
      FAnchors.Add(LLetter.Original, LIdx);
      LLetter.AddDirection(APlacement.Direction, LPosition);
      FTouched.Add(LIdx);
      FCellWord[LIdx] := LNewIndex;
      Inc(FLetterCount);
    end;

    Inc(LIdx, LStep);
  end;

  Inc(FCrossingCount, APlacement.Crossings);
  ExpandBounds(APlacement.H, APlacement.V);
  case APlacement.Direction of
    wdHorizontal: ExpandBounds(APlacement.H + AWord.Length - 1, APlacement.V);
    wdVertical:   ExpandBounds(APlacement.H, APlacement.V + AWord.Length - 1);
  end;

  FWordCross.Add(APlacement.Crossings);
  LPlaced.Word := AWord;
  LPlaced.Placement := APlacement;
  FWords.Add(LPlaced);
end;

procedure TXwBoard.ExpandBounds(const AH, AV: Integer);
begin
  if AH < FBounds.MinH then FBounds.MinH := AH;
  if AH > FBounds.MaxH then FBounds.MaxH := AH;
  if AV < FBounds.MinV then FBounds.MinV := AV;
  if AV > FBounds.MaxV then FBounds.MaxV := AV;
end;

function TXwBoard.BoundsAfter(const AWord: IXwWord;
  const APlacement: TXwWordPlacement): TXwBounds;
var
  LEndH, LEndV: Integer;
begin
  LEndH := APlacement.H;
  LEndV := APlacement.V;
  case APlacement.Direction of
    wdHorizontal: Inc(LEndH, AWord.Length - 1);
    wdVertical:   Inc(LEndV, AWord.Length - 1);
  end;

  Result.MinH := Min(FBounds.MinH, APlacement.H);
  Result.MaxH := Max(FBounds.MaxH, LEndH);
  Result.MinV := Min(FBounds.MinV, APlacement.V);
  Result.MaxV := Max(FBounds.MaxV, LEndV);
end;

function TXwBoard.SeedPlacement(const AWord: IXwWord; const ADirection: TXwWordDirection;
  out APlacement: TXwWordPlacement): Boolean;
begin
  APlacement := Default(TXwWordPlacement);

  if (AWord.Length > FMatrix.HSize) and (AWord.Length > FMatrix.VSize) then
    Exit(False);

  APlacement.Direction := ADirection;
  if (APlacement.Direction = wdHorizontal) and (AWord.Length > FMatrix.HSize) then
    APlacement.Direction := wdVertical
  else if (APlacement.Direction = wdVertical) and (AWord.Length > FMatrix.VSize) then
    APlacement.Direction := wdHorizontal;

  case APlacement.Direction of
    wdHorizontal:
      begin
        APlacement.H := (FMatrix.HSize - AWord.Length) div 2;
        APlacement.V := FMatrix.VSize div 2;
      end;
    wdVertical:
      begin
        APlacement.H := FMatrix.HSize div 2;
        APlacement.V := (FMatrix.VSize - AWord.Length) div 2;
      end;
  end;

  APlacement.StartIndex := FMatrix.IndexOf(APlacement.H, APlacement.V);
  APlacement.Crossings  := 0;
  APlacement.Score      := 0;
  APlacement.Rescue     := 0;

  Result := True;
end;

function TXwBoard.PlaceFirst(const AWord: IXwWord): Boolean;
var
  LPlacement: TXwWordPlacement;
begin
  Result := SeedPlacement(AWord, FDominantDirection, LPlacement);
  if Result then
    PlaceWord(AWord, LPlacement);
end;

function TXwBoard.Candidates(const AWord: IXwWord): TArray<TXwWordPlacement>;
begin
  Result := EnumeratePlacements(AWord);
end;

function TXwBoard.Revalidate(const AWord: IXwWord; var APlacement: TXwWordPlacement): Boolean;
begin
  Result := CanPlaceWord(AWord, APlacement);
end;

function TXwBoard.ScoreOf(const AWord: IXwWord; const APlacement: TXwWordPlacement): Double;
begin
  Result := ScorePlacement(AWord, APlacement);
end;

procedure TXwBoard.Commit(const AWord: IXwWord; const APlacement: TXwWordPlacement);
begin
  PlaceWord(AWord, APlacement);
end;

function TXwBoard.EnumeratePlacements(const AWord: IXwWord): TArray<TXwWordPlacement>;
var
  LAnchor: IXwLetter;
  LLetter: Char;
  LPos, LSlot, LGrid, LCount, J: Integer;
  LPlacement: TXwWordPlacement;
  LDuplicate: Boolean;
begin
  SetLength(Result, 16);
  LCount := 0;

  for LPos := 1 to AWord.Length do
  begin
    LLetter := AWord.GetLetter(LPos).Original;
    LSlot := 0;
    while LSlot < FAnchors.CountOf(LLetter) do
    begin
      LGrid := FAnchors.PositionAt(LLetter, LSlot);
      LAnchor := FMatrix.Flat[LGrid];

      if not LAnchor.CanAnchor(LPlacement.Direction) then
      begin
        FAnchors.RemoveAt(LLetter, LSlot);
        Continue;
      end;

      FMatrix.CoordsOf(LGrid, LPlacement.H, LPlacement.V);

      case LPlacement.Direction of
        wdHorizontal: Dec(LPlacement.H, LPos - 1);
        wdVertical:   Dec(LPlacement.V, LPos - 1);
      end;

      if CanPlaceWord(AWord, LPlacement) then
      begin
        LDuplicate := False;
        for J := 0 to LCount - 1 do
          if (Result[J].StartIndex = LPlacement.StartIndex)
            and (Result[J].Direction = LPlacement.Direction) then
          begin
            LDuplicate := True;
            Break;
          end;

        if not LDuplicate then
        begin
          if LCount = Length(Result) then
            SetLength(Result, LCount * 2);
          Result[LCount] := LPlacement;
          Inc(LCount);
        end;
      end;

      Inc(LSlot);
    end;
  end;

  SetLength(Result, LCount);
end;

function TXwBoard.ScorePlacement(const AWord: IXwWord;
  const APlacement: TXwWordPlacement): Double;
var
  LDelta: Integer;
begin
  LDelta := BoundsAfter(AWord, APlacement).Area - FBounds.Area;
  if LDelta < 0 then LDelta := 0;

  Result := FWeightCrossing * APlacement.Crossings
          - FWeightArea * Sqrt(LDelta)
          + FWeightRescue * APlacement.Rescue;
end;

procedure TXwBoard.SetStrategy(const Value: TXwStrategy);
begin
  FStrategy := Value;
end;

procedure TXwBoard.SetWeightRescue(const Value: Double);
begin
  FWeightRescue := Value;
end;

function TXwBoard.ChoosePlacement(const AVariants: TArray<TXwWordPlacement>): Integer;
var
  I: Integer;
  LBest: Double;
begin
  Result := 0;
  if FStrategy = stFirstFit then Exit;

  LBest := AVariants[0].Score;
  for I := 1 to High(AVariants) do
    if AVariants[I].Score > LBest then
    begin
      LBest := AVariants[I].Score;
      Result := I;
    end;
end;

function TXwBoard.TryPlaceWord(const AWord: IXwWord): Boolean;
var
  LVariants: TArray<TXwWordPlacement>;
  I, LChoice: Integer;
begin
  if FWords.Count = 0 then Exit(PlaceFirst(AWord));

  LVariants := EnumeratePlacements(AWord);
  if Length(LVariants) = 0 then Exit(False);

  if FStrategy <> stFirstFit then
    for I := 0 to High(LVariants) do
      LVariants[I].Score := ScorePlacement(AWord, LVariants[I]);

  LChoice := ChoosePlacement(LVariants);
  PlaceWord(AWord, LVariants[LChoice]);
  Result := True;
end;

function TXwBoard.Evaluate: TXwBoardScore;
var
  LCross: Integer;
  {$IFOPT C+} LSum: Integer; {$ENDIF}
begin
  Result.Words     := FWords.Count;
  Result.Letters   := FLetterCount;
  Result.Crossings := FCrossingCount;
  Result.Area      := FBounds.Area;

  if Result.Area = 0 then
    Result.Density := 0
  else
    Result.Density := Result.Letters / Result.Area;

  Result.Orphans := 0;
  Result.MinCross := 0;
  {$IFOPT C+} LSum := 0; {$ENDIF}

  if FWordCross.Count > 0 then
  begin
    Result.MinCross := MaxInt;
    for LCross in FWordCross do
    begin
      if LCross <= 1 then Inc(Result.Orphans);
      if LCross < Result.MinCross then Result.MinCross := LCross;
      {$IFOPT C+} Inc(LSum, LCross); {$ENDIF}
    end;
  end;

  {$IFOPT C+}
  Assert(FWordCross.Count = FWords.Count,
    Format('FWordCross=%d <> FWords=%d', [FWordCross.Count, FWords.Count]));
  Assert(LSum = 2 * FCrossingCount,
    Format('suma FWordCross=%d <> 2*FCrossingCount=%d', [LSum, 2 * FCrossingCount]));
  {$ENDIF}

  if Result.Words > 0 then
    Result.AvgCross := 2.0 * Result.Crossings / Result.Words
  else
    Result.AvgCross := 0;

  Result.Total := Result.Crossings * FScoreCrossing
                + Result.Words     * FScoreWord
                + Result.Density   * FScoreDensity
                - Result.Orphans   * FScoreOrphan;
end;

end.

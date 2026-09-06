unit Xw.Generator;

interface

uses
  Xw.Board,
  Xw.Contracts,
  Xw.Metrics;

type

  TXwMove = record
    WordIndex: Integer;
    Placement: TXwWordPlacement;
  end;

  TXwScoreWeights = record
    Crossing: Double;
    Rescue: Double;
    Potential: Double;
    Growth: Double;
    Aspect: Double;
    Run: Double;
    TargetAspect: Double;

    class function Standard: TXwScoreWeights; static;
    class function Legacy: TXwScoreWeights; static;
  end;

  TXwGenOptions = record
    Seed: UInt64;
    MaxAttempts: Integer;
    TimeBudgetMs: Integer;
    ScoreSlack: Double;
    SeedWordPool: Integer;
    ArenaSide: Integer;
    RefineRounds: Integer;
    UseBoardScore: Boolean;
    Score: TXwScoreWeights;
    Weights: TXwMetricWeights;

    class function Standard: TXwGenOptions; static;
    class function Deterministic: TXwGenOptions; static;
  end;

  TXwGenResult = record
    Board: IXwBoard;
    Metrics: TXwMetrics;
    Attempts: Integer;
    Relocations: Integer;
    Enumerations: Int64;
    ElapsedMs: Double;
  end;

  TXwGenerator = class
  strict private
    FLang: IXwLang;
    FState: UInt64;
    FEnumerations: Int64;

    FWords: TArray<IXwWord>;
    FMasks: TArray<UInt64>;
    FMaskable: Boolean;
    FLetterIdx: TArray<TArray<Integer>>;
    FDistinct: TArray<TArray<Integer>>;
    FLetterNeed: TArray<Integer>;

    FPlaced: TArray<Boolean>;
    FDirty: TArray<Boolean>;
    FCands: TArray<TArray<TXwWordPlacement>>;

    function NextRandom: UInt64;
    function NextInt(const ABound: Integer): Integer;

    procedure BuildIndexes;
    procedure ResetNeed;
    procedure ConsumeNeed(const AWordIndex: Integer);
    procedure MarkDirty(const AWordIndex: Integer);

    function ScoreMove(const AWordIndex: Integer;
      const APlacement: TXwWordPlacement;
      const ABounds: TXwBounds;
      const AUnplaced, ARunLimit: Integer;
      const AWeights: TXwScoreWeights): Double;

    function ChooseSeedIndex(const APool: Integer): Integer;

    procedure Replay(const AImpl: TXwBoard; const AMoves: TArray<TXwMove>);
    function TryRelocate(const AImpl: TXwBoard; const ABoard: IXwBoard;
      var AMoves: TArray<TXwMove>; const APos: Integer;
      const AOptions: TXwGenOptions; var ABest: TXwMetrics): Boolean;
    function RefineBoard(const AImpl: TXwBoard; const ABoard: IXwBoard;
      var AMoves: TArray<TXwMove>; const AOptions: TXwGenOptions;
      var ABest: TXwMetrics): Integer;
  public
    constructor Create(const ALang: IXwLang);

    class function ArenaSideFor(const AWords: TArray<IXwWord>): Integer; static;

    function Generate(const AWords: TArray<IXwWord>;
      const AOptions: TXwGenOptions): TXwGenResult;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  System.Diagnostics;

class function TXwScoreWeights.Standard: TXwScoreWeights;
begin
  Result.Crossing     := 10.0;
  Result.Rescue       := 8.0;
  Result.Potential    := 1.5;
  Result.Growth       := 4.0;
  Result.Aspect       := 6.0;
  Result.Run          := 0.0;
  Result.TargetAspect := 1.0;
end;

class function TXwScoreWeights.Legacy: TXwScoreWeights;
begin
  Result := TXwScoreWeights.Standard;
  Result.Potential := 0.0;
  Result.Aspect    := 0.0;
  Result.Run       := 0.0;
  Result.Growth    := 1.0;
end;

class function TXwGenOptions.Standard: TXwGenOptions;
begin
  Result.Seed          := 20260904;
  Result.MaxAttempts   := 24;
  Result.TimeBudgetMs  := 0;
  Result.ScoreSlack    := 0.0;
  Result.SeedWordPool  := 12;
  Result.ArenaSide     := 0;
  Result.RefineRounds  := 4;
  Result.UseBoardScore := False;
  Result.Score         := TXwScoreWeights.Standard;
  Result.Weights       := TXwMetricWeights.Standard;
end;

class function TXwGenOptions.Deterministic: TXwGenOptions;
begin
  Result := TXwGenOptions.Standard;
  Result.MaxAttempts  := 1;
  Result.ScoreSlack   := 0.0;
  Result.SeedWordPool := 1;
end;

constructor TXwGenerator.Create(const ALang: IXwLang);
begin
  inherited Create;
  FLang := ALang;
  FState := 88172645463325252;
end;

function TXwGenerator.NextRandom: UInt64;
begin
  FState := FState xor (FState shl 13);
  FState := FState xor (FState shr 7);
  FState := FState xor (FState shl 17);
  Result := FState;
end;

function TXwGenerator.NextInt(const ABound: Integer): Integer;
begin
  if ABound <= 1 then Exit(0);
  Result := Integer(NextRandom mod UInt64(ABound));
end;

class function TXwGenerator.ArenaSideFor(const AWords: TArray<IXwWord>): Integer;
var
  I, LTotal, LMaxLen, LSide: Integer;
begin
  LTotal := 0;
  LMaxLen := 0;
  for I := 0 to High(AWords) do
  begin
    Inc(LTotal, AWords[I].Length);
    if AWords[I].Length > LMaxLen then LMaxLen := AWords[I].Length;
  end;

  if LTotal = 0 then Exit(8);

  LSide := Ceil(Sqrt(LTotal / 0.30));
  Result := Max(LMaxLen + 4, Ceil(LSide * 2.2));
end;

procedure TXwGenerator.BuildIndexes;
var
  I, K, N, LIdx, LCount: Integer;
  LSeen: TArray<Integer>;
begin
  N := Length(FWords);
  FMaskable := FLang.LetterCount <= 64;

  SetLength(FMasks, N);
  SetLength(FLetterIdx, N);
  SetLength(FDistinct, N);

  SetLength(LSeen, FLang.LetterCount);
  for I := 0 to High(LSeen) do
    LSeen[I] := -1;

  for I := 0 to N - 1 do
  begin
    SetLength(FLetterIdx[I], FWords[I].Length);
    SetLength(FDistinct[I], FWords[I].Length);
    LCount := 0;
    FMasks[I] := 0;

    for K := 0 to FWords[I].Length - 1 do
    begin
      LIdx := FLang.IndexOf(FWords[I].GetLetter(K + 1).Original);
      FLetterIdx[I][K] := LIdx;

      if LIdx < 0 then Continue;

      if FMaskable and (LIdx < 64) then
        FMasks[I] := FMasks[I] or (UInt64(1) shl LIdx);

      if LSeen[LIdx] <> I then
      begin
        LSeen[LIdx] := I;
        FDistinct[I][LCount] := LIdx;
        Inc(LCount);
      end;
    end;

    SetLength(FDistinct[I], LCount);
  end;
end;

procedure TXwGenerator.ResetNeed;
var
  I, K: Integer;
begin
  SetLength(FLetterNeed, FLang.LetterCount);
  for I := 0 to High(FLetterNeed) do
    FLetterNeed[I] := 0;

  for I := 0 to High(FWords) do
    for K := 0 to High(FDistinct[I]) do
      Inc(FLetterNeed[FDistinct[I][K]]);
end;

procedure TXwGenerator.ConsumeNeed(const AWordIndex: Integer);
var
  K: Integer;
begin
  for K := 0 to High(FDistinct[AWordIndex]) do
    Dec(FLetterNeed[FDistinct[AWordIndex][K]]);
end;

procedure TXwGenerator.MarkDirty(const AWordIndex: Integer);
var
  I: Integer;
  LMask: UInt64;
begin
  if not FMaskable then
  begin
    for I := 0 to High(FWords) do
      if not FPlaced[I] then
        FDirty[I] := True;
    Exit;
  end;

  LMask := FMasks[AWordIndex];
  for I := 0 to High(FWords) do
    if (not FPlaced[I]) and ((FMasks[I] and LMask) <> 0) then
      FDirty[I] := True;
end;

function TXwGenerator.ScoreMove(const AWordIndex: Integer;
  const APlacement: TXwWordPlacement;
  const ABounds: TXwBounds;
  const AUnplaced, ARunLimit: Integer;
  const AWeights: TXwScoreWeights): Double;
var
  LLen, LEndH, LEndV, K, LIdx, LNeed, LAcc: Integer;
  LMinH, LMaxH, LMinV, LMaxV: Integer;
  LW0, LH0, LW1, LH1: Integer;
  LAspect: Double;
begin
  LLen := FWords[AWordIndex].Length;

  LEndH := APlacement.H;
  LEndV := APlacement.V;
  if APlacement.Direction = wdHorizontal then
    Inc(LEndH, LLen - 1)
  else
    Inc(LEndV, LLen - 1);

  LW0 := ABounds.Width;
  LH0 := ABounds.Height;

  LMinH := Min(ABounds.MinH, APlacement.H);
  LMaxH := Max(ABounds.MaxH, LEndH);
  LMinV := Min(ABounds.MinV, APlacement.V);
  LMaxV := Max(ABounds.MaxV, LEndV);

  LW1 := LMaxH - LMinH + 1;
  LH1 := LMaxV - LMinV + 1;

  if Min(LW1, LH1) > 0 then
    LAspect := Max(LW1, LH1) / Min(LW1, LH1)
  else
    LAspect := 1.0;

  LAcc := 0;
  if AWeights.Potential <> 0 then
    for K := 0 to LLen - 1 do
      if (K >= 32) or ((APlacement.CrossMask and (UInt32(1) shl K)) = 0) then
      begin
        LIdx := FLetterIdx[AWordIndex][K];
        if LIdx >= 0 then
        begin
          LNeed := FLetterNeed[LIdx] - 1;
          if LNeed > 0 then Inc(LAcc, LNeed);
        end;
      end;

  Result := AWeights.Crossing * APlacement.Crossings
          + AWeights.Rescue * APlacement.Rescue
          - AWeights.Growth * ((LW1 + LH1) - (LW0 + LH0))
          - AWeights.Aspect * Max(0.0, LAspect - AWeights.TargetAspect);

  if AWeights.Potential <> 0 then
    Result := Result + AWeights.Potential * LAcc / Max(1, AUnplaced);

  if (AWeights.Run <> 0) and (APlacement.MaxRun > ARunLimit) then
    Result := Result - AWeights.Run * (APlacement.MaxRun - ARunLimit);
end;

function TXwGenerator.ChooseSeedIndex(const APool: Integer): Integer;
var
  I, J, LPool, LBestLen, LBestAt, LTmp: Integer;
  LOrder: TArray<Integer>;
begin
  if Length(FWords) = 0 then Exit(-1);

  SetLength(LOrder, Length(FWords));
  for I := 0 to High(LOrder) do
    LOrder[I] := I;

  LPool := APool;
  if LPool < 1 then LPool := 1;
  if LPool > Length(FWords) then LPool := Length(FWords);

  for I := 0 to LPool - 1 do
  begin
    LBestLen := FWords[LOrder[I]].Length;
    LBestAt := I;
    for J := I + 1 to High(LOrder) do
      if FWords[LOrder[J]].Length > LBestLen then
      begin
        LBestLen := FWords[LOrder[J]].Length;
        LBestAt := J;
      end;
    LTmp := LOrder[I];
    LOrder[I] := LOrder[LBestAt];
    LOrder[LBestAt] := LTmp;
  end;

  Result := LOrder[NextInt(LPool)];
end;

procedure TXwGenerator.Replay(const AImpl: TXwBoard; const AMoves: TArray<TXwMove>);
var
  I: Integer;
begin
  AImpl.Clear;
  for I := 0 to High(AMoves) do
    AImpl.Commit(FWords[AMoves[I].WordIndex], AMoves[I].Placement);
end;

function TXwGenerator.TryRelocate(const AImpl: TXwBoard; const ABoard: IXwBoard;
  var AMoves: TArray<TXwMove>; const APos: Integer;
  const AOptions: TXwGenOptions; var ABest: TXwMetrics): Boolean;
var
  LTrial: TArray<TXwMove>;
  LWeights: TXwScoreWeights;
  LCands: TArray<TXwWordPlacement>;
  LBounds: TXwBounds;
  LP: TXwWordPlacement;
  LMetrics: TXwMetrics;
  I, J, N, LCount, LPick, LWord: Integer;
  LScore, LBestScore: Double;
  LOk: Boolean;
begin
  Result := False;
  N := Length(AMoves);
  if (APos < 1) or (APos >= N) then Exit;

  LWeights := AOptions.Score;
  LWeights.Potential := 0.0;

  SetLength(LTrial, N);
  LCount := 0;
  LOk := True;

  AImpl.Clear;

  for I := 0 to N - 1 do
  begin
    if I = APos then Continue;

    LWord := AMoves[I].WordIndex;
    LP := AMoves[I].Placement;

    if LCount > 0 then
      if not AImpl.Revalidate(FWords[LWord], LP) then
      begin
        LOk := False;
        Break;
      end;

    AImpl.Commit(FWords[LWord], LP);
    LTrial[LCount].WordIndex := LWord;
    LTrial[LCount].Placement := LP;
    Inc(LCount);
  end;

  if LOk then
  begin
    LWord := AMoves[APos].WordIndex;
    LCands := AImpl.Candidates(FWords[LWord]);

    if Length(LCands) > 0 then
    begin
      LBounds := AImpl.GetBounds;
      LBestScore := -1.0e300;
      LPick := -1;

      for J := 0 to High(LCands) do
      begin
        LScore := ScoreMove(LWord, LCands[J], LBounds, 1,
          AOptions.Weights.MaxRunLimit, LWeights);
        if LScore > LBestScore then
        begin
          LBestScore := LScore;
          LPick := J;
        end;
      end;

      LP := LCands[LPick];
      if AImpl.Revalidate(FWords[LWord], LP) then
      begin
        AImpl.Commit(FWords[LWord], LP);
        LTrial[LCount].WordIndex := LWord;
        LTrial[LCount].Placement := LP;
        Inc(LCount);

        LMetrics := XwMeasure(ABoard, Length(FWords), AOptions.Weights);
        if LMetrics.Total > ABest.Total + 1.0e-9 then
        begin
          SetLength(LTrial, LCount);
          AMoves := LTrial;
          ABest := LMetrics;
          Result := True;
        end;
      end;
    end;
  end;

  if not Result then
    Replay(AImpl, AMoves);
end;

function TXwGenerator.RefineBoard(const AImpl: TXwBoard; const ABoard: IXwBoard;
  var AMoves: TArray<TXwMove>; const AOptions: TXwGenOptions;
  var ABest: TXwMetrics): Integer;
var
  LCross, LOrder: TArray<Integer>;
  I, J, K, N, LH, LV, LStepH, LStepV, LTmp, LBestAt, LPos: Integer;
  LRound: Integer;
  LImproved: Boolean;
begin
  Result := 0;
  N := Length(AMoves);
  if N < 3 then Exit;

  for LRound := 1 to AOptions.RefineRounds do
  begin
    LImproved := False;
    N := Length(AMoves);

    SetLength(LCross, N);
    SetLength(LOrder, N);

    for I := 0 to N - 1 do
    begin
      LOrder[I] := AMoves[I].WordIndex;
      LCross[I] := 0;

      if AMoves[I].Placement.Direction = wdHorizontal then
      begin
        LStepH := 1;
        LStepV := 0;
      end
      else
      begin
        LStepH := 0;
        LStepV := 1;
      end;

      LH := AMoves[I].Placement.H;
      LV := AMoves[I].Placement.V;
      for K := 1 to FWords[AMoves[I].WordIndex].Length do
      begin
        if ABoard.CellState(LH, LV) = 3 then
          Inc(LCross[I]);
        Inc(LH, LStepH);
        Inc(LV, LStepV);
      end;
    end;

    for I := 0 to N - 2 do
    begin
      LBestAt := I;
      for J := I + 1 to N - 1 do
        if LCross[J] < LCross[LBestAt] then
          LBestAt := J;
      if LBestAt <> I then
      begin
        LTmp := LCross[I]; LCross[I] := LCross[LBestAt]; LCross[LBestAt] := LTmp;
        LTmp := LOrder[I]; LOrder[I] := LOrder[LBestAt]; LOrder[LBestAt] := LTmp;
      end;
    end;

    for I := 0 to N - 1 do
    begin
      LPos := -1;
      for J := 0 to High(AMoves) do
        if AMoves[J].WordIndex = LOrder[I] then
        begin
          LPos := J;
          Break;
        end;

      if LPos < 1 then Continue;

      if TryRelocate(AImpl, ABoard, AMoves, LPos, AOptions, ABest) then
      begin
        LImproved := True;
        Inc(Result);
      end;
    end;

    if not LImproved then Break;
  end;
end;

function TXwGenerator.Generate(const AWords: TArray<IXwWord>;
  const AOptions: TXwGenOptions): TXwGenResult;
var
  LBoard: IXwBoard;
  LImpl: TXwBoard;
  LSide, LCount, N: Integer;
  LWatch: TStopwatch;
  LAttempt: Integer;
  LMoves, LBestMoves: TArray<TXwMove>;
  LMoveCount: Integer;
  LMetrics, LBestMetrics: TXwMetrics;
  LHaveBest: Boolean;
  I, J: Integer;
  LBestScore, LScore: Double;
  LPickI, LPickJ, LTies: Integer;
  LChosen: TXwWordPlacement;
  LSeedIdx: Integer;
  LSeedDir: TXwWordDirection;
  LBounds: TXwBounds;
begin
  Result := Default(TXwGenResult);

  FWords := AWords;
  N := Length(FWords);
  if N = 0 then Exit;

  for I := 0 to N - 1 do
    FWords[I].Rebuild;

  FEnumerations := 0;
  FState := AOptions.Seed;
  if FState = 0 then FState := 88172645463325252;

  BuildIndexes;

  SetLength(FPlaced, N);
  SetLength(FDirty, N);
  SetLength(FCands, N);

  LSide := AOptions.ArenaSide;
  if LSide <= 0 then
    LSide := ArenaSideFor(FWords);

  LImpl := TXwBoard.Create(LSide, LSide, FLang);
  LBoard := LImpl;

  LHaveBest := False;
  LBestMetrics := Default(TXwMetrics);
  LAttempt := 0;

  LWatch := TStopwatch.StartNew;

  while True do
  begin
    if (AOptions.MaxAttempts > 0) and (LAttempt >= AOptions.MaxAttempts) then Break;
    if (AOptions.TimeBudgetMs > 0) and (LAttempt > 0)
      and (LWatch.Elapsed.TotalMilliseconds >= AOptions.TimeBudgetMs) then Break;

    Inc(LAttempt);
    LImpl.Clear;
    ResetNeed;

    for I := 0 to N - 1 do
    begin
      FPlaced[I] := False;
      FDirty[I] := True;
      FCands[I] := nil;
    end;

    SetLength(LMoves, N);
    LMoveCount := 0;
    LCount := 0;

    LSeedIdx := ChooseSeedIndex(AOptions.SeedWordPool);
    if NextInt(2) = 0 then
      LSeedDir := wdHorizontal
    else
      LSeedDir := wdVertical;

    if not LImpl.SeedPlacement(FWords[LSeedIdx], LSeedDir, LChosen) then Continue;

    LImpl.Commit(FWords[LSeedIdx], LChosen);
    FPlaced[LSeedIdx] := True;
    ConsumeNeed(LSeedIdx);
    Inc(LCount);
    LMoves[LMoveCount].WordIndex := LSeedIdx;
    LMoves[LMoveCount].Placement := LChosen;
    Inc(LMoveCount);
    MarkDirty(LSeedIdx);

    while LCount < N do
    begin
      for I := 0 to N - 1 do
        if (not FPlaced[I]) and FDirty[I] then
        begin
          FCands[I] := LImpl.Candidates(FWords[I]);
          FDirty[I] := False;
          Inc(FEnumerations);
        end;

      LBounds := LImpl.GetBounds;

      LBestScore := -1.0e300;
      for I := 0 to N - 1 do
      begin
        if FPlaced[I] then Continue;
        for J := 0 to High(FCands[I]) do
        begin
          if AOptions.UseBoardScore then
            LScore := LImpl.ScoreOf(FWords[I], FCands[I][J])
          else
            LScore := ScoreMove(I, FCands[I][J], LBounds,
              N - LCount, AOptions.Weights.MaxRunLimit, AOptions.Score);

          FCands[I][J].Score := LScore;
          if LScore > LBestScore then
            LBestScore := LScore;
        end;
      end;

      if LBestScore <= -1.0e299 then Break;

      LTies := 0;
      LPickI := -1;
      LPickJ := -1;
      for I := 0 to N - 1 do
      begin
        if FPlaced[I] then Continue;
        for J := 0 to High(FCands[I]) do
          if FCands[I][J].Score >= LBestScore - AOptions.ScoreSlack then
          begin
            Inc(LTies);
            if NextInt(LTies) = 0 then
            begin
              LPickI := I;
              LPickJ := J;
            end;
          end;
      end;

      if LPickI < 0 then Break;

      LChosen := FCands[LPickI][LPickJ];
      if not LImpl.Revalidate(FWords[LPickI], LChosen) then
      begin
        FCands[LPickI] := nil;
        FDirty[LPickI] := True;
        Continue;
      end;

      LImpl.Commit(FWords[LPickI], LChosen);
      FPlaced[LPickI] := True;
      ConsumeNeed(LPickI);
      FCands[LPickI] := nil;
      Inc(LCount);

      LMoves[LMoveCount].WordIndex := LPickI;
      LMoves[LMoveCount].Placement := LChosen;
      Inc(LMoveCount);

      MarkDirty(LPickI);
    end;

    LMetrics := XwMeasure(LBoard, N, AOptions.Weights);

    if (not LHaveBest) or (LMetrics.Total > LBestMetrics.Total) then
    begin
      LHaveBest := True;
      LBestMetrics := LMetrics;
      SetLength(LBestMoves, LMoveCount);
      for I := 0 to LMoveCount - 1 do
        LBestMoves[I] := LMoves[I];
    end;
  end;

  Replay(LImpl, LBestMoves);

  if (AOptions.RefineRounds > 0) and LHaveBest then
  begin
    LBestMetrics := XwMeasure(LBoard, N, AOptions.Weights);
    Result.Relocations := RefineBoard(LImpl, LBoard, LBestMoves, AOptions, LBestMetrics);
  end;

  LWatch.Stop;

  Result.Board := LBoard;
  Result.Metrics := XwMeasure(LBoard, N, AOptions.Weights);
  Result.Attempts := LAttempt;
  Result.Enumerations := FEnumerations;
  Result.ElapsedMs := LWatch.Elapsed.TotalMilliseconds;
  Result.Metrics.ElapsedMs := Result.ElapsedMs;
end;

end.

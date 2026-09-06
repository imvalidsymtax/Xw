unit Xw.Metrics;

interface

uses
  Xw.Contracts;

type

  TXwMetricWeights = record
    Coverage: Double;
    Interlock: Double;
    Compactness: Double;
    Solvability: Double;
    Shape: Double;

    RefInterlock: Double;
    RefFill: Double;
    TargetAspect: Double;
    MaxRunLimit: Integer;
    PenaltyDead0: Double;
    PenaltyDead1: Double;
    PenaltyLongRun: Double;

    class function Standard: TXwMetricWeights; static;
  end;

  TXwMetrics = record
    Requested: Integer;
    Placed: Integer;
    Letters: Integer;
    Crossings: Integer;

    Width: Integer;
    Height: Integer;
    Area: Integer;

    HWords: Integer;
    VWords: Integer;

    Dead0: Integer;
    Dead1: Integer;
    MinCross: Integer;
    AvgCross: Double;

    MaxRun: Integer;
    LongRunWords: Integer;

    Coverage: Double;
    Interlock: Double;
    FillRatio: Double;
    Aspect: Double;
    Balance: Double;

    ScoreCoverage: Double;
    ScoreInterlock: Double;
    ScoreCompactness: Double;
    ScoreSolvability: Double;
    ScoreShape: Double;
    Total: Double;

    ElapsedMs: Double;

    function AsText: string;
    class function Header: string; static;
    function AsRow(const ALabel: string): string;
  end;

function XwMeasure(const ABoard: IXwBoard; const ARequested: Integer): TXwMetrics; overload;
function XwMeasure(const ABoard: IXwBoard; const ARequested: Integer;
  const AWeights: TXwMetricWeights): TXwMetrics; overload;

implementation

uses
  System.SysUtils, System.Math;

class function TXwMetricWeights.Standard: TXwMetricWeights;
begin
  Result.Coverage    := 0.35;
  Result.Interlock   := 0.20;
  Result.Compactness := 0.15;
  Result.Solvability := 0.25;
  Result.Shape       := 0.05;

  Result.RefInterlock := 0.35;
  Result.RefFill      := 0.55;
  Result.TargetAspect := 1.0;
  Result.MaxRunLimit  := 4;

  Result.PenaltyDead0   := 1.00;
  Result.PenaltyDead1   := 0.50;
  Result.PenaltyLongRun := 0.40;
end;

function XwMeasure(const ABoard: IXwBoard; const ARequested: Integer): TXwMetrics;
begin
  Result := XwMeasure(ABoard, ARequested, TXwMetricWeights.Standard);
end;

function XwMeasure(const ABoard: IXwBoard; const ARequested: Integer;
  const AWeights: TXwMetricWeights): TXwMetrics;
var
  LBounds: TXwBounds;
  LPlaced: TXwPlacedWord;
  I, K, LH, LV, LStepH, LStepV: Integer;
  LWordCross, LRun, LWordMaxRun: Integer;
  LCrossSum: Integer;
  LPenalty, LWordPenalty, LSumWeights: Double;
  LMinSide, LMaxSide: Integer;
begin
  Result := Default(TXwMetrics);

  Result.Requested := ARequested;
  Result.Placed := ABoard.WordCount;

  LBounds := ABoard.Bounds;
  Result.Width  := LBounds.Width;
  Result.Height := LBounds.Height;
  Result.Area   := LBounds.Area;

  for LV := LBounds.MinV to LBounds.MaxV do
    for LH := LBounds.MinH to LBounds.MaxH do
      if ABoard.CellState(LH, LV) <> 0 then
        Inc(Result.Letters);

  Result.MinCross := MaxInt;
  LCrossSum := 0;
  LPenalty := 0;

  for I := 0 to Result.Placed - 1 do
  begin
    LPlaced := ABoard.PlacedWords[I];

    if LPlaced.Placement.Direction = wdHorizontal then
    begin
      Inc(Result.HWords);
      LStepH := 1;
      LStepV := 0;
    end
    else
    begin
      Inc(Result.VWords);
      LStepH := 0;
      LStepV := 1;
    end;

    LWordCross := 0;
    LRun := 0;
    LWordMaxRun := 0;

    LH := LPlaced.Placement.H;
    LV := LPlaced.Placement.V;

    for K := 1 to LPlaced.Word.Length do
    begin
      if ABoard.CellState(LH, LV) = 3 then
      begin
        Inc(LWordCross);
        LRun := 0;
      end
      else
      begin
        Inc(LRun);
        if LRun > LWordMaxRun then LWordMaxRun := LRun;
      end;

      Inc(LH, LStepH);
      Inc(LV, LStepV);
    end;

    Inc(LCrossSum, LWordCross);

    if LWordCross < Result.MinCross then Result.MinCross := LWordCross;
    if LWordMaxRun > Result.MaxRun then Result.MaxRun := LWordMaxRun;

    LWordPenalty := 0;
    if LWordCross = 0 then
      LWordPenalty := AWeights.PenaltyDead0
    else if LWordCross = 1 then
      LWordPenalty := AWeights.PenaltyDead1;

    if LWordCross = 0 then Inc(Result.Dead0)
    else if LWordCross = 1 then Inc(Result.Dead1);

    if LWordMaxRun > AWeights.MaxRunLimit then
    begin
      Inc(Result.LongRunWords);
      LWordPenalty := LWordPenalty + AWeights.PenaltyLongRun;
    end;

    if LWordPenalty > 1.0 then LWordPenalty := 1.0;
    LPenalty := LPenalty + LWordPenalty;
  end;

  if Result.Placed = 0 then Result.MinCross := 0;

  Result.Crossings := LCrossSum div 2;

  if Result.Placed > 0 then
    Result.AvgCross := LCrossSum / Result.Placed
  else
    Result.AvgCross := 0;

  if Result.Letters > 0 then
    Result.Interlock := Result.Crossings / Result.Letters
  else
    Result.Interlock := 0;

  if Result.Area > 0 then
    Result.FillRatio := Result.Letters / Result.Area
  else
    Result.FillRatio := 0;

  LMinSide := Min(Result.Width, Result.Height);
  LMaxSide := Max(Result.Width, Result.Height);
  if LMinSide > 0 then
    Result.Aspect := LMaxSide / LMinSide
  else
    Result.Aspect := 0;

  if Max(Result.HWords, Result.VWords) > 0 then
    Result.Balance := Min(Result.HWords, Result.VWords) / Max(Result.HWords, Result.VWords)
  else
    Result.Balance := 0;

  if ARequested > 0 then
    Result.Coverage := Result.Placed / ARequested
  else
    Result.Coverage := 0;

  Result.ScoreCoverage := Min(1.0, Result.Coverage);

  if AWeights.RefInterlock > 0 then
    Result.ScoreInterlock := Min(1.0, Result.Interlock / AWeights.RefInterlock)
  else
    Result.ScoreInterlock := 0;

  if AWeights.RefFill > 0 then
    Result.ScoreCompactness := Min(1.0, Result.FillRatio / AWeights.RefFill)
  else
    Result.ScoreCompactness := 0;

  if Result.Placed > 0 then
    Result.ScoreSolvability := Max(0.0, 1.0 - LPenalty / Result.Placed)
  else
    Result.ScoreSolvability := 0;

  if (AWeights.TargetAspect > 0) and (Result.Aspect > 0) then
    Result.ScoreShape := Max(0.0,
      1.0 - Abs(Result.Aspect - AWeights.TargetAspect) / AWeights.TargetAspect)
  else
    Result.ScoreShape := 0;

  LSumWeights := AWeights.Coverage + AWeights.Interlock + AWeights.Compactness
    + AWeights.Solvability + AWeights.Shape;

  if LSumWeights <= 0 then
    Result.Total := 0
  else
    Result.Total :=
      ( AWeights.Coverage    * Result.ScoreCoverage
      + AWeights.Interlock   * Result.ScoreInterlock
      + AWeights.Compactness * Result.ScoreCompactness
      + AWeights.Solvability * Result.ScoreSolvability
      + AWeights.Shape       * Result.ScoreShape ) / LSumWeights;
end;

function TXwMetrics.AsText: string;
begin
  Result :=
    Format('  slowa          %d / %d   (pokrycie %.1f%%)'#13#10, [Placed, Requested, Coverage * 100]) +
    Format('  litery         %d,  skrzyzowania %d'#13#10, [Letters, Crossings]) +
    Format('  bbox           %d x %d = %d   (wypelnienie %.3f, proporcja %.2f)'#13#10, [Width, Height, Area, FillRatio, Aspect]) +
    Format('  plecionka      interlock %.3f,  srednio %.2f skrzyzowan/slowo,  min %d'#13#10, [Interlock, AvgCross, MinCross]) +
    Format('  slabe slowa    0-skrzyzowan: %d,  1-skrzyzowanie: %d'#13#10, [Dead0, Dead1]) +
    Format('  dlugie ciagi   max %d liter bez podpowiedzi,  slow ponad limit: %d'#13#10, [MaxRun, LongRunWords]) +
    Format('  poziom/pion    %d / %d  (balans %.2f)'#13#10, [HWords, VWords, Balance]) +
    Format('  skladowe       cov %.3f  int %.3f  cmp %.3f  slv %.3f  shp %.3f'#13#10, [ScoreCoverage, ScoreInterlock, ScoreCompactness, ScoreSolvability, ScoreShape]) +
    Format('  TOTAL          %.4f      czas %.2f ms'#13#10, [Total, ElapsedMs]);
end;

class function TXwMetrics.Header: string;
begin
  Result :=
    '  wariant                   slowa   pokr   interl  wypeln  prop   d0  d1   >lim   TOTAL    ms'#13#10 +
    '  ----------------------------------------------------------------------------------------------';
end;

function TXwMetrics.AsRow(const ALabel: string): string;
begin
  Result := Format('  %-24s %4d  %5.1f%%  %6.3f  %6.3f  %5.2f  %3d %3d  %6d  %6.4f  %6.2f',
    [ALabel, Placed, Coverage * 100, Interlock, FillRatio, Aspect,
     Dead0, Dead1, LongRunWords, Total, ElapsedMs]);
end;

end.

unit Xw.Tests;

interface

uses
  Xw.Contracts;

function XwRunUnitTests: Boolean;
procedure XwRunBenchmark(const AWordCount: Integer = 120);
procedure XwPrintSample(const AWordCount: Integer = 45);

function XwValidateBoard(const ABoard: IXwBoard; out AMessage: string): Boolean;
function XwFillBoard(const ABoard: IXwBoard; const AWords: TArray<IXwWord>;
  const APasses: Integer): Integer;

implementation

uses
  System.SysUtils,
  System.Math,
  System.Diagnostics,
  System.Generics.Collections,
  Xw.Anchors,
  Xw.Board,
  Xw.Corpus,
  Xw.Generator,
  Xw.Langs,
  Xw.Metrics,
  Xw.Word;

var
  GPassed: Integer;
  GFailed: Integer;

procedure Check(const ACondition: Boolean; const AName: string);
begin
  if ACondition then
  begin
    Inc(GPassed);
    Writeln(Format('  [ ok ] %s', [AName]));
  end
  else
  begin
    Inc(GFailed);
    Writeln(Format('  [FAIL] %s', [AName]));
  end;
end;

procedure CheckEq(const AExpected, AActual: Integer; const AName: string);
begin
  if AExpected = AActual then
  begin
    Inc(GPassed);
    Writeln(Format('  [ ok ] %s', [AName]));
  end
  else
  begin
    Inc(GFailed);
    Writeln(Format('  [FAIL] %s  (oczekiwano %d, jest %d)', [AName, AExpected, AActual]));
  end;
end;

function XwFillBoard(const ABoard: IXwBoard; const AWords: TArray<IXwWord>;
  const APasses: Integer): Integer;
var
  LPending, LNext: TList<IXwWord>;
  LPass, I, LBefore: Integer;
begin
  Result := 0;
  LPending := TList<IXwWord>.Create;
  LNext := TList<IXwWord>.Create;
  try
    for I := 0 to High(AWords) do
      LPending.Add(AWords[I]);

    for LPass := 1 to APasses do
    begin
      if LPending.Count = 0 then Break;
      LBefore := Result;
      LNext.Clear;

      for I := 0 to LPending.Count - 1 do
        if ABoard.TryPlaceWord(LPending[I]) then
          Inc(Result)
        else
          LNext.Add(LPending[I]);

      LPending.Clear;
      LPending.AddRange(LNext);

      if Result = LBefore then Break;
    end;
  finally
    LNext.Free;
    LPending.Free;
  end;
end;

function XwValidateBoard(const ABoard: IXwBoard; out AMessage: string): Boolean;
var
  LBounds: TXwBounds;
  LExpected: TDictionary<string, Integer>;
  LKey, LRun: string;
  LPlaced: TXwPlacedWord;
  I, H, V, LCount: Integer;
  LChar: Char;
  LDir: TXwWordDirection;
  LPair: TPair<string, Integer>;
begin
  AMessage := '';
  Result := False;
  LBounds := ABoard.Bounds;

  LExpected := TDictionary<string, Integer>.Create;
  try
    for I := 0 to ABoard.WordCount - 1 do
    begin
      LPlaced := ABoard.PlacedWords[I];
      LKey := Format('%d:%d:%d:%s', [Ord(LPlaced.Placement.Direction),
        LPlaced.Placement.H, LPlaced.Placement.V, LPlaced.Word.Word]);
      if LExpected.TryGetValue(LKey, LCount) then
        LExpected[LKey] := LCount + 1
      else
        LExpected.Add(LKey, 1);
    end;

    for LDir := wdHorizontal to wdVertical do
      for V := LBounds.MinV to LBounds.MaxV do
        for H := LBounds.MinH to LBounds.MaxH do
        begin
          if not ABoard.IsOccupied(H, V) then Continue;

          if LDir = wdHorizontal then
          begin
            if ABoard.IsOccupied(H - 1, V) then Continue;
          end
          else
          begin
            if ABoard.IsOccupied(H, V - 1) then Continue;
          end;

          LRun := '';
          I := 0;
          while True do
          begin
            if LDir = wdHorizontal then
              LChar := ABoard.CellChar(H + I, V)
            else
              LChar := ABoard.CellChar(H, V + I);
            if LChar = #0 then Break;
            LRun := LRun + LChar;
            Inc(I);
          end;

          if Length(LRun) < 2 then Continue;

          LKey := Format('%d:%d:%d:%s', [Ord(LDir), H, V, LRun]);
          if not LExpected.TryGetValue(LKey, LCount) then
          begin
            AMessage := Format(
              'ciag "%s" w (%d,%d) kierunek %d nie odpowiada zadnemu polozonemu slowu',
              [LRun, H, V, Ord(LDir)]);
            Exit;
          end;

          if LCount = 1 then
            LExpected.Remove(LKey)
          else
            LExpected[LKey] := LCount - 1;
        end;

    if LExpected.Count > 0 then
    begin
      for LPair in LExpected do
      begin
        AMessage := Format('slowo %s zadeklarowane, ale nieodnalezione na planszy', [LPair.Key]);
        Break;
      end;
      Exit;
    end;

    Result := True;
  finally
    LExpected.Free;
  end;
end;

procedure TestLang;
var
  LPlain, LDia: IXwLang;
  LMsg: string;
begin
  Writeln('TestLang');
  LDia := TXwLangPL.Create(True);
  LPlain := TXwLangPL.Create(False);

  Check(LDia.Normalize('żółw') = 'ŻÓŁW', 'diakrytyki zachowane przy ADiacritics=True');
  Check(LPlain.Normalize('żółw') = 'ZOLW', 'diakrytyki zlozone do bazy przy ADiacritics=False');
  Check(LDia.Normalize('  bialy - kot ') = 'BIALYKOT', 'trim, spacje i myslniki usuniete');
  Check(not LDia.IsValid('A', LMsg), 'jednoliterowe odrzucone');
  Check(not LDia.IsValid('KOT1', LMsg), 'cyfra odrzucona');
  Check(LDia.IsValid('KOT', LMsg), 'poprawne slowo zaakceptowane');
  Check(LDia.IndexOf('Ż') >= 0, 'Z z kropka jest w alfabecie');
  Check(LDia.IndexOf('@') < 0, 'znak spoza alfabetu daje -1');
end;

procedure TestAnchors;
var
  LLang: IXwLang;
  LIdx: TXwAnchorIndex;
begin
  Writeln('TestAnchors');
  LLang := TXwLangPL.Create(True);
  LIdx := TXwAnchorIndex.Create(LLang);
  try
    LIdx.Add('A', 10);
    LIdx.Add('A', 20);
    LIdx.Add('A', 30);
    LIdx.Add('B', 40);

    CheckEq(3, LIdx.CountOf('A'), 'trzy kotwice na A');
    CheckEq(1, LIdx.CountOf('B'), 'jedna kotwica na B');
    CheckEq(4, LIdx.TotalCount, 'lacznie cztery kotwice');

    LIdx.RemoveAt('A', 0);
    CheckEq(2, LIdx.CountOf('A'), 'po usunieciu zostaja dwie');
    CheckEq(30, LIdx.PositionAt('A', 0), 'swap-remove przenosi ostatni na zwolnione miejsce');

    LIdx.Clear;
    CheckEq(0, LIdx.TotalCount, 'Clear czysci wszystkie kubelki');
  finally
    LIdx.Free;
  end;
end;

procedure TestBounds;
var
  LB: TXwBounds;
begin
  Writeln('TestBounds');
  LB := TXwBounds.CreateEmpty;
  Check(LB.IsEmpty, 'swiezy bounds jest pusty');
  CheckEq(0, LB.Area, 'pusty bounds ma pole 0');

  LB.MinH := 2; LB.MaxH := 5; LB.MinV := 3; LB.MaxV := 3;
  CheckEq(4, LB.Width, 'szerokosc liczona inclusive');
  CheckEq(1, LB.Height, 'wysokosc liczona inclusive');
  CheckEq(4, LB.Area, 'pole to iloczyn bokow');
  Check(LB.Contains(3, 3), 'punkt wewnatrz');
  Check(not LB.Contains(6, 3), 'punkt poza');
end;

procedure TestGeometry;
var
  LLang: IXwLang;
  LFactory: IXwWordFactory;
  LBoard: IXwBoard;
  LMsg: string;
  LI, LJ: Integer;
begin
  Writeln('TestGeometry');
  LLang := TXwLangPL.Create(True);
  LFactory := TXwWordFactory.Create(LLang);
  LBoard := TXwBoard.Create(15, 15, LLang);

  Check(LBoard.TryPlaceWord(LFactory.CreateWord('kot', 'a')), 'pierwsze slowo wchodzi na srodek');
  CheckEq(1, LBoard.WordCount, 'plansza ma jedno slowo');

  Check(not LBoard.TryPlaceWord(LFactory.CreateWord('pub', 'b')),
    'slowo bez wspolnych liter odrzucone');
  CheckEq(1, LBoard.WordCount, 'odrzucone slowo nie zmienia planszy');

  Check(LBoard.TryPlaceWord(LFactory.CreateWord('tor', 'c')),
    'slowo dzielace litere wchodzi');
  CheckEq(2, LBoard.WordCount, 'plansza ma dwa slowa');

  Check(XwValidateBoard(LBoard, LMsg), 'walidator nie znajduje pasozytniczych ciagow: ' + LMsg);
  CheckEq(1, LBoard.Evaluate.Crossings, 'dwa slowa daja jedno skrzyzowanie');

  Check(LBoard.CellChar(6, 7) = 'K', 'tablica cieni zna litere pierwszej komorki');
  CheckEq(1, LBoard.CellState(6, 7), 'K uzyte tylko poziomo');
  CheckEq(3, LBoard.CellState(8, 7), 'T uzyte w obu kierunkach');
  CheckEq(0, LBoard.CellState(0, 0), 'puste pole ma stan zero');
  Check(LBoard.CellChar(0, 0) = #0, 'puste pole nie ma litery');
  Check(LBoard.CellChar(-1, 7) = #0, 'poza plansza zwraca pustke');

  for LI := 0 to LBoard.HSize - 1 do
    for LJ := 0 to LBoard.VSize - 1 do
      if (LBoard.CellChar(LI, LJ) <> #0) <> (LBoard.LetterAt(LI, LJ) <> nil) then
        Check(False, Format('tablica cieni rozjechala sie z siatka w (%d,%d)', [LI, LJ]));
  Check(True, 'tablica cieni zgodna z siatka obiektow na calej planszy');
end;

procedure TestPlacementMetrics;
var
  LLang: IXwLang;
  LFactory: IXwWordFactory;
  LImpl: TXwBoard;
  LBoard: IXwBoard;
  LWord: IXwWord;
  LP: TXwWordPlacement;
begin
  Writeln('TestPlacementMetrics');
  LLang := TXwLangPL.Create(True);
  LFactory := TXwWordFactory.Create(LLang);
  LImpl := TXwBoard.Create(15, 15, LLang);
  LBoard := LImpl;

  LImpl.TryPlaceWord(LFactory.CreateWord('kot', 'a'));

  LWord := LFactory.CreateWord('tor', 'b');
  LP := Default(TXwWordPlacement);
  LP.H := 8;
  LP.V := 7;
  LP.Direction := wdVertical;

  Check(LImpl.Revalidate(LWord, LP), 'TOR pionowo od litery T jest legalne');
  CheckEq(1, LP.Crossings, 'jedno skrzyzowanie');
  CheckEq(1, Integer(LP.CrossMask), 'maska wskazuje na pierwsza litere');
  CheckEq(2, LP.MaxRun, 'dwie litery bez podpowiedzi po skrzyzowaniu');

  LWord := LFactory.CreateWord('otok', 'c');
  LP := Default(TXwWordPlacement);
  LP.H := 7;
  LP.V := 7;
  LP.Direction := wdVertical;

  Check(LImpl.Revalidate(LWord, LP), 'OTOK pionowo od litery O jest legalne');
  CheckEq(1, Integer(LP.CrossMask), 'skrzyzowanie na pozycji pierwszej');
  CheckEq(3, LP.MaxRun, 'trzy litery bez podpowiedzi na koncu');
end;

procedure TestFullBoard;
var
  LLang: IXwLang;
  LFactory: IXwWordFactory;
  LBoard: IXwBoard;
  LWords: TArray<IXwWord>;
  LPlaced, LSide: Integer;
  LMsg: string;
  LScore: TXwBoardScore;
  LMetrics: TXwMetrics;
begin
  Writeln('TestFullBoard');
  LLang := TXwLangPL.Create(True);
  LFactory := TXwWordFactory.Create(LLang);
  LWords := XwBuildWords(LFactory, 80);
  LSide := TXwGenerator.ArenaSideFor(LWords);
  LBoard := TXwBoard.Create(LSide, LSide, LLang);

  LPlaced := XwFillBoard(LBoard, LWords, 1);

  CheckEq(LPlaced, LBoard.WordCount, 'licznik ulozonych zgadza sie z plansza');
  Check(XwValidateBoard(LBoard, LMsg), 'pelna plansza bez pasozytniczych ciagow: ' + LMsg);

  LScore := LBoard.Evaluate;
  LMetrics := XwMeasure(LBoard, Length(LWords));

  CheckEq(LScore.Crossings, LMetrics.Crossings, 'metryki i Evaluate licza tyle samo skrzyzowan');
  CheckEq(LScore.Letters, LMetrics.Letters, 'metryki i Evaluate licza tyle samo liter');
  CheckEq(LScore.Words, LMetrics.Placed, 'metryki i Evaluate licza tyle samo slow');
  Check(SameValue(LScore.AvgCross, LMetrics.AvgCross, 0.0001),
    'metryki i Evaluate licza tak samo srednia skrzyzowan');
  CheckEq(LScore.Orphans, LMetrics.Dead0 + LMetrics.Dead1,
    'Orphans z Evaluate to suma Dead0 i Dead1 z metryk');
end;

procedure TestClearRebuild;
var
  LLang: IXwLang;
  LFactory: IXwWordFactory;
  LBoard: IXwBoard;
  LWords: TArray<IXwWord>;
  LSide: Integer;
  LFirst, LSecond: TXwBoardScore;
  LMsg: string;
begin
  Writeln('TestClearRebuild');
  LLang := TXwLangPL.Create(True);
  LFactory := TXwWordFactory.Create(LLang);
  LWords := XwBuildWords(LFactory, 60);
  LSide := TXwGenerator.ArenaSideFor(LWords);
  LBoard := TXwBoard.Create(LSide, LSide, LLang);

  XwFillBoard(LBoard, LWords, 1);
  LFirst := LBoard.Evaluate;

  LBoard.Clear;
  CheckEq(0, LBoard.WordCount, 'Clear oproznia liste slow');
  CheckEq(0, LBoard.Evaluate.Letters, 'Clear zeruje licznik liter');
  CheckEq(0, LBoard.Evaluate.Area, 'Clear zeruje bounding box');

  XwFillBoard(LBoard, LWords, 1);
  LSecond := LBoard.Evaluate;

  CheckEq(LFirst.Words, LSecond.Words, 'powtorzony przebieg daje te sama liczbe slow');
  CheckEq(LFirst.Crossings, LSecond.Crossings, 'powtorzony przebieg daje te same skrzyzowania');
  CheckEq(LFirst.Area, LSecond.Area, 'powtorzony przebieg daje to samo pole');
  Check(XwValidateBoard(LBoard, LMsg), 'plansza po przebudowie jest poprawna: ' + LMsg);
end;

procedure TestGenerator;
var
  LLang: IXwLang;
  LFactory: IXwWordFactory;
  LWords: TArray<IXwWord>;
  LGen: TXwGenerator;
  LOpt: TXwGenOptions;
  LA, LB, LC: TXwGenResult;
  LMsg: string;
begin
  Writeln('TestGenerator');
  LLang := TXwLangPL.Create(True);
  LFactory := TXwWordFactory.Create(LLang);
  LWords := XwBuildWords(LFactory, 100);

  LGen := TXwGenerator.Create(LLang);
  try
    LOpt := TXwGenOptions.Standard;
    LOpt.MaxAttempts := 8;

    LA := LGen.Generate(LWords, LOpt);
    LB := LGen.Generate(LWords, LOpt);

    CheckEq(LA.Metrics.Placed, LB.Metrics.Placed, 'ten sam seed daje te sama liczbe slow');
    Check(SameValue(LA.Metrics.Total, LB.Metrics.Total, 0.000001),
      'ten sam seed daje ten sam wynik');
    Check(XwValidateBoard(LB.Board, LMsg), 'plansza z generatora jest poprawna: ' + LMsg);

    LOpt.Seed := LOpt.Seed + 1;
    LC := LGen.Generate(LWords, LOpt);
    Check(XwValidateBoard(LC.Board, LMsg), 'plansza z innego seeda jest poprawna: ' + LMsg);

    LOpt := TXwGenOptions.Deterministic;
    LA := LGen.Generate(LWords, LOpt);
    CheckEq(1, LA.Attempts, 'tryb deterministyczny robi jedna probe');
    Check(LA.Metrics.Placed > 2, 'globalny wybor ruchu nie zakleszcza sie na dwoch slowach');
    Check(XwValidateBoard(LA.Board, LMsg), 'plansza deterministyczna jest poprawna: ' + LMsg);
  finally
    LGen.Free;
  end;
end;

procedure TestRefine;
var
  LLang: IXwLang;
  LFactory: IXwWordFactory;
  LWords: TArray<IXwWord>;
  LGen: TXwGenerator;
  LOpt: TXwGenOptions;
  LPlain, LFine: TXwGenResult;
  LMsg: string;
begin
  Writeln('TestRefine');
  LLang := TXwLangPL.Create(True);
  LFactory := TXwWordFactory.Create(LLang);
  LWords := XwBuildWords(LFactory, 100);

  LGen := TXwGenerator.Create(LLang);
  try
    LOpt := TXwGenOptions.Standard;
    LOpt.MaxAttempts := 4;
    LOpt.RefineRounds := 0;
    LPlain := LGen.Generate(LWords, LOpt);

    LOpt.RefineRounds := 4;
    LFine := LGen.Generate(LWords, LOpt);

    CheckEq(0, LPlain.Relocations, 'bez poprawek nie ma przestawien');
    Check(LFine.Metrics.Total >= LPlain.Metrics.Total - 0.000001,
      'przebieg poprawkowy nigdy nie pogarsza wyniku');
    Check(XwValidateBoard(LFine.Board, LMsg),
      'plansza po poprawkach jest poprawna: ' + LMsg);
    CheckEq(LPlain.Metrics.Placed, LFine.Metrics.Placed,
      'poprawki nie gubia slow');
    Check(LFine.Metrics.Dead0 = 0, 'poprawki nie odlaczaja slow od planszy');
  finally
    LGen.Free;
  end;
end;

function XwRunUnitTests: Boolean;
begin
  GPassed := 0;
  GFailed := 0;

  Writeln('=== TESTY JEDNOSTKOWE ===');
  Writeln;

  TestLang;
  TestAnchors;
  TestBounds;
  TestGeometry;
  TestPlacementMetrics;
  TestFullBoard;
  TestClearRebuild;
  TestGenerator;
  TestRefine;

  Writeln;
  Writeln(Format('=== zdane: %d, niezdane: %d ===', [GPassed, GFailed]));
  Writeln;
  Result := GFailed = 0;
end;

procedure RunConfig(const ALabel: string; const AWordCount: Integer;
  const AStrategy: TXwStrategy; const ALongestFirst: Boolean; const APasses: Integer);
var
  LLang: IXwLang;
  LFactory: IXwWordFactory;
  LBoard: IXwBoard;
  LWords: TArray<IXwWord>;
  LSide: Integer;
  LWatch: TStopwatch;
  LMetrics: TXwMetrics;
  LMsg: string;
begin
  LLang := TXwLangPL.Create(True);
  LFactory := TXwWordFactory.Create(LLang);
  LWords := XwBuildWords(LFactory, AWordCount);
  if ALongestFirst then
    LWords := XwSortLongestFirst(LWords);

  LSide := TXwGenerator.ArenaSideFor(LWords);
  LBoard := TXwBoard.Create(LSide, LSide, LLang);
  LBoard.Strategy := AStrategy;

  LWatch := TStopwatch.StartNew;
  XwFillBoard(LBoard, LWords, APasses);
  LWatch.Stop;

  LMetrics := XwMeasure(LBoard, Length(LWords));
  LMetrics.ElapsedMs := LWatch.Elapsed.TotalMilliseconds;

  Writeln(LMetrics.AsRow(ALabel));

  if not XwValidateBoard(LBoard, LMsg) then
    Writeln('    !!! NIEPOPRAWNA PLANSZA: ' + LMsg);
end;

procedure WriteAggHeader;
begin
  Writeln('  wariant                    slowa   pokr   interl  wypeln  prop   d1  >lim    TOTAL   odch     ms');
  Writeln('  --------------------------------------------------------------------------------------------------');
end;

procedure RunGen(const ATag: string; const AWordCount: Integer;
  const AOptions: TXwGenOptions; const ASeeds: Integer);
var
  LLang: IXwLang;
  LFactory: IXwWordFactory;
  LWords: TArray<IXwWord>;
  LGen: TXwGenerator;
  LRes: TXwGenResult;
  LOpt: TXwGenOptions;
  LMsg, LLabel: string;
  K, LBad, LRuns, LAttempts: Integer;
  LTotals: TArray<Double>;
  LSumPlaced, LSumD1, LSumLong: Integer;
  LSumCov, LSumInt, LSumFill, LSumAsp, LSumTot, LSumMs: Double;
  LMean, LAcc, LSd: Double;
begin
  LRuns := ASeeds;
  if LRuns < 1 then LRuns := 1;

  LLang := TXwLangPL.Create(True);
  LFactory := TXwWordFactory.Create(LLang);
  LWords := XwBuildWords(LFactory, AWordCount);

  SetLength(LTotals, LRuns);
  LSumPlaced := 0;
  LSumD1 := 0;
  LSumLong := 0;
  LSumCov := 0;
  LSumInt := 0;
  LSumFill := 0;
  LSumAsp := 0;
  LSumTot := 0;
  LSumMs := 0;
  LBad := 0;
  LAttempts := 0;

  LGen := TXwGenerator.Create(LLang);
  try
    for K := 0 to LRuns - 1 do
    begin
      LOpt := AOptions;
      LOpt.Seed := AOptions.Seed + UInt64(K) * 7919;

      LRes := LGen.Generate(LWords, LOpt);

      LTotals[K] := LRes.Metrics.Total;
      Inc(LSumPlaced, LRes.Metrics.Placed);
      Inc(LSumD1, LRes.Metrics.Dead1);
      Inc(LSumLong, LRes.Metrics.LongRunWords);
      LSumCov := LSumCov + LRes.Metrics.Coverage;
      LSumInt := LSumInt + LRes.Metrics.Interlock;
      LSumFill := LSumFill + LRes.Metrics.FillRatio;
      LSumAsp := LSumAsp + LRes.Metrics.Aspect;
      LSumTot := LSumTot + LRes.Metrics.Total;
      LSumMs := LSumMs + LRes.ElapsedMs;
      LAttempts := LRes.Attempts;

      if not XwValidateBoard(LRes.Board, LMsg) then
        Inc(LBad);
    end;
  finally
    LGen.Free;
  end;

  LMean := LSumTot / LRuns;
  LAcc := 0;
  for K := 0 to LRuns - 1 do
    LAcc := LAcc + Sqr(LTotals[K] - LMean);
  if LRuns > 1 then
    LSd := Sqrt(LAcc / (LRuns - 1))
  else
    LSd := 0;

  LLabel := Format('%s p%d s%.0f x%d', [ATag, AOptions.SeedWordPool,
    AOptions.ScoreSlack, LAttempts]);

  Writeln(Format('  %-25s %5.1f %5.1f%%  %6.3f  %6.3f  %5.2f %4.1f %4.1f  %7.4f %6.4f %7.1f',
    [LLabel,
     LSumPlaced / LRuns, LSumCov / LRuns * 100,
     LSumInt / LRuns, LSumFill / LRuns, LSumAsp / LRuns,
     LSumD1 / LRuns, LSumLong / LRuns,
     LMean, LSd, LSumMs / LRuns]));

  if LBad > 0 then
    Writeln(Format('    !!! NIEPOPRAWNYCH PLANSZ: %d z %d', [LBad, LRuns]));
end;

procedure XwRunBenchmark(const AWordCount: Integer);
const
  CSEEDS = 5;
  CABLA  = 8;
var
  LOpt: TXwGenOptions;
begin
  Writeln('=== BASELINE (TryPlaceWord, jeden przebieg) ===');
  Writeln;
  Writeln(TXwMetrics.Header);

  RunConfig('firstfit wejscie x1', AWordCount, stFirstFit, False, 1);
  RunConfig('bestscore dlugie x1', AWordCount, stBestScore, True, 1);

  Writeln;
  Writeln(Format('=== GENERATOR: stara kontra nowa (srednia z %d ziaren) ===', [CSEEDS]));
  Writeln;
  WriteAggHeader;

  LOpt := TXwGenOptions.Deterministic;
  LOpt.RefineRounds := 0;
  LOpt.UseBoardScore := True;
  RunGen('stara ocena', AWordCount, LOpt, CSEEDS);

  LOpt := TXwGenOptions.Deterministic;
  LOpt.RefineRounds := 0;
  RunGen('nowa ocena', AWordCount, LOpt, CSEEDS);

  LOpt := TXwGenOptions.Standard;
  LOpt.MaxAttempts := 12;
  LOpt.RefineRounds := 0;
  LOpt.UseBoardScore := True;
  RunGen('stara ocena', AWordCount, LOpt, CSEEDS);

  LOpt := TXwGenOptions.Standard;
  LOpt.MaxAttempts := 12;
  LOpt.RefineRounds := 0;
  RunGen('nowa ocena', AWordCount, LOpt, CSEEDS);

  Writeln;
  Writeln(Format('=== ABLACJA nowej bazy (12 prob, srednia z %d ziaren) ===', [CABLA]));
  Writeln;
  WriteAggHeader;

  LOpt := TXwGenOptions.Standard;
  LOpt.MaxAttempts := 12;
  LOpt.RefineRounds := 0;
  RunGen('nowa baza', AWordCount, LOpt, CABLA);

  LOpt := TXwGenOptions.Standard;
  LOpt.MaxAttempts := 12;
  LOpt.RefineRounds := 0;
  LOpt.Score := TXwScoreWeights.Legacy;
  RunGen('tylko cross+growth', AWordCount, LOpt, CABLA);

  LOpt := TXwGenOptions.Standard;
  LOpt.MaxAttempts := 12;
  LOpt.RefineRounds := 0;
  LOpt.Score.Potential := 0.0;
  RunGen('bez potencjalu', AWordCount, LOpt, CABLA);

  LOpt := TXwGenOptions.Standard;
  LOpt.MaxAttempts := 12;
  LOpt.RefineRounds := 0;
  LOpt.Score.Aspect := 0.0;
  RunGen('bez kary ksztalt', AWordCount, LOpt, CABLA);

  LOpt := TXwGenOptions.Standard;
  LOpt.MaxAttempts := 12;
  LOpt.RefineRounds := 0;
  LOpt.Score.Growth := 0.0;
  RunGen('bez kary wzrost', AWordCount, LOpt, CABLA);

  Writeln;
  Writeln(Format('=== ETAP F: przebieg poprawkowy (srednia z %d ziaren) ===', [CABLA]));
  Writeln;
  WriteAggHeader;

  LOpt := TXwGenOptions.Standard;
  LOpt.MaxAttempts := 12;
  LOpt.RefineRounds := 0;
  RunGen('12 prob, bez poprawek', AWordCount, LOpt, CABLA);

  LOpt := TXwGenOptions.Standard;
  LOpt.MaxAttempts := 12;
  LOpt.RefineRounds := 2;
  RunGen('12 prob, poprawki x2', AWordCount, LOpt, CABLA);

  LOpt := TXwGenOptions.Standard;
  LOpt.MaxAttempts := 3;
  LOpt.RefineRounds := 4;
  RunGen('3 proby, poprawki x4', AWordCount, LOpt, CABLA);

  LOpt := TXwGenOptions.Standard;
  LOpt.MaxAttempts := 1;
  LOpt.RefineRounds := 4;
  RunGen('1 proba, poprawki x4', AWordCount, LOpt, CABLA);

  LOpt := TXwGenOptions.Standard;
  LOpt.MaxAttempts := 24;
  LOpt.RefineRounds := 4;
  RunGen('24 proby, poprawki x4', AWordCount, LOpt, CABLA);

  Writeln;
  Writeln(Format('=== KOMPROMIS: waga Run przy stalej miarce (limit ciagu = %d) ===',
    [TXwMetricWeights.Standard.MaxRunLimit]));
  Writeln;
  Writeln('  patrz na >lim (slow z dlugim ciagiem) kontra interl (plecionka)');
  Writeln;
  WriteAggHeader;

  LOpt := TXwGenOptions.Standard;
  LOpt.MaxAttempts := 12;
  LOpt.RefineRounds := 0;
  LOpt.Score.Run := 0.0;
  RunGen('run 0.0', AWordCount, LOpt, CABLA);

  LOpt := TXwGenOptions.Standard;
  LOpt.MaxAttempts := 12;
  LOpt.RefineRounds := 0;
  LOpt.Score.Run := 1.0;
  RunGen('run 1.0', AWordCount, LOpt, CABLA);

  LOpt := TXwGenOptions.Standard;
  LOpt.MaxAttempts := 12;
  LOpt.RefineRounds := 0;
  LOpt.Score.Run := 2.5;
  RunGen('run 2.5', AWordCount, LOpt, CABLA);

  LOpt := TXwGenOptions.Standard;
  LOpt.MaxAttempts := 12;
  LOpt.RefineRounds := 0;
  LOpt.Score.Run := 5.0;
  RunGen('run 5.0', AWordCount, LOpt, CABLA);

  LOpt := TXwGenOptions.Standard;
  LOpt.MaxAttempts := 12;
  LOpt.RefineRounds := 0;
  LOpt.Score.Run := 10.0;
  RunGen('run 10.0', AWordCount, LOpt, CABLA);

  Writeln;
end;

procedure XwPrintSample(const AWordCount: Integer);
var
  LLang: IXwLang;
  LFactory: IXwWordFactory;
  LWords: TArray<IXwWord>;
  LGen: TXwGenerator;
  LOpt: TXwGenOptions;
  LRes: TXwGenResult;
begin
  LLang := TXwLangPL.Create(True);
  LFactory := TXwWordFactory.Create(LLang);
  LWords := XwBuildWords(LFactory, AWordCount);

  LOpt := TXwGenOptions.Standard;
  LOpt.MaxAttempts := 48;
  LOpt.SeedWordPool := 24;

  LGen := TXwGenerator.Create(LLang);
  try
    LRes := LGen.Generate(LWords, LOpt);

    Writeln('=== PRZYKLADOWA PLANSZA ===');
    Writeln;
    LRes.Board.PrintToConsole(True);
    Writeln;
    Write(LRes.Metrics.AsText);
    Writeln(Format('  proby          %d,  przestawien %d,  enumeracji %d',
      [LRes.Attempts, LRes.Relocations, LRes.Enumerations]));
    Writeln;
  finally
    LGen.Free;
  end;
end;

end.

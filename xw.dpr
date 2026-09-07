program xw;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Winapi.Windows,
  Xw.Anchors in 'src\Xw.Anchors.pas',
  Xw.Board in 'src\Xw.Board.pas',
  Xw.Contracts in 'src\Xw.Contracts.pas',
  Xw.Corpus in 'src\Xw.Corpus.pas',
  Xw.Grid in 'src\Xw.Grid.pas',
  Xw.Langs in 'src\Xw.Langs.pas',
  Xw.Letter in 'src\Xw.Letter.pas',
  Xw.Metrics in 'src\Xw.Metrics.pas',
  Xw.Tests in 'src\Xw.Tests.pas',
  Xw.Word in 'src\Xw.Word.pas',
  Xw.Generator in 'src\Xw.Generator.pas',
  Sjp.Client in 'src\Sjp.Client.pas',
  Sjp.Contracts in 'src\Sjp.Contracts.pas',
  Sjp.Http in 'src\Sjp.Http.pas',
  Sjp.Parser in 'src\Sjp.Parser.pas',
  Sjp.Url in 'src\Sjp.Url.pas',
  Xw.Present in 'src\Xw.Present.pas',
  Xw.Game in 'src\Xw.Game.pas';

procedure Test;
const
  CCOUNT     = 100;
  CHINTS     = 4;
  CCANDIDATE : array [0 .. 1] of string =
    ('programowanie', 'delphi jest fajne');
var
  LLang: IXwLang;
  LClient: ISjpClient;
  LGen: TXwGenerator;
  LOpt: TXwGenOptions;
  LRes: TXwGenResult;
  LEntries: TXwEntries;
  LResponse: TSjpEntry;
  LPrint: TXwPrintBoard;
  LPlay: IXwPlayBoard;

  procedure Section(const ATitle: string);
  begin
    Writeln;
    Writeln('=== ' + ATitle + ' ===');
    Writeln;
  end;

  procedure FetchEntries;
  var
    K: Integer;
  begin
    SetLength(LEntries, CCOUNT);
    for K := 0 to CCOUNT - 1 do
    begin
      LResponse := LClient.GetRandom;
      LEntries[K].Phrase := LResponse.Term;

      if Length(LResponse.Meanings) > 0 then
        LEntries[K].Description := LResponse.Meanings[0]
      else
        LEntries[K].Description := '(brak definicji)';

      OutputDebugString(PChar(LResponse.Term));
    end;
  end;

  procedure ReportIntake;
  var
    K: Integer;
  begin
    Section(Format('WEJSCIE: przyjete %d, odrzucone %d',
      [LRes.Accepted, Length(LRes.Rejected)]));

    for K := 0 to High(LRes.Rejected) do
      Writeln(Format('  "%s" -> %s',
        [LRes.Rejected[K].Phrase, LRes.Rejected[K].Reason]));

    if Length(LRes.Rejected) = 0 then
      Writeln('  wszystkie frazy zaakceptowane');
  end;

  function ApplySolution: Boolean;
  var
    K: Integer;
  begin
    for K := 0 to High(CCANDIDATE) do
      if LRes.Board.TrySetSolution(CCANDIDATE[K]) then
        Exit(True);
    Result := False;
  end;

  procedure ShowBoard;
  begin
    Section(Format('PLANSZA %d x %d', [LPrint.Width, LPrint.Height]));
    XwWriteLines(XwRenderBoard(LPrint, rmLetters));

    Section('DO WYDRUKU (bez liter)');
    XwWriteLines(XwRenderBoard(LPrint, rmBlank));

    Section('NUMERY HASEL');
    XwWriteLines(XwRenderBoard(LPrint, rmNumbers));

    if LPrint.Solution <> '' then
    begin
      Section('HASLO: ' + LPrint.Solution);
      XwWriteLines(XwRenderBoard(LPrint, rmSolution));
    end
    else
    begin
      Section('HASLO');
      Writeln('  zadne z kandydujacych hasel nie zmiescilo sie na planszy');
    end;
  end;

  procedure ShowClues;
  begin
    Section('LISTA PYTAN');
    XwWriteLines(XwRenderClues(LPrint));
  end;

  function FindPlayEntry(const ANumber: Integer;
    const ADirection: TXwWordDirection): IXwPlayEntry;
  var
    K: Integer;
  begin
    for K := 0 to LPlay.EntryCount - 1 do
      if (LPlay.Entries[K].Number = ANumber)
        and (LPlay.Entries[K].Direction = ADirection) then
        Exit(LPlay.Entries[K]);
    Result := nil;
  end;

  function IfThen(const AValue: Boolean; const ATrue, AFalse: string): string;
  begin
    if AValue then Result := ATrue else Result := AFalse;
  end;

  procedure PlayDemo;
  var
    LEntry: IXwPlayEntry;
    LFilled, K, P: Integer;
  begin
    LPlay := XwBuildPlay(LRes.Board, CHINTS);

    Section(Format('GRA: %d hasel, %d podpowiedzi',
      [LPlay.EntryCount, LPlay.HintsLeft]));

    while LPlay.TryHint do ;
    Writeln(Format('  wykorzystano %d podpowiedzi (priorytet: skrzyzowania)',
      [LPlay.HintsUsed]));
    Writeln('  male litery to podpowiedzi, duze to wpisy gracza');
    Writeln;
    XwWriteLines(XwRenderPlay(LPlay));

    LFilled := 0;
    for K := 0 to High(LPrint.Entries) do
    begin
      if LFilled >= 3 then Break;

      LEntry := FindPlayEntry(LPrint.Entries[K].Number,
        LPrint.Entries[K].Direction);
      if LEntry = nil then Continue;

      for P := 0 to LEntry.Length - 1 do
        LEntry[P].Guess := LPrint.Entries[K].Text[P + 1];

      Writeln(Format('  wpisano %d %s: %s -> rozwiazane: %s',
        [LPrint.Entries[K].Number,
         IfThen(LPrint.Entries[K].Direction = wdHorizontal, 'poziomo', 'pionowo'),
         LPrint.Entries[K].Text,
         BoolToStr(LEntry.IsSolved, True)]));

      Inc(LFilled);
    end;

    Writeln;
    XwWriteLines(XwRenderPlay(LPlay));
    Writeln;
    Writeln(Format('  cala plansza rozwiazana: %s',
      [BoolToStr(LPlay.IsSolved, True)]));

    LPlay.Reset;
    Writeln(Format('  po Reset: podpowiedzi %d, rozwiazane: %s',
      [LPlay.HintsLeft, BoolToStr(LPlay.IsSolved, True)]));
  end;

begin
  LLang := TXwLangPL.Create;
  LClient := TSjpClient.Create;

  FetchEntries;

  LGen := TXwGenerator.Create(LLang);
  try
    LOpt := TXwGenOptions.Standard;
    LRes := LGen.Generate(LEntries, LOpt);
  finally
    LGen.Free;
  end;

  ReportIntake;

  if LRes.Accepted < 2 then
  begin
    Writeln(Format('Za malo poprawnych slow: %d', [LRes.Accepted]));
    Exit;
  end;

  ApplySolution;
  LPrint := XwBuildPrint(LRes.Board);

  ShowBoard;
  ShowClues;

  Section('METRYKI');
  Write(LRes.Metrics.AsText);
  Writeln(Format('  proby          %d,  przestawien %d,  enumeracji %d',
    [LRes.Attempts, LRes.Relocations, LRes.Enumerations]));

  PlayDemo;
end;

begin
  try
    {XwRunUnitTests;
    XwRunBenchmark(120);
    XwPrintSample(45);}

    //Test;

    XwPlayInConsole;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;

  Write('ENTER konczy...');
  Readln;
end.

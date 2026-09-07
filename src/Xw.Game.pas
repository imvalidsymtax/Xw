unit Xw.Game;

interface

uses
  Xw.Contracts;

type
  TXwGetEntry = reference to function(out AEntry: TXwEntry): Boolean;

procedure XwPlayInConsole(const AOnGetEntry: TXwGetEntry = nil);

implementation

uses
  System.SysUtils,
  System.StrUtils,
  System.Character,
  Xw.Langs,
  Xw.Corpus,
  Xw.Generator,
  Xw.Present;

procedure XwPlayInConsole(const AOnGetEntry: TXwGetEntry);
const
  CSOLUTIONPOOL  = 60;
  CCLUEWIDTH     = 64;
  CANIMMS        = 12;
  CSOLUTIONTRIES = 400;
  CFETCHFAILS    = 20;
var
  LLang: IXwLang;
  LGen: TXwGenerator;
  LOpt: TXwGenOptions;
  LRes: TXwGenResult;
  LWords: TXwEntries;
  LSolutions: TXwEntries;
  LPrint: TXwPrintBoard;
  LPlay: IXwPlayBoard;
  LWordCount, LHints, LTries: Integer;
  LLine, LStatus: string;
  LRunning: Boolean;

  function AskCount: Integer;
  var
    LText: string;
    LValue: Integer;
  begin
    Result := 30;
    if Assigned(AOnGetEntry) then
      Write('Ile slow (5..200, ENTER = 30)? ')
    else
      Write(Format('Ile slow (5..%d, ENTER = 30)? ', [XwCorpusCount]));

    Readln(LText);
    if LText.Trim = '' then Exit;
    if not TryStrToInt(LText.Trim, LValue) then Exit;

    if LValue < 5 then LValue := 5;
    if Assigned(AOnGetEntry) then
    begin
      if LValue > 200 then LValue := 200;
    end
    else
      if LValue > XwCorpusCount then LValue := XwCorpusCount;

    Result := LValue;
  end;

  function Fetch(const ACount: Integer): TXwEntries;
  var
    LEntry: TXwEntry;
    LTaken, LFails: Integer;
  begin
    SetLength(Result, ACount);
    LTaken := 0;
    LFails := 0;

    while (LTaken < ACount) and (LFails < CFETCHFAILS) do
    begin
      try
        if AOnGetEntry(LEntry) then
        begin
          Result[LTaken] := LEntry;
          Inc(LTaken);
          if LTaken mod 10 = 0 then
            Write('.');
          Continue;
        end;
      except
        on E: Exception do
          Writeln(Format(' blad pobierania: %s', [E.Message]));
      end;
      Inc(LFails);
    end;

    SetLength(Result, LTaken);
  end;

  procedure BuildPools;
  var
    LPool: TXwEntries;
    K: Integer;
  begin
    if not Assigned(AOnGetEntry) then
    begin
      LPool := XwCorpusEntries(XwCorpusCount);
      if LWordCount > Length(LPool) then
        LWordCount := Length(LPool);
    end
    else
    begin
      Write(Format('pobieram %d fraz ', [LWordCount + CSOLUTIONPOOL]));
      LPool := Fetch(LWordCount + CSOLUTIONPOOL);
      Writeln;
      Writeln(Format('  pobrano %d', [Length(LPool)]));
      if LWordCount > Length(LPool) then
        LWordCount := Length(LPool);
    end;

    SetLength(LWords, LWordCount);
    for K := 0 to LWordCount - 1 do
      LWords[K] := LPool[K];

    if Length(LPool) > LWordCount then
    begin
      SetLength(LSolutions, Length(LPool) - LWordCount);
      for K := 0 to High(LSolutions) do
        LSolutions[K] := LPool[LWordCount + K];
    end
    else
      LSolutions := LPool;
  end;

  procedure ReportIntake;
  var
    K: Integer;
  begin
    if Length(LRes.Rejected) = 0 then Exit;

    Writeln(Format('  odrzucono %d fraz:', [Length(LRes.Rejected)]));
    for K := 0 to High(LRes.Rejected) do
      Writeln(Format('    "%s" -> %s',
        [LRes.Rejected[K].Phrase, LRes.Rejected[K].Reason]));
  end;

  function DrawSolution: Boolean;
  var
    K: Integer;
  begin
    if Length(LSolutions) = 0 then Exit(False);

    for K := 1 to CSOLUTIONTRIES do
      if LRes.Board.TrySetSolution(
        LSolutions[Random(Length(LSolutions))].Phrase) then
        Exit(True);

    Result := False;
  end;

  function FindEntry(const ANumber: Integer;
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

  function SolutionSoFar: string;
  var
    LCell: IXwPlayCell;
    H, V: Integer;
  begin
    Result := StringOfChar('_', Length(LPrint.Solution));
    for V := 0 to LPlay.Height - 1 do
      for H := 0 to LPlay.Width - 1 do
      begin
        LCell := LPlay.CellAt(H, V);
        if LCell = nil then Continue;
        if LCell.SolutionOrder = 0 then Continue;
        if not LCell.IsFilled then Continue;
        Result[LCell.SolutionOrder] := LCell.Guess;
      end;
  end;

  procedure ShowGrid;
  begin
    Writeln;
    XwWriteLines(XwRenderPlayNumbered(LPlay));
    Writeln;
    if LPrint.Solution = '' then
      Writeln(Format('  podpowiedzi: %d', [LPlay.HintsLeft]))
    else
      Writeln(Format('  haslo: %s        podpowiedzi: %d',
        [SolutionSoFar, LPlay.HintsLeft]));
  end;

  procedure ShowClues;
  var
    LDir: TXwWordDirection;
    LEntry: IXwPlayEntry;
    K: Integer;
    LMark, LText: string;
  begin
    Writeln;
    for LDir := wdHorizontal to wdVertical do
    begin
      if LDir = wdHorizontal then
        Writeln('POZIOMO')
      else
        Writeln('PIONOWO');

      for K := 0 to High(LPrint.Entries) do
      begin
        if LPrint.Entries[K].Direction <> LDir then Continue;

        LEntry := FindEntry(LPrint.Entries[K].Number, LDir);
        if (LEntry <> nil) and LEntry.IsSolved then
          LMark := '+'
        else
          LMark := ' ';

        LText := LPrint.Entries[K].Description.Trim;
        if LText = '' then
          LText := '(bez definicji)'
        else if Length(LText) > CCLUEWIDTH then
          LText := Copy(LText, 1, CCLUEWIDTH - 3) + '...';

        Writeln(Format(' %s %2d %s  %-*s  (%d)',
          [LMark, LPrint.Entries[K].Number,
           IfThen(LDir = wdHorizontal, 'poz', 'pio'),
           CCLUEWIDTH, LText, LPrint.Entries[K].Length]));
      end;
    end;
  end;

  procedure ShowHelp;
  begin
    Writeln;
    Writeln('  3p KOT / 3v TOR  wpisz haslo poziome / pionowe');
    Writeln('  3p               wyczysc haslo');
    Writeln('  ?  podpowiedz    k  koniec');
  end;

  procedure Refresh;
  begin
    Writeln;
    Writeln(StringOfChar('-', 60));
    ShowGrid;
    ShowClues;
    ShowHelp;
  end;

  procedure Reveal;
  begin
    Writeln;
    Writeln('rozwiazanie:');
    Writeln;
    XwWriteLinesAnimated(XwRenderBoard(LPrint, rmLetters), CANIMMS, 3);
    if LPrint.Solution <> '' then
    begin
      Writeln;
      Writeln('haslo: ' + LPrint.Solution);
    end;
  end;

  function ApplyEntry(const ACommand: string): string;
  var
    LEntry: IXwPlayEntry;
    LDirection: TXwWordDirection;
    LNumber, LAt, K: Integer;
    LDigits, LAnswer, LName: string;
    LBefore: TArray<Char>;
  begin
    Result := '';
    LAt := 1;
    LDigits := '';
    while (LAt <= Length(ACommand)) and ACommand[LAt].IsDigit do
    begin
      LDigits := LDigits + ACommand[LAt];
      Inc(LAt);
    end;

    if (LDigits = '') or (LAt > Length(ACommand)) then
      Exit('nie rozumiem, wpisz np.  3p KOT');

    case ACommand[LAt].ToLower of
      'p': LDirection := wdHorizontal;
      'v': LDirection := wdVertical;
    else
      Exit('kierunek to p (poziomo) albo v (pionowo)');
    end;

    LNumber := StrToInt(LDigits);
    LEntry := FindEntry(LNumber, LDirection);
    if LEntry = nil then
      Exit(Format('nie ma hasla %d%s', [LNumber, ACommand[LAt]]));

    LName := Format('%d %s', [LNumber,
      IfThen(LDirection = wdHorizontal, 'poziomo', 'pionowo')]);

    LAnswer := LLang.Normalize(Copy(ACommand, LAt + 1, MaxInt));

    if LAnswer = '' then
    begin
      for K := 0 to LEntry.Length - 1 do
        LEntry[K].Guess := #0;
      Exit(Format('%s wyczyszczone', [LName]));
    end;

    if Length(LAnswer) <> LEntry.Length then
      Exit(Format('%s ma %d liter, a "%s" ma %d - nie wpisano',
        [LName, LEntry.Length, LAnswer, Length(LAnswer)]));

    SetLength(LBefore, LEntry.Length);
    for K := 0 to LEntry.Length - 1 do
      LBefore[K] := LEntry[K].Guess;

    for K := 0 to LEntry.Length - 1 do
      LEntry[K].Guess := LAnswer[K + 1];

    if LEntry.IsSolved then
    begin
      Result := Format('%s: TRAFIONE', [LName]);
      Exit;
    end;

    for K := 0 to LEntry.Length - 1 do
      LEntry[K].Guess := LBefore[K];

    Result := Format('%s: "%s" nie pasuje - plansza bez zmian',
      [LName, LAnswer]);
  end;

begin
  Randomize;

  LLang := TXwLangPL.Create(True);
  LWordCount := AskCount;

  Writeln;
  BuildPools;

  if Length(LWords) < 2 then
  begin
    Writeln('Za malo fraz zeby cokolwiek ulozyc.');
    Exit;
  end;

  Writeln('generuje...');

  LGen := TXwGenerator.Create(LLang);
  try
    LOpt := TXwGenOptions.Standard;
    LOpt.Seed := UInt64(Random(MaxInt)) + 1;
    LRes := LGen.Generate(LWords, LOpt);
  finally
    LGen.Free;
  end;

  ReportIntake;

  if LRes.Accepted < 2 then
  begin
    Writeln('Za malo poprawnych slow.');
    Exit;
  end;

  LTries := 0;
  while not DrawSolution do
  begin
    Inc(LTries);
    if LTries >= 3 then
    begin
      Writeln('Nie udalo sie wylosowac hasla mieszczacego sie na planszy.');
      Break;
    end;
  end;

  LPrint := XwBuildPrint(LRes.Board);
  LHints := 3 + LRes.Metrics.Placed div 20;
  LPlay := XwBuildPlay(LRes.Board, LHints);

  Writeln;
  Writeln(Format('Plansza %d x %d, %d hasel, haslo na %d liter.',
    [LPrint.Width, LPrint.Height, LPlay.EntryCount, Length(LPrint.Solution)]));
  Writeln;
  XwWriteLinesAnimated(XwRenderPlayNumbered(LPlay), CANIMMS);

  Refresh;

  LStatus := '';
  LRunning := True;
  while LRunning do
  begin
    Writeln;
    Write('> ');
    Readln(LLine);
    LLine := LLine.Trim;

    if LLine = '' then
      Continue
    else if SameText(LLine, 'k') then
      LRunning := False
    else if LLine = '?' then
    begin
      if LPlay.TryHint then
        LStatus := 'podpowiedz naniesiona'
      else
        LStatus := 'brak podpowiedzi albo nie ma czego podpowiedziec';
      Refresh;
    end
    else
    begin
      LStatus := ApplyEntry(LLine);
      Refresh;
    end;

    if LStatus <> '' then
    begin
      Writeln;
      Writeln('>>> ' + LStatus);
      LStatus := '';
    end;

    if LRunning and LPlay.IsSolved then
    begin
      Writeln;
      Writeln('Cala krzyzowka rozwiazana.');
      if LPrint.Solution <> '' then
        Writeln('Haslo: ' + SolutionSoFar);
      LRunning := False;
    end;
  end;

  Reveal;
end;

end.

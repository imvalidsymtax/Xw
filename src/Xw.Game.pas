unit Xw.Game;

interface

procedure XwPlayInConsole;

implementation

uses
  System.SysUtils,
  System.Character,
  Xw.Contracts,
  Xw.Langs,
  Xw.Corpus,
  Xw.Generator,
  Xw.Present;

procedure XwPlayInConsole;
const
  CSOLUTIONTRIES = 400;
var
  LLang: IXwLang;
  LGen: TXwGenerator;
  LOpt: TXwGenOptions;
  LRes: TXwGenResult;
  LPool: TXwEntries;
  LPrint: TXwPrintBoard;
  LPlay: IXwPlayBoard;
  LWordCount, LHints, LTries: Integer;
  LLine: string;
  LRunning: Boolean;

  function AskCount: Integer;
  var
    LText: string;
    LValue: Integer;
  begin
    Result := 30;
    Write(Format('Ile slow (5..%d, ENTER = 30)? ', [XwCorpusCount]));
    Readln(LText);
    if LText.Trim = '' then Exit;
    if not TryStrToInt(LText.Trim, LValue) then Exit;
    if LValue < 5 then LValue := 5;
    if LValue > XwCorpusCount then LValue := XwCorpusCount;
    Result := LValue;
  end;

  function DrawSolution: Boolean;
  var
    K: Integer;
  begin
    for K := 1 to CSOLUTIONTRIES do
      if LRes.Board.TrySetSolution(LPool[Random(Length(LPool))].Phrase) then
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
    Writeln(Format('  haslo: %s        podpowiedzi: %d',
      [SolutionSoFar, LPlay.HintsLeft]));
  end;

  procedure ShowClues;
  var
    LDir: TXwWordDirection;
    LEntry: IXwPlayEntry;
    K: Integer;
    LMark: string;
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

        Writeln(Format(' %s %d. %s (%d liter)',
          [LMark, LPrint.Entries[K].Number,
           LPrint.Entries[K].Description, LPrint.Entries[K].Length]));
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
    XwWriteLines(XwRenderBoard(LPrint, rmLetters));
    Writeln;
    Writeln('haslo: ' + LPrint.Solution);
  end;

  procedure ApplyEntry(const ACommand: string);
  var
    LEntry: IXwPlayEntry;
    LDirection: TXwWordDirection;
    LNumber, LAt, K: Integer;
    LDigits, LAnswer: string;
  begin
    LAt := 1;
    LDigits := '';
    while (LAt <= Length(ACommand)) and ACommand[LAt].IsDigit do
    begin
      LDigits := LDigits + ACommand[LAt];
      Inc(LAt);
    end;

    if (LDigits = '') or (LAt > Length(ACommand)) then
    begin
      Writeln('  nie rozumiem, wpisz np.  3p KOT');
      Exit;
    end;

    case ACommand[LAt].ToLower of
      'p': LDirection := wdHorizontal;
      'v': LDirection := wdVertical;
    else
      Writeln('  kierunek to p (poziomo) albo v (pionowo)');
      Exit;
    end;

    LNumber := StrToInt(LDigits);
    LEntry := FindEntry(LNumber, LDirection);
    if LEntry = nil then
    begin
      Writeln(Format('  nie ma hasla %d%s', [LNumber, ACommand[LAt]]));
      Exit;
    end;

    LAnswer := LLang.Normalize(Copy(ACommand, LAt + 1, MaxInt));

    if LAnswer = '' then
    begin
      for K := 0 to LEntry.Length - 1 do
        LEntry[K].Guess := #0;
      Writeln('  wyczyszczone');
      Exit;
    end;

    if Length(LAnswer) <> LEntry.Length then
    begin
      Writeln(Format('  to haslo ma %d liter, podales %d',
        [LEntry.Length, Length(LAnswer)]));
      Exit;
    end;

    for K := 0 to LEntry.Length - 1 do
      LEntry[K].Guess := LAnswer[K + 1];

    if LEntry.IsSolved then
      Writeln('  trafione')
    else
      Writeln('  wpisane');
  end;

begin
  Randomize;

  LLang := TXwLangPL.Create(True);
  LWordCount := AskCount;
  LPool := XwCorpusEntries(XwCorpusCount);

  Writeln;
  Writeln('generuje...');

  LGen := TXwGenerator.Create(LLang);
  try
    LOpt := TXwGenOptions.Standard;
    LOpt.Seed := UInt64(Random(MaxInt)) + 1;
    LRes := LGen.Generate(XwCorpusEntries(LWordCount), LOpt);
  finally
    LGen.Free;
  end;

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

  Refresh;

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
        Writeln('  podpowiedz naniesiona')
      else
        Writeln('  brak podpowiedzi albo nie ma czego podpowiedziec');
      Refresh;
    end
    else
    begin
      ApplyEntry(LLine);
      Refresh;
    end;

    if LRunning and LPlay.IsSolved then
    begin
      Writeln;
      Writeln('Cala krzyzowka rozwiazana.');
      Writeln('Haslo: ' + SolutionSoFar);
      LRunning := False;
    end;
  end;

  Reveal;
end;

end.

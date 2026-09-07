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
  Sjp.Url in 'src\Sjp.Url.pas';

procedure Test;
const
  CCOUNT = 50;
var
  LLang: IXwLang;
  LClient: ISjpClient;
  LGen: TXwGenerator;
  LOpt: TXwGenOptions;
  LRes: TXwGenResult;
  LEntries: TXwEntries;
  LResponse: TSjpEntry;
  I: Integer;
begin
  LLang := TXwLangPL.Create;
  LClient := TSjpClient.Create;

  SetLength(LEntries, CCOUNT);
  for I := 0 to CCOUNT - 1 do
  begin
    LResponse := LClient.GetRandom;
    LEntries[I].Phrase := LResponse.Term;
    LEntries[I].Description := LResponse.Meanings[0];
  end;

  LGen := TXwGenerator.Create(LLang);
  try
    LOpt := TXwGenOptions.Standard;
    LRes := LGen.Generate(LEntries, LOpt);
  finally
    LGen.Free;
  end;

  for I := 0 to High(LRes.Rejected) do
    OutputDebugString(PChar(Format('odrzucone "%s": %s',
      [LRes.Rejected[I].Phrase, LRes.Rejected[I].Reason])));

  if LRes.Accepted < 2 then
  begin
    Writeln(Format('Za malo poprawnych slow: %d', [LRes.Accepted]));
    Exit;
  end;

  LRes.Board.PrintToConsole(True);
  Writeln;
  Write(LRes.Metrics.AsText);
  Writeln(Format('  przyjete       %d,  odrzucone %d,  przestawien %d',
    [LRes.Accepted, Length(LRes.Rejected), LRes.Relocations]));
end;

begin
  try
    XwRunUnitTests;
    XwRunBenchmark(120);
    XwPrintSample(45);
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;

  Write('ENTER konczy...');
  Readln;
end.

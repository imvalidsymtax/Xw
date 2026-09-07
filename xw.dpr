program xw;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
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

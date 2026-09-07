unit Sjp.Parser;

interface

uses
  Sjp.Contracts;

type
  TSjpParser = class(TInterfacedObject, ISjpParser)
  strict private const
    TermPattern = '<h1[^>]*>(.*?)</h1>';
    RowPattern = '<tr[^>]*>(.*?)</tr>';
    CellPattern = '<t[dh][^>]*>(.*?)</t[dh]>';
    MeaningsBlockPattern = 'znaczenie\s*:(.*?)(?:POWI\u0104ZANE|KOMENTARZE|<hr|</body)';
    MeaningsSplitPattern = '\s*\d+\.\s*';
    RelatedBlockPattern = 'POWI\u0104ZANE HAS\u0141A(.*?)(?:KOMENTARZE|<hr|</body)';
    RelatedItemPattern = '<a[^>]*>(.*?)</a>';
    AllowedPattern = '(?<!nie)dopuszczalne w grach';
    SourcesRow = 'wyst\u0119powanie';
    InflectedRow = 'odmienno\u015B\u0107';
    UpdatedRow = 'aktualizacja';
  strict private
    type
      TSjpRow = record
        Name: string;
        Value: string;
      end;
    function ParseTerm(const AHtml: string): string;
    function ParseRows(const AHtml: string): TArray<TSjpRow>;
    function RowValue(const ARows: TArray<TSjpRow>; const AName: string): string;
    function IsMetaRow(const AName: string): Boolean;
    function ParseFormGroups(const ARows: TArray<TSjpRow>): TArray<TSjpFormGroup>;
    function ParseMeanings(const AHtml: string): TArray<string>;
    function ParseRelated(const AHtml: string): TArray<string>;
  public
    function Parse(const AHtml: string): TSjpEntry;
  end;

  TSjpHtml = record
    class function Text(const AHtml: string): string; static;
    class function TryMatch(const AHtml, APattern: string; out AValue: string): Boolean; static;
    class function Matches(const AHtml, APattern: string): TArray<string>; static;
    class function Contains(const AHtml, APattern: string): Boolean; static;
    class function Split(const AValue: string; ADelimiter: Char): TArray<string>; static;
  end;

implementation

uses
  System.SysUtils, System.RegularExpressions, System.NetEncoding;

function TSjpParser.Parse(const AHtml: string): TSjpEntry;
var
  LRows: TArray<TSjpRow>;
begin
  if AHtml.Trim = '' then
    raise ESjpParseError.Create('Pusty dokument');

  Result := Default(TSjpEntry);
  Result.Term := ParseTerm(AHtml);

  LRows := ParseRows(AHtml);
  Result.Sources := TSjpHtml.Split(RowValue(LRows, SourcesRow), ';');
  Result.Inflected := SameText(RowValue(LRows, InflectedRow), 'tak');
  Result.UpdatedAt := RowValue(LRows, UpdatedRow);
  Result.FormGroups := ParseFormGroups(LRows);

  Result.AllowedInGames := TSjpHtml.Contains(AHtml, AllowedPattern);
  Result.Meanings := ParseMeanings(AHtml);
  Result.Related := ParseRelated(AHtml);
end;

function TSjpParser.ParseTerm(const AHtml: string): string;
var
  LRaw: string;
begin
  if not TSjpHtml.TryMatch(AHtml, TermPattern, LRaw) then
    raise ESjpParseError.Create('Nie znaleziono naglowka <h1>');

  Result := TSjpHtml.Text(LRaw);
  if Result = '' then
    raise ESjpParseError.Create('Naglowek <h1> jest pusty');
end;

function TSjpParser.ParseRows(const AHtml: string): TArray<TSjpRow>;
var
  LRowHtml: string;
  LCells: TArray<string>;
  LRow: TSjpRow;
begin
  Result := [];
  for LRowHtml in TSjpHtml.Matches(AHtml, RowPattern) do
  begin
    LCells := TSjpHtml.Matches(LRowHtml, CellPattern);
    if Length(LCells) < 2 then
      Continue;

    LRow.Name := TSjpHtml.Text(LCells[0]);
    LRow.Value := TSjpHtml.Text(LCells[1]);
    if LRow.Name <> '' then
      Result := Result + [LRow];
  end;
end;

function TSjpParser.RowValue(const ARows: TArray<TSjpRow>; const AName: string): string;
var
  LRow: TSjpRow;
begin
  for LRow in ARows do
    if SameText(LRow.Name, AName) then
      Exit(LRow.Value);
  Result := '';
end;

function TSjpParser.IsMetaRow(const AName: string): Boolean;
begin
  Result := SameText(AName, SourcesRow) or SameText(AName, InflectedRow) or
    SameText(AName, UpdatedRow);
end;

function TSjpParser.ParseFormGroups(const ARows: TArray<TSjpRow>): TArray<TSjpFormGroup>;
var
  LRow: TSjpRow;
  LGroup: TSjpFormGroup;
begin
  Result := [];
  for LRow in ARows do
  begin
    if IsMetaRow(LRow.Name) or (LRow.Value = '') then
      Continue;

    LGroup.Category := LRow.Name;
    LGroup.Forms := TSjpHtml.Split(LRow.Value, ',');
    if Length(LGroup.Forms) > 0 then
      Result := Result + [LGroup];
  end;
end;

function TSjpParser.ParseMeanings(const AHtml: string): TArray<string>;
var
  LBlock, LPart: string;
begin
  Result := [];
  if not TSjpHtml.TryMatch(AHtml, MeaningsBlockPattern, LBlock) then
    Exit;

  for LPart in TRegEx.Split(TSjpHtml.Text(LBlock), MeaningsSplitPattern) do
    if LPart.Trim <> '' then
      Result := Result + [LPart.Trim.TrimRight([';', '.', ' '])];
end;

function TSjpParser.ParseRelated(const AHtml: string): TArray<string>;
var
  LBlock, LItem, LText: string;
begin
  Result := [];
  if not TSjpHtml.TryMatch(AHtml, RelatedBlockPattern, LBlock) then
    Exit;

  for LItem in TSjpHtml.Matches(LBlock, RelatedItemPattern) do
  begin
    LText := TSjpHtml.Text(LItem);
    if LText <> '' then
      Result := Result + [LText];
  end;
end;

const
  Options = [roIgnoreCase, roSingleLine];
  NoBreakSpace = #$00A0;

class function TSjpHtml.Text(const AHtml: string): string;
begin
  Result := TRegEx.Replace(AHtml, '<[^>]*>', ' ');
  Result := TNetEncoding.HTML.Decode(Result);
  Result := Result.Replace(NoBreakSpace, ' ', [rfReplaceAll]);
  Result := TRegEx.Replace(Result, '\s+', ' ');
  Result := Result.Trim;
end;

class function TSjpHtml.TryMatch(const AHtml, APattern: string;
  out AValue: string): Boolean;
var
  LMatch: TMatch;
begin
  LMatch := TRegEx.Match(AHtml, APattern, Options);
  Result := LMatch.Success;
  if Result then
    AValue := LMatch.Groups[1].Value
  else
    AValue := '';
end;

class function TSjpHtml.Matches(const AHtml, APattern: string): TArray<string>;
var
  LMatch: TMatch;
begin
  Result := [];
  LMatch := TRegEx.Match(AHtml, APattern, Options);
  while LMatch.Success do
  begin
    Result := Result + [LMatch.Groups[1].Value];
    LMatch := LMatch.NextMatch;
  end;
end;

class function TSjpHtml.Contains(const AHtml, APattern: string): Boolean;
begin
  Result := TRegEx.IsMatch(AHtml, APattern, Options);
end;

class function TSjpHtml.Split(const AValue: string; ADelimiter: Char): TArray<string>;
var
  LPart: string;
begin
  Result := [];
  if AValue.Trim = '' then
    Exit;

  for LPart in AValue.Split([ADelimiter]) do
    if LPart.Trim <> '' then
      Result := Result + [LPart.Trim];
end;

end.

unit Sjp.Contracts;

interface

uses
  System.SysUtils;

type
  ESjpError = class(Exception);

  ESjpParseError = class(ESjpError);

  ESjpHttpError = class(ESjpError)
  strict private
    FStatusCode: Integer;
    FURL: string;
  public
    constructor Create(AStatusCode: Integer; const AURL: string);
    property StatusCode: Integer read FStatusCode;
    property URL: string read FURL;
  end;

  TSjpFormGroup = record
    Category: string;
    Forms: TArray<string>;
  end;

  TSjpEntry = record
    Term: string;
    AllowedInGames: Boolean;
    Inflected: Boolean;
    Sources: TArray<string>;
    FormGroups: TArray<TSjpFormGroup>;
    Meanings: TArray<string>;
    Related: TArray<string>;
    UpdatedAt: string;
    function IsEmpty: Boolean;
    function AllForms: TArray<string>;
  end;

  ISjpHttpClient = interface
    ['{6F2A1C34-9B7D-4E58-A0C1-3D8E5F71B204}']
    function Get(const AURL: string): string;
  end;

  ISjpParser = interface
    ['{1B93D47E-25AF-4C06-8E9B-7A0C6D2F5813}']
    function Parse(const AHtml: string): TSjpEntry;
  end;

  ISjpClient = interface
    ['{E840B5C7-31D2-4A9F-B6E3-0C15A97D4E62}']
    function GetRandom: TSjpEntry;
    function GetEntry(const ATerm: string): TSjpEntry;
  end;

implementation

{ ESjpHttpError }

constructor ESjpHttpError.Create(AStatusCode: Integer; const AURL: string);
begin
  inherited CreateFmt('HTTP %d dla %s', [AStatusCode, AURL]);
  FStatusCode := AStatusCode;
  FURL := AURL;
end;

{ TSjpEntry }

function TSjpEntry.IsEmpty: Boolean;
begin
  Result := Term.Trim = '';
end;

function TSjpEntry.AllForms: TArray<string>;
var
  LGroup: TSjpFormGroup;
  LForm: string;
  LIndex: Integer;
  LTotal: Integer;
begin
  LTotal := 0;
  for LGroup in FormGroups do
    Inc(LTotal, Length(LGroup.Forms));

  SetLength(Result, LTotal);
  LIndex := 0;
  for LGroup in FormGroups do
    for LForm in LGroup.Forms do
    begin
      Result[LIndex] := LForm;
      Inc(LIndex);
    end;
end;

end.

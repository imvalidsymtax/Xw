unit Sjp.Client;

interface

uses
  Sjp.Contracts;

type
  TSjpClient = class(TInterfacedObject, ISjpClient)
  strict private const
    BaseURL = 'https://sjp.pl';
    RandomPath = '/sl/los/';
  strict private
    FHttp: ISjpHttpClient;
    FParser: ISjpParser;
    function Fetch(const APath: string): TSjpEntry;
  public
    constructor Create; overload;
    constructor Create(const AHttp: ISjpHttpClient; const AParser: ISjpParser); overload;
    function GetRandom: TSjpEntry;
    function GetEntry(const ATerm: string): TSjpEntry;
  end;

implementation

uses
  System.SysUtils, System.NetEncoding, Sjp.Http, Sjp.Parser;

constructor TSjpClient.Create;
begin
  Create(TSjpHttpClient.Create, TSjpParser.Create);
end;

constructor TSjpClient.Create(const AHttp: ISjpHttpClient; const AParser: ISjpParser);
begin
  inherited Create;
  if AHttp = nil then
    raise ESjpError.Create('TSjpClient: brak implementacji ISjpHttpClient');
  if AParser = nil then
    raise ESjpError.Create('TSjpClient: brak implementacji ISjpParser');

  FHttp := AHttp;
  FParser := AParser;
end;

function TSjpClient.Fetch(const APath: string): TSjpEntry;
begin
  Result := FParser.Parse(FHttp.Get(BaseURL + APath));
end;

function TSjpClient.GetRandom: TSjpEntry;
begin
  Result := Fetch(RandomPath);
end;

function TSjpClient.GetEntry(const ATerm: string): TSjpEntry;
begin
  if ATerm.Trim = '' then
    raise ESjpError.Create('TSjpClient.GetEntry: puste haslo');

  Result := Fetch('/' + TNetEncoding.URL.EncodePath(ATerm.Trim));
end;

end.

unit Sjp.Http;

interface

uses
  System.Classes, System.Net.HttpClient, Sjp.Contracts;

type
  TSjpHttpClient = class(TInterfacedObject, ISjpHttpClient)
  strict private const
    MaxRedirects = 5;
    DefaultUserAgent = 'Mozilla/5.0 (compatible; SjpClient/1.0)';
  strict private
    FClient: THTTPClient;
    function NextLocation(const AURL: string; const AResponse: IHTTPResponse): string;
    function DecodeBody(AStream: TStream): string;
  public
    constructor Create;
    destructor Destroy; override;
    function Get(const AURL: string): string;
  end;

implementation

uses
  System.SysUtils, Sjp.Url;

constructor TSjpHttpClient.Create;
begin
  inherited Create;
  FClient := THTTPClient.Create;
  FClient.AutomaticDecompression := [THTTPCompressionMethod.Any];
  FClient.UserAgent := DefaultUserAgent;
  FClient.HandleRedirects := False;
end;

destructor TSjpHttpClient.Destroy;
begin
  FClient.Free;
  inherited;
end;

function TSjpHttpClient.NextLocation(const AURL: string;
  const AResponse: IHTTPResponse): string;
var
  LLocation: string;
begin
  LLocation := AResponse.HeaderValue['Location'];
  if LLocation = '' then
    raise ESjpError.CreateFmt('Przekierowanie bez naglowka Location: %s', [AURL]);
  Result := TSjpUrl.Resolve(AURL, TSjpUrl.EncodeRawBytes(LLocation));
end;

function TSjpHttpClient.DecodeBody(AStream: TStream): string;
var
  LBytes: TBytes;
begin
  AStream.Position := 0;
  SetLength(LBytes, AStream.Size);
  if Length(LBytes) > 0 then
    AStream.ReadBuffer(LBytes[0], Length(LBytes));
  Result := TEncoding.UTF8.GetString(LBytes);
end;

function TSjpHttpClient.Get(const AURL: string): string;
var
  LStream: TMemoryStream;
  LResponse: IHTTPResponse;
  LURL: string;
  LHop: Integer;
begin
  LStream := TMemoryStream.Create;
  try
    LURL := AURL;
    LResponse := nil;

    for LHop := 0 to MaxRedirects do
    begin
      LStream.Clear;
      LResponse := FClient.Get(LURL, LStream);
      if LResponse.StatusCode div 100 <> 3 then
        Break;
      LURL := NextLocation(LURL, LResponse);
    end;

    if LResponse.StatusCode div 100 = 3 then
      raise ESjpError.CreateFmt('Przekroczono limit przekierowan: %s', [LURL]);

    if LResponse.StatusCode <> 200 then
      raise ESjpHttpError.Create(LResponse.StatusCode, LURL);

    Result := DecodeBody(LStream);
  finally
    LStream.Free;
  end;
end;

end.

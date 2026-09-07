unit Sjp.Url;

interface

type
  TSjpUrl = record
    class function HasNonASCII(const AValue: string): Boolean; static;
    class function EncodeRawBytes(const AValue: string): string; static;
    class function Resolve(const ABase, ALocation: string): string; static;
  end;

implementation

uses
  System.SysUtils, System.Net.URLClient;

class function TSjpUrl.HasNonASCII(const AValue: string): Boolean;
var
  I: Integer;
begin
  for I := 1 to Length(AValue) do
    if Ord(AValue[I]) > 127 then
      Exit(True);
  Result := False;
end;

class function TSjpUrl.EncodeRawBytes(const AValue: string): string;
var
  LBytes: TBytes;
  LByte: Byte;
  LBuilder: TStringBuilder;
begin
  if not HasNonASCII(AValue) then
    Exit(AValue);

  LBytes := TEncoding.ANSI.GetBytes(AValue);

  LBuilder := TStringBuilder.Create;
  try
    for LByte in LBytes do
      if LByte < $80 then
        LBuilder.Append(Char(LByte))
      else
        LBuilder.Append('%').Append(IntToHex(LByte, 2));
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

class function TSjpUrl.Resolve(const ABase, ALocation: string): string;
var
  LBase: TURI;
begin
  if ALocation.StartsWith('http://', True) or ALocation.StartsWith('https://', True) then
    Exit(ALocation);

  LBase := TURI.Create(ABase);
  if ALocation.StartsWith('/') then
    Result := Format('%s://%s%s', [LBase.Scheme, LBase.Host, ALocation])
  else
    Result := Format('%s://%s/%s', [LBase.Scheme, LBase.Host, ALocation]);
end;

end.

unit Xw.Letter;

interface

uses
  Xw.Contracts,
  System.SysUtils;

type

  TXwLetter = class(TInterfacedObject, IXwLetter)
    strict private type
      TXwLetterMatchType = (lmtOriginal, lmtMatched);
      TXwLetterMatches = array [TXwLetterMatchType] of Char;
    strict private
      FLetter: TXwLetterMatches;
      FOnMatchProc: TProc;
      FUsedDirections: TXwWordDirections;
      FPositions: array [TXwWordDirection] of TXwLetterPosition;
    public
      constructor Create(const ALetter: Char; const AOnMatch: TProc = nil);

      procedure Match(const ALetter: Char);

      function GetPosition(const ADirection: TXwWordDirection): TXwLetterPosition;
      function GetIsFirst(const ADirection: TXwWordDirection): Boolean;
      function GetIsLast(const ADirection: TXwWordDirection): Boolean;

      function UsedDirections: TXwWordDirections;
      function IsCrossed: Boolean;
      procedure AddDirection(const ADirection: TXwWordDirection; const APosition: TXwLetterPosition);
      function CanAnchor(out ADirection: TXwWordDirection): Boolean;

      function IsGuessed: Boolean;
      function GetOriginal: Char;
      function GetMatched: Char;

      procedure Rebuild;
      procedure Reset;
  end;

implementation

const
  XW_ALL_DIRECTIONS = [wdHorizontal, wdVertical];

constructor TXwLetter.Create(const ALetter: Char; const AOnMatch: TProc);
begin
  inherited Create;
  FLetter[lmtOriginal] := ALetter;
  FLetter[lmtMatched] := #0;
  FUsedDirections := [];
  FPositions[wdHorizontal] := lpNone;
  FPositions[wdVertical] := lpNone;
  FOnMatchProc := AOnMatch;
end;

function TXwLetter.CanAnchor(out ADirection: TXwWordDirection): Boolean;
begin
  Result := (FUsedDirections <> []) and (FUsedDirections <> XW_ALL_DIRECTIONS);
  if Result then
    if wdHorizontal in FUsedDirections then
      ADirection := wdVertical
    else
      ADirection := wdHorizontal;
end;

function TXwLetter.IsCrossed: Boolean;
begin
  Result := FUsedDirections = XW_ALL_DIRECTIONS;
end;

procedure TXwLetter.AddDirection(const ADirection: TXwWordDirection; const APosition: TXwLetterPosition);
begin
  FPositions[ADirection] := APosition;
  FUsedDirections := FUsedDirections + [ADirection];
end;

function TXwLetter.GetPosition(const ADirection: TXwWordDirection): TXwLetterPosition;
begin
  Result := FPositions[ADirection];
end;

function TXwLetter.GetIsFirst(const ADirection: TXwWordDirection): Boolean;
begin
  Result := FPositions[ADirection] = lpFirst;
end;

function TXwLetter.GetIsLast(const ADirection: TXwWordDirection): Boolean;
begin
  Result := FPositions[ADirection] = lpLast;
end;

function TXwLetter.GetMatched: Char;
begin
  Result := FLetter[lmtMatched];
end;

function TXwLetter.GetOriginal: Char;
begin
  Result := FLetter[lmtOriginal];
end;

function TXwLetter.IsGuessed: Boolean;
begin
  Result := FLetter[lmtMatched] = FLetter[lmtOriginal];
end;

procedure TXwLetter.Match(const ALetter: Char);
begin
  FLetter[lmtMatched] := ALetter;
  if Assigned(FOnMatchProc) then FOnMatchProc();
end;

procedure TXwLetter.Rebuild;
begin
  FUsedDirections := [];
  FPositions[wdHorizontal] := lpNone;
  FPositions[wdVertical] := lpNone;
  Reset;
end;

procedure TXwLetter.Reset;
begin
  FLetter[lmtMatched] := #0;
end;

function TXwLetter.UsedDirections: TXwWordDirections;
begin
  Result := FUsedDirections;
end;

end.

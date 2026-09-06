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
      FLetterPositions: array [TXwWordDirection] of TXwLetterPosition;
    public

      function GetLetterPosition(const ADirection: TXwWordDirection): TXwLetterPosition;

      constructor Create(const ALetter: Char; const AOnMatch: TProc = nil);

      procedure Match(const ALetter: Char);

      function UsedDirections: TXwWordDirections;
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

{ TXwLetter }

function TXwLetter.CanAnchor(out ADirection: TXwWordDirection): Boolean;
begin
  Result := (FUsedDirections <> []) and (FUsedDirections <> XW_ALL_DIRECTIONS);
  if Result then
    if wdHorizontal in FUsedDirections then
      ADirection := wdVertical
    else
      ADirection := wdHorizontal;
end;

procedure TXwLetter.AddDirection(const ADirection: TXwWordDirection; const APosition: TXwLetterPosition);
begin
  FLetterPositions[ADirection] := APosition;
  FUsedDirections := FUsedDirections + [ADirection];
end;

constructor TXwLetter.Create(const ALetter: Char; const AOnMatch: TProc);
begin
  FLetter[lmtOriginal] := ALetter;
  FLetter[lmtMatched] := #0;

  FOnMatchProc := AOnMatch;
end;

function TXwLetter.GetLetterPosition(const ADirection: TXwWordDirection): TXwLetterPosition;
begin
  Result := FLetterPositions[ADirection];
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
  FLetterPositions[wdHorizontal] := lpNone;
  FLetterPositions[wdVertical] := lpNone;
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

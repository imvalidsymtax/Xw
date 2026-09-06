unit Xw.Contracts;

interface

uses
  System.SysUtils;

type

  EXwError = class(Exception);

  IXwWord = interface;
  IXwBoard = interface;

  TXwWordDirection = (
    wdHorizontal,
    wdVertical
  );

  TXwWordDirections = set of TXwWordDirection;

  TXwWordPlacement = record
    H, V: Integer;
    Direction: TXwWordDirection;
    StartIndex: Integer;
    Crossings: Integer;
    Rescue: Integer;
    MaxRun: Integer;
    CrossMask: UInt32;
    Score: Double;
  end;

  TXwPlacedWord = record
    Word: IXwWord;
    Placement: TXwWordPlacement;
  end;

  TXwLetterPosition = (lpNone, lpFirst, lpMiddle, lpLast);

  IXwLang = interface
    ['{A87D3B25-206A-4040-AF9D-D12014194029}']
    function GetName: string;
    property Name: string read GetName;

    function GetLetterCount: Integer;
    property LetterCount: Integer read GetLetterCount;
    function LetterAt(const AIndex: Integer): Char;
    function IndexOf(const ALetter: Char): Integer;

    function IsValid(const AWord: string; out AMessage: string): Boolean;
    function Normalize(const AWord: string): string; overload;
    function Normalize(const ALetter: Char): Char; overload;
    function TryPrepare(const ARaw: string; out AWord: string; out AMessage: string): Boolean;
  end;

  IXwLetter = interface
    ['{24E0A18A-ABFF-4293-9252-A5D965ACBEF9}']

    procedure Match(const ALetter: Char);

    function GetOriginal: Char;
    function GetMatched: Char;
    function IsGuessed: Boolean;

    function GetPosition(const ADirection: TXwWordDirection): TXwLetterPosition;
    function GetIsFirst(const ADirection: TXwWordDirection): Boolean;
    function GetIsLast(const ADirection: TXwWordDirection): Boolean;

    function UsedDirections: TXwWordDirections;
    function IsCrossed: Boolean;
    procedure AddDirection(const ADirection: TXwWordDirection; const APosition: TXwLetterPosition);
    function CanAnchor(out ADirection: TXwWordDirection): Boolean;

    property Original: Char read GetOriginal;
    property Matched: Char read GetMatched;

    property Position[const ADirection: TXwWordDirection]: TXwLetterPosition read GetPosition;
    property IsFirst[const ADirection: TXwWordDirection]: Boolean read GetIsFirst;
    property IsLast[const ADirection: TXwWordDirection]: Boolean read GetIsLast;

    procedure Rebuild;
    procedure Reset;
  end;

  IXwWord = interface
    ['{F7D57202-9DAA-4D1C-BE60-8DE1F2FF4371}']

    function IsGuessed: Boolean;

    function GetDescription: string;
    function GetWord: string;
    function GetLength: Integer;
    function GetLetter(const APosition: Integer): IXwLetter;
    procedure CrossAt(const APosition: Integer; const ALetter: IXwLetter);

    property Description: string read GetDescription;
    property Word: string read GetWord;
    property Length: Integer read GetLength;
    property Letters[const APosition: Integer]: IXwLetter read GetLetter; default;

    procedure Rebuild;
    procedure Reset;
  end;

  IXwWordFactory = interface
    ['{1A5A64DD-F44C-444C-A818-73CEBAAB4116}']

    function CreateWord(const AWord, ADescription: string): IXwWord;
  end;

  TXwBounds = record
    MinH, MaxH, MinV, MaxV: Integer;
    function IsEmpty: Boolean; inline;
    function Width: Integer; inline;
    function Height: Integer; inline;
    function Area: Integer; inline;
    function Contains(const AH, AV: Integer): Boolean; inline;
    class function CreateEmpty: TXwBounds; static;
  end;

  TXwStrategy = (stFirstFit, stBestScore);

  TXwBoardScore = record
    Words: Integer;
    Letters: Integer;
    Crossings: Integer;
    Area: Integer;
    Density: Double;
    Orphans: Integer;
    MinCross: Integer;
    AvgCross: Double;
    Total: Double;
  end;

  IXwBoard = interface
    ['{F160B342-2E13-4993-B545-E4717CA5A338}']

    function GetHSize: Integer;
    function GetVSize: Integer;
    property HSize: Integer read GetHSize;
    property VSize: Integer read GetVSize;

    function GetBounds: TXwBounds;
    property Bounds: TXwBounds read GetBounds;

    function GetOriginH: Integer;
    function GetOriginV: Integer;
    property OriginH: Integer read GetOriginH;
    property OriginV: Integer read GetOriginV;

    function LetterAt(const AH, AV: Integer): IXwLetter;
    function IsOccupied(const AH, AV: Integer): Boolean;

    function GetWordCount: Integer;
    function GetPlacedWord(const AIndex: Integer): TXwPlacedWord;
    property WordCount: Integer read GetWordCount;
    property PlacedWords[const AIndex: Integer]: TXwPlacedWord read GetPlacedWord;

    function TryPlaceWord(const AWord: IXwWord): Boolean;

    function GetStrategy: TXwStrategy;
    procedure SetStrategy(const Value: TXwStrategy);

    function GetWeightRescue: Double;
    procedure SetWeightRescue(const Value: Double);

    function Evaluate: TXwBoardScore;

    property Strategy: TXwStrategy read GetStrategy write SetStrategy;
    property WeightRescue: Double read GetWeightRescue write SetWeightRescue;

    procedure PrintToConsole(const ShowOriginal: Boolean);

    procedure Clear;
    procedure Reset;
  end;

implementation

class function TXwBounds.CreateEmpty: TXwBounds;
begin
  Result.MinH := MaxInt;  Result.MinV := MaxInt;
  Result.MaxH := -1;      Result.MaxV := -1;
end;

function TXwBounds.IsEmpty: Boolean;
begin
  Result := MaxH < MinH;
end;

function TXwBounds.Width: Integer;
begin
  if IsEmpty then Exit(0);
  Result := MaxH - MinH + 1;
end;

function TXwBounds.Height: Integer;
begin
  if IsEmpty then Exit(0);
  Result := MaxV - MinV + 1;
end;

function TXwBounds.Area: Integer;
begin
  Result := Width * Height;
end;

function TXwBounds.Contains(const AH, AV: Integer): Boolean;
begin
  Result := (AH >= MinH) and (AH <= MaxH) and (AV >= MinV) and (AV <= MaxV);
end;

end.

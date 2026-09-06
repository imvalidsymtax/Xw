unit Xw.Corpus;

interface

uses
  Xw.Contracts;

type
  TXwCorpusEntry = record
    Phrase: string;
    Clue: string;
  end;

function XwCorpusCount: Integer;
function XwCorpusEntry(const AIndex: Integer): TXwCorpusEntry;

function XwBuildWords(const AFactory: IXwWordFactory; const ACount: Integer): TArray<IXwWord>;
function XwSortLongestFirst(const AWords: TArray<IXwWord>): TArray<IXwWord>;
implementation

uses
  System.Math,
  System.Generics.Collections,
  System.Generics.Defaults;

const
  CCORPUS: array [0 .. 162] of TXwCorpusEntry = (
    (Phrase: 'kot'; Clue: 'domowy mruczek'),
    (Phrase: 'dom'; Clue: 'budynek mieszkalny'),
    (Phrase: 'las'; Clue: 'zbiorowisko drzew'),
    (Phrase: 'most'; Clue: 'przeprawa nad rzeka'),
    (Phrase: 'ryba'; Clue: 'zyje w wodzie'),
    (Phrase: 'sowa'; Clue: 'nocny ptak'),
    (Phrase: 'tama'; Clue: 'zapora wodna'),
    (Phrase: 'ucho'; Clue: 'narzad sluchu'),
    (Phrase: 'waga'; Clue: 'przyrzad do wazenia'),
    (Phrase: 'zebra'; Clue: 'pasiasty kon'),
    (Phrase: 'igla'; Clue: 'do szycia'),
    (Phrase: 'kula'; Clue: 'bryla obrotowa'),
    (Phrase: 'lupa'; Clue: 'szklo powiekszajace'),
    (Phrase: 'mapa'; Clue: 'obraz terenu'),
    (Phrase: 'noga'; Clue: 'konczyna dolna'),
    (Phrase: 'okno'; Clue: 'otwor w scianie'),
    (Phrase: 'pas'; Clue: 'element stroju'),
    (Phrase: 'rak'; Clue: 'skorupiak'),
    (Phrase: 'ser'; Clue: 'produkt mleczny'),
    (Phrase: 'tor'; Clue: 'droga kolejowa'),
    (Phrase: 'wir'; Clue: 'ruch obrotowy wody'),
    (Phrase: 'zagiel'; Clue: 'napedza lodz'),
    (Phrase: 'balon'; Clue: 'lata na goracym powietrzu'),
    (Phrase: 'cegla'; Clue: 'material budowlany'),
    (Phrase: 'dzban'; Clue: 'naczynie na plyny'),
    (Phrase: 'ekran'; Clue: 'powierzchnia projekcji'),
    (Phrase: 'figura'; Clue: 'ksztalt geometryczny'),
    (Phrase: 'gitara'; Clue: 'instrument strunowy'),
    (Phrase: 'harfa'; Clue: 'instrument szarpany'),
    (Phrase: 'iskra'; Clue: 'zarzewie ognia'),
    (Phrase: 'jezioro'; Clue: 'zbiornik wodny'),
    (Phrase: 'kaktus'; Clue: 'roslina pustynna'),
    (Phrase: 'latarnia'; Clue: 'zrodlo swiatla'),
    (Phrase: 'magnes'; Clue: 'przyciaga zelazo'),
    (Phrase: 'nozyce'; Clue: 'do ciecia'),
    (Phrase: 'obraz'; Clue: 'dzielo malarskie'),
    (Phrase: 'piorun'; Clue: 'wyladowanie atmosferyczne'),
    (Phrase: 'rakieta'; Clue: 'pojazd kosmiczny'),
    (Phrase: 'sanie'; Clue: 'zimowy pojazd'),
    (Phrase: 'teczka'; Clue: 'na dokumenty'),
    (Phrase: 'ulica'; Clue: 'droga w miescie'),
    (Phrase: 'wiatrak'; Clue: 'miele zboze'),
    (Phrase: 'zamek'; Clue: 'warownia'),
    (Phrase: 'arkusz'; Clue: 'kartka papieru'),
    (Phrase: 'bursztyn'; Clue: 'zywica kopalna'),
    (Phrase: 'cyrkiel'; Clue: 'do rysowania kol'),
    (Phrase: 'dywan'; Clue: 'na podlodze'),
    (Phrase: 'emalia'; Clue: 'powloka ochronna'),
    (Phrase: 'fortepian'; Clue: 'duzy instrument klawiszowy'),
    (Phrase: 'granica'; Clue: 'linia rozdzielajaca'),
    (Phrase: 'humor'; Clue: 'poczucie komizmu'),
    (Phrase: 'indyk'; Clue: 'duzy ptak hodowlany'),
    (Phrase: 'jaskinia'; Clue: 'podziemna grota'),
    (Phrase: 'kominek'; Clue: 'domowe palenisko'),
    (Phrase: 'lawina'; Clue: 'masa sniegu'),
    (Phrase: 'marmur'; Clue: 'skala ozdobna'),
    (Phrase: 'nektar'; Clue: 'slodki sok kwiatow'),
    (Phrase: 'orkiestra'; Clue: 'zespol muzyczny'),
    (Phrase: 'paleta'; Clue: 'deska malarza'),
    (Phrase: 'reklama'; Clue: 'promocja towaru'),
    (Phrase: 'skarbiec'; Clue: 'miejsce na kosztownosci'),
    (Phrase: 'turbina'; Clue: 'silnik przeplywowy'),
    (Phrase: 'uczen'; Clue: 'chodzi do szkoly'),
    (Phrase: 'wulkan'; Clue: 'gora ogniowa'),
    (Phrase: 'zwierciadlo'; Clue: 'lustro'),
    (Phrase: 'antena'; Clue: 'odbiera fale'),
    (Phrase: 'beczka'; Clue: 'drewniane naczynie'),
    (Phrase: 'chmura'; Clue: 'na niebie'),
    (Phrase: 'drabina'; Clue: 'do wchodzenia'),
    (Phrase: 'energia'; Clue: 'zdolnosc do pracy'),
    (Phrase: 'fabryka'; Clue: 'zaklad produkcyjny'),
    (Phrase: 'gniazdo'; Clue: 'dom ptaka'),
    (Phrase: 'herbata'; Clue: 'napar z lisci'),
    (Phrase: 'iglica'; Clue: 'szpiczaste zakonczenie'),
    (Phrase: 'jarzyna'; Clue: 'warzywo'),
    (Phrase: 'kotwica'; Clue: 'trzyma statek'),
    (Phrase: 'lampa'; Clue: 'oswietla pokoj'),
    (Phrase: 'mrowka'; Clue: 'pracowity owad'),
    (Phrase: 'naparstek'; Clue: 'chroni palec'),
    (Phrase: 'ogrod'; Clue: 'miejsce upraw'),
    (Phrase: 'pociag'; Clue: 'jedzie po torach'),
    (Phrase: 'radio'; Clue: 'odbiornik fal'),
    (Phrase: 'smoła'; Clue: 'lepka substancja'),
    (Phrase: 'topola'; Clue: 'wysokie drzewo'),
    (Phrase: 'urwisko'; Clue: 'strome zbocze'),
    (Phrase: 'wodospad'; Clue: 'spadajaca woda'),
    (Phrase: 'zagadka'; Clue: 'lamiglowka'),
    (Phrase: 'brzoza'; Clue: 'biale drzewo'),
    (Phrase: 'cukier'; Clue: 'slodzi herbate'),
    (Phrase: 'deszcz'; Clue: 'opad atmosferyczny'),
    (Phrase: 'echo'; Clue: 'odbicie dzwieku'),
    (Phrase: 'fala'; Clue: 'ruch na wodzie'),
    (Phrase: 'gorset'; Clue: 'ciasny stroj'),
    (Phrase: 'hamak'; Clue: 'wiszace loze'),
    (Phrase: 'iglak'; Clue: 'drzewo szpilkowe'),
    (Phrase: 'jablko'; Clue: 'owoc jabloni'),
    (Phrase: 'kamien'; Clue: 'twarda bryla'),
    (Phrase: 'liscie'; Clue: 'opadaja jesienia'),
    (Phrase: 'mlyn'; Clue: 'miele ziarno'),
    (Phrase: 'nurek'; Clue: 'plywa pod woda'),
    (Phrase: 'obora'; Clue: 'dla krow'),
    (Phrase: 'piasek'; Clue: 'na plazy'),
    (Phrase: 'rzeka'; Clue: 'plynie do morza'),
    (Phrase: 'szpula'; Clue: 'nawija nic'),
    (Phrase: 'trawa'; Clue: 'zielona na lace'),
    (Phrase: 'ubranie'; Clue: 'odziez'),
    (Phrase: 'wieza'; Clue: 'wysoka budowla'),
    (Phrase: 'zboze'; Clue: 'rosnie na polu'),
    (Phrase: 'agrafka'; Clue: 'spina material'),
    (Phrase: 'bochenek'; Clue: 'duzy chleb'),
    (Phrase: 'czajnik'; Clue: 'do gotowania wody'),
    (Phrase: 'dzwonek'; Clue: 'sygnal dzwiekowy'),
    (Phrase: 'elektron'; Clue: 'czastka ujemna'),
    (Phrase: 'firanka'; Clue: 'w oknie'),
    (Phrase: 'gwiazda'; Clue: 'swieci noca'),
    (Phrase: 'horyzont'; Clue: 'linia widnokregu'),
    (Phrase: 'instrument'; Clue: 'narzedzie muzyka'),
    (Phrase: 'kalendarz'; Clue: 'pokazuje daty'),
    (Phrase: 'labirynt'; Clue: 'platanina korytarzy'),
    (Phrase: 'mikroskop'; Clue: 'powieksza obrazy'),
    (Phrase: 'notatnik'; Clue: 'do zapiskow'),
    (Phrase: 'olowek'; Clue: 'do pisania'),
    (Phrase: 'parasol'; Clue: 'chroni przed deszczem'),
    (Phrase: 'rower'; Clue: 'pojazd na dwoch kolach'),
    (Phrase: 'stolica'; Clue: 'glowne miasto'),
    (Phrase: 'telefon'; Clue: 'sluzy do rozmow'),
    (Phrase: 'walizka'; Clue: 'na podroz'),
    (Phrase: 'zeszyt'; Clue: 'szkolny brulion'),
    (Phrase: 'ananas'; Clue: 'tropikalny owoc'),
    (Phrase: 'burza'; Clue: 'gwaltowna pogoda'),
    (Phrase: 'chleb'; Clue: 'z maki i wody'),
    (Phrase: 'dach'; Clue: 'chroni dom'),
    (Phrase: 'igloo'; Clue: 'lodowy dom'),
    (Phrase: 'jesion'; Clue: 'gatunek drzewa'),
    (Phrase: 'klucz'; Clue: 'otwiera zamek'),
    (Phrase: 'lodka'; Clue: 'mala lodz'),
    (Phrase: 'morze'; Clue: 'slony akwen'),
    (Phrase: 'nozyk'; Clue: 'male ostrze'),
    (Phrase: 'owca'; Clue: 'daje welne'),
    (Phrase: 'pilka'; Clue: 'do gry'),
    (Phrase: 'rekin'; Clue: 'drapieznik morski'),
    (Phrase: 'stol'; Clue: 'mebel z blatem'),
    (Phrase: 'tygrys'; Clue: 'pasiasty drapieznik'),
    (Phrase: 'wilk'; Clue: 'dziki krewny psa'),
    (Phrase: 'zloto'; Clue: 'szlachetny metal'),
    (Phrase: 'aparat'; Clue: 'robi zdjecia'),
    (Phrase: 'bilet'; Clue: 'upowaznia do przejazdu'),
    (Phrase: 'cien'; Clue: 'brak swiatla'),
    (Phrase: 'dolina'; Clue: 'obnizenie terenu'),
    (Phrase: 'ekierka'; Clue: 'przybor kreslarski'),
    (Phrase: 'fasola'; Clue: 'roslina straczkowa'),
    (Phrase: 'garnek'; Clue: 'do gotowania'),
    (Phrase: 'hokej'; Clue: 'sport na lodzie'),
    (Phrase: 'kaseta'; Clue: 'nosnik tasmowy'),
    (Phrase: 'linia'; Clue: 'najkrotsza droga'),
    (Phrase: 'motyl'; Clue: 'kolorowy owad'),
    (Phrase: 'orzech'; Clue: 'twarda skorupa'),
    (Phrase: 'perla'; Clue: 'w muszli'),
    (Phrase: 'rosa'; Clue: 'poranna wilgoc'),
    (Phrase: 'sztorm'; Clue: 'silny wiatr na morzu'),
    (Phrase: 'tunel'; Clue: 'podziemne przejscie'),
    (Phrase: 'wapno'; Clue: 'material budowlany'),
    (Phrase: 'zima'; Clue: 'najzimniejsza pora')
  );

function XwCorpusCount: Integer;
begin
  Result := Length(CCORPUS);
end;

function XwCorpusEntry(const AIndex: Integer): TXwCorpusEntry;
begin
  if (AIndex < 0) or (AIndex > High(CCORPUS)) then
    raise EXwError.CreateFmt('XwCorpusEntry: Out of bounds [0..%d]', [High(CCORPUS)]);
  Result := CCORPUS[AIndex];
end;

function XwBuildWords(const AFactory: IXwWordFactory; const ACount: Integer): TArray<IXwWord>;
var
  I, LTake: Integer;
begin
  LTake := Min(ACount, Length(CCORPUS));
  if LTake < 0 then LTake := 0;
  SetLength(Result, LTake);
  for I := 0 to LTake - 1 do
    Result[I] := AFactory.CreateWord(CCORPUS[I].Phrase, CCORPUS[I].Clue);
end;

function XwSortLongestFirst(const AWords: TArray<IXwWord>): TArray<IXwWord>;
begin
  Result := Copy(AWords);
  TArray.Sort<IXwWord>(Result, TComparer<IXwWord>.Construct(
    function(const L, R: IXwWord): Integer
    begin
      Result := R.Length - L.Length;
    end));
end;

end.

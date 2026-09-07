unit Xw.Corpus;

interface

uses
  Xw.Contracts;

function XwCorpusCount: Integer;
function XwCorpusEntries(const ACount: Integer): TXwEntries;

function XwBuildWords(const AFactory: IXwWordFactory; const ACount: Integer): TArray<IXwWord>;
function XwSortLongestFirst(const AWords: TArray<IXwWord>): TArray<IXwWord>;
implementation

uses
  System.Math,
  System.Generics.Collections,
  System.Generics.Defaults;

const
  CCORPUS: array [0 .. 162] of TXwEntry = (
    (Phrase: 'kot'; Description: 'domowy mruczek'),
    (Phrase: 'dom'; Description: 'budynek mieszkalny'),
    (Phrase: 'las'; Description: 'zbiorowisko drzew'),
    (Phrase: 'most'; Description: 'przeprawa nad rzeka'),
    (Phrase: 'ryba'; Description: 'zyje w wodzie'),
    (Phrase: 'sowa'; Description: 'nocny ptak'),
    (Phrase: 'tama'; Description: 'zapora wodna'),
    (Phrase: 'ucho'; Description: 'narzad sluchu'),
    (Phrase: 'waga'; Description: 'przyrzad do wazenia'),
    (Phrase: 'zebra'; Description: 'pasiasty kon'),
    (Phrase: 'igla'; Description: 'do szycia'),
    (Phrase: 'kula'; Description: 'bryla obrotowa'),
    (Phrase: 'lupa'; Description: 'szklo powiekszajace'),
    (Phrase: 'mapa'; Description: 'obraz terenu'),
    (Phrase: 'noga'; Description: 'konczyna dolna'),
    (Phrase: 'okno'; Description: 'otwor w scianie'),
    (Phrase: 'pas'; Description: 'element stroju'),
    (Phrase: 'rak'; Description: 'skorupiak'),
    (Phrase: 'ser'; Description: 'produkt mleczny'),
    (Phrase: 'tor'; Description: 'droga kolejowa'),
    (Phrase: 'wir'; Description: 'ruch obrotowy wody'),
    (Phrase: 'zagiel'; Description: 'napedza lodz'),
    (Phrase: 'balon'; Description: 'lata na goracym powietrzu'),
    (Phrase: 'cegla'; Description: 'material budowlany'),
    (Phrase: 'dzban'; Description: 'naczynie na plyny'),
    (Phrase: 'ekran'; Description: 'powierzchnia projekcji'),
    (Phrase: 'figura'; Description: 'ksztalt geometryczny'),
    (Phrase: 'gitara'; Description: 'instrument strunowy'),
    (Phrase: 'harfa'; Description: 'instrument szarpany'),
    (Phrase: 'iskra'; Description: 'zarzewie ognia'),
    (Phrase: 'jezioro'; Description: 'zbiornik wodny'),
    (Phrase: 'kaktus'; Description: 'roslina pustynna'),
    (Phrase: 'latarnia'; Description: 'zrodlo swiatla'),
    (Phrase: 'magnes'; Description: 'przyciaga zelazo'),
    (Phrase: 'nozyce'; Description: 'do ciecia'),
    (Phrase: 'obraz'; Description: 'dzielo malarskie'),
    (Phrase: 'piorun'; Description: 'wyladowanie atmosferyczne'),
    (Phrase: 'rakieta'; Description: 'pojazd kosmiczny'),
    (Phrase: 'sanie'; Description: 'zimowy pojazd'),
    (Phrase: 'teczka'; Description: 'na dokumenty'),
    (Phrase: 'ulica'; Description: 'droga w miescie'),
    (Phrase: 'wiatrak'; Description: 'miele zboze'),
    (Phrase: 'zamek'; Description: 'warownia'),
    (Phrase: 'arkusz'; Description: 'kartka papieru'),
    (Phrase: 'bursztyn'; Description: 'zywica kopalna'),
    (Phrase: 'cyrkiel'; Description: 'do rysowania kol'),
    (Phrase: 'dywan'; Description: 'na podlodze'),
    (Phrase: 'emalia'; Description: 'powloka ochronna'),
    (Phrase: 'fortepian'; Description: 'duzy instrument klawiszowy'),
    (Phrase: 'granica'; Description: 'linia rozdzielajaca'),
    (Phrase: 'humor'; Description: 'poczucie komizmu'),
    (Phrase: 'indyk'; Description: 'duzy ptak hodowlany'),
    (Phrase: 'jaskinia'; Description: 'podziemna grota'),
    (Phrase: 'kominek'; Description: 'domowe palenisko'),
    (Phrase: 'lawina'; Description: 'masa sniegu'),
    (Phrase: 'marmur'; Description: 'skala ozdobna'),
    (Phrase: 'nektar'; Description: 'slodki sok kwiatow'),
    (Phrase: 'orkiestra'; Description: 'zespol muzyczny'),
    (Phrase: 'paleta'; Description: 'deska malarza'),
    (Phrase: 'reklama'; Description: 'promocja towaru'),
    (Phrase: 'skarbiec'; Description: 'miejsce na kosztownosci'),
    (Phrase: 'turbina'; Description: 'silnik przeplywowy'),
    (Phrase: 'uczen'; Description: 'chodzi do szkoly'),
    (Phrase: 'wulkan'; Description: 'gora ogniowa'),
    (Phrase: 'zwierciadlo'; Description: 'lustro'),
    (Phrase: 'antena'; Description: 'odbiera fale'),
    (Phrase: 'beczka'; Description: 'drewniane naczynie'),
    (Phrase: 'chmura'; Description: 'na niebie'),
    (Phrase: 'drabina'; Description: 'do wchodzenia'),
    (Phrase: 'energia'; Description: 'zdolnosc do pracy'),
    (Phrase: 'fabryka'; Description: 'zaklad produkcyjny'),
    (Phrase: 'gniazdo'; Description: 'dom ptaka'),
    (Phrase: 'herbata'; Description: 'napar z lisci'),
    (Phrase: 'iglica'; Description: 'szpiczaste zakonczenie'),
    (Phrase: 'jarzyna'; Description: 'warzywo'),
    (Phrase: 'kotwica'; Description: 'trzyma statek'),
    (Phrase: 'lampa'; Description: 'oswietla pokoj'),
    (Phrase: 'mrowka'; Description: 'pracowity owad'),
    (Phrase: 'naparstek'; Description: 'chroni palec'),
    (Phrase: 'ogrod'; Description: 'miejsce upraw'),
    (Phrase: 'pociag'; Description: 'jedzie po torach'),
    (Phrase: 'radio'; Description: 'odbiornik fal'),
    (Phrase: 'smoła'; Description: 'lepka substancja'),
    (Phrase: 'topola'; Description: 'wysokie drzewo'),
    (Phrase: 'urwisko'; Description: 'strome zbocze'),
    (Phrase: 'wodospad'; Description: 'spadajaca woda'),
    (Phrase: 'zagadka'; Description: 'lamiglowka'),
    (Phrase: 'brzoza'; Description: 'biale drzewo'),
    (Phrase: 'cukier'; Description: 'slodzi herbate'),
    (Phrase: 'deszcz'; Description: 'opad atmosferyczny'),
    (Phrase: 'echo'; Description: 'odbicie dzwieku'),
    (Phrase: 'fala'; Description: 'ruch na wodzie'),
    (Phrase: 'gorset'; Description: 'ciasny stroj'),
    (Phrase: 'hamak'; Description: 'wiszace loze'),
    (Phrase: 'iglak'; Description: 'drzewo szpilkowe'),
    (Phrase: 'jablko'; Description: 'owoc jabloni'),
    (Phrase: 'kamien'; Description: 'twarda bryla'),
    (Phrase: 'liscie'; Description: 'opadaja jesienia'),
    (Phrase: 'mlyn'; Description: 'miele ziarno'),
    (Phrase: 'nurek'; Description: 'plywa pod woda'),
    (Phrase: 'obora'; Description: 'dla krow'),
    (Phrase: 'piasek'; Description: 'na plazy'),
    (Phrase: 'rzeka'; Description: 'plynie do morza'),
    (Phrase: 'szpula'; Description: 'nawija nic'),
    (Phrase: 'trawa'; Description: 'zielona na lace'),
    (Phrase: 'ubranie'; Description: 'odziez'),
    (Phrase: 'wieza'; Description: 'wysoka budowla'),
    (Phrase: 'zboze'; Description: 'rosnie na polu'),
    (Phrase: 'agrafka'; Description: 'spina material'),
    (Phrase: 'bochenek'; Description: 'duzy chleb'),
    (Phrase: 'czajnik'; Description: 'do gotowania wody'),
    (Phrase: 'dzwonek'; Description: 'sygnal dzwiekowy'),
    (Phrase: 'elektron'; Description: 'czastka ujemna'),
    (Phrase: 'firanka'; Description: 'w oknie'),
    (Phrase: 'gwiazda'; Description: 'swieci noca'),
    (Phrase: 'horyzont'; Description: 'linia widnokregu'),
    (Phrase: 'instrument'; Description: 'narzedzie muzyka'),
    (Phrase: 'kalendarz'; Description: 'pokazuje daty'),
    (Phrase: 'labirynt'; Description: 'platanina korytarzy'),
    (Phrase: 'mikroskop'; Description: 'powieksza obrazy'),
    (Phrase: 'notatnik'; Description: 'do zapiskow'),
    (Phrase: 'olowek'; Description: 'do pisania'),
    (Phrase: 'parasol'; Description: 'chroni przed deszczem'),
    (Phrase: 'rower'; Description: 'pojazd na dwoch kolach'),
    (Phrase: 'stolica'; Description: 'glowne miasto'),
    (Phrase: 'telefon'; Description: 'sluzy do rozmow'),
    (Phrase: 'walizka'; Description: 'na podroz'),
    (Phrase: 'zeszyt'; Description: 'szkolny brulion'),
    (Phrase: 'ananas'; Description: 'tropikalny owoc'),
    (Phrase: 'burza'; Description: 'gwaltowna pogoda'),
    (Phrase: 'chleb'; Description: 'z maki i wody'),
    (Phrase: 'dach'; Description: 'chroni dom'),
    (Phrase: 'igloo'; Description: 'lodowy dom'),
    (Phrase: 'jesion'; Description: 'gatunek drzewa'),
    (Phrase: 'klucz'; Description: 'otwiera zamek'),
    (Phrase: 'lodka'; Description: 'mala lodz'),
    (Phrase: 'morze'; Description: 'slony akwen'),
    (Phrase: 'nozyk'; Description: 'male ostrze'),
    (Phrase: 'owca'; Description: 'daje welne'),
    (Phrase: 'pilka'; Description: 'do gry'),
    (Phrase: 'rekin'; Description: 'drapieznik morski'),
    (Phrase: 'stol'; Description: 'mebel z blatem'),
    (Phrase: 'tygrys'; Description: 'pasiasty drapieznik'),
    (Phrase: 'wilk'; Description: 'dziki krewny psa'),
    (Phrase: 'zloto'; Description: 'szlachetny metal'),
    (Phrase: 'aparat'; Description: 'robi zdjecia'),
    (Phrase: 'bilet'; Description: 'upowaznia do przejazdu'),
    (Phrase: 'cien'; Description: 'brak swiatla'),
    (Phrase: 'dolina'; Description: 'obnizenie terenu'),
    (Phrase: 'ekierka'; Description: 'przybor kreslarski'),
    (Phrase: 'fasola'; Description: 'roslina straczkowa'),
    (Phrase: 'garnek'; Description: 'do gotowania'),
    (Phrase: 'hokej'; Description: 'sport na lodzie'),
    (Phrase: 'kaseta'; Description: 'nosnik tasmowy'),
    (Phrase: 'linia'; Description: 'najkrotsza droga'),
    (Phrase: 'motyl'; Description: 'kolorowy owad'),
    (Phrase: 'orzech'; Description: 'twarda skorupa'),
    (Phrase: 'perla'; Description: 'w muszli'),
    (Phrase: 'rosa'; Description: 'poranna wilgoc'),
    (Phrase: 'sztorm'; Description: 'silny wiatr na morzu'),
    (Phrase: 'tunel'; Description: 'podziemne przejscie'),
    (Phrase: 'wapno'; Description: 'material budowlany'),
    (Phrase: 'zima'; Description: 'najzimniejsza pora')
  );

function XwCorpusCount: Integer;
begin
  Result := Length(CCORPUS);
end;

function XwCorpusEntries(const ACount: Integer): TXwEntries;
var
  I, LTake: Integer;
begin
  LTake := Min(ACount, Length(CCORPUS));
  if LTake < 0 then LTake := 0;
  SetLength(Result, LTake);
  for I := 0 to LTake - 1 do
    Result[I] := CCORPUS[I];
end;

function XwBuildWords(const AFactory: IXwWordFactory; const ACount: Integer): TArray<IXwWord>;
var
  I, LTake: Integer;
begin
  LTake := Min(ACount, Length(CCORPUS));
  if LTake < 0 then LTake := 0;
  SetLength(Result, LTake);
  for I := 0 to LTake - 1 do
    Result[I] := AFactory.CreateWord(CCORPUS[I].Phrase, CCORPUS[I].Description);
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

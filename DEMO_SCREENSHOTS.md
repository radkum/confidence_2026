# Demo Screenshots — ps-parser-cli edition

**Cel:** zebrać 10 screenshotów które trafią do `AMSI_vs_Obfuscation.pptx` jako konkretne dowody tezy. Narracja: Layer 1 = pure-Rust statyczna deobfuskacja (`ps-parser-cli`), Layer 2 = kernel behavioral (sysmon-rs). Defense in depth.

**Co się zmieniło względem `SCREENSHOT_SCENARIO.md`:** wycięte odniesienia do PsParser.dll / PsParser.exe. Layer 1 prezentowany jako jeden silnik w czystym Ruscie. Sample 27 punch przeformułowany z "Clean → Caught" na "Suspicious → Definitive" — bo nawet najbardziej agresywna statyka tylko podejrzewa, a behaviour rozstrzyga.

---

## Setup wstępny (jednorazowo, nie do screen)

```powershell
# Na VM, admin PowerShell:

# 1. Sync najnowszej paczki release z hosta (jeśli jeszcze nie)
Copy-Item "C:\VSExclude\confidence_2026\deploy\confidence-release\*" `
          "C:\Users\rados\Downloads\confidence-release\" -Recurse -Force

# 2. Skopiuj binarkę ps-parser-cli do working dir (samodzielna, bez .NET)
Copy-Item "C:\VSExclude\confidence_2026\ramsi-rs\target\release\ps-parser-cli.exe" `
          "C:\Users\rados\Downloads\confidence-release\ps-parser-cli.exe"

cd C:\Users\rados\Downloads\confidence-release

# 3. Reinstall żeby mieć świeży ramsi-com.dll i kernel driver
.\reinstall.ps1

# 4. Start kernel drivera
sc.exe start ConfidenceKm
sc.exe query ConfidenceKm   # potwierdź STATE: 4 RUNNING

# 5. W OSOBNYM OKNIE — daemon (zostaw otwarte do końca; będzie potrzebne do SCREENSHOT 8/9)
& 'C:\Program Files\Confidence\sysmon-um.exe'
# wypisuje: "Connected to driver. Monitoring..."
```

W pierwszym oknie (OKNO A) wykonujesz polecenia z kolejnych screenshotów. OKNO B (sysmon-um) tylko zrzuca SCREENSHOT 8 i 9.

---

## SCREENSHOT 1 — obfuscated source (`1_obfuscated_sample.png`)

**Komenda:**

```powershell
type .\samples\malicious\14_amsi_buffer_path.ps1 | Select-Object -First 8
```

**Co zrzucić:** terminal z pierwszymi 8 liniami pliku. **Linia 3 to gigantyczna base64 blob** — to cały skompilowany .NET DLL zakodowany w stringu, ładowany przez `[Reflection.Assembly]::Load([Convert]::FromBase64String("TVqQAAMAAA..."))`.

**Opis pod screen:**

> *"Real-world AMSI bypass — `samples/malicious/14_amsi_buffer_path.ps1`. Cały skompilowany .NET DLL (`AmsiBypass.dll`) zakodowany w base64 i ładowany do pamięci przez `Reflection.Assembly::Load`. Wyświetlając pierwsze 8 linii widać niewiele poza ścianą znaków — żaden człowiek nie powie co to robi bez dekodowania. Klasyczny przykład 'fileless' loaderu — payload nigdy nie ląduje na dysku."*

---

## SCREENSHOT 2 — ps-parser-cli wykrywa pomimo obfuskacji (`2_pscli_sample14_detection.png`)

**Komenda:**

```powershell
& '.\ps-parser-cli.exe' --json .\samples\malicious\14_amsi_buffer_path.ps1
```

**Co zrzucić:** JSON output. **Zaznacz ramkami:**

- `"engine": "ps-parser/1.0.1"` — silnik
- `"status": "AMSI BYPASS"`
- `"confidence": 100`
- `"is_amsi_bypass": true`
- W `"indicators"`: pozycje `AmsiDll`, `MemoryPatch` (z opisem `VirtualProtect` / `AllocHGlobal`), `VtableManipulation`

**Opis pod screen:**

> *"Rekurencyjny base64 deobfuskator wyciągnął zawartość zaszytego `.NET DLL`. W sekcji `#US` (string heap) widać literalne `amsi.dll`, `AmsiScanBuffer`, `VirtualProtect`, `AllocHGlobal` w UTF-16LE. Verdykt: AMSI BYPASS, confidence 100, cztery niezależne kategorie predykatów (memory patch + vtable manipulation + amsi.dll reference). Skrypt nigdy by się nie wykonał — AMSI zablokuje go na podstawie naszego raportu."*

---

## SCREENSHOT 3 — Detection rate na pełnym zestawie (`3_pscli_full_corpus.png`)

**Komenda:**

```powershell
& '.\ps-parser-cli.exe' .\samples\malicious\
```

**Co zrzucić:** całą tabelę. Header `Scanning 28 file(s)...`, kolumny `File / Status / Conf / Indicators`. 28 wierszy.

**Zaznacz markerem / ramką po prawej:**

- 27 wierszy `AMSI BYPASS`
- 1 wiersz `Suspicious` — to **sample 27** (przygotowanie do Acta 4)
- 0 wierszy `Clean`

**Opis pod screen:**

> *"Na pełnym zestawie 28 obfuskowanych malicious sample'ów: **27/28 wykrytych = 96 %**. Tylko jeden — sample 27, świadomie ewasywny — pozostaje pod progiem AMSI BYPASS. To nie artefakt jednego parsera: jest to silnik w czystym Ruscie z rekursywną deobfuskacją base64, predykatami na ETW/WLDP/script-block smuggling/vtable hijack, score'em z combo bonusami. Statyka dochodzi do swojego pułapu."*

---

## SCREENSHOT 4 — Sample 26 source (`4_sample26_source.png`)

**Setup przed odpaleniem:**

```powershell
# Pokaż treść sampla (literalna wersja z github radkum)
type .\samples\malicious\26_amsi_provider_disruption.ps1 | Select-Object -First 20
```

**Co zrzucić:** terminal z 20 linijkami. Widać **literalne** `DllGetClassObject`, `Marshal.WriteIntPtr`, `IUnknown`, `AllocHGlobal` — bez żadnej obfuskacji.

**Opis pod screen:**

> *"Sample 26 — adaptacja [github.com/radkum/AmsiProviderScanDisruption](https://github.com/radkum/AmsiProviderScanDisruption). Zaawansowana technika: patchuje vtable AMSI providerów w pamięci. Tu literalne nazwy: `DllGetClassObject`, `Marshal.WriteIntPtr`, `AllocHGlobal` — wszystko jak na dłoni."*

---

## SCREENSHOT 5 — Live AMSI block sample 26 (`5_amsi_red_error.png`)

**Setup przed odpaleniem:**

```powershell
# Wyczyść log (opcjonalnie — pomaga jeśli ktoś będzie chciał obejrzeć ramsi-com.log po fakcie)
Remove-Item C:\ProgramData\Confidence\logs\ramsi-com.log -Force -ErrorAction SilentlyContinue
```

**Komenda:**

```powershell
& powershell.exe -File .\samples\malicious\26_amsi_provider_disruption.ps1
```

**Co zrzucić:** **czerwony błąd AMSI** w PowerShellu. Standardowy komunikat:

```
This script contains malicious content and has been blocked by your antivirus software.
At C:\Users\rados\Downloads\confidence-release\samples\malicious\26_amsi_provider_disruption.ps1:1 char:1
+ #----------------------------------IMPORT FUNCTIONS--------- ...
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : ParserError: (:) [], ParentContainsErrorRecordException
    + FullyQualifiedErrorId : ScriptContainedMaliciousContent
```

Najważniejsze do zaznaczenia: **`ScriptContainedMaliciousContent`** w stopce.

**Opis pod screen:**

> *"Sample 26 odpalony przez `powershell.exe`. To **nie nasza wstawka** — to standardowy komunikat AMSI: `ScriptContainedMaliciousContent`. Provider `ramsi-com.dll` zarejestrowany w `HKLM\SOFTWARE\Microsoft\AMSI\Providers` przeprocesował kod, zwrócił `AMSI_RESULT_DETECTED`, runtime PS odmówił wykonania. **Skrypt napisany 5 lat temu jako technika ataku jest dziś blokowany przez detector zbudowany przez tę samą osobę**. Cat-and-mouse cycle full circle."*

---

## SCREENSHOT 6 — Sample 27 source (`6_sample27_source.png`)

**Komenda:**

```powershell
type .\samples\malicious\27_amsi_provider_disruption_evasive.ps1
```

**Co zrzucić:** **cały plik** (ok. 40 linijek). Kluczowe momenty do zaznaczenia markerem na slajdzie:

1. Linijka `[int][char]$k[0] -eq 65` — char-code comparison zamiast literalnego `"A"`
2. Brak literalnego "AMSI" w kodzie — szukamy bajtów `65 77 83 73` (ASCII "AMSI")
3. `$root.opensubkey($targetKey).opensubkey('Providers').getsubkeynames()` — registry API z runtime-built stringiem
4. **Zero base64-literałów rozumianych przez standardowe parsery, zero char-array, zero XOR** — bo nie ma co dekodować jednorazowo

**Opis pod screen:**

> *"Sample 27 — moja modyfikacja oryginału. Robi **dokładnie to samo** (enumerację AMSI providerów z rejestru), ale każdy literalny identyfikator zrekonstruowany w runtime: nazwa typu "AMSI" przez char-code compare z bajtami 65/77/83/73, nazwa metody `DllGetClassObject` przez base64 (`'RGxsR2V0Q2xhc3NPYmplY3Q='`), atrybut przez konkatenację. Każdy element legalny PowerShell. Nigdzie nie pada literalnie 'AMSI'."*

---

## SCREENSHOT 7 — Sample 27, ps-parser-cli mówi "Suspicious" ⭐ **PUNCH** (`7_pscli_sample27_suspicious.png`)

**Komenda:**

```powershell
& '.\ps-parser-cli.exe' --json .\samples\malicious\27_amsi_provider_disruption_evasive.ps1
```

**Co zrzucić:** JSON output. **Zaznacz ramkami (to są kluczowe pola do podkreślenia na slajdzie):**

- `"engine": "ps-parser/1.0.1"`
- `"status": "Suspicious"` — **nie `Clean`, nie `AMSI BYPASS`**
- `"confidence": 24`
- `"is_amsi_bypass": false` — kluczowe mimo Suspicious
- `"indicators"` zawiera dwa wpisy `ComManipulation`:
  - opis ze słowem `dllgetclassobject` (zdekodowane z base64 `'RGxsR2V0Q2xhc3NPYmplY3Q='`)
  - opis ze słowem `getdelegateforfunctionpointer`

Jeśli w polu `"deobfuscated"` widać że `RGxsR2V0Q2xhc3NPYmplY3Q=` rozszyfrowało się do `DllGetClassObject` — **dodatkowa strzałka / annotation** *"recovered from base64"*.

**Opis pod screen (klucz prezentacji):**

> *"Najbardziej agresywny silnik statyczny jaki umiem zbudować — rekurencyjna deobfuskacja base64, ewaluacja format operator, char arrays, 30+ predykatów AMSI bypass — daje `Suspicious(24)` z dwoma indicatorami `ComManipulation`. To znaczy że deobfuscator coś widzi: rozszyfrował z base64 nazwę metody `DllGetClassObject`. Ale literalnego 'AMSI' nie ma nigdzie w kodzie ani w wyniku deobfuskacji.*
>
> *Verdykt: **Suspicious — nie Clean, nie AMSI BYPASS**. Bo to dokładnie ten obszar w którym statyka napotyka fundamentalny pułap: dostajemy sygnał że coś jest dziwne, ale dowodu na bypass nie ma. Pełna pewność wymaga obserwacji behaviour — nie kodu, lecz tego co naprawdę zachodzi w runtime."*

---

## SCREENSHOT 8 — Sample 27, Layer 2 (kernel) ŁAPIE (`8_sample27_layer2_caught.png`)

**Setup:** wyczyść okno sysmon-um.exe (`Ctrl+L` w nim lub `Clear-Host`).

**Komenda w OKNIE A:**

```powershell
# Layer 1 zwróci Suspicious (nie zablokuje), ale kernel widzi behaviour:
& powershell.exe -File .\samples\malicious\27_amsi_provider_disruption_evasive.ps1
```

**Co zrzucić: OKNO B (sysmon-um.exe).** Powinny pojawić się linijki:

```
[!] AMSI-RECON     pid=XXXX  key="\REGISTRY\MACHINE\SOFTWARE\Microsoft\AMSI"
[!] AMSI-RECON     pid=XXXX  key="\REGISTRY\MACHINE\SOFTWARE\Microsoft\AMSI\Providers"
[!] AMSI-RECON     pid=XXXX  key="\REGISTRY\MACHINE\SOFTWARE\Microsoft\AMSI\Providers\{2781761E-...}"
```

(Każde `OpenSubKey` w PowerShellu skutkuje eventem `RegNtPostOpenKeyEx` w driverze, który filtruje ścieżki zawierające `\AMSI\` i wysyła do daemona.)

**Opis pod screen:**

> *"Kernel driver widzi co **naprawdę robi** ten proces — niezależnie od tego jakimi nazwami operuje w kodzie źródłowym. Każde otwarcie klucza rejestru z `\AMSI\` w ścieżce → event `AMSI-RECON`. **Żadna legitymna aplikacja tego nie robi**. Dla Layer 2 ten skrypt jest oczywisty — czyta sekretne klucze konfiguracji AMSI. Decyzja: AMSI BYPASS. Definitywna."*

---

## SCREENSHOT 9 (BONUS) — Twin AMSI-RECON series (`9_dual_recon.png`)

**Komenda:** Nic dodatkowego — używasz już istniejących eventów w oknie sysmon-um.

**Co zrzucić:** w **OKNIE B** widoczne dwie serie `AMSI-RECON`:
- pierwsza seria po sample 26 (z SCREENSHOT 5)
- druga seria po sample 27 (z SCREENSHOT 8)

→ wizualnie **identyczne**.

**Opis pod screen:**

> *"To samo behaviour. Kernel widzi to samo, niezależnie od tego czy atakujący użył literalnego `'AMSI'` (sample 26) czy zrekonstruował to z kodów ASCII w runtime (sample 27). Behaviour zostaje. **Defense in depth: Layer 1 łapie 96 % statycznie, Layer 2 łapie pozostałe 4 % i przyszłe techniki obfuskacji których jeszcze nie znamy.**"*

---

## SCREENSHOT 10 — ps-parser-cli pełny scan (bonus do slajdu architektury) (`10_pscli_full_dir.png`)

(Opcjonalny — jeśli SCREENSHOT 3 już dał ten widok, możesz pominąć. Bierz tylko jeśli chcesz mieć osobny przykład na slajdzie *"silnik standalone, bez .NET runtime"*.)

**Komenda — różnica względem SCREENSHOT 3:** to samo, ale z absolute path do binarki żeby było widać że to standalone tool:

```powershell
& 'C:\VSExclude\confidence_2026\ramsi-rs\target\release\ps-parser-cli.exe' `
    'C:\VSExclude\confidence_2026\samples\Obfuscated_Malicious_Powershell\'
```

**Co zrzucić:** ta sama tabela co w SCREENSHOT 3, ale w prompt'cie widać że odpalasz **z host path** (nie z release bundle). Dowód że binarka jest samodzielna — działa z dowolnego katalogu, bez instalacji, bez .NET runtime.

**Opis pod screen:**

> *"ps-parser-cli to **4.7 MB statycznie zlinkowana binarka Rust**. Działa z dowolnego katalogu, nie wymaga .NET runtime, nie wymaga instalacji. Można puścić w CI/CD pipeline jako pre-commit hook, w SOC jako batch scanner na korpusie scriptów, w incident response jako triage tool. **Mała powierzchnia ataku — wszystko czego potrzebuje to dostęp do pliku do odczytu**."*

---

## Slajd "Sample 27 — gradient detekcji"

Z dwóch screenshotów (7 i 8) buduj **2-kolumnowy slajd**:

```
┌─────────────────────────────┬─────────────────────────────┐
│  ps-parser-cli              │  Layer 2 (kernel driver)    │
│  Rust + recursive base64    │  behavioral, runtime        │
├─────────────────────────────┼─────────────────────────────┤
│                             │                             │
│      [SCREENSHOT 7]         │      [SCREENSHOT 8]         │
│                             │                             │
├─────────────────────────────┼─────────────────────────────┤
│  Suspicious (24)            │  AMSI BYPASS                │
│  "widzi pęknięcie"          │  "widzi realny dostęp"      │
└─────────────────────────────┴─────────────────────────────┘
```

**Tekst pod slajdem (kluczowy moment talku):**

> *"Sample 27 wykonuje dokładnie to samo zachowanie co sample 26, ale każdy literalny identyfikator zrekonstruowany w runtime: nazwa typu z bajtów, nazwa metody z base64, atrybut z konkatenacji. Dwa silniki różnej głębokości, dwa różne werdykty:*
>
> *ps-parser-cli rekursywnie dekoduje base64, ewaluuje format operator i char arrays, dispatchuje przez 30+ predykatów. Wyciąga `DllGetClassObject` z base64. **Widzi pęknięcie** — ale bez literalnego AMSI nie wydaje conclusive verdyktu. Suspicious(24).*
>
> *Layer 2 nie patrzy na kod, patrzy na zachowanie. `RegNtPostOpenKeyEx` na ścieżce zawierającej `\AMSI\` — żadna legitymna aplikacja tego nie robi. **Definitywnie** AMSI BYPASS. Decyzja w 10 ms.*
>
> *To nie jest "Layer 1 zawiódł" — to demonstracja **fundamentalnego pułapu statyki**. Nawet najlepszy parser jaki umiemy napisać nie zobaczy intencji która materializuje się dopiero w runtime. Defense in depth nie jest opcjonalne — jest konieczne."*

---

## Podsumowanie do prezentacji

Mapowanie 5-aktów demo na screenshoty:

| Akt | Co dzieje się | Screen(y) |
|---|---|---|
| **1. Layer 1 blocks bypass** | Pokaż obfuscated source, potem `ps-parser-cli` daje AMSI BYPASS | 1, 2 |
| **2. Detection sweep** | 27/28 statycznie | 3 (i opcjonalnie 10) |
| **3. Layer 1 catches radkum original** | sample 26 source + live AMSI block | 4, 5 |
| **4. Layer 1 misses evasive — Suspicious only** | sample 27 source + `ps-parser-cli` Suspicious | 6, 7 |
| **5. Layer 2 catches behavioural** | sample 27 → kernel AMSI-RECON | 8, 9 |

Po zebraniu screenów wrzuć je do `demo_screens/` z dokładnie tymi nazwami plików — `generate_pptx.py` osadzi je na właściwych slajdach przy następnym `python generate_pptx.py`.

**Status screen-checkboxa:**

- [ ] 1 — obfuscated source sample 14
- [ ] 2 — ps-parser-cli sample 14 → AMSI BYPASS
- [ ] 3 — ps-parser-cli sample directory → 27/28
- [ ] 4 — sample 26 source
- [ ] 5 — live red AMSI error sample 26
- [ ] 6 — sample 27 source
- [ ] 7 — ps-parser-cli sample 27 → Suspicious **(PUNCH)**
- [ ] 8 — sysmon-um AMSI-RECON sample 27
- [ ] 9 — twin AMSI-RECON series (sample 26 + 27)
- [ ] 10 — (opcjonalny) ps-parser-cli z host path

**Po zrobieniu:** powiedz *"gotowe"* / *"wrzuciłem screeny"* — to dalej idziemy do aktualizacji `PRESENTATION.md` i `AMSI_vs_Obfuscation.pptx`.

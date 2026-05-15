# Demo Screenshot Scenario

**Cel:** zebrać 8 screenshotów + krótkie opisy, które potem trafią do PRESENTATION.md jako konkretne dowody tezy.

**Setup wstępny (jednorazowo, nie do screen):**

```powershell
# Na VM, admin PS:
# 1. Sync najnowszej paczki z hosta (jeśli jeszcze nie):
Copy-Item "C:\VSExclude\confidence_2026\deploy\confidence-release\*" `
          "C:\Users\rados\Downloads\confidence-release\" -Recurse -Force

cd C:\Users\rados\Downloads\confidence-release

# 2. Reinstall żeby dostać świeży DLL z poprawionym detector-em (bez .endswith)
.\reinstall.ps1

# 3. Start drivera
sc.exe start ConfidenceKm
sc.exe query ConfidenceKm  # potwierdź RUNNING

# 4. W OSOBNYM OKNIE -- daemon (zostaw otwarte do końca):
& 'C:\Program Files\Confidence\sysmon-um.exe'
# powinno wypisać: "Connected to driver. Monitoring..."
```

---

## SCREENSHOT 1 -- obfuskowany sample (pokazujemy że bez deobfuscatora to bełkot)

**Komenda:**
```powershell
type .\samples\malicious\14_amsi_buffer_path.ps1 | Select-Object -First 8
```

**Co zrzucić:** terminal z pierwszymi 8 liniami sampla 14. **Linia 3 to gigantyczna base64 blob** — to cały skompilowany .NET DLL zakodowany w stringu, ładowany przez `[Reflection.Assembly]::Load([Convert]::FromBase64String("TVqQAAMAAA..."))`.

**Opis pod screen (do wstawienia w prezentację):**
> *"Real-world AMSI bypass — `samples/malicious/14_amsi_buffer_path.ps1`. Cały skompilowany .NET DLL (`AmsiBypass.dll`) zakodowany w base64 i ładowany do pamięci przez `Reflection.Assembly::Load`. Wyświetlając pierwsze 8 linii widać niewiele poza ścianą znaków — żaden człowiek nie powie co to robi bez dekodowania. Klasyczny przykład 'fileless' loaderu — payload nigdy nie ląduje na dysku."*

**Alternatywa:** możesz też pokazać `samples/malicious/26_amsi_provider_disruption.ps1 | Select-Object -First 25` żeby zobaczyć vtable hijacking — jeśli wolisz pokazać konkretną technikę zamiast base64.

---

## SCREENSHOT 2 -- Layer 1 wykrywa pomimo obfuskacji

**Komenda:**
```powershell
& 'C:\VSExclude\confidence_2026\PsParser\bin\Release\net8.0\PSParser.exe' --json .\samples\malicious\14_amsi_buffer_path.ps1
```

**Co zrzucić:** terminal z JSON output. Kluczowe pola do podkreślenia:
- `"status":"AMSI BYPASS"`
- `"confidence_score":75`
- `"is_amsi_bypass":true`
- lista `indicators`:
  - `MemoryPatch / Critical` — wykryte ślady patchowania pamięci AMSI
  - `AmsiDll / High` — wykryta referencja do `amsi.dll`

**Opis pod screen:**
> *"Deobfuscator widzi wewnątrz base64 ciąg dla `amsi.dll` + ślady `VirtualProtect`/`AmsiScanBuffer`. Verdict: AMSI BYPASS, confidence 75, dwa niezależne predykaty (MemoryPatch Critical + AmsiDll High). Skrypt nie wykonałby się — AMSI go zablokuje na podstawie naszego raportu."*

---

## SCREENSHOT 3 -- Detection rate na pełnym zestawie

**Komenda (PowerShell oneliner — uruchom z folderu z paczką):**
```powershell
$exe = 'C:\VSExclude\confidence_2026\PsParser\bin\Release\net8.0\PSParser.exe'

$mal = Get-ChildItem '.\samples\malicious\*.ps1'
$det=0; $miss=0
foreach ($f in $mal) {
    $j = & $exe --json $f.FullName 2>&1 | Where-Object { $_ -match '^\s*\{' } | Select-Object -First 1
    if ($j -match '"is_amsi_bypass":true') { $det++ } else { $miss++ }
}
Write-Host "Malicious: detected=$det miss=$miss"

$ben = Get-ChildItem '.\samples\benign\*.ps1'
$clean=0; $fp=0
foreach ($f in $ben) {
    $j = & $exe --json $f.FullName 2>&1 | Where-Object { $_ -match '^\s*\{' } | Select-Object -First 1
    if ($j -match '"status":"Clean"') { $clean++ } else { $fp++ }
}
Write-Host "Benign: clean=$clean fp=$fp"
```

**Co zrzucić:** dwie ostatnie linie z liczbami.

Spodziewany output:
```
Malicious: detected=26 miss=1
Benign: clean=49 fp=1
```

**Opis pod screen:**
> *"Na realnych obfuskowanych bypass'ach: 26/27 = **96% detection**. Na 50 legit installer scripts (Office, OneDrive, Autopilot...): 49 czystych = **2% false positive**. Jeden bypass (#27) i jeden FP — przeanalizowane dalej."*

---

## SCREENSHOT 4 -- Sample 26 (radkum oryginał) — Layer 1 łapie

**Setup przed odpaleniem:**
```powershell
# Wyczyść log
Remove-Item C:\ProgramData\Confidence\logs\ramsi-com.log -Force -EA SilentlyContinue

# Pokaż treść sampla (literalna wersja z github radkum)
type .\samples\malicious\26_amsi_provider_disruption.ps1 | Select-Object -First 20
```

**Co zrzucić:** terminal z 20 linijkami pokazującymi `DllGetClassObject`, `Marshal.WriteIntPtr`, `IUnknown` literalnie obecne w kodzie.

**Opis pod screen:**
> *"Sample 26 — adaptacja [github.com/radkum/AmsiProviderScanDisruption](https://github.com/radkum/AmsiProviderScanDisruption). Zaawansowana technika: patchuje vtable AMSI providerów w pamięci. Tu literalne nazwy: `DllGetClassObject`, `Marshal.WriteIntPtr`, `AllocHGlobal`."*

---

## SCREENSHOT 5 -- ramsi-com.log po odpaleniu sampla 26

**Komenda:**
```powershell
& powershell.exe -File .\samples\malicious\26_amsi_provider_disruption.ps1 2>&1 | Out-Null
Start-Sleep -Milliseconds 500
Get-Content C:\ProgramData\Confidence\logs\ramsi-com.log | Select-String "scan_script|PsParser|EXIT" | Select-Object -Last 10
```

**Co zrzucić:** widać linijki w stylu:
```
scan_script ENTRY type=PsScript len=4xxx preview="#----------------------------------IMPORT..."
PsParser result: is_bypass=true confidence=100
scan_script EXIT PsParser -> Detected
```

**Opis pod screen:**
> *"Gdy skrypt trafia do AMSI, nasz provider (ramsi-com.dll) loguje wynik: PsParser zdiagnozował confidence 100, vendor=Detected. Skrypt nie wykonał się — AMSI go zablokował na podstawie naszego verdyktu."*

---

## SCREENSHOT 6 -- Sample 27 ewasywny — kod (pokazujemy że "nie ma czego deobfuskować")

**Komenda:**
```powershell
type .\samples\malicious\27_amsi_provider_disruption_evasive.ps1
```

**Co zrzucić:** **cały plik** (ok. 40 linijek). Kluczowe momenty do zaznaczenia po screen:

1. Linijka `[int][char]$k[0] -eq 65` — char-code comparison, nie obfuskacja
2. Brak literalnego "AMSI" — szukamy bajtów 65,77,83,73 (= ASCII "AMSI")
3. `$root.opensubkey($targetKey).opensubkey('Providers').getsubkeynames()` — normalna registry API
4. **Zero base64, zero char-array, zero XOR** — bo nie ma co dekodować

**Opis pod screen:**
> *"Sample 27 — moja modyfikacja oryginału. Robi **dokładnie to samo** (enumerację AMSI providerów), ale bez literalnych słów. Zamiast `'AMSI'` porównuje znak po znaku z bajtami 65,77,83,73. Deobfuscator nie ma czego dekodować — to legalna PowerShell składnia."*

---

## SCREENSHOT 7 -- Sample 27 — Layer 1 mówi "Clean" (klucz prezentacji!)

**Komenda:**
```powershell
& 'C:\VSExclude\confidence_2026\PsParser\bin\Release\net8.0\PSParser.exe' --json .\samples\malicious\27_amsi_provider_disruption_evasive.ps1
```

**Co zrzucić:** JSON output, kluczowe:
- `"status":"Clean"`
- `"is_amsi_bypass":false`
- `"confidence_score":0`
- `"indicators":[]` (puste!)

**Opis pod screen:**
> *"**Layer 1 mówi: czyste.** Deobfuscator wykrył: nic. Confidence 0. Bo statyczna analiza nie potrafi rozszyfrować że porównywanie znaków z bajtem 65 to "A". To **fundamentalny limit** każdej statycznej analizy bez symbolic execution."*

---

## SCREENSHOT 8 -- Sample 27 — Layer 2 (kernel driver) ŁAPIE

**Setup — wyczyść okno sysmon-um (Ctrl+L lub Clear-Host w nim).**

**W oknie A wpisz:**
```powershell
# Odpal sample 27 (Layer 1 nic nie powie, ale kernel widzi)
& powershell.exe -File .\samples\malicious\27_amsi_provider_disruption_evasive.ps1
```

**Co zrzucić:** **OKNO B (sysmon-um.exe)** — powinny pojawić się linijki:
```
[!] AMSI-RECON     pid=XXXX  key="\REGISTRY\MACHINE\SOFTWARE\Microsoft\AMSI"
[!] AMSI-RECON     pid=XXXX  key="\REGISTRY\MACHINE\SOFTWARE\Microsoft\AMSI\Providers"
[!] AMSI-RECON     pid=XXXX  key="\REGISTRY\MACHINE\SOFTWARE\Microsoft\AMSI\Providers\{2781761E-...}"
```

(Każdy `opensubkey` w PowerShell skutkuje wpisem w driverze.)

**Opis pod screen:**
> *"Kernel driver widzi co **naprawdę robi** ten proces — niezależnie od tego jakimi nazwami operuje w kodzie. Każde otwarcie klucza rejestru z `\AMSI\` w ścieżce → event AMSI-RECON. **Żadna legitymna aplikacja tego nie robi.** Dla Layer 2 ten skrypt jest oczywisty — czyta sekretne klucze."*

---

## SCREENSHOT 9 (BONUS) -- Reset i wynik podsumowujący

**Komenda:**
```powershell
# Pokaż wszystkie AMSI-RECON eventy w jednym kadrze (w oknie sysmon-um)
# albo z log-a jeśli sysmon-um zapisuje (sprawdź czy zostawiamy persistentny log)
```

Jeśli chcesz prosty visual: wciąż w OKNIE B (sysmon-um), zrób screen z **dwóch sąsiednich serii** AMSI-RECON:
- pierwsza seria po sample 26
- druga po sample 27

→ wizualnie identyczne. Driver nie zna różnicy między literalną a ewasywną wersją — bo behavior jest ten sam.

**Opis pod screen:**
> *"To samo behavior — kernel widzi to samo. Niezależnie od tego czy atakujący obfuskuje, czy ewaduje przez char-code rebuild — registry access pozostaje. **Defense in depth: Layer 1 łapie 96%, Layer 2 łapie resztę i przyszłe nowe techniki.**"*

---

# Podsumowanie do prezentacji

Po zebraniu screenów, podaj mi je w formie:

```
Screenshot 1: [krótki tekst który chcesz pod screen]
Screenshot 2: ...
...
```

Albo zrób krótkie notki do każdego — wstawię je do `PRESENTATION.md` w odpowiednich miejscach. Slajdy 4 (Demo 1), 5 (Demo 2), 6 (Demo 3) — tam screeny pasują najlepiej.

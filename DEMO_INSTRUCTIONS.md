# Confidence — Demo Screenshot Session

**Cel:** zebrać 9 screenów + krótkie opisy, które pokażą tezę prezentacji:
> Deobfuscator wykrywa większość obfuskowanych bypassów statycznie (~96%). Ale niektóre techniki są niemożliwe do zdeobfuskować bez wykonania kodu — wtedy kernel-driver Layer 2 łapie je behavioralnie.

---

## Setup (jednorazowo, ~3 min)

### Na hoście (host PowerShell)

```powershell
# Final sync paczki na VM
Copy-Item "C:\VSExclude\confidence_2026\deploy\confidence-release\*" `
          "C:\Users\rados\Downloads\confidence-release\" -Recurse -Force
```

### Na VM (admin cmd lub admin PowerShell)

```cmd
cd C:\Users\rados\Downloads\confidence-release

:: Świeży install
powershell -ExecutionPolicy Bypass -File .\install.ps1

:: Start kernel drivera
sc start ConfidenceKm
sc query ConfidenceKm
:: → powinno być STATE: 4 RUNNING

:: (Opcjonalnie) Defender exclusion na samples dir żeby nie blokował Layer 1 demo
powershell -c "Add-MpPreference -ExclusionPath 'C:\Users\rados\Downloads\confidence-release\samples'"
```

---

## Ułożenie okien

```
┌─────────────────────────────────────────────────────────────┐
│  OKNO A (lewa połowa) — Twój test terminal                  │
│  Tu będziesz wpisywać komendy demo                          │
│  Admin PowerShell                                           │
│  cd C:\Users\rados\Downloads\confidence-release             │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  OKNO B (prawa połowa) — sysmon-um monitor                  │
│  & 'C:\Program Files\Confidence\sysmon-um.exe'              │
│  Zostaw widoczne, nie zamykaj do końca sesji                │
└─────────────────────────────────────────────────────────────┘
```

---

## **S0 — Przykałd amsi bypass**

# Sesja screenshotów (9 screenów, ~10 min)

## **S1 — Obfuskowany sample (wizualnie ścianę base64)**

### Komenda (OKNO A)

```powershell
type .\samples\malicious\14_amsi_buffer_path.ps1 | Select-Object -First 8
```

### Co zrzucić

Terminal z 8 liniami; widać `Reflection.Assembly::Load([Convert]::FromBase64String("TVqQAAA..."` — gigantyczna baza64 (cały .NET DLL zakodowany).

### Notka do prezentacji

> Real-world AMSI bypass z `samples/malicious/14_amsi_buffer_path.ps1`. Cały skompilowany .NET DLL (`AmsiBypass.dll`) zakodowany w base64 i ładowany do pamięci przez `Reflection.Assembly::Load`. Wyświetlając pierwsze 8 linii widać niewiele poza ścianą znaków base64. Klasyczny fileless loader — payload nigdy nie ląduje na dysku.

---

## **S2 — Layer 1 wykrywa pomimo obfuskacji**

### Komenda (OKNO A)

```powershell
& 'C:\Program Files\Confidence\PSParser.exe' --json .\samples\malicious\14_amsi_buffer_path.ps1
```

### Co zrzucić

JSON output z kluczowymi polami:
- `"status": "AMSI BYPASS"`
- `"confidence_score": 75`
- `"is_amsi_bypass": true`
- Indicators: `MemoryPatch / Critical` + `AmsiDll / High`
- `"matched_value": "[binary content, 7244 bytes, PE magic=MZ (Windows EXE/DLL)]"`

### Notka

> Deobfuscator dekoduje base64 wewnątrz skryptu. Po dekodowaniu znajduje string `AmsiScanBuffer` oraz `amsi.dll` w środku — klasyczne ślady patchowania pamięci AMSI. Status: AMSI BYPASS, confidence 75, dwa niezależne predykaty (MemoryPatch Critical + AmsiDll High).

---

## **S3 — Detection rate na pełnym zestawie**

### Komenda (OKNO A)

```powershell
$exe = 'C:\Program Files\Confidence\PSParser.exe'

# Malicious detection rate
$mal = Get-ChildItem '.\samples\malicious\*.ps1'
$det=0; $miss=0
foreach ($f in $mal) {
    $j = (& $exe --json $f.FullName 2>&1 | Out-String)
    if ($j -match '"is_amsi_bypass":\s*true') { $det++ } else { $miss++ }
}
Write-Host "Malicious: detected=$det miss=$miss"

# Benign false positive rate
$ben = Get-ChildItem '.\samples\benign\*.ps1'
$clean=0; $fp=0
foreach ($f in $ben) {
    $j = (& $exe --json $f.FullName 2>&1 | Out-String)
    if ($j -match '"status":\s*"Clean"') { $clean++ } else { $fp++ }
}
Write-Host "Benign:    clean=$clean fp=$fp"
```

### Co zrzucić

Dwie ostatnie linie:
```
Malicious: detected=26 miss=1
Benign:    clean=49 fp=1
```

### Notka

> Na realnych obfuskowanych bypass'ach: **26/27 = 96% detection**. Na 50 legitymnych installer scripts (Office, OneDrive, Autopilot...): **49 czystych = 2% false positive**. Jeden bypass missed (sample 27 — przeanalizowany dalej) i jeden FP (benign installer trafia w heurystykę).

---

## **S4 — Sample 26 (radkum literalny) — pokazujemy kod**

### Komenda (OKNO A)

```powershell
type .\samples\malicious\26_amsi_provider_disruption.ps1 | Select-Object -First 25
```

### Co zrzucić

Pierwsze 25 linii. Widać literalnie: `DllGetClassObject`, `Marshal.WriteIntPtr`, `AllocHGlobal`, `UnmanagedFunctionPointer` — wszystkie kompromitujące nazwy.

### Notka

> Sample 26 — adaptacja **[github.com/radkum/AmsiProviderScanDisruption](https://github.com/radkum/AmsiProviderScanDisruption)**. Zaawansowana technika: patchuje vtable AMSI providerów w pamięci. Tu literalne nazwy: `DllGetClassObject`, `Marshal.WriteIntPtr`, `AllocHGlobal` — łatwy target dla statycznego deobfuscatora.

---

## **S5 — Layer 1 łapie sample 26**

### Komenda (OKNO A)

```powershell
& 'C:\Program Files\Confidence\PSParser.exe' --json .\samples\malicious\26_amsi_provider_disruption.ps1 | Select-Object -First 30
```

### Co zrzucić

JSON, kluczowe pola:
- `"status": "AMSI BYPASS"`
- `"is_amsi_bypass": true`
- `"confidence_score": 84`
- Indicators: 6 niezależnych predykatów: `ComManipulation` (DllGetClassObject, GetDelegateForFunctionPointer, UnmanagedFunctionPointer), `VtableManipulation` (WriteIntPtr, ReadIntPtr, AllocHGlobal).

### Notka

> 6 niezależnych predykatów wykrywa sample 26: `DllGetClassObject`, `GetDelegateForFunctionPointer`, `WriteIntPtr`, `ReadIntPtr`, `AllocHGlobal`, `UnmanagedFunctionPointer`. Confidence 84, AMSI BYPASS. Defender by też pewnie złapał — to dobrze, defense in depth.

---

## **S6 — Sample 27 (ewasywny) — pokazujemy kod**

### Komenda (OKNO A)

```powershell
type .\samples\malicious\27_amsi_provider_disruption_evasive.ps1
```

### Co zrzucić

Cały plik (~120 linii). Kluczowe linie do zaznaczenia:

1. **Runtime-built identyfikatory:**
   ```powershell
   $N_DGO  = _b 'RGxsR2V0Q2xhc3NPYmplY3Q='   # base64('DllGetClassObject')
   $N_WRITE = _b 'V3JpdGVJbnRQdHI='          # base64('WriteIntPtr')
   ```

2. **Char-code budowa "AMSI":**
   ```powershell
   if ($k.Length -eq 4 -and
       [int][char]$k[0] -eq 65 -and   # 'A'
       [int][char]$k[1] -eq 77 -and   # 'M'
       [int][char]$k[2] -eq 83 -and   # 'S'
       [int][char]$k[3] -eq 73)       # 'I'
   ```

3. **Reflected method access:**
   ```powershell
   $mWriteIP = $marshalT.GetMethod($N_WRITE, [Type[]]@([IntPtr],[int],[IntPtr]))
   ```

### Notka

> Sample 27 robi **dokładnie to samo** co 26 (provider vtable hijack), ale wszystkie identyfikatory zrekonstruowane w runtime z base64 i char-codes. Zero literalnych słów: `AMSI`, `DllGetClassObject`, `WriteIntPtr` w kodzie. To **nie obfuskacja** — to legalna PowerShell składnia porównująca bajty.

---

## **S7 — Layer 1 mówi "Clean" (PUNCH moment)**

### Komenda (OKNO A)

```powershell
& 'C:\Program Files\Confidence\PSParser.exe' --json .\samples\malicious\27_amsi_provider_disruption_evasive.ps1
```

### Co zrzucić

JSON output, kluczowe pola:
- `"status": "Clean"`
- `"is_amsi_bypass": false`
- `"confidence_score": 0`
- `"indicators": []` (puste!)

### Notka

> **Layer 1 mówi: czyste.** Deobfuscator wykrył: nic. Confidence 0, zero indicators. Bo statyczna analiza nie potrafi rozszyfrować że `[int][char]$k[0] -eq 65` to porównanie ze znakiem 'A'. To **fundamentalny limit** każdej statycznej analizy bez symbolic execution.

---

## **S8 — Layer 2 łapie sample 27 (BIG MOMENT) i pokazanie że podobnie jest z 26**

### Komenda (OKNO A — UWAGA: musi być inne okno niż sysmon-um!)

```cmd
powershell -ExecutionPolicy Bypass -File C:\Users\rados\Downloads\confidence-release\samples\malicious\27_amsi_provider_disruption_evasive.ps1
```

### Co się stanie

1. Spawn nowego procesu `powershell.exe` z `-File ...27.ps1`
2. PowerShell zaczyna wykonywać skrypt, otwiera klucze rejestru AMSI
3. **Driver** łapie POST_OPEN_KEY na `\REGISTRY\MACHINE\SOFTWARE\Microsoft\AMSI\Providers`
4. **sysmon-um**:
   - Wstrzymuje proces (`NtSuspendProcess`)
   - Ocenia: `tracked=true` + cmdline zawiera `.ps1` z `\downloads\` → **SUSPECT**
   - Wyświetla czerwony tekst w konsoli ofiary
   - Zabija proces (`TerminateProcess`)

### Zrzut #1 (OKNO A — konsola w której odpalono komendę)

**Czerwony komunikat** (kolor czerwony, na bieli/szarym tle):
```
This script contains malicious content and has been blocked by Confidence Layer 2.
Reason: AMSI provider registry enumeration (technique used to disable AMSI before payload).
    + CategoryInfo          : ParserError: (:) [], ParseException
    + FullyQualifiedErrorId : ConfidenceAmsiProviderHijackBlocked
    + PID                   : XXXX
```

### Zrzut #2 (OKNO B — sysmon-um monitor)

**Pełen audit log:**
```
[+] ProcessCreate  pid=XXXX  ppid=YYYY  cmd=powershell.exe -ExecutionPolicy Bypass -File ...27_evasive.ps1
[!] AMSI-RECON     pid=XXXX  key="\REGISTRY\MACHINE\SOFTWARE\Microsoft\AMSI\Providers"
    [~] SUSPENDED pid=XXXX
        image:   C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
        cmdline: powershell.exe -ExecutionPolicy Bypass -File C:\Users\rados\Downloads\...\27_evasive.ps1
        tracked: true
    [X] VERDICT: SUSPECT -- terminating
    [X] pid=XXXX TERMINATED
```

### Notka

> Layer 2 widzi behavioralny pattern: proces enumerujący AMSI providers w rejestrze. **Niezależnie od ukrycia literałów w skrypcie** — registry access jest oczywisty dla kernel callback. sysmon zawiesza proces (`NtSuspendProcess`), ocenia (PowerShell z `.ps1` z user-path = suspect), wyświetla blok jak AMSI (czerwony tekst), zabija. Pełen lifecycle: detect → suspend → decide → block.

---

### Co zrzucić

Pojedynczy screenshot łączący 3 rzeczy (na slajdzie ułożone obok siebie):

| Sample | Layer 1 verdict | Layer 2 verdict |
|---|---|---|
| 26 (literalny radkum) | **DETECTED** — score 84, 6 indicators | **BLOCKED** — registry recon caught |
| 27 (ewasywny) | **Clean** — score 0, 0 indicators | **BLOCKED** — registry recon caught |

### Notka

> To samo zachowanie (provider hijack). Layer 1 łapie samples z literalnymi identyfikatorami (26). Layer 2 łapie **behaviour** niezależnie od obfuskacji (zarówno 26 jak i 27). **Defense in depth.** Atakujący musi obejść obie warstwy żeby przejść niezauważony.

---

# Plan awaryjny

## S8 czerwony tekst nie wyświetlił się

- **Przyczyna:** `AttachConsole` nie zadziałał (np. odpaliłeś z interactive PS, nie z nowego cmd).
- **Fix:** odpalaj komendę z OKNO A jako **admin cmd** lub **admin PowerShell** uruchomione przez "Run as administrator" (nie z innego PS).

## sysmon-um nie zabija sample 27

- Sprawdź w outpucie sysmon-um:
  - `tracked: true` — proces zarejestrowany, sysmon-um widział ProcessCreate
  - cmdline zawiera `.ps1` z `\downloads\` lub `\users\` — heurystyka match
- Jeśli `tracked: false` ALE proces nadal został zabity przez regułę 4 (untracked powershell.exe) — OK.
- Jeśli `VERDICT: whitelisted` zamiast SUSPECT → daj output, zaktualizuję heurystykę.

## Layer 1 zwraca inne liczby niż 26/49

- Możliwe że Defender wyrzucił jakieś sample z folderu samples:
  ```powershell
  Get-MpThreatDetection | Select-Object -Last 10
  ```
- Sprawdź czy wszystkie samples są obecne:
  ```powershell
  (Get-ChildItem .\samples\malicious\*.ps1).Count   # → 27
  (Get-ChildItem .\samples\benign\*.ps1).Count      # → 50
  ```

## Driver nie firnie (brak AMSI-RECON w sysmon-um)

```cmd
:: Reboot często rozwiązuje (driver się reloaduje po reboocie):
shutdown /r /t 5

:: Po reboocie:
sc start ConfidenceKm
"C:\Program Files\Confidence\sysmon-um.exe"
```

---

# Po skończeniu sesji

Wklej **9 screenów** + krótkie opisy (możesz użyć moich notek lub napisać własne). Wrzucę je do `PRESENTATION.md` w odpowiednie slajdy.

Powodzenia.

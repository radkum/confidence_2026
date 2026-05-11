# Instrukcje Pobierania Sampli

## Co zostało pobrane automatycznie

| Folder | Zawartość | Ilość PS1 |
|--------|-----------|-----------|
| `benign/` | Skrypty z PowerShell Gallery | ~203 |
| `malicious/nishang/` | Offensive PowerShell framework | ~70 |
| `malicious/PowerSploit/` | Post-exploitation framework | ~51 |
| `obfuscation-tools/Invoke-Obfuscation/` | Narzędzie do obfuscacji | 14 |
| `amsi-bypass/` | AMSI bypass samples (C#, README) | - |

---

## Do pobrania ręcznie

### 1. MalwareBazaar (Real Malware Samples)

**URL:** https://bazaar.abuse.ch/browse/tag/powershell/

**Jak pobrać:**
1. Wejdź na stronę i przeglądaj samples z tagiem `powershell`
2. Kliknij na wybrany sample, aby zobaczyć szczegóły
3. Pobierz ZIP (hasło do archiwum: `infected`)
4. Rozpakuj do `samples/malicious/malwarebazaar/`

**Polecane hashe do pobrania:**
```
# Szukaj samples z tymi tagami:
- powershell
- script
- dropper
- emotet (często używa PS)
- cobalt-strike
```

**API (automatyczne pobieranie):**
```powershell
# Pobieranie przez API (wymaga curl)
$sha256 = "HASH_SAMPLA"
curl -X POST -d "query=get_file&sha256_hash=$sha256" https://mb-api.abuse.ch/api/v1/ -o sample.zip
# Rozpakuj z hasłem: infected
```

---

### 2. VirusTotal (Wymaga konta)

**URL:** https://www.virustotal.com/

**Jak pobrać:**
1. Załóż konto na VirusTotal (darmowe)
2. Użyj wyszukiwania: `tag:powershell type:ps1 positives:10+`
3. Pobieranie sampli wymaga konta Premium lub Intelligence API

**Alternatywa - VT Intelligence queries:**
```
behavior:"AMSI bypass"
behavior:"Invoke-Expression" 
tag:script positives:5+
```

---

### 3. GitHub - Dodatkowe repozytoria

**Empire (zaarchiwizowane, ale użyteczne):**
```powershell
git clone https://github.com/EmpireProject/Empire samples/malicious/Empire
```

**Atomic Red Team (testy bezpieczeństwa):**
```powershell
git clone https://github.com/redcanaryco/atomic-red-team samples/malicious/atomic-red-team
```

**PoshC2:**
```powershell
git clone https://github.com/nettitude/PoshC2 samples/malicious/PoshC2
```

---

### 4. Tworzenie własnych obfuscated samples

Użyj pobranego Invoke-Obfuscation do generowania samples:

```powershell
Import-Module .\samples\obfuscation-tools\Invoke-Obfuscation\Invoke-Obfuscation.psd1

# Przykład obfuscacji prostego skryptu
$script = 'Write-Host "Hello World"'
Invoke-Obfuscation -ScriptBlock ([ScriptBlock]::Create($script)) -Command 'Token\All\1'
```

**Techniki w Invoke-Obfuscation:**
- `Token` - tokenizacja
- `String` - manipulacja stringów
- `Encoding` - Base64, ASCII, hex
- `Compress` - kompresja
- `Launcher` - różne sposoby uruchomienia

---

### 5. Więcej benign samples (jeśli potrzebujesz więcej)

**GitHub Search:**
```
https://github.com/search?q=extension%3Aps1+language%3APowerShell+stars%3A%3E10&type=repositories
```

**Microsoft Official repos:**
```powershell
git clone https://github.com/Azure/azure-powershell samples/benign/azure-powershell
git clone https://github.com/PowerShell/PowerShell samples/benign/powershell-official
```

---

## Struktura rekomendowana dla ML

```
samples/
├── benign/           # ~500-1000 samples (masz ~203)
├── malicious/        # ~200-500 samples (masz ~121)
│   ├── nishang/
│   ├── PowerSploit/
│   ├── Empire/       # do pobrania
│   └── malwarebazaar/ # do pobrania
├── amsi-bypass/      # osobna kategoria
└── obfuscation-tools/ # narzędzia do generowania
```

---

## Uwagi bezpieczeństwa

⚠️ **NIGDY nie uruchamiaj malware samples poza sandboxem!**

1. Używaj izolowanej VM (VirtualBox/VMware/Hyper-V)
2. Wyłącz sieć lub użyj isolated network
3. Zrób snapshot przed testami
4. Defender może blokować/usuwać samples - dodaj wyjątki lub wyłącz na czas testów

```powershell
# Dodanie wyjątku dla folderu samples (jako admin)
Add-MpPreference -ExclusionPath "c:\VSExclude\confidence\samples"
```

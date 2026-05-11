# Plan Prezentacji: AMSI vs. Obfuscation - A Cat-and-Mouse Game

## STRUKTURA: 45 MINUT (CORE) + Opcjonalne rozszerzenia

---

## I. Wprowadzenie (2 minuty)
- **Cel prezentacji**: Zrozumienie AMSI, technik obejścia i strategii obronnych
- **Kontekst**: Rosnąca popularność ataków opartych na skryptach w Windows
- **Struktura**: Od teorii do praktyki obronnej

---

## II. Zagrożenia w Skryptach (5 minut) [CORE]

### 2.1 Dlaczego skrypty są niebezpieczne?
- **Bliskość do systemu operacyjnego**: PowerShell, WMI, VBScript, JavaScript
- **Brak wymagań**: Nie wymagają kompilacji, łatwe do uruchomienia
- **Trudność w detekcji**: Często wykorzystywane jako "Living off the land" ataki

### 2.2 Popularne wektory ataku
- **Script-based malware**: Ransomware, cryptominers, data stealers
- **Post-exploitation**: Lateral movement, privilege escalation
- **Initial Access**: Spear-phishing z załącznikami PS1, VBS, JS

### 2.3 Przykłady rzeczywistych zagrożeń
- PowerShell droppers
- WMI-based persistence
- Obfuscated scripts w phishingu

---

## III. Anti-Malware Scan Interface (AMSI) (8 minut) [CORE]

### 3.1 Czym jest AMSI?
- **Definicja**: Interface umożliwiający aplikacjom skanowanie treści dla programów antimalware
- **Historia**: Wprowadzony w Windows 10
- **Cel**: Ustandaryzowanie skanowania złośliwego kodu

### 3.2 Architektura AMSI
- **Komponenty**: AmsiClient, AmsiServer, Provider
- **Integracja ze skryptami**: PowerShell, VBScript, JScript, WMI
- **Flow**: Kod skryptu → AMSI API → Registered providers → Verdict

### 3.3 Skanowane obszary
- Skrypty PowerShell (w całości i dynamicznie)
- Parametry funkcji (Get-Content, Invoke-WebRequest, etc.)
- Obiekty COM w WMI
- Komendy konsolowe (bez -NoProfile)

### 3.4 Mechanizmy ochrony AMSI
- **Memory protection**: Ochrona struktóry sesji AMSI
- **Real-time scanning**: Ciągła analiza kodu
- **Provider integration**: Zintegrowanie z Defenserm, third-party AVem

---

## IV. Techniki Obfuscacji i AMSI Bypass (12 minut) [CORE]

### 4.1 Obfuscacja w PowerShelu
- **Podstawowe techniki**:
  - Zamiana zmiennych na Base64
  - Łączenie stringów
  - Wykorzystanie `Invoke-Expression` i `$ExecutionContext`
  - Aliasy i dodatkowe znaki

- **Zaawansowane techniki**:
  - String interpolation manipulation
  - CmdletBinding spoofing
  - Unicode encoding obejścia

#### Narzędzie: **ps-parser** (https://crates.io/crates/ps-parser)
- Parser PowerShella w Rust do analizy i detekcji obfuscacji
- Zdolność do rozwijania obfuscowanych kodów
- Szybka analiza statyczna

### 4.2 AMSI Bypass - Techniki In-Memory
- **Reflection-based**: Modyfikacja AmsiContext w pamięci
- **Hooking**: Przejęcie AMSI API calls
- **Provider disabling**: Wyłączenie AMSI providera

#### Metoda: **AmsiProviderScanDisruption** (https://github.com/radkum/AmsiProviderScanDisruption)
- Autorski AMSI bypass leveraging provider-level disruption
- Demonstracja: Jak DisruptAMSI() działa w praktyce
- PoC w C# - uruchamiany z PowerShela

### 4.3 Obfuscacja w C#
- Kompilacja dynamiczna
- Encoded assemblies
- Reflection + DynamicMethod

#### Narzędzie: **cs-parser** (https://github.com/radkum/cs-parser)
- Parser C# dla detekcji obfuscacji
- Zdolność do analizy dynamicznych kodów

### 4.4 Łączenie technik: AMSI Bypass + Obfuscacja
- **Praktyka w malware**: Wielowarstwowe ukrycie
- **Case study**: Rzeczywisty sample z pole (anonimizowany)
- **Skuteczność**: Jak wiele warstw jest potrzebnych

---

## V. Wykrywanie Technik AMSI Bypass i Obfuscacji (10 minut) [CORE]

### 5.1 Strategie obrony warstwowe
- **Layer 1 - Statyczna analiza**:
  - Sygnatury obfuscacji (Base64, podejrzane funkcje)
  - Analiza AST za pomocą narzędzi takich jak ps-parser

- **Layer 2 - Behawioralna analiza**:
  - Monitorowanie AMSI API hooks
  - Śledzenie niepowtarzalnych parametrów PowerShela

- **Layer 3 - Telemetria endpoint**:
  - ETW (Event Tracing for Windows) do śledzenia:
    - Process creation z podejrzanymi parametrami
    - Ładowanie bibliotek systemu
    - Reflection API calls

- **Layer 4 - Hybrid ML-based Detection** (Lightweight approach):
  - **Heurystyczne ML**: Statystyczne modelowanie normalnego zachowania
    - Entropia stringów w kodzie
    - Ratio obfuscacji (Base64/encoded content %)
    - Frequency analysis - podejrzane API calls
    - AST complexity metrics
  
  - **Feature engineering** z narzędzi:
    - ps-parser: Generowanie features z AST PowerShela
    - cs-parser: Analysis C# bytecode patterns
    - ramsi-rs: Runtime behavioral signals
  
  - **Lightweight modele**:
    - Random Forest / Gradient Boosting (szybkie, interpretable)
    - One-class SVM do anomaly detection
    - Autoencoder dla bytecode patterns (TinyML)
  
  - **Scoring system**: Hybrid score
    - 40% - Rule-based signatures
    - 30% - Heurystyczne ML
    - 30% - Behavioral telemetry
  
  - **Zaletami**:
    - Szybkie (puede w real-time na endpoint)
    - Interpretable (można wyjaśnić why flagged)
    - Mały footprint (mogą biegać na resource-constrained systemach)
    - Adaptive (learning z lokalnych samples)

### 5.2 Wskaźniki zagrożenia (IoCs)
- **Reflectional indicators**:
  - `System.Reflection.Assembly.Load()`
  - `MethodInfo`, `GetField()`, `Invoke()`
  
- **Obfuscation indicators**:
  - Base64 w tekście
  - Excessive string concatenation
  - Multiple encoding layers

- **AMSI-specific indicators**:
  - UnmanagedCode permissions
  - `kernel32.dll` imports
  - Memory tampering patterns

### 5.3 Narzędzia do detekcji

#### **ramsi-rs** (https://github.com/radkum/ramsi-rs)
- Rust-based analyzer dla AMSI bypass detection
- Szybka analiza w runtime
- **Hybrid detection engine**:
  - Rule-based signatures dla znanych bypass technik
  - Heurystyczne ML scoring dla unknown obfuscation
  - Integration z endpoint telemetry
  - Low-resource footprint (native Rust, pode na agents)
- Generowanie feature vectors z analyzed code
- Outputy actionable alerts z confidence scores

#### **ps-parser + cs-parser**
- Automatyczne rozwijanie obfuscowanych kodów
- Generowanie IoCs
- Raportowanie na poziomie AST

### 5.4 Praktyczne podejście do detekcji
- **Logowanie**: Powershell transcripts, AMSI logs, Sysmon
- **Alerting**: Custom rules w SIEM (Splunk, ELK)
- **Response**: Playbook dla zablokowania i quarantine

---

## VI. Praktyczna Demonstracja (5 minut) [CORE - zintegrowana z sekcjami]

### 6.1 Demo: Hybrid Detection Pipeline
- Szybkie live demo jednego sample:
  - Obfuscated code → ps-parser analysis
  - AMSI bypass signature detection w ramsi-rs
  - Hybrid ML score

---

## VII. Podsumowanie & Q&A (3 minuty) [CORE]

### 7.1 Kluczowe wiadomości
- AMSI to niezbędny layer, ale nie jedyny
- Obfuscation jest łatwa, ale detekowalna
- Obrona wielowarstwowa jest konieczna
- **Hybrid ML jest future**: Rule + ML = lepsze detection bez black-box gotchas

### 7.2 Szybkie Q&A (jeśli zostanie czas)

---

## OPCJONALNE ROZSZERZENIA (dla wariantu ~60 minut)

### VIII. Best Practices dla Defensów (5 minut) [OPCJONALNE]
- **Hardening**:
  - Włączenie Constrained Language Mode (CLM) w PowerShelu
  - Wpisy "Block at first sight" (BAFS)
  - Script Block Logging i Module Logging

- **Monitoring**:
  - Centralny monitoring AMSI logs
  - ETW providerów dla visibility
  - Continuous threat hunting

- **Hybrid ML w praktyce**:
  - Zbieranie baselinie normalnych PowerShell/C# skryptów
  - Training lightweight ML modelu (Random Forest, XGBoost)
  - Deployment na endpoints z ramsi-rs
  - Dashboard: Rule score vs ML score divergence

---

## Materiały pomocnicze:

### Narzędzia do zaprezentowania:
1. **ramsi-rs**: https://github.com/radkum/ramsi-rs
2. **ps-parser**: https://crates.io/crates/ps-parser
3. **cs-parser**: https://github.com/radkum/cs-parser
4. **AmsiProviderScanDisruption**: https://github.com/radkum/AmsiProviderScanDisruption

### Zalecane slajdy:
- Screenshot architektury AMSI
- Schemat flow dla obfuscacji
- Diagram warstw obrony (CORE: 3 warstwy, Opcjonalne: 4 warstwy z ML)
- Przykłady obfuscowanego kodu (side-by-side)
- Logi z detektowanych ataków

### Czas trwania:
- **CORE (45 minut)**: I + II + III + IV + V + VI + VII
- **Rozszerzony (60 minut)**: + Sekcja VIII (Best Practices opcjonalne)
- **Q&A**: Elastyczne, zależy od dostępnego czasu

---

**Uwagi:**
- **45 minut (CORE)**: Fokus na zagrożenia → AMSI → Obfuscacja/bypass → Detektowanie + szybkie demo
- Pomiń sekcję VIII (Best Practices) jeśli czas jest ograniczony
- Demo powinno być **jedno, szybkie** (~2 min max) - pokazujące obfuscation + detection pipeline
- Dostosuj przykłady do doświadczenia publiczności (Security Engineers vs. Incident Responders)
- Przygotuj sandboxowane środowisko dla demo z wcześniej przygotowanymi samples
- Miej backup slides dla szczególnych pytań z publiczności
- Jeśli publiczność będzie zainteresowana ML, możesz rozwinąć sekcję V.1 Layer 4

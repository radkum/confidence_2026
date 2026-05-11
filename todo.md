# TODO: Przygotowanie Prezentacji "AMSI vs. Obfuscation"

## PRIORYTET 1: Przygotowanie Sampli i Testów

### [ ] 1.1 Zebranie Real-World Sampli
- [ ] Zebrać co najmniej 10-15 obfuscowanych PowerShell skryptów (z rzeczywistych malware'u)
  - [ ] Z VirusTotal / GitHub security advisories (anonimizowane)
  - [ ] Z własnych penetration testów (zdessanityzowane)
  - [ ] Mix: simple Base64 → complex multi-layer obfuscation
- [ ] Zebrać 5-10 AMSI bypass samples
  - [ ] Reflection-based bypasses
  - [ ] Hooking-based bypasses
  - [ ] Provider disruption (AmsiProviderScanDisruption PoC)
- [ ] Zebrać C# obfuscated samples (dla cs-parser demo)
- **Dokumentacja**: Lista sampli z opisem technik w każdym

### [ ] 1.2 Przygotowanie Demo Environmentu
- [ ] Sandbox environment (VM): Windows 10/11 + PowerShell 5.1+
- [ ] Zainstalować narzędzia:
  - [ ] ps-parser (z Crates.io)
  - [ ] cs-parser (build z GitHub)
  - [ ] ramsi-rs (build z GitHub)
  - [ ] AmsiProviderScanDisruption (build C# PoC)
- [ ] Przygotować one-click scripts do deploymętu demo
- [ ] Przygotować capture/screenshots z ETW i AMSI logs

### [ ] 1.3 Testowanie Sampli
- [ ] Uruchomić każdy sample w sandbox z logging (PowerShell transcripts, Sysmon, ETW)
- [ ] Zvalidować detektowanie w Microsoft Defender
- [ ] Zvalidować detektowanie w ramsi-rs (aktualna wersja)
- [ ] Zvalidować rozwijanie obfuscacji w ps-parser
- [ ] Dokumentować: Co się detekuje? Co nie?
- [ ] Zidentyfikować samples dla demo (best for visualization)

---

## PRIORYTET 2: Implementacja Lightweight ML Algorithm

### [ ] 2.1 Design ML Pipeline
- [ ] Zdefiniować feature set:
  - [ ] String entropy calculation
  - [ ] Base64/encoding ratio (%)
  - [ ] AST complexity metrics (z ps-parser)
  - [ ] Suspicious API frequency (System.Reflection, etc.)
  - [ ] Code length & structure anomalies
  - [ ] Variable naming patterns (random vs. meaningful)
- [ ] Zdefiniować target model: Random Forest vs. XGBoost vs. Isolation Forest
  - [ ] Recommendation: Isolation Forest (anomaly detection, low overhead)
  - [ ] Backup: Random Forest (better interpretability)

### [ ] 2.2 Dataset Preparation
- [ ] Zbierz benign samples (~500-1000):
  - [ ] Real PowerShell scripts z GitHub
  - [ ] Windows admin scripts
  - [ ] DevOps/automation scripts
- [ ] Zbierz malicious samples (~200-500):
  - [ ] Z sampli zebranych w 1.1
  - [ ] Label jako "obfuscated" or "bypass"
- [ ] Feature extraction pipeline:
  - [ ] Napisz extractor korzystający z ps-parser
  - [ ] Generate CSV z features + labels

### [ ] 2.3 Model Training & Evaluation
- [ ] Train model (Isolation Forest / Random Forest)
  - [ ] Test/train split: 80/20
  - [ ] Cross-validation: 5-fold
- [ ] Evaluate metrics:
  - [ ] Precision, Recall, F1-score
  - [ ] ROC-AUC curve
  - [ ] Confusion matrix
- [ ] Feature importance analysis
  - [ ] Identyfikuj które features są most discriminative
- [ ] Export model:
  - [ ] ONNX format (portable)
  - [ ] Pickle (dla Python deployment)

### [ ] 2.4 Integration z ramsi-rs
- [ ] Design scoring function w ramsi-rs:
  - [ ] Load trained model
  - [ ] Extract features z analyzed code (ps-parser integration)
  - [ ] Output ML score (0.0 - 1.0)
- [ ] Hybrid scoring:
  - [ ] 40% rule-based signature match
  - [ ] 30% ML anomaly score
  - [ ] 30% behavioral indicators
- [ ] Test end-to-end z sampli

### [ ] 2.5 Performance Optimization
- [ ] Benchmark model performance:
  - [ ] Inference time na typical sample
  - [ ] Memory footprint
- [ ] Optimize jeśli slow:
  - [ ] Model quantization
  - [ ] Feature pruning (drop low-importance features)
  - [ ] C++ acceleration (jeśli Python bottleneck)

---

## PRIORYTET 3: PowerShell Parser na C# (ps-parser→cs-parser Integration)

### [ ] 3.1 Design C# Parser
- [ ] Zdefiniuj scope:
  - [ ] Parsowanie PowerShell AST (Abstract Syntax Tree)
  - [ ] Detekcja obfuscacji patterns
  - [ ] Native .NET string evaluation
  - [ ] Reuse logic z ps-parser (Rust) ale w C#
- [ ] Zdefiniuj API:
  - [ ] `ParseScript(string code): AST`
  - [ ] `DetectObfuscation(AST): ObfuscationReport`
  - [ ] `EvaluateStrings(AST): ResolvedStrings`

### [ ] 3.2 Implementacja Parser
- [ ] Setup C# project (.NET 6.0+ / Framework)
- [ ] Implement tokenizer:
  - [ ] Lex PowerShell keywords, operators, strings
  - [ ] Handle comments, escape sequences
- [ ] Implement AST builder:
  - [ ] Parse statements, expressions, pipeline
  - [ ] Build tree structure
- [ ] Implement obfuscation detectors:
  - [ ] Base64 detection
  - [ ] String concatenation patterns
  - [ ] Invoke-Expression/IEX patterns
  - [ ] Encoding/decoding calls (EncodeToBase64, etc.)
  - [ ] Variable name entropy

### [ ] 3.3 Native String Evaluation
- [ ] Implement safe string deobfuscation:
  - [ ] Base64 decode (native `Convert.FromBase64String`)
  - [ ] Gzip/deflate decompression (`System.IO.Compression`)
  - [ ] URL decoding (`System.Net.WebUtility`)
  - [ ] Regex expansion (limited scope - no code execution!)
- [ ] **SECURITY**: Sandbox evaluation:
  - [ ] NO actual code execution (use static analysis only)
  - [ ] NO direct `Invoke-Expression` simulation
  - [ ] Timeout protection (malicious infinite loops)
  - [ ] Memory limits
- [ ] Test z obfuscated samples:
  - [ ] Validate deobfuscation accuracy
  - [ ] Compare z ps-parser output

### [ ] 3.4 Integration z ramsi-rs & AmsiProviderScanDisruption
- [ ] C# Wrapper dla ramsi-rs:
  - [ ] P/Invoke lub FFI do Rust library
  - [ ] Pass AST/features do ML scoring
- [ ] Integration z AmsiProviderScanDisruption PoC:
  - [ ] Use parser do analyze code before/after bypass attempt
  - [ ] Validate bypass effectiveness
  - [ ] Generate detection report

### [ ] 3.5 Testing & Validation
- [ ] Unit tests:
  - [ ] Tokenizer tests
  - [ ] AST builder tests
  - [ ] Deobfuscation tests (Base64, gzip, itd.)
- [ ] Integration tests:
  - [ ] End-to-end: raw script → AST → obfuscation report
  - [ ] Compare output z ps-parser (spot-check subset)
- [ ] Performance tests:
  - [ ] Benchmark parsing speed
  - [ ] Memory usage na large scripts
- [ ] Security tests:
  - [ ] Malicious regex patterns (ReDoS protection)
  - [ ] Malicious decompression (zip bombs)

### [ ] 3.6 Documentation & Demo
- [ ] Code documentation (comments, XML docs)
- [ ] README: How to use C# parser
- [ ] Demo: Obfuscated script → AST visualization
- [ ] Performance comparison: C# vs. ps-parser (Rust)

---

## PRIORYTET 4: Prezentacja - Materiały Demo

### [ ] 4.1 Przygotowanie Slide'ów
- [ ] Slide 1: Intro + Agenda
- [ ] Slide 2-3: Threat landscape (script-based attacks)
- [ ] Slide 4-5: AMSI architecture diagram
- [ ] Slide 6-7: Obfuscation techniques (examples)
- [ ] Slide 8: AMSI bypass techniques
- [ ] Slide 9: Detection layers diagram (3 core + optional 4th with ML)
- [ ] Slide 10: Hybrid ML scoring explanation
- [ ] Slide 11: Tools overview (ramsi-rs, ps-parser, cs-parser, AmsiProviderScanDisruption)
- [ ] Slide 12: Q&A / Resources

### [ ] 4.2 Live Demo Script
- [ ] Demo script (PowerShell): Obfuscated sample
- [ ] Demo output: ps-parser deobfuscation
- [ ] Demo output: ramsi-rs detection + ML score
- [ ] Demo output: ETW/AMSI logs showing detection
- [ ] Fallback: Pre-recorded videos (jeśli live demo fails)

### [ ] 4.3 Handouts & Resources
- [ ] Slide PDF export
- [ ] Cheat sheet: AMSI bypass indicators
- [ ] Cheat sheet: Obfuscation detection heuristics
- [ ] Links: GitHub repos, documentation, OWASP resources

---

## PRIORYTET 5: Testy & Validation

### [ ] 5.1 E2E Testing
- [ ] Test: Obfuscated sample → ramsi-rs → ML score → Alert
- [ ] Test: AmsiProviderScanDisruption bypass → Detection by ramsi-rs
- [ ] Test: C# parser accuracy vs ps-parser (spot-check)

### [ ] 5.2 Stress Testing
- [ ] Large scripts (10K+ lines)
- [ ] Deeply nested structures
- [ ] Multiple encoding layers
- [ ] Concurrent processing (jeśli C# parser async)

### [ ] 5.3 False Positive Testing
- [ ] Run legitimate PowerShell scripts through pipeline
  - [ ] Admin scripts
  - [ ] DevOps automation
  - [ ] Standard Windows scripts
- [ ] Measure false positive rate
- [ ] Tune ML thresholds if needed

---

## PRIORYTET 6: Finalizacja & Delivery

### [ ] 6.1 Code Review & Quality
- [ ] Code review: C# parser
- [ ] Code review: ML integration w ramsi-rs
- [ ] Fix security issues
- [ ] Optimize performance

### [ ] 6.2 Documentation
- [ ] Update README w tools z C# parser info
- [ ] Add ML methodology documentation
- [ ] Add detection accuracy metrics

### [ ] 6.3 Final Verification
- [ ] Run full demo na fresh VM
- [ ] Verify all links in slides
- [ ] Verify all tools build & run correctly
- [ ] Backup slides ready

### [ ] 6.4 Post-Presentation
- [ ] Record presentation (jeśli possible)
- [ ] Collect feedback z audience
- [ ] Update GitHub repos z slides + recordings
- [ ] Blog post / write-up w medium/LinkedIn

---

## Timeline Estimate

| Fase | Czas | Deadline |
|------|------|----------|
| Priorytet 1 (Sampli & Testy) | 3-4 dni | ASAP |
| Priorytet 2 (ML Algorithm) | 4-5 dni | 1 tydzień |
| Priorytet 3 (C# Parser) | 5-7 dni | 2 tygodnie |
| Priorytet 4 (Slides & Demo) | 2-3 dni | 3 tygodnie |
| Priorytet 5 (Validation) | 2 dni | 3 tygodnie |
| Priorytet 6 (Finalizacja) | 1-2 dni | Dzień przed prezentacją |

**Total: ~3-4 tygodnie**

---

## Dependencies & Blockers

- [ ] Dostęp do VirusTotal / malware samples (wymagany dla Priorytet 1)
- [ ] C# compiler & .NET SDK (wymagany dla Priorytet 3)
- [ ] Python ML libraries (scikit-learn, pandas) na dev machine (Priorytet 2)
- [ ] Rust compiler (już masz, dla ramsi-rs)

---

## Notes

- **Start z Priorytet 1**: Bez sampli, nie możesz testować nic
- **Priorytet 2 & 3 parallelize**: ML i C# parser to niezależne, mogą biegać równolegle
- **Demo jest kluczowy**: Poświęć czas na przygotowanie - live demo zawsze robi wrażenie
- **ML model nie musi być perfect**: Nawet ~85% accuracy jest OK na konferencji - chodzi o proof-of-concept
- **C# parser**: To ambitny projekt - jeśli będzie za dużo, możesz zredukować do wrapper'a do ps-parser zamiast full reimplementation

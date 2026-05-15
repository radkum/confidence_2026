# Confidence — AMSI vs. Obfuscation

A two-layer defense system against PowerShell-based AMSI bypass attacks:

1. **Layer 1 (inline AMSI provider)** — Rust COM provider that hands every PowerShell
   script to a C# NativeAOT detector. The detector deobfuscates (9 techniques) and
   matches against 30+ predicates covering reflection bypass, ETW bypass, WLDP
   bypass, vtable hijack, and more.
2. **Layer 2 (kernel driver)** — Rust no_std driver registers process / image-load /
   registry callbacks. When something enumerates `HKLM\SOFTWARE\Microsoft\AMSI\
   Providers`, the userspace daemon suspends the process, evaluates a policy, and
   either resumes or terminates with a red console notice.

## Demo thesis

> Deobfuscator catches **~96 %** of obfuscated real-world bypasses statically.
> But some techniques (runtime-built identifiers, char-code comparisons) cannot
> be deobfuscated without executing — that is where kernel-side behavioural
> detection takes over.

Detection rate on bundled samples:

| Category              | Count | Detected | Rate    |
| --------------------- | ----- | -------- | ------- |
| Malicious obfuscated  | 28    | 27       | **96 %** |
| Benign installers     | 50    | 49 clean | **2 % FP** |

## Repository layout

```
.
├── PsParser/            ← C# NativeAOT detector (Layer 1 brain)
│   ├── AmsiBypassDetector.cs    30+ predicates, deduplicated
│   ├── ObfuscationDetector.cs   9 deobfuscation techniques
│   ├── FeatureExtractor.cs      20-feature vector for ML
│   ├── MlScorer.cs              online learning, confidence ramp-up
│   ├── NativeApi.cs             FFI exports for ramsi-com
│   └── Program.cs               CLI: PSParser.exe --json <file>
│
├── ramsi-rs/            ← Rust workspace: AMSI COM provider (Layer 1 host)
│   ├── ramsi-com/       COM-registered AMSI provider DLL
│   ├── ps-parser/       Rust-side fallback heuristic parser
│   ├── cs-parser/       C# code analyser (used inside Add-Type blocks)
│   └── shared/          Common types, FFI helpers, file logger
│
├── sysmon-rs/           ← Rust workspace: kernel driver + userspace daemon
│   ├── sysmon-km/       no_std kernel driver (Layer 2 sensor)
│   ├── sysmon-um/       userspace policy enforcer (suspend → decide → kill)
│   └── common/          IPC types shared via \\.\SysMon device
│
├── deploy/              ← Build + package + install scripts
│   ├── build.bat                Builds all three components
│   ├── package.bat              Bundles into confidence-release.zip
│   ├── sign_build.ps1           Self-signs sysmon.sys + exports .cer
│   ├── install.ps1              On-target install (regsvr32 + sc create)
│   ├── uninstall.ps1            Force-unload locked DLLs via ramon-client
│   ├── test_amsi.ps1            End-to-end Layer 1 self-test
│   ├── diagnose_layer2.ps1      Kernel callback diagnostics
│   ├── compare_layers.ps1       Run scenarios in C1/C2/C3 configs
│   └── confidence-release/      Output: ready-to-ship bundle (gitignored)
│
├── samples/             ← PowerShell samples (subset, see download notes)
│   └── Obfuscated_Malicious_Powershell/
│       ├── 26_amsi_provider_disruption.ps1            radkum-original vtable hijack
│       ├── 27_amsi_provider_disruption_evasive.ps1    evasive variant — Layer 1 misses
│       └── 28_etw_bypass.ps1                          classic ETW telemetry disable
│
├── demo_screens/        ← Screenshots used in the .pptx deck
├── AMSI_vs_Obfuscation.pptx    Presentation deck (28 slides, ~50 min)
├── PRESENTATION.md      Markdown mirror of slide content
├── DEMO_INSTRUCTIONS.md Step-by-step screenshot session
└── progress.md          Project status log
```

## Build

### Requirements

- **Rust nightly** (for `sysmon-km` kernel-mode flags)
- **.NET 8 SDK** with native AOT workload
- **Visual Studio 2022** with C++ desktop workload (for NativeAOT linker)
- **Windows 10/11 x64**
- For Layer 2: **test signing mode** enabled (`bcdedit /set testsigning on`, then reboot)

### One-shot build

```cmd
cd deploy
build.bat        :: builds PSParser, ramsi-com, sysmon-km, sysmon-um
package.bat      :: bundles everything into confidence-release.zip
```

Produces `deploy/confidence-release.zip` (~37 MB) with installers, signed driver,
and self-contained PSParser.exe.

### Component builds (advanced)

```cmd
:: Layer 1 detector
cd PsParser
dotnet build -c Release
dotnet publish -r win-x64 -c Release -p:PublishAot=true -p:NativeLib=Shared -o publish

:: Layer 1 COM provider
cd ramsi-rs
cargo build -p ramsi-com --release

:: Layer 2 kernel driver  (must build from sysmon-km dir for .cargo/config.toml)
cd sysmon-rs/sysmon-km
cargo build --release

:: Layer 2 userspace daemon
cd sysmon-rs
cargo build -p sysmon-client --release
```

## Install (target machine)

Requires Administrator + test signing mode.

```cmd
:: Extract confidence-release.zip, cd into it, then:
install.bat

sc start ConfidenceKm                                   :: start kernel driver
"C:\Program Files\Confidence\sysmon-um.exe"             :: start userspace monitor
```

`install.ps1` does:

1. Copy binaries to `C:\Program Files\Confidence\`
2. Copy `sysmon.sys` to `C:\Windows\System32\drivers\`
3. Import self-signed cert into LocalMachine\Root + TrustedPublisher
4. `regsvr32 ramsi_com.dll` (register AMSI provider in `HKLM\...\AMSI\Providers`)
5. `sc create ConfidenceKm` (register kernel service)

To uninstall: `uninstall.bat` (force-unloads any locked DLLs via the included
`ramon-client.exe` helper).

## Quick smoke test

```powershell
# Layer 1 -- offline scan
"C:\Program Files\Confidence\PSParser.exe" --json sample.ps1
# → JSON with status / confidence / indicators

# Layer 1 -- AMSI integration self-test
.\test_amsi.ps1
# → exercises ramsi-com via fresh PowerShell session

# Layer 2 -- kernel driver diagnostics
.\diagnose_layer2.ps1
# → verifies driver hash, callbacks, AMSI registry events
```

## Demo flow

The presentation deck (`AMSI_vs_Obfuscation.pptx`) walks through the full demo in
~50 minutes. The interactive part runs in two windows side by side:

```
┌─────────────────────────────────┬───────────────────────────────────┐
│  command terminal               │  sysmon-um.exe live monitor      │
│  (admin PowerShell)             │  (separate console)              │
└─────────────────────────────────┴───────────────────────────────────┘
```

Then sequentially:

```powershell
# Act 1 — Layer 1 blocks real-world bypass
.\samples\malicious\28_etw_bypass.ps1
# → red ScriptContainedMaliciousContent in your shell

# Act 2 — detection rate sweep
.\PSParser.exe --json (gci .\samples\malicious\*.ps1)
# → 27/28 detected

# Act 3 — Layer 1 catches literal radkum
& powershell.exe -File .\samples\malicious\26_amsi_provider_disruption.ps1
# → ramsi-com.log shows is_bypass=true

# Act 4 — Layer 1 MISSES evasive variant
.\PSParser.exe --json .\samples\malicious\27_amsi_provider_disruption_evasive.ps1
# → "status": "Clean"  (PUNCH MOMENT)

# Act 5 — Layer 2 catches the recon technique
& powershell.exe -File .\samples\malicious\27_amsi_provider_disruption_evasive.ps1
# → Layer 2 suspends, decides SUSPECT, terminates;
#   sysmon-um monitor shows full audit trail
```

Full step-by-step including screenshot points lives in `DEMO_INSTRUCTIONS.md`.

## Samples — what is included

The bundled `samples/Obfuscated_Malicious_Powershell/` directory contains the
three samples used in the demo (26, 27, 28). The rest of the sample collection
(nishang, PowerSploit, Invoke-Obfuscation, AmsiScanBufferBypass, benign Az/M365
installers) is **not redistributed** — see `samples/INSTRUKCJE_POBIERANIA.md`
(Polish) for direct-download instructions. Those repositories carry their own
licenses; only download them if your engagement allows.

## Architecture notes

### Online ML layer (early stage)

`PsParser/MlScorer.cs` runs logistic regression over the 20-feature vector from
`FeatureExtractor.cs`. The final confidence is blended with rule-based detection:

```
weight        = min(samples_collected / 10_000, 1.0)
final_score   = rules_score · (1 − weight) + ml_score · weight
```

Each scan increments the sample counter. The deck has slide 14 dedicated to this
architecture; the rationale is honest gradual hand-off from rules to ML as a real
training set accrues.

### Kernel callback fix

The vtable hijack technique published by [radkum/AmsiProviderScanDisruption](https://github.com/radkum/AmsiProviderScanDisruption)
patches the AMSI provider's COM vtable in user space. The kernel-side fix
registers a `CmRegisterCallbackEx` handler that fires on `RegNtPostOpenKeyEx`
(notify class 29 — note: not 28 which is the *pre* variant; this caught us
during development), filters paths containing `\AMSI\`, and emits a
`RegistryEnumerate` event over `\\.\SysMon`. The userspace daemon receives it,
calls `NtSuspendProcess`, checks the process image / cmdline against a small
whitelist, then `NtTerminateProcess` if suspect.

### Sample 27 — what makes it evasive

Sample 27 reconstructs every flagged identifier at runtime:

- Method names from base64 (`'RGxsR2V0Q2xhc3NPYmplY3Q='` → `DllGetClassObject`)
- Type name "AMSI" from char codes (`65 77 83 73`)
- Add-Type attribute name from string concat (`'Unmanaged' + 'FunctionPointer'`)

The .ps1 source file therefore contains **zero literal substrings** that match
any of the deobfuscator's predicates. Layer 1 returns `Clean`. Only Layer 2's
behavioural detection catches it because the registry access **happens at
runtime** regardless of how the path string was assembled.

## License

Source code: choose a license (e.g. MIT or Apache-2.0). External samples shipped
under the licenses of their original repositories — refer to each.

## Acknowledgements

- [radkum/AmsiProviderScanDisruption](https://github.com/radkum/AmsiProviderScanDisruption) — original vtable hijack technique
- [windows-kernel-rs](https://github.com/radkum/windows-kernel-rs) — kernel-mode bindings used by `sysmon-km`
- Microsoft AMSI documentation and the Microsoft-Windows-PowerShell ETW provider

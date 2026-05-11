"""
Detection Matrix Test
=====================
Test 1: AMSI bypass techniques (Obfuscated_Malicious_Powershell/)
Test 2: Obfuscation resilience (malicious samples + programmatic obfuscation)

Usage:
    python test_matrix.py              # run both tests
    python test_matrix.py --test1      # AMSI bypass detection only
    python test_matrix.py --test2      # obfuscation resilience only
    python test_matrix.py --csv        # also write CSV files
"""

import subprocess, json, os, sys, base64, re, math
from pathlib import Path
from dataclasses import dataclass, field

ROOT      = Path(__file__).parent
SAMPLES   = ROOT / "samples"
OBFDIR    = SAMPLES / "Obfuscated_Malicious_Powershell"
MALICIOUS = SAMPLES / "malicious"
PSPARSER  = ROOT / "PsParser" / "PSParser.csproj"

# ── PsParser runner ───────────────────────────────────────────────────────────

def scan(ps1_path: Path) -> dict:
    """Run PsParser --json on a file and return parsed JSON result."""
    try:
        result = subprocess.run(
            ["dotnet", "run", "--project", str(PSPARSER), "--", "--json", str(ps1_path)],
            capture_output=True, text=True, timeout=30
        )
        for line in result.stdout.splitlines():
            line = line.strip()
            if line.startswith("{"):
                return json.loads(line)
    except (subprocess.TimeoutExpired, json.JSONDecodeError, Exception):
        pass
    return {"status": "ERROR", "confidence": 0, "obfuscation": {}, "amsi_bypass": {}}

# ── Obfuscation transforms ────────────────────────────────────────────────────

def obf_base64(code: str) -> str:
    b64 = base64.b64encode(code.encode("utf-16-le")).decode()
    return f'IEX([System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String(\'{b64}\')))'

def obf_string_split(code: str) -> str:
    """Split suspicious keywords into concatenated parts."""
    replacements = {
        "Invoke-Expression": "'Inv'+'oke-Exp'+'ression'",
        "Invoke-Mimikatz":   "'Inv'+'oke-Mim'+'ikatz'",
        "AmsiScanBuffer":    "'Ams'+'iSca'+'nBuffer'",
        "amsiInitFailed":    "'amsi'+'Init'+'Failed'",
        "VirtualProtect":    "'Virt'+'ual'+'Protect'",
        "Invoke-WebRequest": "'Inv'+'oke-Web'+'Request'",
    }
    result = code
    for original, split in replacements.items():
        result = result.replace(original, f"({split})")
    return result

def obf_backtick(code: str) -> str:
    """Insert backticks into keywords."""
    keywords = ["Invoke", "Expression", "Mimikatz", "AmsiScan", "VirtualProtect"]
    result = code
    for kw in keywords:
        if kw in result:
            # insert backtick after 3rd char
            obfuscated = kw[:3] + "`" + kw[3:]
            result = result.replace(kw, obfuscated)
    return result

def obf_char_array(code: str) -> str:
    """Wrap entire script as char array join."""
    chars = ",".join(str(ord(c)) for c in code)
    return f"-join([char[]]@({chars}))|IEX"

def obf_double_base64(code: str) -> str:
    """Double Base64 encoding."""
    inner = obf_base64(code)
    return obf_base64(inner)

TRANSFORMS = {
    "original":      lambda c: c,
    "base64":        obf_base64,
    "string_split":  obf_string_split,
    "backtick":      obf_backtick,
    "char_array":    obf_char_array,
    "double_base64": obf_double_base64,
}

# ── Helpers ───────────────────────────────────────────────────────────────────

def indicator_summary(result: dict) -> str:
    indicators = []
    bypass = result.get("amsi_bypass", {}) or {}
    for ind in bypass.get("indicators", []):
        indicators.append(ind.get("type", "?"))
    obf = result.get("obfuscation", {}) or {}
    for ind in obf.get("indicators", []):
        t = ind.get("type", "?")
        if t not in indicators:
            indicators.append(t)
    return ", ".join(indicators[:4]) + ("..." if len(indicators) > 4 else "")

def status_icon(status: str) -> str:
    return {"AMSI BYPASS": "[BYPASS]", "Suspicious": "[SUSPIC]", "Clean": "[CLEAN ]", "ERROR": "[ERROR ]"}.get(status, "[?    ]")

def confidence_bar(conf: int) -> str:
    filled = conf // 10
    return "█" * filled + "░" * (10 - filled) + f" {conf}%"

def write_csv(rows: list[dict], path: Path):
    if not rows:
        return
    headers = list(rows[0].keys())
    with open(path, "w", encoding="utf-8") as f:
        f.write(",".join(headers) + "\n")
        for row in rows:
            f.write(",".join(str(row.get(h, "")) for h in headers) + "\n")
    print(f"  → CSV: {path}")

# ── Test 1: AMSI Bypass Detection Matrix ─────────────────────────────────────

def test1_amsi_bypass(write_csv_flag=False):
    print("\n" + "="*70)
    print("TEST 1: AMSI Bypass Detection Matrix")
    print("="*70)
    print(f"  Source: {OBFDIR.relative_to(ROOT)}")

    files = sorted(OBFDIR.glob("*.ps1"), key=lambda p: int(re.match(r'^(\d+)', p.stem).group(1))
                   if re.match(r'^(\d+)', p.stem) else 999)

    if not files:
        print("  ERROR: No .ps1 files found in Obfuscated_Malicious_Powershell/")
        return []

    print(f"  Files: {len(files)}\n")
    print(f"  {'#':<4} {'File':<40} {'Status':<14} {'Conf':>5}  Indicators")
    print(f"  {'-'*4} {'-'*40} {'-'*14} {'-'*5}  {'-'*30}")

    rows = []
    detected = 0
    for f in files:
        result = scan(f)
        status   = result.get("status", "ERROR")
        conf     = result.get("confidence", 0)
        icon     = status_icon(status)
        inds     = indicator_summary(result)
        num      = re.match(r'^(\d+)', f.stem)
        num_str  = num.group(1) if num else "?"
        if status != "Clean":
            detected += 1
        print(f"  {num_str:<4} {f.stem:<40} {icon} {status:<12} {conf:>4}%  {inds}")
        rows.append({
            "file": f.name,
            "status": status,
            "confidence": conf,
            "indicators": inds
        })

    print(f"\n  Detected: {detected}/{len(files)} ({100*detected//len(files)}%)")
    missed = [r["file"] for r in rows if r["status"] == "Clean"]
    if missed:
        print(f"  Missed:   {', '.join(missed)}")

    if write_csv_flag:
        write_csv(rows, ROOT / "results_test1_amsi_bypass.csv")

    return rows

# ── Test 2: Obfuscation Resilience Matrix ─────────────────────────────────────

# Representative malicious samples to test
TEST_SAMPLES = [
    ("Invoke-Mimikatz",     MALICIOUS / "nishang/Gather/Invoke-Mimikatz.ps1"),
    ("Invoke-AmsiBypass",   MALICIOUS / "nishang/Bypass/Invoke-AmsiBypass.ps1"),
    ("Invoke-Shellcode",    MALICIOUS / "PowerSploit/CodeExecution/Invoke-Shellcode.ps1"),
    ("Get-PassHashes",      MALICIOUS / "nishang/Gather/Get-PassHashes.ps1"),
    ("HTTP-Backdoor",       MALICIOUS / "nishang/Backdoors/HTTP-Backdoor.ps1"),
    ("Invoke-PowerShellTcp",MALICIOUS / "nishang/Shells/Invoke-PowerShellTcp.ps1"),
]

def test2_resilience(write_csv_flag=False):
    print("\n" + "="*70)
    print("TEST 2: Obfuscation Resilience Matrix")
    print("="*70)

    technique_cols = list(TRANSFORMS.keys())
    rows = []

    # Header
    col_w = 14
    header = f"  {'Sample':<28}" + "".join(f"{t:>{col_w}}" for t in technique_cols)
    print(header)
    print("  " + "-"*28 + "-"*(col_w * len(technique_cols)))

    for label, path in TEST_SAMPLES:
        if not path.exists():
            print(f"  {label:<28}  [FILE NOT FOUND]")
            continue

        original_code = path.read_text(encoding="utf-8", errors="ignore")
        row = {"sample": label}
        line = f"  {label:<28}"

        for tech_name, transform in TRANSFORMS.items():
            try:
                obfuscated = transform(original_code)
            except Exception:
                obfuscated = original_code

            # Write to temp file, scan, delete
            tmp = ROOT / f"_tmp_test_{tech_name}.ps1"
            try:
                tmp.write_text(obfuscated, encoding="utf-8")
                result = scan(tmp)
                status = result.get("status", "ERROR")
                conf   = result.get("confidence", 0)
                cell   = f"{status_icon(status)}{conf:>3}%"
            except Exception:
                cell = " ERR"
            finally:
                if tmp.exists():
                    tmp.unlink()

            row[tech_name] = cell
            line += f"{cell:>{col_w}}"

        rows.append(row)
        print(line)

    # Legend
    print("\n  Legend: [BYPASS] AMSI BYPASS  [SUSPIC] Suspicious  [CLEAN ] Clean  [ERROR ] Error")
    print("  Format: icon + confidence%")

    # Summary: which technique evades detection most
    print("\n  Evasion rate per technique (% of samples going Clean after obfuscation):")
    for tech in technique_cols:
        clean_count = sum(1 for r in rows if "[CLEAN ]" in str(r.get(tech, "")))
        total = len([r for r in rows if tech in r])
        if total > 0:
            pct = 100 * clean_count // total
            bar = "█" * (pct // 10) + "░" * (10 - pct // 10)
            print(f"    {tech:<16} {bar} {pct:>3}% evasion")

    if write_csv_flag:
        # Flatten for CSV
        csv_rows = []
        for label, path in TEST_SAMPLES:
            if not path.exists():
                continue
            original_code = path.read_text(encoding="utf-8", errors="ignore")
            for tech_name, transform in TRANSFORMS.items():
                try:
                    obfuscated = transform(original_code)
                    tmp = ROOT / f"_tmp_csv_{tech_name}.ps1"
                    tmp.write_text(obfuscated, encoding="utf-8")
                    result = scan(tmp)
                    csv_rows.append({
                        "sample": label,
                        "technique": tech_name,
                        "status": result.get("status", "ERROR"),
                        "confidence": result.get("confidence", 0),
                        "indicators": indicator_summary(result),
                    })
                except Exception as e:
                    csv_rows.append({"sample": label, "technique": tech_name,
                                     "status": "ERROR", "confidence": 0, "indicators": str(e)})
                finally:
                    if tmp.exists():
                        tmp.unlink()
        write_csv(csv_rows, ROOT / "results_test2_resilience.csv")

    return rows

# ── Main ──────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    args = sys.argv[1:]
    do_csv   = "--csv"   in args
    do_test1 = "--test1" in args or not any(a.startswith("--test") for a in args)
    do_test2 = "--test2" in args or not any(a.startswith("--test") for a in args)

    print("PsParser Detection Matrix")
    print(f"Project: {ROOT}")

    # Warm up dotnet (first run compiles)
    print("\nWarming up dotnet build...", end=" ", flush=True)
    subprocess.run(["dotnet", "build", str(PSPARSER), "-v", "quiet"],
                   capture_output=True)
    print("done.")

    if do_test1:
        test1_amsi_bypass(do_csv)
    if do_test2:
        test2_resilience(do_csv)

    print("\n" + "="*70)
    print("Done.")

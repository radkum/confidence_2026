#Requires -RunAsAdministrator
# ============================================================
#  test_amsi.ps1 -- Layer 1 (AMSI) end-to-end test
#
#  IMPORTANT: This script must NOT contain any AMSI bypass
#  source strings, otherwise Defender's AMSI will block it
#  before parsing. All bypass payloads live in samples\.
#
#  Steps:
#   1. Verify AMSI provider registration (registry keys)
#   2. Verify DLL files exist
#   3. Test PSParser CLI on malicious + benign samples
#   4. Test AMSI live by running a sample in fresh PowerShell
# ============================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$AmsiClsid   = '{b8614e83-84ac-45fb-82a8-21711aaf07f2}'
$InstallDir  = 'C:\Program Files\Confidence'
$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$SamplesDir  = "$ScriptDir\samples"

$pass = 0
$fail = 0

function TestOK([string]$msg)  { Write-Host "  [PASS] $msg" -ForegroundColor Green; $script:pass++ }
function TestFail([string]$msg){ Write-Host "  [FAIL] $msg" -ForegroundColor Red;   $script:fail++ }
function TestInfo([string]$msg){ Write-Host "  [INFO] $msg" -ForegroundColor Cyan }

Write-Host "========================================" -ForegroundColor Yellow
Write-Host "  Confidence AMSI Test  $(Get-Date)" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

if (-not [Environment]::Is64BitProcess) {
    Write-Host ""
    Write-Host "[ABORT] You are running this in a 32-bit PowerShell." -ForegroundColor Red
    Write-Host "        Spawned powershell.exe will inherit bitness and load the 32-bit AMSI provider chain --"
    Write-Host "        which does NOT include our 64-bit ramsi_com.dll. Tests will fail."
    Write-Host ""
    Write-Host "        Relaunch in 64-bit PowerShell:"
    Write-Host '          C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
    Write-Host '        or:'
    Write-Host '          "C:\Program Files\PowerShell\7\pwsh.exe"'
    Write-Host ""
    exit 1
}

# ----------------------------------------------------------------
Write-Host ""
Write-Host "[1/4] AMSI Provider registration..." -ForegroundColor Yellow

$amsiKey  = "HKLM:\SOFTWARE\Microsoft\AMSI\Providers\$AmsiClsid"
$clsidKey = "HKLM:\SOFTWARE\Classes\CLSID\$AmsiClsid\InProcServer32"

if (Test-Path $amsiKey) {
    TestOK "AMSI Providers key registered"
} else {
    TestFail "AMSI Providers key NOT found ($amsiKey)"
}

if (Test-Path $clsidKey) {
    $dllFromReg = (Get-ItemProperty $clsidKey).'(default)'
    TestOK "CLSID InProcServer32 -> $dllFromReg"
    if (Test-Path $dllFromReg) {
        TestOK "ramsi_com.dll file exists on disk"
    } else {
        TestFail "ramsi_com.dll file NOT found at $dllFromReg"
    }
} else {
    TestFail "CLSID InProcServer32 key NOT found"
}

# ----------------------------------------------------------------
Write-Host ""
Write-Host "[2/4] Supporting files..." -ForegroundColor Yellow

$envPath = [System.Environment]::GetEnvironmentVariable('PSPARSER_DLL_PATH', 'Machine')
if ($envPath) {
    TestOK "PSPARSER_DLL_PATH = $envPath"
    if (Test-Path $envPath) {
        TestOK "PSParser.dll exists at env path"
    } else {
        TestFail "PSParser.dll NOT found at $envPath"
    }
} else {
    TestInfo "PSPARSER_DLL_PATH not set (fallback uses hardcoded path)"
}

if (Test-Path "$InstallDir\PSParser.dll") {
    TestOK "PSParser.dll present in $InstallDir"
} else {
    TestFail "PSParser.dll missing from $InstallDir"
}

# ----------------------------------------------------------------
Write-Host ""
Write-Host "[3/4] PSParser CLI direct detection..." -ForegroundColor Yellow

# Use compiled PSParser.exe (no `dotnet run` welcome banner)
$PsParserExe = @(
    "C:\VSExclude\confidence_2026\PsParser\bin\Release\net8.0\PSParser.exe",
    "C:\VSExclude\confidence_2026\PsParser\bin\Debug\net8.0\PSParser.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

function Invoke-PsParser([string]$path) {
    # PsParser prints "Scanning N file(s)..." then a single-line JSON
    $out = & $PsParserExe --json $path 2>&1 | Out-String
    $jsonLine = ($out -split "`r?`n") | Where-Object { $_.TrimStart().StartsWith('{') } | Select-Object -First 1
    if (-not $jsonLine) {
        TestInfo "  raw output: $($out.Substring(0, [Math]::Min(200, $out.Length)))"
        return $null
    }
    try {
        return $jsonLine | ConvertFrom-Json
    } catch {
        TestInfo "  ConvertFrom-Json error: $($_.Exception.Message)"
        TestInfo "  JSON head: $($jsonLine.Substring(0, [Math]::Min(150, $jsonLine.Length)))..."
        return $null
    }
}

if (-not $PsParserExe) {
    TestInfo "PSParser.exe not found -- skipping CLI test"
} else {
    # malicious sample should be detected
    $malSample = Get-ChildItem "$SamplesDir\malicious\*.ps1" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($malSample) {
        TestInfo "Scanning malicious sample: $($malSample.Name)"
        $result = Invoke-PsParser $malSample.FullName
        if (-not $result) {
            TestFail "PsParser returned no JSON for $($malSample.Name)"
        } else {
            $bypass = $result.amsi_bypass.is_amsi_bypass
            $score  = $result.amsi_bypass.confidence_score
            if ($bypass) {
                TestOK "Detected as AMSI bypass (score: $score, status: $($result.status))"
            } elseif ($score -ge 40) {
                TestOK "Flagged as suspicious (score: $score)"
            } else {
                TestFail "Malicious sample NOT detected (score: $score, status: $($result.status))"
            }
        }
    } else {
        TestInfo "No malicious samples found"
    }

    # benign sample should NOT be detected
    $benSample = Get-ChildItem "$SamplesDir\test-synthetic\test_05_benign.ps1" -ErrorAction SilentlyContinue
    if ($benSample) {
        TestInfo "Scanning benign sample: $($benSample.Name)"
        $result = Invoke-PsParser $benSample.FullName
        if (-not $result) {
            TestFail "PsParser returned no JSON for $($benSample.Name)"
        } else {
            $bypass = $result.amsi_bypass.is_amsi_bypass
            $score  = $result.amsi_bypass.confidence_score
            if (-not $bypass -and $score -lt 40) {
                TestOK "Benign correctly NOT flagged (score: $score, status: $($result.status))"
            } else {
                TestFail "Benign FALSE POSITIVE (score: $score, bypass: $bypass)"
            }
        }
    }
}

# ----------------------------------------------------------------
Write-Host ""
Write-Host "[4/4] AMSI integration (live PS session)..." -ForegroundColor Yellow

$ramsiLog = 'C:\ProgramData\Confidence\logs\ramsi-com.log'

if (-not (Test-Path $amsiKey)) {
    TestInfo "Skipping live test -- AMSI provider not registered"
} else {
    # Delete ramsi-com log so we only see entries from this test (Set-Content '' leaves BOM)
    if (Test-Path $ramsiLog) {
        Remove-Item -Path $ramsiLog -Force -ErrorAction SilentlyContinue
        TestInfo "Removed ramsi-com.log"
    }

    # --- Phase A: benign script -- proves ramsi-com.dll is loaded into powershell.exe -----
    TestInfo "Phase A: running BENIGN script in fresh PS session..."
    $marker = "ramsi_test_marker_$(Get-Random)"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Write-Host '$marker'" 2>&1 | Out-Null
    Start-Sleep -Milliseconds 500

    if (Test-Path $ramsiLog) {
        $logLines = Get-Content $ramsiLog -ErrorAction SilentlyContinue
        if ($logLines -and ($logLines -match 'scan_script ENTRY')) {
            TestOK "ramsi-com is loaded into powershell.exe (saw scan_script ENTRY)"
            $entryCount = ($logLines | Select-String 'scan_script ENTRY').Count
            TestInfo "  -> scan_script ENTRY count: $entryCount"
            if ($logLines -match [Regex]::Escape($marker)) {
                TestOK "ramsi-com saw the exact marker script we sent"
            }
        } else {
            TestFail "ramsi-com.log empty -- DLL NOT loaded into powershell.exe"
            TestInfo "  Possible causes:"
            TestInfo "  - regsvr32 didn't run successfully"
            TestInfo "  - PSPARSER_DLL_PATH not visible to powershell.exe (Machine env not refreshed)"
            TestInfo "  - ramsi_com.dll missing dependencies"
        }
    } else {
        TestFail "ramsi-com.log not created -- ramsi_com.dll never ran"
        TestInfo "  -> ramsi-com is NOT loaded by powershell.exe"
    }

    # --- Phase B: malicious script (best-effort, may be blocked by Defender filesystem scan) -----
    Write-Host ""
    TestInfo "Phase B: running MALICIOUS sample (Defender may block at filesystem level)..."
    $bypassSample = "$SamplesDir\test-synthetic\test_01_reflection_bypass.ps1"
    if (Test-Path $bypassSample) {
        $beforeCount = 0
        if (Test-Path $ramsiLog) {
            $beforeCount = ((Get-Content $ramsiLog) | Select-String 'scan_script ENTRY').Count
        }

        $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $bypassSample 2>&1 | Out-String
        Start-Sleep -Milliseconds 500

        if ($output -match 'contains a virus|potentially unwanted') {
            TestInfo "Defender filesystem scanner blocked the file (before AMSI) -- expected on systems with Defender"
            TestInfo "  -> exclude '$SamplesDir' in Defender to test ramsi-com on real bypass payloads"
        } elseif (Test-Path $ramsiLog) {
            $newLines = Get-Content $ramsiLog
            $afterCount = ($newLines | Select-String 'scan_script ENTRY').Count
            if ($afterCount -gt $beforeCount) {
                TestOK "ramsi-com saw the bypass script ($($afterCount - $beforeCount) new scan_script entries)"
                $detected = $newLines | Select-String '-> Detected|is_bypass=true' | Select-Object -Last 5
                if ($detected) {
                    TestOK "ramsi-com classified script as Detected/bypass"
                    $detected | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
                }
            } else {
                TestInfo "Sample ran but no new scan_script entries -- check log"
            }
        }
    }

    # --- Print last log lines so user can inspect manually -----
    if (Test-Path $ramsiLog) {
        $allLines = @(Get-Content $ramsiLog -ErrorAction SilentlyContinue)
        Write-Host ""
        Write-Host "  --- ramsi-com.log (last 15 of $($allLines.Count) lines) ---" -ForegroundColor Cyan
        if ($allLines.Count -gt 0) {
            $allLines | Select-Object -Last 15 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        } else {
            Write-Host "  (file is empty)" -ForegroundColor Gray
        }
        Write-Host "  --- end ---" -ForegroundColor Cyan
    }
}

# ----------------------------------------------------------------
Write-Host ""
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "  RESULTS: $pass passed, $fail failed" -ForegroundColor $(if ($fail -eq 0) { 'Green' } else { 'Red' })
Write-Host "========================================" -ForegroundColor Yellow

if ($fail -gt 0) {
    Write-Host ""
    Write-Host "Hint: if registration tests failed, run install.bat (as Admin) first." -ForegroundColor Yellow
}


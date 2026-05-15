#Requires -RunAsAdministrator
# compare_layers.ps1 -- runs identical scenarios in current install state,
# saves a labeled report. Run 3x in 3 states to compare:
#   1. No ramsi  (uninstall.ps1)
#   2. ramsi yes, driver no  (install.ps1 then sc stop ConfidenceKm)
#   3. ramsi + driver        (install.ps1 + sc start ConfidenceKm)

Set-StrictMode -Version Latest

if (-not [Environment]::Is64BitProcess) {
    Write-Host "[ABORT] run in 64-bit PowerShell" -ForegroundColor Red; exit 1
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ReportDir = "$ScriptDir\reports"
if (-not (Test-Path $ReportDir)) { New-Item -ItemType Directory -Path $ReportDir | Out-Null }

# ─── Detect current state ───────────────────────────────────────────────────
$AmsiClsid = '{b8614e83-84ac-45fb-82a8-21711aaf07f2}'
$ramsiOn   = Test-Path "HKLM:\SOFTWARE\Microsoft\AMSI\Providers\$AmsiClsid"
$drvSvc    = Get-Service ConfidenceKm -ErrorAction SilentlyContinue
$drvOn     = $drvSvc -and $drvSvc.Status -eq 'Running'
$defOn     = $true
try {
    $mp = Get-MpPreference -ErrorAction Stop
    $defOn = -not $mp.DisableRealtimeMonitoring
} catch {}

$stateLabel = if (-not $ramsiOn) { 'C1_no-ramsi' }
              elseif (-not $drvOn) { 'C2_ramsi-only' }
              else { 'C3_ramsi+driver' }

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$reportFile = "$ReportDir\compare_${stateLabel}_$timestamp.txt"
$ramsiLog = 'C:\ProgramData\Confidence\logs\ramsi-com.log'

# ─── Build report header ────────────────────────────────────────────────────
function W([string]$s) {
    Write-Host $s
    Add-Content $reportFile -Value $s -Encoding UTF8
}

Set-Content $reportFile -Value '' -Encoding UTF8
W "========================================"
W "  Layer Comparison Report -- $(Get-Date)"
W "========================================"
W "State          : $stateLabel"
W "Defender (RT)  : $(if ($defOn) {'ON'} else {'OFF'})"
W "ramsi-com AMSI : $(if ($ramsiOn) {'REGISTERED'} else {'not registered'})"
W "sysmon driver  : $(if ($drvOn) {'RUNNING'} else {'stopped/absent'})"
W ""

# Clear ramsi log so each run starts fresh
if (Test-Path $ramsiLog) { Remove-Item $ramsiLog -Force -ErrorAction SilentlyContinue }

# ─── Test scenarios ─────────────────────────────────────────────────────────
# All inline -Command (no .ps1 on disk) -- avoids Defender filesystem scan.
# Scripts are assembled at runtime from constituent strings so this very file
# stays clean of AMSI bypass signatures (otherwise Defender's AMSI blocks
# compare_layers.ps1 itself before parsing).

$scenarios = @(
    @{
        Name = 'S1_benign'
        Desc = 'Benign command (baseline -- everything passes)'
        Build = { "Write-Host hello_$(Get-Random)" }
    }
    @{
        Name = 'S2_reflection_bypass'
        Desc = 'Classic AmsiUtils reflection bypass'
        # Assembled dynamically so the source file does not carry the signature
        Build = {
            $a = '[Ref].Assembly.GetType('
            $b = "'System.Management.Automation.A" + "msiUtils')"
            $c = ".GetField('amsi" + "InitFailed','NonPublic,Static').SetValue(`$null,`$true)"
            "$a$b$c"
        }
    }
    @{
        Name = 'S3_etw_bypass'
        Desc = 'PSEtwLogProvider etwProvider null'
        Build = {
            $a = '[System.Management.Automation.Tracing.PSEtwLogProvider]'
            $b = ".GetField('etwProvider','NonPublic,Static').SetValue(`$null,`$null)"
            "$a$b"
        }
    }
    @{
        Name = 'S4_base64_iex'
        Desc = 'Base64-encoded Invoke-Expression'
        Build = {
            $payload = 'Write-Host base64_ok'
            $b64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($payload))
            "iex([Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('$b64')))"
        }
    }
    @{
        Name = 'S5_psv2_downgrade_attempt'
        Desc = 'powershell -Version 2 (downgrade attempt)'
        Build = { 'powershell -Version 2 -Command "Write-Host downgraded"' }
    }
    @{
        Name = 'S6_provider_vtable_patch'
        Desc = 'AmsiProviderScanDisruption: patches vtable of ALL AMSI providers (incl. ramsi-com)'
        # The script is shipped as a sample file. Read from disk + run inline so
        # Defender filesystem scan does not block the .ps1 (AMSI still sees content).
        Build = {
            $samplePath = Join-Path $script:ScriptDir 'samples\malicious\26_amsi_provider_disruption.ps1'
            if (-not (Test-Path $samplePath)) { return $null }
            $content = Get-Content -Raw $samplePath
            # Wrap in scriptblock so output is captured; run via Invoke-Expression
            "Invoke-Expression @'`n$content`n'@"
        }
    }
)

W "===== Scenarios ====="
foreach ($s in $scenarios) {
    W ""
    W "[$($s.Name)]  $($s.Desc)"

    $cmd = & $s.Build
    if (-not $cmd) {
        W "  SKIPPED (missing sample / setup)"
        continue
    }
    $cmdPreview = if ($cmd.Length -gt 80) { $cmd.Substring(0,80) + '...' } else { $cmd }
    W "  cmd: $cmdPreview"

    # Snapshot ramsi log size before
    $beforeCount = 0
    if (Test-Path $ramsiLog) {
        $beforeCount = (Get-Content $ramsiLog | Measure-Object -Line).Lines
    }

    # Run inline in fresh PS
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $cmd 2>&1 | Out-String
    Start-Sleep -Milliseconds 400

    # Detect Defender filesystem block (rare for inline, but happens with -File)
    $defBlock = $output -match 'contains a virus|ScriptContainedMaliciousContent|potentially unwanted'
    # Detect AMSI-time block (Defender's AMSI provider rejecting)
    $amsiBlock = $output -match 'malicious content has been blocked|ScriptBlockLogging'
    $executed = -not ($defBlock -or $amsiBlock) -and ($output -notmatch '^\s*$')

    # ramsi-com.log delta
    $ramsiSawIt = $false
    $ramsiVerdict = 'n/a'
    if (Test-Path $ramsiLog) {
        $allLines = Get-Content $ramsiLog
        $newLines = $allLines | Select-Object -Skip $beforeCount
        if ($newLines -match 'scan_script ENTRY') {
            $ramsiSawIt = $true
            $detected = $newLines | Select-String 'scan_script EXIT' | Select-Object -Last 1
            if ($detected) { $ramsiVerdict = ($detected.Line -split '-> ')[-1].Trim() }
        }
    }

    W "  output (first 100ch): $($output.Trim().Substring(0, [Math]::Min(100, $output.Trim().Length)))"
    W "  Defender block : $defBlock"
    W "  AMSI block     : $amsiBlock"
    W "  Executed       : $executed"
    W "  ramsi saw it   : $ramsiSawIt"
    W "  ramsi verdict  : $ramsiVerdict"
}

W ""
W "========================================"
W "Report saved: $reportFile"
W "========================================"
Write-Host ""
Write-Host "Next: run this script again in a different config (uninstall / driver stop / full)" -ForegroundColor Cyan
Write-Host "Then diff the 3 reports in $ReportDir" -ForegroundColor Cyan

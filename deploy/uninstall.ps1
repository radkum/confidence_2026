#Requires -RunAsAdministrator
param([switch]$Force)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$InstallDir = 'C:\Program Files\Confidence'
$DriversDir = "$env:SystemRoot\System32\drivers"
$LogDir     = 'C:\ProgramData\Confidence\logs'
$Timestamp  = Get-Date -Format 'yyyyMMdd_HHmmss'
$LogFile    = "$LogDir\uninstall_$Timestamp.log"
$SvcName    = 'ConfidenceKm'
$AmsiClsid  = '{b8614e83-84ac-45fb-82a8-21711aaf07f2}'

$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$ForceDelete = "$ScriptDir\ramon-client.exe"

function Remove-FileForce([string]$path) {
    # Try plain delete first; fall back to ramon-client force-delete for locked files (loaded DLLs).
    if (-not (Test-Path $path)) {
        Log "Not found (OK): $(Split-Path -Leaf $path)"
        return
    }
    try {
        Remove-Item -Path $path -Force -ErrorAction Stop
        Log "Deleted: $(Split-Path -Leaf $path)"
        return
    } catch {
        Log "Standard delete failed for $(Split-Path -Leaf $path) -- trying force delete"
    }
    if (Test-Path $ForceDelete) {
        $out = & $ForceDelete response delete-file $path 2>&1 | Out-String
        Log "ramon-client: $($out.Trim())"
        if (-not (Test-Path $path)) {
            Log "OK: force-deleted $(Split-Path -Leaf $path)"
        } else {
            Log "[WARNING] $(Split-Path -Leaf $path) still present -- may be scheduled for delete on reboot"
        }
    } else {
        Log "[WARNING] ramon-client.exe not found at $ForceDelete -- cannot force-delete"
    }
}

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Log([string]$msg) {
    $line = "  $msg"
    Write-Host $line
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}
function LogH([string]$msg) {
    Write-Host $msg
    Add-Content -Path $LogFile -Value $msg -Encoding UTF8
}

LogH "========================================"
LogH "  Confidence UNINSTALL  $(Get-Date)"
LogH "  InstallDir = $InstallDir"
LogH "  Service    = $SvcName"
LogH "  AMSI CLSID = $AmsiClsid"
LogH "========================================"


# ----------------------------------------------------------------
LogH ""
LogH "[1/5] Stopping and removing service $SvcName..."

$svc = Get-Service -Name $SvcName -ErrorAction SilentlyContinue
if ($svc) {
    if ($svc.Status -eq 'Running') {
        Log "Stopping service..."
        Stop-Service -Name $SvcName -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }
    Log "Deleting service..."
    $del = & sc.exe delete $SvcName
    if ($LASTEXITCODE -eq 0) {
        Log "OK: service deleted"
    } else {
        Log "[WARNING] sc delete failed (code $LASTEXITCODE) -- retry after reboot"
    }
    Start-Sleep -Seconds 1
} else {
    Log "Service not found -- skipping."
}

# ----------------------------------------------------------------
LogH ""
LogH "[2/5] Unregistering AMSI provider..."

$amsiKey = "HKLM:\SOFTWARE\Microsoft\AMSI\Providers\$AmsiClsid"
if (Test-Path $amsiKey) {
    $dllPath = "$InstallDir\ramsi_com.dll"
    $unregOk = $false

    if (Test-Path $dllPath) {
        Log "regsvr32 /u /s $dllPath ..."
        $proc = Start-Process -FilePath regsvr32 -ArgumentList "/u /s `"$dllPath`"" -Wait -PassThru -NoNewWindow
        Log "regsvr32 /u exit code: $($proc.ExitCode)"
        if ($proc.ExitCode -eq 0) {
            $unregOk = $true
            Log "OK: unregistered via regsvr32"
        } else {
            Log "[WARNING] regsvr32 /u failed -- removing registry keys manually"
        }
    } else {
        Log "ramsi_com.dll not in $InstallDir -- removing keys manually"
    }

    if (-not $unregOk) {
        try {
            Remove-Item -Path $amsiKey -Recurse -Force
            Log "OK: AMSI Providers key deleted"
        } catch {
            Log "[ERROR] Cannot delete AMSI Providers key: $_"
        }
        $clsidKey = "HKLM:\SOFTWARE\Classes\CLSID\$AmsiClsid"
        if (Test-Path $clsidKey) {
            try {
                Remove-Item -Path $clsidKey -Recurse -Force
                Log "OK: CLSID key deleted"
            } catch {
                Log "[WARNING] CLSID key not found or access denied: $_"
            }
        }
    }
} else {
    Log "AMSI provider not registered -- skipping."
}

# ----------------------------------------------------------------
LogH ""
LogH "[3/5] Removing PSPARSER_DLL_PATH env var..."

try {
    $current = [System.Environment]::GetEnvironmentVariable('PSPARSER_DLL_PATH', [System.EnvironmentVariableTarget]::Machine)
    if ($null -ne $current) {
        [System.Environment]::SetEnvironmentVariable('PSPARSER_DLL_PATH', $null, [System.EnvironmentVariableTarget]::Machine)
        Log "OK: PSPARSER_DLL_PATH removed"
    } else {
        Log "Not set -- skipping."
    }
} catch {
    Log "[WARNING] Could not remove env var: $_"
}

# ----------------------------------------------------------------
LogH ""
LogH "[4/5] Removing files from $InstallDir..."

if (Test-Path $InstallDir) {
    foreach ($file in @('PSParser.dll', 'ramsi_com.dll', 'sysmon-um.exe')) {
        Remove-FileForce -path "$InstallDir\$file"
    }
    $remaining = @(Get-ChildItem $InstallDir -ErrorAction SilentlyContinue)
    if ($remaining.Count -eq 0) {
        try {
            Remove-Item -Path $InstallDir -Force
            Log "Directory removed (was empty)"
        } catch {
            Log "[WARNING] Cannot remove directory: $_"
        }
    } else {
        Log "Directory not empty -- leaving in place ($($remaining.Count) item(s) remain)"
    }
} else {
    Log "Directory not found -- skipping."
}

# ----------------------------------------------------------------
LogH ""
LogH "[5/5] Removing driver from $DriversDir..."

Remove-FileForce -path "$DriversDir\sysmon.sys"

# ----------------------------------------------------------------
LogH ""
LogH "========================================"
LogH "  UNINSTALL COMPLETE  $(Get-Date)"
LogH "  Log: $LogFile"
LogH "========================================"
Write-Host ""
Write-Host "[OK] Uninstall complete."
Write-Host "  Log: $LogFile"
Write-Host ""


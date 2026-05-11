
<#PSScriptInfo

.VERSION 1.1

.GUID a45e3eba-38f7-416f-9b4e-d5aa924a02d0

.AUTHOR Joseph Pradeep

.COMPANYNAME

.COPYRIGHT

.TAGS

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
Version 1.0:  Intial version.

.PRIVATEDATA

#>

<# 

.DESCRIPTION 
 Retrives Hardware information from client machine 

#> 
Param(
    [Parameter(Mandatory = $False)] [String] $OutputFile = "$($env:TEMP)\HardwareInfo.csv"
)
Begin {
    Function Add-ContentToFile($Path, $Data) {
        $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
        [System.IO.File]::WriteAllLines($Path, $Data, $Utf8NoBomEncoding)
    }
}
Process {

    Write-Verbose "Checking Serial number of the device"
    $serialNum = (Get-CimInstance -Class Win32_BIOS).SerialNumber

    Write-Verbose "Checking Hardware info of the device"
    $hardwareDetails = (Get-CimInstance -Namespace root/cimv2/mdm/dmmap -Class MDM_DevDetail_Ext01 -Filter "InstanceID='Ext' AND ParentID='./DevDetail'")
    $hash = $hardwareDetails.DeviceHardwareData
    $data = [PSCustomObject]@{
        "Device Serial Number" = $serialNum
        "Windows Product ID"   = ""
        "Hardware Hash"        = $hash
    }
    if ($OutputFile) {
        Add-ContentToFile -Path $($OutputFile) -data $($data | ConvertTo-Csv -NoTypeInformation | % { $_ -replace '"', '' })
    }
}
End {
    return $data
}


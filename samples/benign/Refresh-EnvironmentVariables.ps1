<#PSScriptInfo

.VERSION 2.0.0

.GUID 9ff8b18d-cc46-449e-81f1-bbdacc3f41b4

.AUTHOR asherto

.COMPANYNAME asheroto

.TAGS PowerShell Windows refresh reload path env environment variable variables update current

.PROJECTURI https://github.com/asheroto/Refresh-EnvironmentVariables

.RELEASENOTES
[Version 0.0.1] - Initial Release.
[Version 1.0.0] - Total rework of script, implementing Chocolatey's Update-SessionEnvironment function into one single script.
[Version 1.0.1] - Rename to Refresh-EnvironmentVariables to avoid naming conflicts with Chocolatey's RefreshEnv.cmd.
[Version 1.0.2] - Fix bug with CheckForUpdate.
[Version 1.1.0] - Fix PATH ordering, prevent overwriting critical environment variables, and remove stale environment variables from session
[Version 2.0.0] - Total redesign, now supports the ability to remove deleted entries from path.

#>

<#
.SYNOPSIS
    Refreshes the environment variables in the current PowerShell session.
.DESCRIPTION
    Refreshes the environment variables in the current PowerShell session.
.EXAMPLE
	Refresh-EnvironmentVariables
.PARAMETER CheckForUpdate
    Checks if there is an update available for the script.
.PARAMETER Version
    Displays the version of the script.
.PARAMETER Help
    Displays the full help information for the script.
.NOTES
	Version      : 2.0.0
	Created by   : asheroto
.LINK
	Project Site: https://github.com/asheroto/Refresh-EnvironmentVariables
#>
[CmdletBinding()]
param (
    [switch]$Version,
    [switch]$Help,
    [switch]$CheckForUpdate,
    [switch]$RemoveStale
)

# Derived from the original work by Chocolatey Software, used in accordance with license
# Copyright © 2017 - 2021 Chocolatey Software, Inc.

# Based on concepts from Chocolatey's Update-SessionEnvironment
# Rewritten and extended for standalone use

# Original license, included per the terms of the Apache 2.0 license:
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.

# Version
$CurrentVersion = '2.0.0'
$RepoOwner = 'asheroto'
$RepoName = 'Refresh-EnvironmentVariables'
$PowerShellGalleryName = 'Refresh-EnvironmentVariables'

# Versions
$ProgressPreference = 'SilentlyContinue'
$ConfirmPreference = 'None'

if ($Version.IsPresent) {
    $CurrentVersion
    exit 0
}

if ($Help) {
    Get-Help -Name $MyInvocation.MyCommand.Source -Full
    exit 0
}

function Get-GitHubRelease {
    [CmdletBinding()]
    param (
        [string]$Owner,
        [string]$Repo
    )
    try {
        $url = "https://api.github.com/repos/$Owner/$Repo/releases/latest"
        $response = Invoke-RestMethod -Uri $url -ErrorAction Stop

        $latestVersion = $response.tag_name
        $publishedAt = $response.published_at

        $UtcDateTime = [DateTime]::Parse($publishedAt, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
        $PublishedLocalDateTime = $UtcDateTime.ToLocalTime()

        [PSCustomObject]@{
            LatestVersion     = $latestVersion
            PublishedDateTime = $PublishedLocalDateTime
        }
    } catch {
        Write-Error "Unable to check for updates.`nError: $_"
        exit 1
    }
}

function CheckForUpdate {
    param (
        [string]$RepoOwner,
        [string]$RepoName,
        [version]$CurrentVersion,
        [string]$PowerShellGalleryName
    )

    $Data = Get-GitHubRelease -Owner $RepoOwner -Repo $RepoName

    if ($Data.LatestVersion -gt $CurrentVersion) {
        Write-Output "`nA new version of $RepoName is available.`n"
        Write-Output "Current version: $CurrentVersion."
        Write-Output "Latest version: $($Data.LatestVersion)."
        Write-Output "Published at: $($Data.PublishedDateTime).`n"
        Write-Output "https://github.com/$RepoOwner/$RepoName/releases`n"
        if ($PowerShellGalleryName) {
            Write-Output "Install-Script $PowerShellGalleryName -Force`n"
        }
    } else {
        Write-Output "`n$RepoName is up to date.`n"
    }
    exit 0
}

if ($CheckForUpdate) {
    CheckForUpdate -RepoOwner $RepoOwner -RepoName $RepoName -CurrentVersion $CurrentVersion -PowerShellGalleryName $PowerShellGalleryName
}

function Get-EnvironmentVariable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][System.EnvironmentVariableTarget] $Scope,
        [switch] $PreserveVariables
    )

    if ($Scope -eq [System.EnvironmentVariableTarget]::Process) {
        return [Environment]::GetEnvironmentVariable($Name, $Scope)
    }

    $keyPath = if ($Scope -eq 'User') { 'Environment' } else { 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment' }
    $registry = if ($Scope -eq 'User') { [Microsoft.Win32.Registry]::CurrentUser } else { [Microsoft.Win32.Registry]::LocalMachine }

    try {
        $key = $registry.OpenSubKey($keyPath)
        if ($null -ne $key) {
            $value = $key.GetValue($Name, '')
            $key.Close()
            if ($value) { return $value }
        }
    } catch {}

    return [Environment]::GetEnvironmentVariable($Name, $Scope)
}

function Get-EnvironmentVariableNames {
    param([System.EnvironmentVariableTarget] $Scope)

    switch ($Scope) {
        'User' { Get-Item 'HKCU:\Environment' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Property }
        'Machine' { Get-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' | Select-Object -ExpandProperty Property }
        'Process' { Get-ChildItem Env:\ | Select-Object -ExpandProperty Key }
    }
}

function Update-SessionEnvironment {
    <#
.SYNOPSIS
Updates the environment variables of the current powershell session...
#>
    param (
        [switch]$RemoveStale
    )

    $userName = $env:USERNAME
    $architecture = $env:PROCESSOR_ARCHITECTURE
    $psModulePath = $env:PSModulePath

    $ScopeList = 'Process', 'Machine'
    if ('SYSTEM', "${env:COMPUTERNAME}`$" -notcontains $userName) {
        $ScopeList += 'User'
    }

    $skip = @(
        'PATH', 'PSModulePath', 'USERNAME', 'PROCESSOR_ARCHITECTURE',
        # Windows login-derived variables (not stored in registry)
        'USERPROFILE', 'APPDATA', 'LOCALAPPDATA', 'HOMEDRIVE', 'HOMEPATH',
        'PUBLIC', 'ALLUSERSPROFILE', 'USERDOMAIN', 'USERDOMAIN_ROAMINGPROFILE',
        'LOGONSERVER', 'SESSIONNAME', 'COMPUTERNAME'
    )

    foreach ($Scope in $ScopeList) {
        Get-EnvironmentVariableNames -Scope $Scope | ForEach-Object {
            if ($skip -contains $_) { return }

            $value = Get-EnvironmentVariable -Scope $Scope -Name $_
            if ($null -ne $value -and $value -ne '') {
                Set-Item "Env:$_" -Value $value -ErrorAction SilentlyContinue
            }
        }
    }

    # PATH fix
    $machinePath = Get-EnvironmentVariable -Name 'PATH' -Scope Machine
    $userPath = Get-EnvironmentVariable -Name 'PATH' -Scope User
    $env:PATH = @($machinePath, $userPath) -join ';'

    # Remove stale variables
    if ($RemoveStale) {
        $validNames = @()
        $validNames += Get-EnvironmentVariableNames -Scope Machine
        $validNames += Get-EnvironmentVariableNames -Scope User
        $validNames = $validNames | Select-Object -Unique

        Get-ChildItem Env: | ForEach-Object {
            if ($skip -contains $_.Name) { return }
            if ($validNames -notcontains $_.Name) {
                Remove-Item "Env:$($_.Name)" -ErrorAction SilentlyContinue
            }
        }
    }

    $env:PSModulePath = $psModulePath
    if ($userName) { $env:USERNAME = $userName }
    if ($architecture) { $env:PROCESSOR_ARCHITECTURE = $architecture }
}

Write-Output "Refreshing environment variables..."
Update-SessionEnvironment -RemoveStale:$RemoveStale
Write-Output "Finished"
# SIG # Begin signature block
# MIIpaAYJKoZIhvcNAQcCoIIpWTCCKVUCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBZpToIV6lXcx3J
# J6KqZNuyxlX0gVKbRkjMZ8cwrdBqdqCCDh8wggawMIIEmKADAgECAhAIrUCyYNKc
# TJ9ezam9k67ZMA0GCSqGSIb3DQEBDAUAMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQK
# EwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNV
# BAMTGERpZ2lDZXJ0IFRydXN0ZWQgUm9vdCBHNDAeFw0yMTA0MjkwMDAwMDBaFw0z
# NjA0MjgyMzU5NTlaMGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwg
# SW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBDb2RlIFNpZ25pbmcg
# UlNBNDA5NiBTSEEzODQgMjAyMSBDQTEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAw
# ggIKAoICAQDVtC9C0CiteLdd1TlZG7GIQvUzjOs9gZdwxbvEhSYwn6SOaNhc9es0
# JAfhS0/TeEP0F9ce2vnS1WcaUk8OoVf8iJnBkcyBAz5NcCRks43iCH00fUyAVxJr
# Q5qZ8sU7H/Lvy0daE6ZMswEgJfMQ04uy+wjwiuCdCcBlp/qYgEk1hz1RGeiQIXhF
# LqGfLOEYwhrMxe6TSXBCMo/7xuoc82VokaJNTIIRSFJo3hC9FFdd6BgTZcV/sk+F
# LEikVoQ11vkunKoAFdE3/hoGlMJ8yOobMubKwvSnowMOdKWvObarYBLj6Na59zHh
# 3K3kGKDYwSNHR7OhD26jq22YBoMbt2pnLdK9RBqSEIGPsDsJ18ebMlrC/2pgVItJ
# wZPt4bRc4G/rJvmM1bL5OBDm6s6R9b7T+2+TYTRcvJNFKIM2KmYoX7BzzosmJQay
# g9Rc9hUZTO1i4F4z8ujo7AqnsAMrkbI2eb73rQgedaZlzLvjSFDzd5Ea/ttQokbI
# YViY9XwCFjyDKK05huzUtw1T0PhH5nUwjewwk3YUpltLXXRhTT8SkXbev1jLchAp
# QfDVxW0mdmgRQRNYmtwmKwH0iU1Z23jPgUo+QEdfyYFQc4UQIyFZYIpkVMHMIRro
# OBl8ZhzNeDhFMJlP/2NPTLuqDQhTQXxYPUez+rbsjDIJAsxsPAxWEQIDAQABo4IB
# WTCCAVUwEgYDVR0TAQH/BAgwBgEB/wIBADAdBgNVHQ4EFgQUaDfg67Y7+F8Rhvv+
# YXsIiGX0TkIwHwYDVR0jBBgwFoAU7NfjgtJxXWRM3y5nP+e6mK4cD08wDgYDVR0P
# AQH/BAQDAgGGMBMGA1UdJQQMMAoGCCsGAQUFBwMDMHcGCCsGAQUFBwEBBGswaTAk
# BggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEEGCCsGAQUFBzAC
# hjVodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9v
# dEc0LmNydDBDBgNVHR8EPDA6MDigNqA0hjJodHRwOi8vY3JsMy5kaWdpY2VydC5j
# b20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNybDAcBgNVHSAEFTATMAcGBWeBDAED
# MAgGBmeBDAEEATANBgkqhkiG9w0BAQwFAAOCAgEAOiNEPY0Idu6PvDqZ01bgAhql
# +Eg08yy25nRm95RysQDKr2wwJxMSnpBEn0v9nqN8JtU3vDpdSG2V1T9J9Ce7FoFF
# UP2cvbaF4HZ+N3HLIvdaqpDP9ZNq4+sg0dVQeYiaiorBtr2hSBh+3NiAGhEZGM1h
# mYFW9snjdufE5BtfQ/g+lP92OT2e1JnPSt0o618moZVYSNUa/tcnP/2Q0XaG3Ryw
# YFzzDaju4ImhvTnhOE7abrs2nfvlIVNaw8rpavGiPttDuDPITzgUkpn13c5Ubdld
# AhQfQDN8A+KVssIhdXNSy0bYxDQcoqVLjc1vdjcshT8azibpGL6QB7BDf5WIIIJw
# 8MzK7/0pNVwfiThV9zeKiwmhywvpMRr/LhlcOXHhvpynCgbWJme3kuZOX956rEnP
# LqR0kq3bPKSchh/jwVYbKyP/j7XqiHtwa+aguv06P0WmxOgWkVKLQcBIhEuWTatE
# QOON8BUozu3xGFYHKi8QxAwIZDwzj64ojDzLj4gLDb879M4ee47vtevLt/B3E+bn
# KD+sEq6lLyJsQfmCXBVmzGwOysWGw/YmMwwHS6DTBwJqakAwSEs0qFEgu60bhQji
# WQ1tygVQK+pKHJ6l/aCnHwZ05/LWUpD9r4VIIflXO7ScA+2GRfS0YW6/aOImYIbq
# yK+p/pQd52MbOoZWeE4wggdnMIIFT6ADAgECAhAKNMZR1UZgqS/qeQN0g3OKMA0G
# CSqGSIb3DQEBCwUAMGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwg
# SW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBDb2RlIFNpZ25pbmcg
# UlNBNDA5NiBTSEEzODQgMjAyMSBDQTEwHhcNMjYwMjA5MDAwMDAwWhcNMjcwMjA4
# MjM1OTU5WjBvMQswCQYDVQQGEwJVUzERMA8GA1UECBMIT2tsYWhvbWExETAPBgNV
# BAcTCE11c2tvZ2VlMRwwGgYDVQQKExNBc2hlciBTb2x1dGlvbnMgSW5jMRwwGgYD
# VQQDExNBc2hlciBTb2x1dGlvbnMgSW5jMIICIjANBgkqhkiG9w0BAQEFAAOCAg8A
# MIICCgKCAgEAsNcdHVM982mI1sSTuI2eOkKc4SoeDvPdZyoybYQWcOxzAYJsVzEI
# EoQcIjKU0KyOmPAEb/4U8VGrlATrm1BYwGLC9eymeBmUWc/VKECl6bPwos3B5K83
# qkNQshZvRtaN1S+surYIhW2vbHAtiIJnK4aY6emutJxB8TKuf68hTH13C9d0lwTG
# BSHTvLnYphdRg2z/VriH39GOP9d58YI/kztkS76v2itPjoO8fmoS7UicgpjfgV/D
# C6L09zg4pR9xhPWO0jpC4bDBw8pJyydSWyJNwiKYsDxSu9EoWWgYSuR3aP27seSj
# Soh6p+gcAHNkwD3TmwcDxgjLQJGQZCq81Wg6XD1wNRcQj3Co+aHM4bDnrEGr3Fr+
# KybVO4JzImTMAqqiNJsJfgZFkJpo8yWX91bmfyo/gCZdq8FM74BqabuCT0POxV2i
# hmj1IEujJlGXV7o1dl3HbOHfAbKBXZ56+sydA2TCANU6Tx72g6MMauaxq+HOOKng
# SYkpScbzng4XafT3Ik4AMutry4XwXvVvplnp7vvTuJC/udSGHicc2gTV9cvD4tH3
# 52J8niCbtlivKvCux+BkoFrZK8C7OTjbc08EWoD5UpMuEddx/L/kWsg65NExvY2a
# pHBsU4JnUe5h6ABqp70hvZJxpoX8b3n8uiWGUYzuC0UaTB+WoMgxMd0CAwEAAaOC
# AgMwggH/MB8GA1UdIwQYMBaAFGg34Ou2O/hfEYb7/mF7CIhl9E5CMB0GA1UdDgQW
# BBQHFH7qQHiyfL6gvRyEHXMdJO+aJTA+BgNVHSAENzA1MDMGBmeBDAEEATApMCcG
# CCsGAQUFBwIBFhtodHRwOi8vd3d3LmRpZ2ljZXJ0LmNvbS9DUFMwDgYDVR0PAQH/
# BAQDAgeAMBMGA1UdJQQMMAoGCCsGAQUFBwMDMIG1BgNVHR8Ega0wgaowU6BRoE+G
# TWh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRHNENvZGVT
# aWduaW5nUlNBNDA5NlNIQTM4NDIwMjFDQTEuY3JsMFOgUaBPhk1odHRwOi8vY3Js
# NC5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkRzRDb2RlU2lnbmluZ1JTQTQw
# OTZTSEEzODQyMDIxQ0ExLmNybDCBlAYIKwYBBQUHAQEEgYcwgYQwJAYIKwYBBQUH
# MAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBcBggrBgEFBQcwAoZQaHR0cDov
# L2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0Q29kZVNpZ25p
# bmdSU0E0MDk2U0hBMzg0MjAyMUNBMS5jcnQwCQYDVR0TBAIwADANBgkqhkiG9w0B
# AQsFAAOCAgEAutKpxJB9JYzuVnoBPTWJJYB0MhRrjbKY2lBq4V58at51H9A4PZjz
# KcLGenWuhgsWgzlgG6i+M/JjTZ2HG6ZXB+vGA5ZJxO5/InNIEcP2llytP6513Bre
# dJqEejqqgV2wmqFdiH272+ejnER+9EgydyD/zzIFLXpJ/5AK1Hr6tE7J37fgX+4e
# Kn9Lr/BOSda1FpSXprbC+mUtjMIm6NgO9c+hctEvl30osz2pzy8SzqliGeE/Nkn9
# MmcLw6KMpRRSLFDIAXgB4hFoWj8isPeNs4p3Sjb8ObrnZJdNQ8qDnWjT8kbrvAGp
# wW4Kp4c7o6VEBGwT2lQnSF/2HGDphCZNj/9sNbJ1wex2HBYkn/a26uFmvGjYHrZG
# SDDKXVBQEFM9BNNPHrXW2cOZyKpTftDsOK0SmX+y+kuHA2UT8HfB0LklyjUc15mz
# yzYn/n2WvVZt7fzTPJgsqRLRuoKOgQ5pIJY9XRq7i9oyFeUDZKsR5EblKB7Fbqcj
# txNcz7YmGLJvxDDx/qjeyvJLRKgBfm3yLRB/vL2xCTNKtmo0yK+Q5z5lrqMId+vm
# lrHx9C1K2KSqn8/JtAi0sOeoENEbD5Azl/ZmEtxQKgfS9fyul4Enh57IqJ9MILAP
# YOW63KIHwYscQAosM/PdjNy5DKDjwk+4jN7x9bEZJquPrl1y5XYE4j4xghqfMIIa
# mwIBATB9MGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjFB
# MD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBDb2RlIFNpZ25pbmcgUlNBNDA5
# NiBTSEEzODQgMjAyMSBDQTECEAo0xlHVRmCpL+p5A3SDc4owDQYJYIZIAWUDBAIB
# BQCgfDAQBgorBgEEAYI3AgEMMQIwADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIB
# BDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQg
# XrB8fNLGqka6k2eILm+4bVaM/9T3jrlNQ7x6bUB5LsMwDQYJKoZIhvcNAQEBBQAE
# ggIANdGccFFVwbZ+TpWsKyz3LxZj8Pz8xg9CzaLrVCWa0y38PO5k76OmoLFHRw9V
# 8DCgCHvHfIxiTGJSCHOtTlP/ZTukz3/HoAGcp9Pv8XqUY5DvpcXEMCt911GF3j7j
# 3P7tAzkdus96buNY41Qo5jYd19IGnhJfGUuajiCNL+VpOPW5qeU7+0iFR0R0oEKA
# zFGZAN6Rbb+Qn6eICu2/TU3iF0fFffow3rm0gdLt4niZsjqmH6hjGDROjKRciw71
# 9CoFiY+SJYDH8PH5WBy8qoneyNkaYIbdlD4Fo6NkWn2HYPGeuMwvaxFx48QR7miJ
# JqJm622II5IEiMnuOlnzeSwBLSGczJ6Mbdl0EBoxiNrAPFQdDDPC05WgEYJi8jeS
# WoEdTTyz5Kdl5UkAXHfXo7tO08BUYksco4nNWqRC80U37eq0Nikx6vBZBsFAC++0
# 0bx38PsReYP056HpTVqijSJPFUtC8u7q/uUoiyAyzrT5Uj4YymfPEG39+ErgkBvv
# CRa3NV3Vltx6H8y9q/8kI6T6l92ZeWWI0cXUrQWFkn3wPBnhDJCt0cd5kUg2sstS
# 33opNiVLyGlHb913jZnONbx1ysZVAW8HQX9JaqSTjqoEKUyPFK+8FhmgVdv0kWEZ
# bQZv7nCviFWqr9nogz4qCivX75tHi69+xbj55b+/MIYqvE+hghd1MIIXcQYKKwYB
# BAGCNwMDATGCF2EwghddBgkqhkiG9w0BBwKgghdOMIIXSgIBAzEPMA0GCWCGSAFl
# AwQCAQUAMHYGCyqGSIb3DQEJEAEEoGcEZTBjAgEBBglghkgBhv1sBwEwMTANBglg
# hkgBZQMEAgEFAAQgJDtPlup+eRBkNexz9tIJFdtwI0qzYsc32NDjf6yR8SoCD0DY
# 8k7bWwOKyhQp58l8QxgPMjAyNjA0MDgxODA3MTRaoIITOjCCBu0wggTVoAMCAQIC
# EAqA7xhLjfEFgtHEdqeVdGgwDQYJKoZIhvcNAQELBQAwaTELMAkGA1UEBhMCVVMx
# FzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMUEwPwYDVQQDEzhEaWdpQ2VydCBUcnVz
# dGVkIEc0IFRpbWVTdGFtcGluZyBSU0E0MDk2IFNIQTI1NiAyMDI1IENBMTAeFw0y
# NTA2MDQwMDAwMDBaFw0zNjA5MDMyMzU5NTlaMGMxCzAJBgNVBAYTAlVTMRcwFQYD
# VQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkGA1UEAxMyRGlnaUNlcnQgU0hBMjU2IFJT
# QTQwOTYgVGltZXN0YW1wIFJlc3BvbmRlciAyMDI1IDEwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQDQRqwtEsae0OquYFazK1e6b1H/hnAKAd/KN8wZQjBj
# MqiZ3xTWcfsLwOvRxUwXcGx8AUjni6bz52fGTfr6PHRNv6T7zsf1Y/E3IU8kgNke
# ECqVQ+3bzWYesFtkepErvUSbf+EIYLkrLKd6qJnuzK8Vcn0DvbDMemQFoxQ2Dsw4
# vEjoT1FpS54dNApZfKY61HAldytxNM89PZXUP/5wWWURK+IfxiOg8W9lKMqzdIo7
# VA1R0V3Zp3DjjANwqAf4lEkTlCDQ0/fKJLKLkzGBTpx6EYevvOi7XOc4zyh1uSqg
# r6UnbksIcFJqLbkIXIPbcNmA98Oskkkrvt6lPAw/p4oDSRZreiwB7x9ykrjS6GS3
# NR39iTTFS+ENTqW8m6THuOmHHjQNC3zbJ6nJ6SXiLSvw4Smz8U07hqF+8CTXaETk
# VWz0dVVZw7knh1WZXOLHgDvundrAtuvz0D3T+dYaNcwafsVCGZKUhQPL1naFKBy1
# p6llN3QgshRta6Eq4B40h5avMcpi54wm0i2ePZD5pPIssoszQyF4//3DoK2O65Uc
# k5Wggn8O2klETsJ7u8xEehGifgJYi+6I03UuT1j7FnrqVrOzaQoVJOeeStPeldYR
# NMmSF3voIgMFtNGh86w3ISHNm0IaadCKCkUe2LnwJKa8TIlwCUNVwppwn4D3/Pt5
# pwIDAQABo4IBlTCCAZEwDAYDVR0TAQH/BAIwADAdBgNVHQ4EFgQU5Dv88jHt/f3X
# 85FxYxlQQ89hjOgwHwYDVR0jBBgwFoAU729TSunkBnx6yuKQVvYv1Ensy04wDgYD
# VR0PAQH/BAQDAgeAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMIGVBggrBgEFBQcB
# AQSBiDCBhTAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMF0G
# CCsGAQUFBzAChlFodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRU
# cnVzdGVkRzRUaW1lU3RhbXBpbmdSU0E0MDk2U0hBMjU2MjAyNUNBMS5jcnQwXwYD
# VR0fBFgwVjBUoFKgUIZOaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0
# VHJ1c3RlZEc0VGltZVN0YW1waW5nUlNBNDA5NlNIQTI1NjIwMjVDQTEuY3JsMCAG
# A1UdIAQZMBcwCAYGZ4EMAQQCMAsGCWCGSAGG/WwHATANBgkqhkiG9w0BAQsFAAOC
# AgEAZSqt8RwnBLmuYEHs0QhEnmNAciH45PYiT9s1i6UKtW+FERp8FgXRGQ/YAavX
# zWjZhY+hIfP2JkQ38U+wtJPBVBajYfrbIYG+Dui4I4PCvHpQuPqFgqp1PzC/ZRX4
# pvP/ciZmUnthfAEP1HShTrY+2DE5qjzvZs7JIIgt0GCFD9ktx0LxxtRQ7vllKluH
# WiKk6FxRPyUPxAAYH2Vy1lNM4kzekd8oEARzFAWgeW3az2xejEWLNN4eKGxDJ8WD
# l/FQUSntbjZ80FU3i54tpx5F/0Kr15zW/mJAxZMVBrTE2oi0fcI8VMbtoRAmaasl
# NXdCG1+lqvP4FbrQ6IwSBXkZagHLhFU9HCrG/syTRLLhAezu/3Lr00GrJzPQFnCE
# H1Y58678IgmfORBPC1JKkYaEt2OdDh4GmO0/5cHelAK2/gTlQJINqDr6JfwyYHXS
# d+V08X1JUPvB4ILfJdmL+66Gp3CSBXG6IwXMZUXBhtCyIaehr0XkBoDIGMUG1dUt
# wq1qmcwbdUfcSYCn+OwncVUXf53VJUNOaMWMts0VlRYxe5nK+At+DI96HAlXHAL5
# SlfYxJ7La54i71McVWRP66bW+yERNpbJCjyCYG2j+bdpxo/1Cy4uPcU3AWVPGrbn
# 5PhDBf3Froguzzhk++ami+r3Qrx5bIbY3TVzgiFI7Gq3zWcwgga0MIIEnKADAgEC
# AhANx6xXBf8hmS5AQyIMOkmGMA0GCSqGSIb3DQEBCwUAMGIxCzAJBgNVBAYTAlVT
# MRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5j
# b20xITAfBgNVBAMTGERpZ2lDZXJ0IFRydXN0ZWQgUm9vdCBHNDAeFw0yNTA1MDcw
# MDAwMDBaFw0zODAxMTQyMzU5NTlaMGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5E
# aWdpQ2VydCwgSW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBUaW1l
# U3RhbXBpbmcgUlNBNDA5NiBTSEEyNTYgMjAyNSBDQTEwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQC0eDHTCphBcr48RsAcrHXbo0ZodLRRF51NrY0NlLWZ
# loMsVO1DahGPNRcybEKq+RuwOnPhof6pvF4uGjwjqNjfEvUi6wuim5bap+0lgloM
# 2zX4kftn5B1IpYzTqpyFQ/4Bt0mAxAHeHYNnQxqXmRinvuNgxVBdJkf77S2uPoCj
# 7GH8BLuxBG5AvftBdsOECS1UkxBvMgEdgkFiDNYiOTx4OtiFcMSkqTtF2hfQz3zQ
# Sku2Ws3IfDReb6e3mmdglTcaarps0wjUjsZvkgFkriK9tUKJm/s80FiocSk1VYLZ
# lDwFt+cVFBURJg6zMUjZa/zbCclF83bRVFLeGkuAhHiGPMvSGmhgaTzVyhYn4p0+
# 8y9oHRaQT/aofEnS5xLrfxnGpTXiUOeSLsJygoLPp66bkDX1ZlAeSpQl92QOMeRx
# ykvq6gbylsXQskBBBnGy3tW/AMOMCZIVNSaz7BX8VtYGqLt9MmeOreGPRdtBx3yG
# OP+rx3rKWDEJlIqLXvJWnY0v5ydPpOjL6s36czwzsucuoKs7Yk/ehb//Wx+5kMqI
# MRvUBDx6z1ev+7psNOdgJMoiwOrUG2ZdSoQbU2rMkpLiQ6bGRinZbI4OLu9BMIFm
# 1UUl9VnePs6BaaeEWvjJSjNm2qA+sdFUeEY0qVjPKOWug/G6X5uAiynM7Bu2ayBj
# UwIDAQABo4IBXTCCAVkwEgYDVR0TAQH/BAgwBgEB/wIBADAdBgNVHQ4EFgQU729T
# SunkBnx6yuKQVvYv1Ensy04wHwYDVR0jBBgwFoAU7NfjgtJxXWRM3y5nP+e6mK4c
# D08wDgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQMMAoGCCsGAQUFBwMIMHcGCCsGAQUF
# BwEBBGswaTAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEEG
# CCsGAQUFBzAChjVodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRU
# cnVzdGVkUm9vdEc0LmNydDBDBgNVHR8EPDA6MDigNqA0hjJodHRwOi8vY3JsMy5k
# aWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNybDAgBgNVHSAEGTAX
# MAgGBmeBDAEEAjALBglghkgBhv1sBwEwDQYJKoZIhvcNAQELBQADggIBABfO+xaA
# HP4HPRF2cTC9vgvItTSmf83Qh8WIGjB/T8ObXAZz8OjuhUxjaaFdleMM0lBryPTQ
# M2qEJPe36zwbSI/mS83afsl3YTj+IQhQE7jU/kXjjytJgnn0hvrV6hqWGd3rLAUt
# 6vJy9lMDPjTLxLgXf9r5nWMQwr8Myb9rEVKChHyfpzee5kH0F8HABBgr0UdqirZ7
# bowe9Vj2AIMD8liyrukZ2iA/wdG2th9y1IsA0QF8dTXqvcnTmpfeQh35k5zOCPmS
# Nq1UH410ANVko43+Cdmu4y81hjajV/gxdEkMx1NKU4uHQcKfZxAvBAKqMVuqte69
# M9J6A47OvgRaPs+2ykgcGV00TYr2Lr3ty9qIijanrUR3anzEwlvzZiiyfTPjLbnF
# RsjsYg39OlV8cipDoq7+qNNjqFzeGxcytL5TTLL4ZaoBdqbhOhZ3ZRDUphPvSRmM
# Thi0vw9vODRzW6AxnJll38F0cuJG7uEBYTptMSbhdhGQDpOXgpIUsWTjd6xpR6oa
# Qf/DJbg3s6KCLPAlZ66RzIg9sC+NJpud/v4+7RWsWCiKi9EOLLHfMR2ZyJ/+xhCx
# 9yHbxtl5TPau1j/1MIDpMPx0LckTetiSuEtQvLsNz3Qbp7wGWqbIiOWCnb5WqxL3
# /BAPvIXKUjPSxyZsq8WhbaM2tszWkPZPubdcMIIFjTCCBHWgAwIBAgIQDpsYjvnQ
# Lefv21DiCEAYWjANBgkqhkiG9w0BAQwFADBlMQswCQYDVQQGEwJVUzEVMBMGA1UE
# ChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSQwIgYD
# VQQDExtEaWdpQ2VydCBBc3N1cmVkIElEIFJvb3QgQ0EwHhcNMjIwODAxMDAwMDAw
# WhcNMzExMTA5MjM1OTU5WjBiMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNl
# cnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdp
# Q2VydCBUcnVzdGVkIFJvb3QgRzQwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIK
# AoICAQC/5pBzaN675F1KPDAiMGkz7MKnJS7JIT3yithZwuEppz1Yq3aaza57G4QN
# xDAf8xukOBbrVsaXbR2rsnnyyhHS5F/WBTxSD1Ifxp4VpX6+n6lXFllVcq9ok3DC
# srp1mWpzMpTREEQQLt+C8weE5nQ7bXHiLQwb7iDVySAdYyktzuxeTsiT+CFhmzTr
# BcZe7FsavOvJz82sNEBfsXpm7nfISKhmV1efVFiODCu3T6cw2Vbuyntd463JT17l
# Necxy9qTXtyOj4DatpGYQJB5w3jHtrHEtWoYOAMQjdjUN6QuBX2I9YI+EJFwq1WC
# QTLX2wRzKm6RAXwhTNS8rhsDdV14Ztk6MUSaM0C/CNdaSaTC5qmgZ92kJ7yhTzm1
# EVgX9yRcRo9k98FpiHaYdj1ZXUJ2h4mXaXpI8OCiEhtmmnTK3kse5w5jrubU75KS
# Op493ADkRSWJtppEGSt+wJS00mFt6zPZxd9LBADMfRyVw4/3IbKyEbe7f/LVjHAs
# QWCqsWMYRJUadmJ+9oCw++hkpjPRiQfhvbfmQ6QYuKZ3AeEPlAwhHbJUKSWJbOUO
# UlFHdL4mrLZBdd56rF+NP8m800ERElvlEFDrMcXKchYiCd98THU/Y+whX8QgUWtv
# sauGi0/C1kVfnSD8oR7FwI+isX4KJpn15GkvmB0t9dmpsh3lGwIDAQABo4IBOjCC
# ATYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQU7NfjgtJxXWRM3y5nP+e6mK4c
# D08wHwYDVR0jBBgwFoAUReuir/SSy4IxLVGLp6chnfNtyA8wDgYDVR0PAQH/BAQD
# AgGGMHkGCCsGAQUFBwEBBG0wazAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGln
# aWNlcnQuY29tMEMGCCsGAQUFBzAChjdodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5j
# b20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3J0MEUGA1UdHwQ+MDwwOqA4oDaG
# NGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RD
# QS5jcmwwEQYDVR0gBAowCDAGBgRVHSAAMA0GCSqGSIb3DQEBDAUAA4IBAQBwoL9D
# XFXnOF+go3QbPbYW1/e/Vwe9mqyhhyzshV6pGrsi+IcaaVQi7aSId229GhT0E0p6
# Ly23OO/0/4C5+KH38nLeJLxSA8hO0Cre+i1Wz/n096wwepqLsl7Uz9FDRJtDIeuW
# cqFItJnLnU+nBgMTdydE1Od/6Fmo8L8vC6bp8jQ87PcDx4eo0kxAGTVGamlUsLih
# Vo7spNU96LHc/RzY9HdaXFSMb++hUD38dglohJ9vytsgjTVgHAIDyyCwrFigDkBj
# xZgiwbJZ9VVrzyerbHbObyMt9H5xaiNrIv8SuFQtJ37YOtnwtoeW/VvRXKwYw02f
# c7cBqZ9Xql4o4rmUMYIDfDCCA3gCAQEwfTBpMQswCQYDVQQGEwJVUzEXMBUGA1UE
# ChMORGlnaUNlcnQsIEluYy4xQTA/BgNVBAMTOERpZ2lDZXJ0IFRydXN0ZWQgRzQg
# VGltZVN0YW1waW5nIFJTQTQwOTYgU0hBMjU2IDIwMjUgQ0ExAhAKgO8YS43xBYLR
# xHanlXRoMA0GCWCGSAFlAwQCAQUAoIHRMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0B
# CRABBDAcBgkqhkiG9w0BCQUxDxcNMjYwNDA4MTgwNzE0WjArBgsqhkiG9w0BCRAC
# DDEcMBowGDAWBBTdYjCshgotMGvaOLFoeVIwB/tBfjAvBgkqhkiG9w0BCQQxIgQg
# rBxN+T7KvLAl0tkxr07fMCccHDIGbtfHEyf8l8wDMrkwNwYLKoZIhvcNAQkQAi8x
# KDAmMCQwIgQgSqA/oizXXITFXJOPgo5na5yuyrM/420mmqM08UYRCjMwDQYJKoZI
# hvcNAQEBBQAEggIAlNdEnWSrzwiUUxbakLuI3/NKdRVjm3M3oGIEXNq6u1dEiQqP
# XDVvOkippUO5RPoXdxeaWS9KGViDryuYMOk2ju4wKvhGKPL0C+Nr5058YAwH7tv5
# 6oEsX8StMz9tcoga8+l+HEeJQC4Mojl8eGihbmwNlV5xSJqd4S3uznGml/BZBcCy
# L2WVkK4sOhoGw4KNSVpLxA1x9yH5JOuicFYVZtkOYCX9cG6hOLj0J1KxHvdtiTgm
# CE5eqbqvI726gRlNR2kL0Afs2Pag/AmRk1miYB1zYUZ/fSyTnAGGfEihu6CGOw4H
# +V03JmpDZTpN0LKED0beomDMWhXmyL2uoJPYMrUmvfo+UJh/EkPbrr4fdCBMhdoI
# r0DF39w1u2Ai2yEbtiPmf46/IDZuQONVfugx1jqrMvuB/L6OKY3hwFuunfg1m48L
# bfAHs1tCZfukxg76hXSJLGmI/kLr3wAArnFfW55RFTzUepsrbskiq+eLMMjrdxBf
# VBClreRNoDwCEgaFcgHQlMM/QKLQvZfrXrtYlOjBia/9FMp+WEKQv1p+5ijEKdXL
# V7EilqZm1nV2grLBi6okInNkGjeziSeFenjVWFR49oFvF1I+4mPSQRK0MF3riawV
# 1GSmnvZZ9KSNE262U6WIaaBQ72vuG54/QltVUniOwi00TNxdvAKKCYuf1oU=
# SIG # End signature block

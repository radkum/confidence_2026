
<#PSScriptInfo

.VERSION 3.1.1

.GUID 456d8a16-2f21-409a-91a1-b2bcb22353e3

.AUTHOR Fabrice Sanga

.COMPANYNAME sangafabrice

.COPYRIGHT © 2022 SangaFabrice. All rights reserved.

.TAGS google chrome chromium omaha update browser

.LICENSEURI https://github.com/sangafabrice/reg-cli/blob/main/LICENSE.md

.PROJECTURI https://github.com/sangafabrice/reg-cli/tree/googlechrome

.ICONURI https://rawcdn.githack.com/sangafabrice/choco-packages/4a3f99c43c1c2529ebb27f5a6b68b4c2efa5d4eb/icon.svg

.EXTERNALMODULEDEPENDENCIES DownloadInfo,RegCli 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
Simplify download info retrieval.

.PRIVATEDATA

#>

#Requires -Module @{ModuleName = 'DownloadInfo'; ModuleVersion = '5.0.4'}
#Requires -Module @{ModuleName = 'RegCli'; ModuleVersion = '6.2.2'}

[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\GoogleChrome",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $BaseNameLocation = "$InstallLocation\chrome"
    $NameLocation = "$BaseNameLocation.exe"
    Try {
        $UpdateModule =
            Import-CommonScript chrome-installer |
            Import-Module -PassThru -Force -Verbose:$False
        @{
            UpdateInfo = $(
                Write-Verbose 'Retrieve install or update information...'
                Try {
                    Get-DownloadInfo -PropertyList @{
                        OSArch = Get-ExecutableType $NameLocation
                    } -From GoogleChrome
                }
                Catch { }
            )
            NameLocation = $NameLocation
            SaveTo = $SaveTo
            SoftwareName = 'Google Chrome'
            InstallerDescription = 'Google Chrome Installer'
            VisualElementManifest = @{
                BaseNameLocation = $BaseNameLocation
                HexColor = '#2D364C'
            }
            Verbose = $VerbosePreference -ine 'SilentlyContinue'
        } | ForEach-Object { Invoke-CommonScript @_ }
    }
    Catch { }
    Finally { $UpdateModule | Remove-Module -Verbose:$False }
}

<#
.SYNOPSIS
    Updates Google Chrome browser software.
.DESCRIPTION
    The script installs or updates Google Chrome browser on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\GoogleChrome.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\GoogleChrome -ErrorAction SilentlyContinue

    PS > .\UpdateGoogleChrome.ps1 -InstallLocation C:\ProgramData\GoogleChrome -SaveTo .

    PS > Get-ChildItem C:\ProgramData\GoogleChrome | Select-Object Name
    Name
    ----
    105.0.5195.102
    chrome_proxy.exe
    chrome.exe
    chrome.VisualElementsManifest.xml

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    google_chrome_105.0.5195.102.exe
    UpdateGoogleChrome.ps1

    Install Google Chrome browser to 'C:\ProgramData\GoogleChrome' and save its setup installer to the current directory.
#>


<#PSScriptInfo

.VERSION 1.0.6

.GUID d860203a-bf1c-4477-aa2d-945981b9834e

.AUTHOR shfritz@microsoft.com

.COMPANYNAME Microsoft

.COPYRIGHT

.TAGS

.LICENSEURI

.PROJECTURI https://mrshannon.wordpress.com/

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
v1.0.6 - 2024mar08 Updated checks for UI.Xaml 2.8 which DesktopAppInstaller now depends on
v1.0.5 - 2023jan30 Changed pattern matches for Microsoft.DesktopAppInstaller files on GitHub
v1.0.4 - 2022jul29 Added a File Hash Integrity check of the DesktopAppInstaller/WinGet Package
v1.0.3 - 2022jul26 Set min/max versions of UI.Xaml to use 2.7.x to prevent 2.8 from being installed
v1.0.2 - 2022jul11 Changed Minimum Version for VCLibs from 14.0.30035.0 to 14.0.30704.0
v1.0.1 - 2022ju105 Provisioned the DesktopAppInstaller with xml licnese
v1.0.0 - 2022ju101 initial release

.PRIVATEDATA

#> 



<#
.SYNOPSIS
Runs the Quick Assist app from the Store and attempts to Install or Update required components if needed.

.DESCRIPTION
 Check if the user/device has the Quick Assist app installed and attempt to run it for the user.
If missing or too old, install Quick Assist from the Store using WinGet.
If missing or too old, install WinGet as part of the DesktopAppInstaller from GitHub.
If missing, install VCLibs 14.0 (C++ Runtime) from download.microsoft.com (DesktopAppInstaller prereq).
If missing, install UI.Xaml from NuGet (DesktopAppInstaller prereq).
If not configured, add NuGet Package Source (UI.Xaml prereq).
If missing or too old, install WebView2 machine-wide using the Evergreen installer from developer.microsoft.com.

.INPUTS
None. You cannot pipe objects to Invoke-QuickAssist.ps1.

.OUTPUTS
None. Invoke-QuickAssist.ps1 does not generate any output.

.EXAMPLE
PS> .\Invoke-QuickAssist.ps1
Invoke-QuickAssist-v1.0.5
Running as DESKTOP-KBQDMR2\defaultuser0 and IS Elevated
Quick Assist App 2.0.15.0 is already installed and meets the minimum required 2.0.6.0
WebView2 109.0.1518.70 is already installed
UAC Secure Desktop is already disabled
Starting Quick Assist App for DESKTOP-KBQDMR2\defaultuser0

.EXAMPLE
PS> .\Invoke-QuickAssist.ps1
Invoke-QuickAssist-v1.0.5
Running as DESKTOP-KBQDMR2\defaultuser0 and IS Elevated
WARNING: Quick Assist App is NOT installed for DESKTOP-KBQDMR2\defaultuser0
WARNING: This device does NOT have Quick Assist App and needs to be installed
WARNING: WinGet.exe is not installed. DesktopInstaller must be updated.
WARNING: DesktopAppInstaller is not installed
WARNING: VCLibs is not installed, attempting to download and install...
VCLibs 14.0.30704.0 has been installed
WARNING: UI.Xaml 2.7 is not installed, attempting to download/install with NuGet...
NuGet 2.8.5.208 is installed
WARNING: Unable to find package sources.
NuGet Package Source is now set to https://www.nuget.org/api/v2
Installing UI.Xaml 2.7 NuGet Package ...
UI.Xaml 2.7 NuGet Package 2.7.3 has been installed
UI.Xaml 2.7 has been registered using 7.2208.15002.0
Attempting to download and install the latest DesktopAppInstaller from GitHub
Downloading and Installing DesktopAppInstaller v1.4.10173
Installer File Integrity was confirmed with SHA256 Hash
DesktopAppInstaller has been updated to 1.19.10173.0
WinGet.exe v1.4.10173 has been installed
WARNING: Temporarily disabling UAC Prompt for Admins for installation
Installing Quick Assist App from the store using WinGet
WARNING: Re-enabling UAC Prompt for Admins
Quick Assist App 2.0.15.0 has been installed
Quick Assist App 2.0.15.0 has been installed for DESKTOP-KBQDMR2\defaultuser0
WARNING: Attempting to download and install the latest WebView2
Waiting for install to finish... (20/20)
Waiting for install to finish... (19/20)
WebView2 109.0.1518.70 has been installed
UAC Secure Desktop has been disabled
Starting Quick Assist App for DESKTOP-KBQDMR2\defaultuser0
#>

Param()

$ScriptName = 'Invoke-QuickAssist-v1.0.6'
Write-Host $ScriptName

# Force using TLS 1.2 connection
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Disable the progress bar in Invoke-WebRequest which speeds things up https://github.com/PowerShell/PowerShell/issues/2138
$ProgressPreference = 'SilentlyContinue'

$whoiam = [system.security.principal.windowsidentity]::getcurrent().name
$isElevated = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if ($isElevated) { Write-Output "Running as $whoiam and IS Elevated"; } else { Write-Warning "Running as $whoiam and is NOT Elevated"; }

### ---

function Get-InstalledVersion {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('DesktopAppInstaller', 'NuGet', 'QuickAssistApp', 'UIXaml', 'VCLibs140', 'WebView2', 'WinGet')]
        [string]$AppName
    )

    switch ($AppName) {
        'DesktopAppInstaller' {
            $AppxPkg = Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($AppxPkg.Version) {
                return [string]$AppxPkg.Version
            }
            else {
                # AppxPkg is not installed
                return [string]''
            }
        }
        'QuickAssistApp' {
            $AppxPkg = Get-AppxPackage -Name 'MicrosoftCorporationII.QuickAssist' -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($AppxPkg.Version) {
                return [string]$AppxPkg.Version
            }
            else {
                # AppxPkg is not installed
                return [string]''
            }
        }
        'UIXaml' {
            $AppxPkg = Get-AppxPackage -Name 'Microsoft.UI.Xaml.2.8' -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($AppxPkg.Version) {
                return [string]$AppxPkg.Version
            }
            else {
                # AppxPkg is not installed
                return [string]''
            }
        }
        'VCLibs140' {
            $AppxPkg = Get-AppxPackage -Name 'Microsoft.VCLibs.140.00.UWPDesktop' -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($AppxPkg.Version) {
                return [string]$AppxPkg.Version
            }
            else {
                # AppxPkg is not installed
                return [string]''
            }
        }
        'NuGet' {
            # NOTE: using -ForceBootstrap will automatically install the package provider if it's not present
            $NuGetProvider = Find-PackageProvider -Name 'NuGet' -ForceBootstrap -IncludeDependencies -WarningAction SilentlyContinue
            if ($NuGetProvider.Version) {
                return [string]$NuGetProvider.Version
            }
            else {
                # NuGet is not installed (this would be weird)
                return [string]''
            }
        }
        'WebView2' {
            # https://docs.microsoft.com/en-us/microsoft-edge/webview2/concepts/distribution#detect-if-a-suitable-webview2-runtime-is-already-installed
            if ([System.Environment]::Is64BitOperatingSystem) {
                $KeyPath = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}'
            }
            else {
                # UNTESTED!
                $KeyPath = 'HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}'
            }
            $WebViewRegKey = Get-ItemProperty -Path $KeyPath -ErrorAction SilentlyContinue
            if ($WebViewRegKey.pv) {
                return [string]$WebViewRegKey.pv
            }
            else {
                # WebView2 is not installed per-machine
                return [string]''
            }
        }
        'WinGet' {
            $WinGetEXE = Get-Command -Type Application -Name 'winget.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($WinGetEXE) {
                $WinGetVer = & winget.exe --version
                #[version]$WinGetVer = $WinGetVer -replace '[a-zA-Z\-]'
                return [string]$WinGetVer
            }
            else {
                # WinGet.exe is not installed
                return [string]''
            }
        }
    }
}

function Install-QuickAssistApp {
    if (-not(Confirm-WinGet)) {
        Write-Error "Cannot install Quick Assist App withouth WinGet"
        return $false
    }
    else {
        # Disable UAC prompt for Admins if it isn't already
        $PolicyKeys = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\' -ErrorAction SilentlyContinue
        if ($PolicyKeys.ConsentPromptBehaviorAdmin) {
            Write-Warning "Temporarily disabling UAC Prompt for Admins for installation"
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\' -Name ConsentPromptBehaviorAdmin -Value 0 -ErrorAction SilentlyContinue
        }

        Write-Host "Installing Quick Assist App from the store using WinGet"
        # Use winget to install the new Quick Assist app form the Store
        # NOTE: Quick Assist doesn't have a machine scope installation, so this doesn't work.
        #winget install "quick assist" --accept-source-agreements --accept-package-agreements --scope=machine
        # NOTE: Using --silent doesn't do anything useful for an appx/msix installer
        #winget install "quick assist" --accept-source-agreements --accept-package-agreements --silent
        #winget install "quick assist" --accept-source-agreements --accept-package-agreements
        & winget install "quick assist" --accept-source-agreements --accept-package-agreements
        #$EXEArgs = @(
        #    "--accept-source-agreements"
        #    "--accept-package-agreements"
        #)
        #Start-Process winget.exe -ArgumentList $EXEArgs -PassThru

        # Re-enable UAC Prompting, if it wasn't already
        if ($PolicyKeys.ConsentPromptBehaviorAdmin) {
            Write-Warning "Re-enabling UAC Prompt for Admins"
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\' -Name ConsentPromptBehaviorAdmin -Value $PolicyKeys.ConsentPromptBehaviorAdmin -ErrorAction SilentlyContinue
        }

        # check our work...
        if ($installedVersion = Get-InstalledVersion -AppName QuickAssistApp) {
            Write-Host "Quick Assist App $installedVersion has been installed"
            return $true
        }
        else {
            Write-Error "Quick Assist App could NOT be installed!"
            return $false
        }
    }
}

function Confirm-HostOS {
    # Quick Assist is only supported on Windows Client OS https://docs.microsoft.com/en-us/windows/release-health/supported-versions-windows-client
    if ('1' -eq $(Get-CimInstance -ClassName Win32_OperatingSystem).ProductType) {
        #Write-Host "This is a Client Operating System."
        return $true
        # Could also check for a minimum build according to what's supported...
        # Windows 11 21H1 GAC  = 10.0.22000.0
        # Windows 10 21H2 GAC  = 10.0.19044.0
        # Windows 10 21H1 SAC  = 10.0.19043.0
        # Windows 10 20H2 SAC  = 10.0.19042.0
        # Windows 10 21H2 LTSC = 10.0.19044.0
        # Windows 10 1809 LTSC = 10.0.17763.0 <-- not supported yet, will be
        # Windows 10 1607 LTSB = 10.0.14393.0 <-- not supported yet, will be
        # Windows 10 1507 LTSB = 10.0.10240.0 <-- not supported yet, will not be
        # if ([Version]'10.0.25120.0' -le [System.Environment]::OSVersion.Version) {
        #     # This is Sun Valley 2, Windows 11 Insider Preview build
        #     # https://blogs.windows.com/windows-insider/2022/03/09/announcing-windows-11-insider-preview-build-22572/
        # }
    }
    else {
        Write-Error "Quick Assist is only supported on Windows Client OS and cannot run here. https://docs.microsoft.com/en-us/windows/release-health/supported-versions-windows-client"
        return $false
    }
}

function Confirm-QuickAssistApp {
    if (-not (Confirm-HostOS)) { return $false; }

    $AppName = "Quick Assist App"
    $PkgName = 'MicrosoftCorporationII.QuickAssist'
    $MinVer = '2.0.6.0' # This is a bit arbitrary, but I've observed 2.0.5.0 pre-installed on SunValley2 fail to work until updated

    if ($installedVersion = Get-InstalledVersion -AppName QuickAssistApp) {
        if ([version]$installedVersion -ge [version]$MinVer) {
            Write-Host "$AppName $installedVersion is already installed and meets the minimum required $MinVer"
            return $true
        }
        else {
            Write-Warning "$AppName $installedVersion is already installed but must be updated"
        }
    }
    else {
        Write-Warning "$AppName is NOT installed for $whoiam"
    }

    if (-not $isElevated) {
        Write-Error "Cannot silently install $AppName without elevation - Try running again as Admin or update it using the Store app"
        return $false
    }

    # Is the App on this device, but maybe not added for this user?
    $Package = Get-AppxPackage -AllUsers -Name $PkgName -ErrorAction SilentlyContinue
    if ($Package.Version) {
        if ([version]$Package.Version -ge [version]$MinVer) {
            Write-Host "This device has $AppName $($Package.Version), adding it for $whoiam"
            $ManifestPath = (Get-AppxPackage -AllUsers -Name "$PkgName").InstallLocation + "\Appxmanifest.xml"
            Add-AppxPackage -Path $ManifestPath -Register -DisableDevelopmentMode
        }
        else {
            Write-Warning "This device has $AppName $($Package.Version) but must be upgraded to $MinVer or newer"
            if (-not (Install-QuickAssistApp)) {
                Write-Error "Failed to upgrade $AppName"
                return $false
            }
        }
    }
    else {
        Write-Warning "This device does NOT have $AppName and needs to be installed"
        if (-not (Install-QuickAssistApp)) {
            Write-Error "Failed to install $AppName"
            return $false
        }
    }

    # check our work...
    if ($installedVersion = Get-InstalledVersion -AppName QuickAssistApp) {
        if ([version]$installedVersion -ge [version]$MinVer) {
            Write-Host "$AppName $installedVersion has been installed for $whoiam"
            return $true
        }
        else {
            Write-Error "$AppName $installedVersion for $whoiam is still older than $MinVer"
            return $false
        }
    }
    else {
        Write-Error "$AppName could not be installed for $whoiam"
        return $false
    }
}

function Confirm-WinGet {
    $AppName = "WinGet.exe"
    $MinVer = '1.3.1251'

    if ($installedVersion = Get-InstalledVersion -AppName WinGet) {
        # WinGet is on the system, is it old?
        # have to remove letters and dashes to convert it to a comparable [version] type
        $installedVersion = $installedVersion -replace '[a-zA-Z\-]'
        if ([version]$installedVersion -ge [version]$MinVer) {
            Write-Host "$AppName $installedVersion is already installed"
            return $true
        }
        else {
            Write-Host "$AppName $installedVersion is already installed, but does not meet the minimum $MinVer"
            Write-Host "DesktopAppInstaller must be updated to update WinGet"
        }
    }
    else {
        Write-Warning "$AppName is not installed. DesktopInstaller must be updated."
    }

    if (Confirm-DesktopAppInstaller) {
        if ($installedVersion = Get-InstalledVersion -AppName WinGet) {
            Write-Host "$AppName $installedVersion has been installed"
            return $true
        }
        else {
            Write-Error "$AppName could NOT be installed!"
            return $false
        }
    }
    else {
        Write-Error "DesktopAppInstaller could NOT be updated to install WinGet!"
        return $false
    }

}

function Confirm-NuGet {
    $AppName = "NuGet"

    if ($installedVersion = Get-InstalledVersion -AppName NuGet) {
        Write-Host "$AppName $installedVersion is installed"
    }
    else {
        Write-Error "$AppName is NOT installed or Failed to install automatically!"
        return $false
    }

    # https://docs.microsoft.com/en-us/powershell/module/packagemanagement/register-packagesource
    $NuGetSrcURI = 'https://www.nuget.org/api/v2'
    $NuGetSource = Get-PackageSource -ProviderName NuGet

    if ($NuGetSource.Location -EQ $NuGetSrcURI) {
        Write-Host "$AppName Package Source is already set to $NuGetSrcURI"
        return $true
    }
    else {
        #Write-Warning "NuGet Package Source is not set as expected, attempting to set it"
        Register-PackageSource -Name NuGet -Location $NuGetSrcURI -ProviderName NuGet
        #check our work
        $NuGetSource = Get-PackageSource -ProviderName NuGet
        if ($NuGetSource.Location -EQ $NuGetSrcURI) {
            Write-Host "$AppName Package Source is now set to $NuGetSrcURI"
            return $true
        }
        else {
            Write-Error "Failed to set $AppName Package Source to $NuGetSrcURI"
            return $false
        }
    }
}

function Confirm-UIXaml {
    $AppName = "UI.Xaml 2.8"
    $PkgName = 'Microsoft.UI.Xaml' # The Appx Package Name on https://www.nuget.org/packages/Microsoft.UI.Xaml/
    $MinVer = '2.8.0' # WinGet/DesktopAppInstaller now requires 2.8.x and 2.7.0 causes a failure, assuming 2.9 will too
    $MaxVer = '2.8.999' # Keeps it under 2.9

    # the AppxPackage version for UI.Xaml 2.8 starts with '8.x' and looks something like 8.2310.30001.0
    if ($installedVersion = Get-InstalledVersion -AppName UIXaml) {
        Write-Host "$AppName $installedVersion is already installed"
        return $true
    } else {
        Write-Warning "$AppName is not installed, attempting to download/install with NuGet..."
    }

    if (-not $isElevated) {
        Write-Error "$AppName cannot be installed without admin elevation!"
        return $false
    }

    if (-not (Confirm-NuGet)) {
        Write-Error "$AppName cannot be installed without NuGet"
        return $false
    }

    # Check for / get the NuGet package
    $UIXamlPackage = Get-Package -Name $PkgName -MinimumVersion $MinVer -MaximumVersion $MaxVer -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($installedVersion = $UIXamlPackage.Version) {
        if ([version]$installedVersion -ge [version]$MinVer -and [version]$installedVersion -le [version]$MaxVer) {
            Write-Host "$AppName NuGet Package $installedVersion is already installed but needs to be registered for $whoiam"
        }
        else {
            Write-Host "$AppName NuGet Package $installedVersion is already installed but is not within versions $MinVer to $maxVer"
            $installedVersion = $null
        }
    }

    if (-not $installedVersion) {
        #Find-Package -Name $PkgName
        Write-Host "Installing $AppName NuGet Package ..."
        #Install-Package -Name $PkgName -RequiredVersion $MaxVer -Force | Out-Null
        Install-Package -Name $PkgName -MinimumVersion $MinVer -MaximumVersion $MaxVer -Force | Out-Null

        # check our work
        $UIXamlPackage = Get-Package -Name $PkgName -MinimumVersion $MinVer -MaximumVersion $MaxVer -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($UIXamlPackage.Version) {
            Write-Host "$AppName NuGet Package $($UIXamlPackage.Version) has been installed"
        }
        else {
            Write-Error "Failed to install $AppName NuGet Package!"
            return $false
        }
    }

    # Once the Package is installed, register the appx for the user
    $UIXamlPath = Split-Path $(Get-Package -Name $PkgName -MinimumVersion $MinVer -MaximumVersion $MaxVer).Source -Parent
    if ([System.Environment]::Is64BitOperatingSystem) {
        $UIXamlPath = "$UIXamlPath\tools\AppX\x64\Release\"
    }
    else {
        # UNTESTED!
        $UIXamlPath = "$UIXamlPath\tools\AppX\x86\Release\"
    }
    $UIXamlAppX = $(Get-ChildItem -Path "$UIXamlPath\*.appx").Name
    Add-AppxPackage -Path "$UIXamlPath\$UIXamlAppX"

    # check our work...
    if ($installedVersion = Get-InstalledVersion -AppName UIXaml) {
        Write-Host "$AppName has been registered using $installedVersion"
        return $true
    }
    else {
        Write-Error "$AppName was NOT registered!"
        return $false
    }
}

function Confirm-VCLibs140 {
    $AppName = "VCLibs"
    # NOTE: The DesktopAppInstaller package has changed its minimum required version which caused this to incorrectly
    # accept older versions of VCLibs and fail to install.  I may need to come up with a way of determining the
    # dependacies from that app manifest rather than statically defining the version here.
    $MinVer = '14.0.30704.0'

    if ($installedVersion = Get-InstalledVersion -AppName VCLibs140) {
        Write-Host "$AppName $installedVersion is already installed"
        if ([version]$installedVersion -ge [version]$MinVer) {
            Write-Host "$AppName $installedVersion meets the mnimum required $MinVer"
            return $true
        }
        else {
            Write-Warning "$AppName $installedVersion is already installed, but does not meet the minimum $MinVer"
        }
    }
    else {
        Write-Warning "$AppName is not installed, attempting to download and install..."
    }

    if (-not $isElevated) {
        Write-Error "$whoiam is NOT Elevated, cannot update or install $AppName..."
        return $false
    }

    # Download the VCLibs dependancy
    # https://docs.microsoft.com/en-us/troubleshoot/developer/visualstudio/cpp/libraries/c-runtime-packages-desktop-bridge
    if ([System.Environment]::Is64BitOperatingSystem) {
        $InstallerURI = 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx'
    }
    else {
        # UNTESTED!
        $InstallerURI = 'https://aka.ms/Microsoft.VCLibs.x86.14.00.Desktop.appx'
    }
    $InstallerAPPX = "$($env:TEMP)\VCLibs140.appx"

    try {
        Invoke-WebRequest -UseBasicParsing -Uri $InstallerURI -OutFile $InstallerAPPX
    }
    catch {
        Write-Error "Download failed : $_"
        return $false
    }
    Add-AppxPackage -Path $InstallerAPPX

    # check our work...
    if ($installedVersion = Get-InstalledVersion -AppName VCLibs140) {
        Write-Host "$AppName $installedVersion has been installed"
        return $true
    }
    else {
        Write-Error "$AppName is NOT installed!"
        return $false
    }
}

function Confirm-WebView2 {
    $AppName = "WebView2"
    $MinVer = '102.0.0.0' # This is arbitrary, but I've observed 90.0.818.66 pre-installed on Win11 fail to work until updated
    if ($installedVersion = Get-InstalledVersion -AppName WebView2) {
        if ([version]$installedVersion -ge [version]$MinVer) {
            Write-Host "$AppName $installedVersion is already installed"
            return $true
        }
        else {
            Write-Warning "$AppName $installedVersion is already installed, but does not meet the minimum $MinVer"
        }
    }

    if (-not $isElevated) {
        Write-Error "$AppName cannot be installed machine-wide without admin elevation!"
        return $false
    }

    Write-Warning "Attempting to download and install the latest $AppName"
    # Download the 'evergreen bootstrap' installer, automatically determines x86 or x64
    $InstallerURI = 'https://go.microsoft.com/fwlink/p/?LinkId=2124703'
    $InstallerEXE = "$($env:TEMP)\MicrosoftEdgeWebview2Setup.exe"

    try {
        Invoke-WebRequest -UseBasicParsing -Uri $InstallerURI -OutFile $InstallerEXE
    }
    catch {
        Write-Error "Download failed : $_"
        return $false
    }
    $SetupArgs = @(
        "/silent"
        "/install"
    )
    Start-Process $InstallerEXE -ArgumentList $SetupArgs -WindowStyle Hidden -PassThru
    # The bootstraper exits before the installation completes, so watch a regkey to determine when it's done
    # https://github.com/MicrosoftEdge/WebView2Feedback/issues/1349
    $retry = 20 # We'll try 20 times, waiting 5 seconds between loops.
    do {
        $installedVersion = Get-InstalledVersion -AppName WebView2
        if ('' -ne $installedVersion -and [version]$installedVersion -gt [version]$MinVer) {
            #Installation complete, exit the retry loop
            $retry = -1
        }
        else {
            Write-Host "Waiting for install to finish... ($retry/20)"
            Start-Sleep 5
            $retry = $retry - 1
        }
    } while ($retry -gt 0)

    if ($retry -eq 0) {
        Write-Error "$AppName failed to install"
        return $false
    }
    else {
        Write-Host "$AppName $installedVersion has been installed"
        return $true
    }
}

function Confirm-DesktopAppInstaller {
    $AppName = "DesktopAppInstaller"
    $MinVer = '1.18.1251.0'
    $installedVersion = Get-InstalledVersion -AppName DesktopAppInstaller

    # WinGet or the "Windows Package Manager" is part of to the DesktopInstaller
    # https://docs.microsoft.com/en-us/windows/package-manager/

    # The DesktopInstaller can be installed manually from the store, or use the release from GitHub
    # https://github.com/microsoft/winget-cli

    # Once installed we can use WinGet to install other store apps (like Quick Assist)
    # However, v1.3.1251-preview was the first to be able to install free store apps without an account
    # https://github.com/microsoft/winget-cli/releases/tag/v1.3.1251-preview

    # v1.4 should GA with this capability, but 1.3.1251-preview would be the minimum, for now
    # https://github.com/microsoft/winget-cli/releases

    # The DesktopInstaller package is versioned differntly from winget itself (of course)
    # DesktopInstaller v1.18.1251.0 was the first to include Winget 1.3.1251
    # so that's our minimum DesktopAppInstaller version - at least the build revisons match (1251).

    if ('' -ne $installedVersion -and ([version]$installedVersion -ge [version]$MinVer)) {
        Write-Host "$AppName $installedVersion already meets the mimum version $MinVer"
        return $true
    }
    elseif ('' -eq $installedVersion) {
        Write-Warning "$AppName is not installed"
    }
    else {
        Write-Warning "$AppName $installedVersion is older than $MinVer, attempting to update"
    }

    if (-not (Confirm-VCLibs140)) {
        Write-Error "Cannot update $AppName without first updating VCLibs"
        return $false
    }

    if (-not (Confirm-UIXaml)) {
        Write-Error "Cannot update $AppName without first updating UI.Xaml"
        return $false
    }

    Write-Host "Attempting to download and install the latest $AppName from GitHub"

    # Download latest winget-cli (DesktopAppInstaller) from github https://github.com/microsoft/winget-cli/releases/latest
    $GitRepo = "microsoft/winget-cli"
    $ReleasesJSON = "https://api.github.com/repos/$GitRepo/releases"
    #$ReleaseFile = 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
    $ReleaseMinVer = '1.3.1251'

    # See the full list of releases
    #Invoke-WebRequest $ReleasesJSON | ConvertFrom-Json | Format-Table -Property name,tag_name,prerelease,target_commitish

    try {
        $Releases = Invoke-WebRequest -UseBasicParsing -Uri $ReleasesJSON | ConvertFrom-Json
    }
    catch {
        Write-Error "Download failed : $_"
        return $false
    }

    $Release = $Releases | Where-Object { -not $_.prerelease } | Select-Object -First 1
    #Write-Host "Latest Release of DesktopAppInstaller from GitHub is $($Release.tag_name)"
    # remove any leading non-numeric characters, then any letters or hyphens
    $ReleaseVer = (($Release.tag_name) -replace '^[^0-9]*') -replace '[a-zA-Z\-]'

    if ([version]$ReleaseVer -lt [version]$ReleaseMinVer) {
        Write-Warning "Latest Release $ReleaseVer is older than $ReleaseMinVer - Checking Previews"

        $Release = $Releases | Where-Object { $_.prerelease } | Select-Object -First 1
        #Write-Host "Latest Preview of DesktopAppInstaller from GitHub is $($Release.tag_name)"
        # remove any leading non-numeric characters, then any letters or hyphens
        $ReleaseVer = (($Release.tag_name) -replace '^[^0-9]*') -replace '[a-zA-Z\-]'

        if ([version]$ReleaseVer -lt [version]$ReleaseMinVer) {
            Write-Error "Latest Preview $ReleaseVer is older than $ReleaseMinVer - Something went wrong..."
            return $false
        }
    }

    Write-Host "Downloading and Installing $AppName $($Release.tag_name)"

    try {
        $ThisJSON = Invoke-WebRequest -UseBasicParsing -Uri "https://api.github.com/repos/$GitRepo/releases/$($Release.id)" | ConvertFrom-Json
    } catch {
        Write-Error "Download failed : $_"
        return $false
    }

    $InstallerLicense = ''
    $InstallerFile = ''
    $InstallerSHA265 = ''
    foreach ($asset in $ThisJSON.assets) {
        switch -Wildcard ($asset.name) {
            '*_License1.xml' {
                #Write-Host "Downloading License: $($asset.browser_download_url)"
                $InstallerLicense = "$($env:TEMP)\$($asset.name)"
                try {
                    Invoke-WebRequest -UseBasicParsing -Uri $asset.browser_download_url -OutFile $InstallerLicense
                } catch {
                    Write-Error "Download failed : $_"
                    return $false
                }
            }

            'Microsoft.DesktopAppInstaller_*.msixbundle' {
                #Write-Host "Downloading App: $($asset.browser_download_url)"
                $InstallerFile = "$($env:TEMP)\$($asset.name)"
                try {
                    Invoke-WebRequest -UseBasicParsing -Uri $asset.browser_download_url -OutFile $InstallerFile
                } catch {
                    Write-Error "Download failed : $_"
                    return $false
                }
            }

            'Microsoft.DesktopAppInstaller_*.txt' {
                #Write-Host "Reading Hash File: $($asset.browser_download_url)"
                try {
                    [string]$InstallerSHA265 = Invoke-RestMethod -Uri $asset.browser_download_url
                } catch {
                    Write-Warning "Download failed : $_"
                }
            }

        }
    }

    if (-not (Test-Path -Path $InstallerLicense) -or -not (Test-Path -Path $InstallerFile) ) {
        Write-Error "Installtion files not found"
        return $false
    }

    if (-not $InstallerSHA265) {
        Write-Warning "Cannot validate installer (checksum unknown) but will continue anyway."
    } else {
        if ($InstallerSHA265.Length -ne 64) {
            Write-Warning "Cannot validate installer (checksum not SHA265) but will continue anyway."
        } else {
            $InstallerSHA265 = $InstallerSHA265.ToUpper()
            $InstalerFileHash = (Get-FileHash -Algorithm SHA256 -Path $InstallerFile).Hash
            $InstalerFileHash = $InstalerFileHash.ToUpper()
            if ($InstallerSHA265 -eq $InstalerFileHash) {
                Write-Host "Installer File Integrity was confirmed with SHA256 Hash"
            } else {
                Write-Error "Installer File Integrity FAILED! File hash ($InstalerFileHash) does not match published hash ($InstallerSHA265)"
                return $false
            }
        }
    }

    #Write-Host "Installing DesktopAppInstaller"
    Add-AppxProvisionedPackage -Online -PackagePath $InstallerFile -LicensePath $InstallerLicense
    Start-Sleep -Seconds 1
    Add-AppxPackage -Path $InstallerFile -ForceUpdateFromAnyVersion -ForceApplicationShutdown
    Start-Sleep -Seconds 1

    $installedVersion = Get-InstalledVersion -AppName DesktopAppInstaller
    if ('' -ne $installedVersion -and ([version]$installedVersion -ge [version]$MinVer)) {
        Write-Host "$AppName has been updated to $installedVersion"
        return $true
    }
    elseif ('' -eq $installedVersion) {
        Write-Error "$AppName was NOT installed!"
        return $false
    }
    else {
        Write-Error "$AppName $installedVersion is still too old!"
        return $false
    }
}

### ---


### Check for the 'new' Quick Assist, and if all good, run it!
if (Confirm-QuickAssistApp) {

    if (-not (Confirm-WebView2)) {
        Write-Warning "WebView2 is not installed machine-wide, Quick Assist may not work unless it is installed per user!"
    }

    # Disable UAC Secure Desktop
    $PolicyKeys = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\' -ErrorAction SilentlyContinue
    if (-not $PolicyKeys.PromptOnSecureDesktop) {
        Write-Host "UAC Secure Desktop is already disabled"
    }
    elseif ($PolicyKeys.PromptOnSecureDesktop -and -not($isElevated)) {
        Write-Warning "Cannot disable UAC Secure Desktop.  Helper will not be able to see the screen if elevation is required"
    }
    elseif ($PolicyKeys.PromptOnSecureDesktop -and $isElevated) {
        Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\' -Name PromptOnSecureDesktop -Value 0 -ErrorAction SilentlyContinue
        $PolicyKeys = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\' -ErrorAction SilentlyContinue
        if (-not $PolicyKeys.PromptOnSecureDesktop) {
            Write-Host "UAC Secure Desktop has been disabled"
        }
        else {
            Write-Warning "Failed to disable the UAC Secure Desktop.  Helper will not be able to see the screen if elevation is required"
        }
    }

    # NOTE: The app seems to run in the context of whoever owns the already running explorer.exe process
    # Even when running this script as a different (admin) user, the spawned process will be the other user.
    # I'm not sure how this would behave on a multi-user host like Win10 multi-session...
    # Let's check so we can at least warn because it looks odd...
    # The GetOwner method sometimes fail in OOBE, so we'll 'try' but not break on it.
    try {
        # Who is running explorer.exe? (it could be many users but we don't really deal with that either)
        $explorerOwner = Get-CimInstance -Class Win32_Process -Filter "Name='explorer.exe'" | Select-Object -First 1 | Invoke-CimMethod -MethodName GetOwner -ErrorAction Stop
        $explorerOwner = "$($explorerOwner.Domain)\$($explorerOwner.User)"

        if ($whoiam -eq $explorerOwner) {
            Write-Host "Starting Quick Assist App for $whoiam"
        }
        else {
            Write-Warning "explorer.exe is running as a different user ($explorerOwner)"
            if ($isElevated) {
                # Make sure this 'other' user has the app added as well...
                $Package = Get-AppxPackage -AllUsers -Name 'MicrosoftCorporationII.QuickAssist'
                $PakcageForThem = $false
                foreach ($PUI in $Package.PackageUserInformation) {
                    if ($PUI.UserSecurityId.Username -eq $explorerOwner -and $PUI.InstallState -eq 'Installed') {
                        #Write-Host "Package is Installed for the logged on user!"
                        $PakcageForThem = $true
                    }
                }
                if ($PakcageForThem) {
                    Write-Warning "$explorerOwner has Quick Assist App installed. Will run as that user..."
                    $explorerOwner
                }
                else {
                    Write-Warning "$explorerOwner) does NOT have Quick Assist App installed! Will run as that user, but expect it to fail..."
                }
            }
            Write-Host "Starting Quick Assist App for $explorerOwner"
        }
    } catch {
        Write-Warning "Unable to determine owner of explorer.exe process. Starting Quick Assist App"
    }

    $Package = Get-AppxPackage -Name 'MicrosoftCorporationII.QuickAssist'
    Start-Process 'explorer.exe' -ArgumentList "shell:AppsFolder\$($Package.PackageFamilyName)!App"
    #Start-Process 'explorer.exe' -ArgumentList "shell:AppsFolder\MicrosoftCorporationII.QuickAssist_8wekyb3d8bbwe!App"
}

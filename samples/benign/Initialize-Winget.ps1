#Requires -Version 5.1
#Requires -RunAsAdministrator

<#PSScriptInfo
.VERSION 1.8
.GUID df32c5bb-3f4a-46d3-9304-96addbf693f4
.AUTHOR Jonathan Pitre
.COMPANYNAME
.COPYRIGHT
.TAGS Winget,Intune,Autopilot,PowerShell,Automation
.LICENSEURI
.PROJECTURI
.ICONURI
.EXTERNALMODULEDEPENDENCIES Microsoft.WinGet.Client
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES winget-install
.RELEASENOTES

1.8 - 2025-09-09
- Updated error handling for Get-Command and Get-AppxPackage to use -ErrorAction SilentlyContinue, preventing script termination on command failures.

1.7 - 2025-07-24
- Fixed Error: "Cannot bind parameter because parameter 'TrustRepository' is specified more than once.

1.6 - 2025-07-21
- Fixed Error: Install-PSResource : Could not parse as a PowerShell script due to it missing PSScriptInfo block

1.5 - 2025-07-05
- Fixed Error: Cannot convert the "System.Object[]" value of type "System.Object[]" to type "System.Version".
- Fixed Error: Start-Process : The system cannot find the file specified.
- Replaced $($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe path with powershell.exe in Start-Process commands
- Added check to run the script in 64-bit mode if necessary

1.4 - 2025-07-05
- Changed default log file name from 'WinGet_Initialization.log' to 'Initialize-Winget.log' for clarity.
- Removed unnecessary parameters from Install-PSResource and Update-PSResource commands to streamline the installation process.
- Created [Pull Request #67](https://github.com/asheroto/winget-install/pull/67) to fix winget-install error with SYSTEM context and other issues
- Added version checking and update logic for the Microsoft.WinGet.Client module.
- Improved error handling for locating winget.exe and added fallback mechanisms.
- Optimized output encoding reset and transcript handling for better script execution flow.
- Enhanced module management efficiency by leveraging the Microsoft.PowerShell.PSResourceGet module's optimized cmdlets.
- Fixed an error with the transcript file not being created on a fresh reboot.


1.3 - 2025-06-02
- Fixed try/catch block
- Improved logging and error handling
- Improved winget.exe path detection

1.2 - 2025-05-30
- Removed dependency on PSAppDeployToolkit.WinGet
- Fixed error "Find-ADTWinGetPackage -Id Microsoft.AppInstaller -Count 1 -Source winget"
- Improved logging and error handling

1.1 - 2025-05-30
- Fixed "Failed to execute Winget command: Cannot validate argument on parameter 'Id'"
- Improved logging and error handling

1.0 - 2025-05-28
- Initial release
#>

<#
.SYNOPSIS
    A PowerShell script that initializes and verifies WinGet installation, with automatic repair capabilities.
    Specifically designed to resolve WinGet issues during Windows Autopilot deployment.

.DESCRIPTION
    This script ensures WinGet is properly installed and functional. It will:
    1. Verify WinGet can find packages using the 'Microsoft.WinGet.Client' module.
    2. Attempt to repair WinGet if package search fails.
    3. Install WinGet and its dependencies if repair fails.
    4. Locate and verify the winget.exe path.

    The script also ensures that necessary helper module 'Microsoft.WinGet.Client' is installed and imported.

.PARAMETER WinGetId
    The WinGet package ID to verify functionality (e.g., "Microsoft.AppInstaller"). This is used to test if WinGet is working properly by attempting to find this package.

.PARAMETER LogPath
    The path where log files will be stored. Defaults to the Intune Management Extension logs directory.

.PARAMETER LogFile
    The name of the log file. Defaults to 'Initialize-Winget.log'.

.EXAMPLE
    Initialize-WinGet -WinGetId "Microsoft.AppInstaller" -Verbose
    # Initializes WinGet and verifies it can find the Microsoft App Installer package.

.EXAMPLE
    Initialize-WinGet -LogPath "C:\Logs" -LogFile "WinGet-Init.log"
    # Initializes WinGet with custom log location and filename.

.INPUTS
    None. You cannot pipe objects to this script.

.OUTPUTS
    The found WinGet package information if successful.

.NOTES
    Author: Jonathan Pitre
    Version: 1.5
    Created: 2025-05-28
    Modified: 2025-07-05

    This function requires and will attempt to install/update the following PowerShell modules from the PowerShell Gallery:
    - 'Microsoft.WinGet.Client': Provides cmdlets to interact with the WinGet service, allowing for searching, installing, and managing packages.

    Administrative privileges are generally required for installing/updating these modules and for WinGet repair/installation operations.
    An active internet connection is needed to download modules from the PowerShell Gallery and for WinGet to function.

.LINK
    https://github.com/microsoft/winget-cli
    https://www.powershellgallery.com/packages/Microsoft.WinGet.Client

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$WinGetId = 'Microsoft.AppInstaller',
    [Parameter(Mandatory = $false)]
    [string]$LogPath = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs",
    [Parameter(Mandatory = $false)]
    [string]$LogFile = 'Initialize-Winget.log'
)

begin {
    $ProgressPreference = 'SilentlyContinue'
    $ErrorActionPreference = 'Stop'

    # Relaunch in 64-bit mode if necessary
    if ("$env:PROCESSOR_ARCHITEW6432" -ne 'ARM64') {
        if (Test-Path "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe") {
            & "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy bypass -NoProfile -File "$PSCommandPath"
            exit $lastexitcode
        }
    }

    # Create log directory if it doesn't exist
    if (-not (Test-Path -Path $LogPath)) {
        New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
    }

    # Start transcript
    Start-Transcript -Path (Join-Path -Path $LogPath -ChildPath $LogFile) -Force -Append

    Write-Host 'Starting WinGet initialization process...' -ForegroundColor Cyan

    # Install required module
    $module = 'Microsoft.WinGet.Client'

    try {
        # Try Install-PSResource first (modern approach)
        if (-not (Get-InstalledPSResource -Name $module -Scope AllUsers -ErrorAction SilentlyContinue)) {
            Write-Verbose "Installing $module using Install-PSResource..."
            Install-PSResource -Name $module -Scope AllUsers -Repository PSGallery -TrustRepository -Quiet -ErrorAction SilentlyContinue
            Write-Verbose "Successfully installed $module using Install-PSResource."
        } else {
            # Check if update is available before updating
            try {
                $installedModule = Get-InstalledPSResource -Name $module -Scope AllUsers -ErrorAction SilentlyContinue
                # Handle case where multiple versions might be returned
                if ($installedModule -is [array]) {
                    $currentVersion = ($installedModule | Sort-Object Version -Descending | Select-Object -First 1).Version
                } else {
                    $currentVersion = $installedModule.Version
                }

                $latestModule = Find-PSResource -Name $module -Repository PSGallery -ErrorAction SilentlyContinue
                # Handle case where multiple versions might be returned
                if ($latestModule -is [array]) {
                    $latestVersion = ($latestModule | Sort-Object Version -Descending | Select-Object -First 1).Version
                } else {
                    $latestVersion = $latestModule.Version
                }

                if ([version]$currentVersion -lt [version]$latestVersion) {
                    Write-Host "Updating $module from $currentVersion to $latestVersion..." -ForegroundColor Yellow
                    Update-PSResource -Name $module -Repository PSGallery -Scope AllUsers -TrustRepository -Quiet -ErrorAction SilentlyContinue
                    Write-Verbose "Successfully updated $module to version $latestVersion."
                } else {
                    Write-Verbose "$module is already up to date (version $currentVersion)."
                }
            } catch {
                Write-Warning "Unable to check for updates for $module. Using currently installed version. Error: $($_.Exception.Message)"
            }
        }
    } catch {
        # Fallback to Install-Module if Install-PSResource fails
        Write-Warning "Install-PSResource failed, falling back to Install-Module: $($_.Exception.Message)"
        try {
            if (-not (Get-Module -Name $module -ErrorAction SilentlyContinue)) {
                Write-Verbose "Installing $module using Install-Module..."
                Install-Module -Name $module -Repository PSGallery -Scope AllUsers -Force -ErrorAction SilentlyContinue
                Write-Verbose "Successfully installed $module using Install-Module."
            } else {
                # Check if update is available before updating
                try {
                    $installedModule = Get-Module -Name $module -ErrorAction SilentlyContinue
                    # Handle case where multiple versions might be returned
                    if ($installedModule -is [array]) {
                        $currentVersion = ($installedModule | Sort-Object Version -Descending | Select-Object -First 1).Version
                    } else {
                        $currentVersion = $installedModule.Version
                    }

                    $latestModule = Find-Module -Name $module -Repository PSGallery -ErrorAction SilentlyContinue
                    # Handle case where multiple versions might be returned
                    if ($latestModule -is [array]) {
                        $latestVersion = ($latestModule | Sort-Object Version -Descending | Select-Object -First 1).Version
                    } else {
                        $latestVersion = $latestModule.Version
                    }

                    if ($currentVersion -and $latestVersion -and [version]$currentVersion -lt [version]$latestVersion) {
                        Write-Host "Updating $module from $currentVersion to $latestVersion..." -ForegroundColor Yellow
                        Update-Module -Name $module -Force -ErrorAction SilentlyContinue
                        Write-Verbose "Successfully updated $module to version $latestVersion."
                    } else {
                        Write-Verbose "$module is already up to date (version $currentVersion)."
                    }
                } catch {
                    Write-Warning "Unable to check for updates for $module. Using currently installed version. Error: $($_.Exception.Message)"
                }
            }
        } catch {
            Write-Error "Failed to install $module using both Install-PSResource and Install-Module. Error: $($_.Exception.Message)"
            throw
        }
    }
}

process {
    function Get-WinGetPath {
        [CmdletBinding()]
        [OutputType([string])]
        param
        (
        )

        try {
            # For the system user, get the path from Program Files directly. For some systems, we can't rely on the
            # output of Get-AppxPackage as it'll update, but Get-AppxPackage won't reflect the new path fast enough.
            # Optimize winget path detection with better error handling and performance
            $winGet = $null

            # Check if running as SYSTEM account first (most restrictive)
            if ([System.Security.Principal.WindowsIdentity]::GetCurrent().IsSystem) {
                $programFilesPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::ProgramFiles)
                $wingetPath = Get-ChildItem -Path "$programFilesPath\WindowsApps\Microsoft.DesktopAppInstaller*\winget.exe" -ErrorAction SilentlyContinue |
                    Sort-Object LastWriteTime -Descending |
                    Select-Object -First 1 -ExpandProperty FullName
                if ($wingetPath) { $winGet = $wingetPath }
            }

            # If not found or not SYSTEM, try Get-Command (fastest for user accounts)
            if (-not $winGet) {
                try {
                    $wingetCommand = Get-Command -Name winget.exe -ErrorAction SilentlyContinue
                    $winGet = $wingetCommand.Source
                } catch {
                    # Fallback to AppxPackage lookup
                    try {
                        $appxPackage = Get-AppxPackage -Name Microsoft.DesktopAppInstaller -AllUsers -ErrorAction SilentlyContinue |
                            Sort-Object -Property { [version]$_.Version } -Descending |
                            Select-Object -First 1 -ExpandProperty InstallLocation

                        if ($appxPackage) {
                            $appxPath = Join-Path $appxPackage 'winget.exe'
                            if ([System.IO.File]::Exists($appxPath)) {
                                $winGet = $appxPath
                            }
                        }
                    } catch {
                        Write-Warning "Failed to locate winget.exe via AppxPackage: $($_.Exception.Message)"
                    }
                }
            }

            # If still not found, attempt to install/update Initialize-WinGet script
            if (-not $winGet) {
                Write-Warning 'Failed to find a valid path to winget.exe on this system.'
                # Try to repair WinGet first
                if (([System.Security.Principal.WindowsIdentity]::GetCurrent().IsSystem)) {
                    # Repair-WinGetPackageManager does not support -AllUsers parameter in SYSTEM context, see https://github.com/microsoft/winget-cli/issues/3935
                    Repair-WinGetPackageManager -Force -Latest
                } else {
                    Repair-WinGetPackageManager -AllUsers -Force -Latest
                }
            }

            # Return the found path to the caller.
            return $winGet
        } catch {
            Write-Warning "Error finding winget.exe path: $($_.Exception.Message)"
            return $null
        }
    }

    # Set the arguments for the winget command
    $wingetArgs = @(
        'search',
        '--id', $WinGetId,
        '--source', 'winget',
        '--count', '1',
        '--exact',
        '--accept-source-agreements',
        '--ignore-warnings'
    )

    # Set the encoding to UTF8
    $origEncoding = [System.Console]::OutputEncoding; [System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8

    try {

        # Verify if WinGet path can be found
        $winGet = Get-WinGetPath

        # Execute the winget command and remove any empty lines
        # Try to find WinGet package
        Write-Verbose "Attempting to find WinGet package: $WinGetId"
        $wingetOutput = & $winGet $wingetArgs 2>&1 | & { process { if ($_ -match '^(\w+|-+$)') { return $_.Trim() } } }
        if (-not $wingetOutput) { throw 'No output received from winget command' }

    } catch {
        Write-Warning "Failed to execute Winget command: $_"
        Write-Verbose 'Attempting to repair WinGet...'

        try {
            # Verify if WinGet path can be found
            $WinGet = Get-WinGetPath
            Write-Verbose 'Attempting to repair WinGet Package Manager.'
            # Try to repair WinGet first
            if (([System.Security.Principal.WindowsIdentity]::GetCurrent().IsSystem)) {
                # Repair-WinGetPackageManager does not support -AllUsers parameter in SYSTEM context, see https://github.com/microsoft/winget-cli/issues/3935
                Repair-WinGetPackageManager -Force -Latest
            } else {
                Repair-WinGetPackageManager -AllUsers -Force -Latest
            }

            # Verify if repair worked by trying to find package again
            Write-Verbose "Verifying WinGet package after repair: $WinGetId"
            $wingetOutput = & $winGet $wingetArgs 2>&1 | & { process { if ($_ -match '^(\w+|-+$)') { return $_.Trim() } } }
            if (-not $wingetOutput) { throw 'No output received from winget command' }
        } catch {
            Write-Warning "Failed to repair WinGet: $_"
            Write-Verbose 'Attempting to install WinGet and dependencies...'

            try {
                # Install WinGet and dependencies
                $WingetInstallScriptDirectory = Join-Path -Path $env:ProgramW6432 -ChildPath 'WindowsPowerShell\Scripts'
                Write-Verbose "Target directory for winget-install.ps1: $WingetInstallScriptDirectory"

                # Ensure the target directory exists. New-Item -Force creates parent directories if needed.
                if (-not (Test-Path -Path $WingetInstallScriptDirectory)) {
                    Write-Verbose "Ensuring WinGet installation script directory exists: $WingetInstallScriptDirectory"
                    New-Item -ItemType Directory -Path $WingetInstallScriptDirectory -Force -ErrorAction SilentlyContinue | Out-Null
                }

                # Save the script to the determined target directory.
                # Using Save-Script instead of Install-Script to precisely control the installation path to ensure it's in the 64-bit Program Files.
                $WingetInstallScript = Join-Path -Path $WingetInstallScriptDirectory -ChildPath 'winget-install.ps1'
                Write-Verbose "Saving winget-install script to $WingetInstallScript"
                try {
                    Save-PSResource -Name winget-install -Path $WingetInstallScriptDirectory -Repository PSGallery -TrustRepository -Quiet -AcceptLicense -ErrorAction SilentlyContinue
                } catch {
                    Write-Warning "Failed to save winget-install script: $_"
                    Write-Verbose 'Attempting to install winget-install script with Save-Script...'
                    Save-Script -Name winget-install -Path $WingetInstallScriptDirectory -Repository PSGallery -TrustRepository -Force -ErrorAction Stop
                    Write-Verbose 'Successfully saved winget-install script with Save-Script.'
                }

                # Run the installation script with system context
                Write-Verbose "Executing WinGet installation script: $WingetInstallScript"
                Start-Process -FilePath 'powershell.exe' -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$WingetInstallScript`" -Force -ForceClose" -Wait -NoNewWindow

                # Verify if installation worked
                $WinGet = Get-WinGetPath
                Write-Verbose "Verifying WinGet package after installation: $WinGetId"

                # Try to find WinGet package
                $wingetOutput = & $winGet $wingetArgs 2>&1 | & { process { if ($_ -match '^(\w+|-+$)') { return $_.Trim() } } }
                if (-not $wingetOutput) { throw 'No output received from winget command' }
            } catch {
                Write-Warning "Failed to install WinGet: $_"
                Write-Verbose 'Attempting to install WinGet and dependencies with alternate method...'

                try {
                    Write-Verbose "Executing WinGet installation script (alternate method): $WingetInstallScript"
                    # Install WinGet and dependencies with alternate method
                    Start-Process -FilePath 'powershell.exe' -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$WingetInstallScript`" -Force -ForceClose -AlternateInstallMethod" -Wait -NoNewWindow

                    # Verify if installation worked
                    $WinGet = Get-WinGetPath
                    Write-Verbose "Verifying WinGet package after alternate installation: $WinGetId"
                    # Try to find WinGet package
                    $wingetOutput = & $winGet $wingetArgs 2>&1 | & { process { if ($_ -match '^(\w+|-+$)') { return $_.Trim() } } }
                    if (-not $wingetOutput) { throw 'No output received from winget command' }
                } catch {
                    throw "Failed to install WinGet: $_"
                }
            }
        }

    }
}

end {
    # Reset the encoding
    [System.Console]::OutputEncoding = $origEncoding

    $WinGetVersion = (& $WinGet --version).Trim('v')
    Write-Verbose "WinGet version: $WinGetVersion" -Verbose
    Write-Host "Winget.exe is installed at: $WinGet" -ForegroundColor Green
    Write-Host "Found WinGet package: $WinGetId" -ForegroundColor Green

    # Stop transcript
    Stop-Transcript
}

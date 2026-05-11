<#PSScriptInfo

.VERSION 0.0.2

.GUID 98cb59b3-0489-4609-9c31-4f85be9433ea

.AUTHOR asheroto

.COMPANYNAME asheroto

.TAGS PowerShell Windows Terminal install installer script

.PROJECTURI https://github.com/asheroto/Install-WindowsTerminal

.RELEASENOTES
[Version 0.0.1] - Initial Release.
[Version 0.0.2] - Adjust UpdateSelf function to reset PSGallery to original state if it was not trusted.

#>

<#
.SYNOPSIS
	Installs winget and Windows Terminal.
.DESCRIPTION
	Installs winget and Windows Terminal.
.EXAMPLE
	Install-WindowsTerminal
.PARAMETER Force
    Ensures installation of winget and its dependencies, even if already present.
.PARAMETER UpdateSelf
    Updates the script to the latest version on PSGallery.
.PARAMETER CheckForUpdate
    Checks if there is an update available for the script.
.PARAMETER Version
    Displays the version of the script.
.PARAMETER Help
    Displays the full help information for the script.
.NOTES
	Version      : 0.0.2
	Created by   : asheroto
.LINK
	Project Site: https://github.com/asheroto/Install-WindowsTerminal
#>
[CmdletBinding()]
param (
    [switch]$Version,
    [switch]$Help,
    [switch]$CheckForUpdate,
    [switch]$UpdateSelf,
    [switch]$Force
)

# Version
$CurrentVersion = '0.0.2'
$RepoOwner = 'asheroto'
$RepoName = 'Install-WindowsTerminal'
$PowerShellGalleryName = 'Install-WindowsTerminal'

# Preferences
$ProgressPreference = 'SilentlyContinue' # Suppress progress bar (makes downloading super fast)
$ConfirmPreference = 'None' # Suppress confirmation prompts

# Display version if -Version is specified
if ($Version.IsPresent) {
    $CurrentVersion
    exit 0
}

# Display full help if -Help is specified
if ($Help) {
    Get-Help -Name $MyInvocation.MyCommand.Source -Full
    exit 0
}

# Display $PSVersionTable and Get-Host if -Verbose is specified
if ($PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose']) {
    $PSVersionTable
    Get-Host
}

# Set debug preferences if -Debug is specified
if ($PSBoundParameters.ContainsKey('Debug') -and $PSBoundParameters['Debug']) {
    $DebugPreference = 'Continue'
    $ConfirmPreference = 'None'
}

function CheckForUpdate {
    param (
        [string]$RepoOwner,
        [string]$RepoName,
        [version]$CurrentVersion,
        [string]$PowerShellGalleryName
    )

    $Data = Get-GitHubRelease -Owner $RepoOwner -Repo $RepoName

    Write-Output ""
    Write-Output ("Repository:       {0,-40}" -f "https://github.com/$RepoOwner/$RepoName")
    Write-Output ("Current Version:  {0,-40}" -f $CurrentVersion)
    Write-Output ("Latest Version:   {0,-40}" -f $Data.LatestVersion)
    Write-Output ("Published at:     {0,-40}" -f $Data.PublishedDateTime)

    if ($Data.LatestVersion -gt $CurrentVersion) {
        Write-Output ("Status:           {0,-40}" -f "A new version is available.")
        Write-Output "`nOptions to update:"
        Write-Output "- Download latest release: https://github.com/$RepoOwner/$RepoName/releases"
        if ($PowerShellGalleryName) {
            Write-Output "- Run: $RepoName -UpdateSelf"
            Write-Output "- Run: Install-Script $PowerShellGalleryName -Force"
        }
    } else {
        Write-Output ("Status:           {0,-40}" -f "Up to date.")
    }
    exit 0
}

function Write-Section($text) {
    <#
        .SYNOPSIS
        Prints a text block surrounded by a section divider for enhanced output readability.

        .DESCRIPTION
        This function takes a string input and prints it to the console, surrounded by a section divider made of hash characters.
        It is designed to enhance the readability of console output.

        .PARAMETER text
        The text to be printed within the section divider.

        .EXAMPLE
        Write-Section "Downloading Files..."
        This command prints the text "Downloading Files..." surrounded by a section divider.
    #>
    Write-Output ""
    Write-Output ("#" * ($text.Length + 4))
    Write-Output "# $text #"
    Write-Output ("#" * ($text.Length + 4))
    Write-Output ""
}

function Strip-ProgressIndent {
    param(
        [ScriptBlock]$ScriptBlock,
        [int]$Indentation = 4
    )

    # Function identical to Strip-Progress function by asheroto, but with an additional parameter to specify the indentation level
    # https://gist.github.com/asheroto/96bcabe428e8ad134ef204573810041f

    # Regex pattern to match spinner characters and progress bar patterns, now accounting for one or more spaces
    $progressPattern = 'Γû[Æê]\s*|^\s*[-\\|/]\s*$'

    # Adjusted regex pattern for size formatting to ensure it can handle variable spacing around the "/"
    $sizePattern = '(\d+(\.\d{1,2})?)\s+(B|KB|MB|GB|TB|PB)\s*/\s*(\d+(\.\d{1,2})?)\s+(B|KB|MB|GB|TB|PB)'

    $previousLineWasEmpty = $false # Track if the previous line was empty

    & $ScriptBlock 2>&1 | ForEach-Object {
        if ($_ -is [System.Management.Automation.ErrorRecord]) {
            "ERROR: $($_.Exception.Message)"
        } elseif ($_ -match '^\s*$') {
            if (-not $previousLineWasEmpty) {
                Write-Output ""
                $previousLineWasEmpty = $true
            }
        } else {
            $line = $_ -replace $progressPattern, '' -replace $sizePattern, '$1 $3 / $4 $6'
            if (-not [string]::IsNullOrWhiteSpace($line)) {
                $previousLineWasEmpty = $false
                (' ' * $Indentation) + $line
            }
        }
    }
}

function Get-CascadiaMonoUrl {
    <#
        .SYNOPSIS
        Retrieves the download URL for the latest release of the Cascadia Mono font.

        .DESCRIPTION
        This function uses the GitHub API to get information about the latest release of the Cascadia Mono font, including its version and the date it was published. It then returns the download URL for the latest release.

        .PARAMETER Match
        The pattern to match in the asset names.

        .EXAMPLE
        Get-CascadiaMonoUrl
    #>

    $uri = "https://api.github.com/repos/microsoft/cascadia-code/releases"
    $releases = Invoke-RestMethod -uri $uri -Method Get -ErrorAction stop

    foreach ($release in $releases) {
        if ($release.name -match "preview") {
            continue
        }
        $data = $release.assets | Where-Object name -Like "CascadiaCode*.zip"
        if ($data) {
            return $data.browser_download_url
        }
    }

    Write-Debug "Falling back to the latest release..."
    $latestRelease = $releases | Select-Object -First 1
    $data = $latestRelease.assets | Where-Object name -Match ".zip"
    return
}

function Get-GitHubRelease {
    <#
        .SYNOPSIS
        Fetches the latest release information of a GitHub repository.

        .DESCRIPTION
        This function uses the GitHub API to get information about the latest release of a specified repository, including its version and the date it was published.

        .PARAMETER Owner
        The GitHub username of the repository owner.

        .PARAMETER Repo
        The name of the repository.

        .EXAMPLE
        Get-GitHubRelease -Owner "asheroto" -Repo "winget-install"
        This command retrieves the latest release version and published datetime of the winget-install repository owned by asheroto.
    #>
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

        # Convert UTC time string to local time
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

    Write-Output ""
    Write-Output ("Repository:       {0,-40}" -f "https://github.com/$RepoOwner/$RepoName")
    Write-Output ("Current Version:  {0,-40}" -f $CurrentVersion)
    Write-Output ("Latest Version:   {0,-40}" -f $Data.LatestVersion)
    Write-Output ("Published at:     {0,-40}" -f $Data.PublishedDateTime)

    if ($Data.LatestVersion -gt $CurrentVersion) {
        Write-Output ("Status:           {0,-40}" -f "A new version is available.")
        Write-Output "`nOptions to update:"
        Write-Output "- Download latest release: https://github.com/$RepoOwner/$RepoName/releases"
        if ($PowerShellGalleryName) {
            Write-Output "- Run: $RepoName -UpdateSelf"
            Write-Output "- Run: Install-Script $PowerShellGalleryName -Force"
        }
    } else {
        Write-Output ("Status:           {0,-40}" -f "Up to date.")
    }
    exit 0
}

function UpdateSelf {
    try {
        # Get PSGallery version of script
        $psGalleryScriptVersion = (Find-Script -Name $PowerShellGalleryName).Version

        # If the current version is less than the PSGallery version, update the script
        if ($CurrentVersion -lt $psGalleryScriptVersion) {
            Write-Output "Updating script to version $psGalleryScriptVersion..."

            # Install NuGet PackageProvider if not already installed
            Install-PackageProvider -Name "NuGet" -Force

            # Trust the PSGallery if not already trusted
            $psRepoInstallationPolicy = (Get-PSRepository -Name 'PSGallery').InstallationPolicy
            if ($psRepoInstallationPolicy -ne 'Trusted') {
                Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted | Out-Null
            }

            # Update the script
            Install-Script $PowerShellGalleryName -Force

            # If PSGallery was not trusted, reset it to its original state
            if ($psRepoInstallationPolicy -ne 'Trusted') {
                Set-PSRepository -Name 'PSGallery' -InstallationPolicy $psRepoInstallationPolicy | Out-Null
            }

            Write-Output "Script updated to version $psGalleryScriptVersion."
            exit 0
        } else {
            Write-Output "Script is already up to date."
            exit 0
        }
    } catch {
        Write-Output "An error occurred: $_"
        exit 1
    }
}

function Write-Section($text) {
    <#
        .SYNOPSIS
        Prints a text block surrounded by a section divider for enhanced output readability.

        .DESCRIPTION
        This function takes a string input and prints it to the console, surrounded by a section divider made of hash characters.
        It is designed to enhance the readability of console output.

        .PARAMETER text
        The text to be printed within the section divider.

        .EXAMPLE
        Write-Section "Downloading Files..."
        This command prints the text "Downloading Files..." surrounded by a section divider.
    #>
    Write-Output ""
    Write-Output ("#" * 80)
    Write-Output "# $text #"
    Write-Output ("#" * 80)
    Write-Output ""
}

function Get-WingetStatus {
    <#
        .SYNOPSIS
        Checks if winget is installed.

        .DESCRIPTION
        This function checks if winget is installed.

        .EXAMPLE
        Get-WingetStatus
    #>

    # Check if winget is installed
    $winget = Get-Command -Name winget -ErrorAction SilentlyContinue

    # If winget is installed, return $true
    if ($null -ne $winget) {
        return $true
    }

    # If winget is not installed, return $false
    return $false
}

function Get-WindowsTerminalStatus {
    <#
        .SYNOPSIS
        Checks if Windows Terminal is installed.

        .DESCRIPTION
        This function checks if Windows Terminal is installed.

        .EXAMPLE
        Get-WindowsTerminalStatus
    #>

    # Check if Windows Terminal is installed
    $windowsTerminal = Get-Command -Name wt -ErrorAction SilentlyContinue

    # If Windows Terminal is installed, return $true
    if ($null -ne $windowsTerminal) {
        return $true
    }

    # If Windows Terminal is not installed, return $false
    return $false
}

function Get-CascadiaMonoStatus {
    $systemFontDir = [System.IO.Path]::Combine($ENV:SystemRoot, "Fonts")
    $userFontDir = [System.IO.Path]::Combine($ENV:USERPROFILE, "AppData", "Local", "Microsoft", "Windows", "Fonts")
    $fontFileName = "CascadiaMono.ttf"

    $systemFontPath = [System.IO.Path]::Combine($systemFontDir, $fontFileName)
    $userFontPath = [System.IO.Path]::Combine($userFontDir, $fontFileName)

    return (Test-Path -Path $systemFontPath) -or (Test-Path -Path $userFontPath)
}

function Test-AdminPrivileges {
    <#
    .SYNOPSIS
        Checks if the script is running with Administrator privileges. Returns $true if running with Administrator privileges, $false otherwise.

    .DESCRIPTION
        This function checks if the current PowerShell session is running with Administrator privileges by examining the role of the current user. It returns $true if the current user is an Administrator, $false otherwise.

    .EXAMPLE
        Test-AdminPrivileges

    .NOTES
        This function is particularly useful for scripts that require elevated permissions to run correctly.
    #>
    if (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        return $true
    }
    return $false
}

function New-TemporaryDirectory {
    <#
    .SYNOPSIS
    Creates a new temporary directory.

    .DESCRIPTION
    This function generates a new directory with a unique name in the system's temporary path.
    #>

    # Get the system's temporary path
    $parent = [System.IO.Path]::GetTempPath()

    # Confirm the parent directory exists
    if (-not (Test-Path -Path $parent)) {
        Write-Error "Parent directory does not exist: $parent"
        return
    }

    # Create a new directory with a unique name
    $name = [System.Guid]::NewGuid().ToString()
    $newTempDir = New-Item -ItemType Directory -Path ([System.IO.Path]::Combine($parent, $name))

    # Return the path to the new directory
    return $newTempDir.FullName
}

Function Install-Font {
    <#
    .SYNOPSIS
    Installs fonts from a specified path on Windows systems.

    .DESCRIPTION
    The Install-Font function supports handling individual font files, directories containing multiple fonts, and wildcard paths. It also supports recursive search for font files in the specified path and all its subdirectories. The function is capable of installing both TTF and OTF font types.

    .PARAMETER Path
    Specifies the path to the font file(s). This can be a path to an individual font file, a directory containing font files, or a wildcard path. The function accepts both relative and absolute paths.

    .PARAMETER Recursive
    When specified, the function will recursively search for font files in the specified path and all its subdirectories. This is useful for bulk installations from directories with nested subfolders.

    .EXAMPLE
    Install-Font -Path ".\MyFont.ttf"
    This example installs a single font file named 'MyFont.ttf' located in the current directory.

    .EXAMPLE
    Install-Font -Path ".\MyFont.otf"
    This example installs a single font file named 'MyFont.otf' located in the current directory.

    .EXAMPLE
    Install-Font -Path "C:\Users\User\Downloads\*.ttf"
    This example installs all TTF fonts located in the 'Downloads' folder of the 'User' directory.

    .EXAMPLE
    Install-Font -Path "*.ttf" -Recursive
    This example installs all TTF fonts found in the current directory and its subdirectories.
    #>
    param (
        [string]$Path,
        [switch]$Recursive
    )
    # Get the path to the Fonts folder
    $SystemFontsPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Fonts)

    # Find all font files based on the given path
    $fontFiles = Get-ChildItem -Path $Path -Recurse:$Recursive -File | Where-Object { $_.Extension -eq '.ttf' -or $_.Extension -eq '.otf' }

    foreach ($file in $fontFiles) {
        Write-Output "Installing $($file.Name)"

        # Construct the path to the font file in the Fonts folder
        $FontDestination = Join-Path -Path $SystemFontsPath -ChildPath $file.Name

        # Get font name from font file
        $ShellFolder = (New-Object -COMObject Shell.Application).Namespace($file.DirectoryName)
        $ShellFile = $ShellFolder.ParseName($file.Name)
        $FontType = $ShellFolder.GetDetailsOf($ShellFile, 2)
        $FontName = $ShellFolder.GetDetailsOf($ShellFile, 21)

        # Check if the file is a font file
        If (-not ($FontType -Like '*font*')) {
            Write-Output "  $($file.Name) is not a recognized font file"
            Continue
        }

        # If the font file doesn't exist in the Fonts folder
        if (-not (Test-Path -Path $FontDestination)) {
            # Copy the font file to the Fonts folder
            Copy-Item -Path $file.FullName -Destination $FontDestination

            # Register the font in the registry for persistence
            $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
            if ($null -ne $FontName) {
                $null = Set-ItemProperty -Path $registryPath -Name "$FontName (TrueType)" -Value $file.Name
            }
            Write-Output "  Installed `"$FontName``"
        } else {
            Write-Output "  `"$FontName`" is already installed"
        }
    }
}

# ============================================================================ #
# Initial checks
# ============================================================================ #

# First heading
Write-Output "Install-WindowsTerminal $CurrentVersion"

# Check for updates if -CheckForUpdate is specified
if ($CheckForUpdate) { CheckForUpdate -RepoOwner $RepoOwner -RepoName $RepoName -CurrentVersion $CurrentVersion -PowerShellGalleryName $PowerShellGalleryName }

# Update the script if -UpdateSelf is specified
if ($UpdateSelf) { UpdateSelf }

# Heading
Write-Output "To check for updates, run Install-WindowsTerminal -CheckForUpdate"

# ============================================================================ #
# Confirm running as administrator
# ============================================================================ #

if (!(Test-AdminPrivileges)) {
    Write-Output "Please run this script as an administrator."
    exit 1
}

# ============================================================================ #
# Install winget
# ============================================================================ #

# Heading
Write-Section "Prerequisites"

# Install winget if not already installed
if ((-not (Get-WingetStatus)) -or $Force) {
    Write-Output "Installing winget..."

    # Indent the process
    Strip-ProgressIndent -ScriptBlock {
        # Install NuGet PackageProvider
        Install-PackageProvider -Name NuGet -Force -Confirm:$false | Out-Null

        # Trust the PSGallery if not already trusted
        $psRepoInstallationPolicy = (Get-PSRepository -Name 'PSGallery').InstallationPolicy
        if ($psRepoInstallationPolicy -ne 'Trusted') {
            Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted | Out-Null
        }

        # Install winget
        Install-Script -Name winget-install -Force
        winget-install -Force

        # If PSGallery was not trusted, reset it to its original state
        if ($psRepoInstallationPolicy -ne 'Trusted') {
            Set-PSRepository -Name 'PSGallery' -InstallationPolicy $psRepoInstallationPolicy | Out-Null
        }
    }

    # Confirm winget is installed
    if (Get-WingetStatus) {
        Write-Output "winget is installed."
    } else {
        Write-Warning "There was an issue installing winget which Windows Terminal depends on. Please try again."
        exit 1
    }
} else {
    Write-Output "winget is already installed."
}

# ============================================================================ #
# Install Windows Terminal
# ============================================================================ #

# Heading
Write-Section "Windows Terminal"

# Install Windows Terminal if not already installed
if ((-not (Get-WindowsTerminalStatus)) -or $Force) {
    # Install Windows Terminal
    Write-Output "Installing Windows Terminal..."

    # Indent the process
    Strip-ProgressIndent -ScriptBlock {
        winget install Microsoft.WindowsTerminal --accept-package-agreements --accept-source-agreements --force --silent --disable-interactivity
    }

    # Confirm Windows Terminal is installed
    if (Get-WindowsTerminalStatus) {
        Write-Output "Windows Terminal is installed."
    } else {
        # Install Windows Terminal using winget from the Microsoft Store
        Write-Warning "Windows Terminal was not installed. Trying another method..."

        # Indent the process
        Strip-ProgressIndent -ScriptBlock {
            winget install "windows terminal" --source "msstore" --accept-package-agreements --accept-source-agreements --force --silent --disable-interactivity
        }

        if (Get-WindowsTerminalStatus) {
            Write-Output "Windows Terminal is installed."
        } else {
            Write-Warning "There was an issue installing Windows Terminal. Please refer to any error messages above for more information."
            exit 1
        }
    }
} else {
    Write-Output "Windows Terminal is already installed."
}

# ============================================================================ #
# Install Cascadia Mono font
# ============================================================================ #

# Heading
Write-Section "Cascadia Mono font"

# Confirm that the Cascadia Mono font is not already installed system or user
if ((-not (Get-CascadiaMonoStatus)) -or $Force) {
    Write-Output "Installing Cascadia Mono (includes Cascadia Code)..."

    # Indent the process
    Strip-ProgressIndent -ScriptBlock {

        # Define vars
        $ProgressPreference = 'SilentlyContinue'
        $url = Get-CascadiaMonoUrl

        # Create a new folder for the download
        $downloadFolder = New-TemporaryDirectory

        # Download the zip file
        $zipFile = [System.IO.Path]::Combine($downloadFolder, "CascadiaCode.zip")
        Invoke-WebRequest -Uri $url -OutFile $zipFile

        # Extract the zip file
        Expand-Archive -Path $zipFile -DestinationPath $downloadFolder

        # Set ttf path
        $ttfPath = [System.IO.Path]::Combine($downloadFolder, "ttf")

        # Install the font (not recursive to avoid installing static fonts)
        Install-Font -Path $ttfPath

        # Clean up
        Remove-Item -Path $downloadFolder -Recurse -Force
    }

    # Confirm the font is installed
    if (Get-CascadiaMonoStatus) {
        Write-Output "Cascadia Mono font installed successfully."
    } else {
        Write-Warning "There was an issue installing the Cascadia Mono font. Please refer to any error messages above for more information."
        exit 1
    }
} else {
    Write-Output "Cascadia Mono font is already installed."
}

# ============================================================================ #
# Complete
# ============================================================================ #

# Heading
Write-Section "Complete"
Write-Output "Windows Terminal is now installed and ready to use."
# SIG # Begin signature block
# MIIpMgYJKoZIhvcNAQcCoIIpIzCCKR8CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAm+hitYGM+iyYk
# 2ZyetC06qEo1f2ZNEirfBAA5NFHxI6CCDh8wggawMIIEmKADAgECAhAIrUCyYNKc
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
# yK+p/pQd52MbOoZWeE4wggdnMIIFT6ADAgECAhAN0Uk2zX4f3m8X7HdlwxBNMA0G
# CSqGSIb3DQEBCwUAMGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwg
# SW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBDb2RlIFNpZ25pbmcg
# UlNBNDA5NiBTSEEzODQgMjAyMSBDQTEwHhcNMjMwMzE3MDAwMDAwWhcNMjQwMzE2
# MjM1OTU5WjBvMQswCQYDVQQGEwJVUzERMA8GA1UECBMIT2tsYWhvbWExETAPBgNV
# BAcTCE11c2tvZ2VlMRwwGgYDVQQKExNBc2hlciBTb2x1dGlvbnMgSW5jMRwwGgYD
# VQQDExNBc2hlciBTb2x1dGlvbnMgSW5jMIICIjANBgkqhkiG9w0BAQEFAAOCAg8A
# MIICCgKCAgEA081RwO7808Fuab0RP0L2gthlZB8fiiGUBpnqJhsD1Bzpk+45B2LA
# qmrUp+nZIXNwr5me/55enGI9CkhaxmZoFhBxoM1u5lODNp8GaAYzIEi0IJldzZ9y
# PAQMfhTkHRiOwKBqTGO3h/gSZtaZ+8F+ltCmlXvv2vpqFpt5JL+uJm9SRIN5WLiP
# QM/isjYR+eIcaZxQeHLfbnemNcaT4cXOMChUsmG6WsoHZO1o76dCN+owz23koLy2
# Y1R3N2PMQj3kj8Bnlph6ffNnitKhXuwj3NkWwPSSQvYhcBuTcCOxpXpUjWlQNuTt
# llTHp9leKMq11raPkSaLe2qVX4eBc6HPtBT+7XagpaA409d7fmYTOLKmE0BCEdgb
# YZzYmKSyjrAgWlU9SYxurhFgHuQFD0CsBW1aXl6IEjn26cVx+hmj2KCOFELAdh1r
# 9UTNt37a/o/TYCp/mQ22/oa/224is1dpNj7RAHnNaix5n8RKKHufEh85lVjS/cBn
# 7z3cCKejyfBaUGK10SUwZKJiJ51DKkRkdh4A5cL85wKkQcFnRpfT/T+KTOEYRFT/
# vz3uK9bMLwuBj+gkP3WnlVXf67IY3FfZaQUDNdtwur4UTGrDQOn8Xl2rEy7L9VlJ
# UOCjX93WfW0B1Q4IxSdF6vIJw1m44HpIU4jxnqTBEo6BVVRCtdmp/x0CAwEAAaOC
# AgMwggH/MB8GA1UdIwQYMBaAFGg34Ou2O/hfEYb7/mF7CIhl9E5CMB0GA1UdDgQW
# BBTH3/U7rGshoJKjtOAVqNAEWJ/PBDAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAww
# CgYIKwYBBQUHAwMwgbUGA1UdHwSBrTCBqjBToFGgT4ZNaHR0cDovL2NybDMuZGln
# aWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0Q29kZVNpZ25pbmdSU0E0MDk2U0hB
# Mzg0MjAyMUNBMS5jcmwwU6BRoE+GTWh0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9E
# aWdpQ2VydFRydXN0ZWRHNENvZGVTaWduaW5nUlNBNDA5NlNIQTM4NDIwMjFDQTEu
# Y3JsMD4GA1UdIAQ3MDUwMwYGZ4EMAQQBMCkwJwYIKwYBBQUHAgEWG2h0dHA6Ly93
# d3cuZGlnaWNlcnQuY29tL0NQUzCBlAYIKwYBBQUHAQEEgYcwgYQwJAYIKwYBBQUH
# MAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBcBggrBgEFBQcwAoZQaHR0cDov
# L2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0Q29kZVNpZ25p
# bmdSU0E0MDk2U0hBMzg0MjAyMUNBMS5jcnQwCQYDVR0TBAIwADANBgkqhkiG9w0B
# AQsFAAOCAgEAQtDUmTp7UG2w4A4WaT6BoMLBLqzm09S64nFfuIUFjWk3KTCStpwR
# 3KzwG78CpYb7I0G6T7O2Emv+u0WgKVaWPbLFlnrjXXB+68DxR+CFWh6UDioz/9wo
# +eD/V2eKilAc2WSEIC8NzXT3C4yEtxUmnebK7Ysxy4qLlb4Sxk9NspS+Lg3jKBxb
# ExduQWHi1ytqw9NCghzK1Y2h5/AHwSYfwz7AyRerN3gTwzmmgTaWYEHVCL0NQddO
# 1lkSz6LPq2/JWHns7I0tNPCT5nZYva1v34EZvP9+P+SUDBH8bfrm6HlTd+Z6qNW5
# ACsALaCCAsZRQ6i7UZfjolD/lADn65f46XfnNMIo8PPpagFBIvxg03DGDJQu4QnY
# AyZhtrLDxc8VLtGZP8QVBf9JVcjVD8FxMMobDnuDq0YZ1h3ydRo1dqOzWVDipp0i
# oPd0UbL7EcZr6QcM72LWFvAACyVcIiXlh5jY+JehqaZMlS9aw4WQT0gpvBOaOJqb
# vGoAbtyHRFIkFbJG/Wxkpr+VkU1JvilXCh8g0OsXwvJk4dK4GeBVa7VLlq95fLiK
# zL54EZDTY1W+YfKYUseiptRlu5XBUn15C9rTpqDZhHFz6exyLfYcJzdxJJdArjio
# UKKR9ZhLfxm1bmFMb8NPWOKH/ZI6vR0jNgwalk3nTx63ZnVAOJLH+BkxghppMIIa
# ZQIBATB9MGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjFB
# MD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBDb2RlIFNpZ25pbmcgUlNBNDA5
# NiBTSEEzODQgMjAyMSBDQTECEA3RSTbNfh/ebxfsd2XDEE0wDQYJYIZIAWUDBAIB
# BQCgfDAQBgorBgEEAYI3AgEMMQIwADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIB
# BDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQg
# ZImQ0TE3CjulTYM81tQMDASPiRZgp44XPU6l9tyu6+UwDQYJKoZIhvcNAQEBBQAE
# ggIA0aD5P8OlGYzjb9hCjq1/KCGxqdQH3y7dDMxyY9nfXI26YTORXziVkspEvTU7
# KG151kPnnN8Fb/Hi3LHAbFZJE9tBkyEqCuuUu4SEUGMhA77oc3te7K/dbuPHxdfH
# EqsqbYhVUzcz5ovcoIyV+kC6yySZxKqLM0ird3mU1MVukp8S9GxWbN67zIUvIHvP
# /eaAGaQj9Kw78pQ6CE6lINp/zjbKHhgmlt2uanA6qgC4/evViOfCMREHcXvIzHSp
# qNm/e9+5Y/8J36W+sjDDnOkDM21Cy9FhSIlSgnNzVzdePmh+yggqYxAB5DIK0xpo
# wTMfinXlZZ7RbLtIubTMhmoH/mFoGHV8o8RDv/vSDoL+DDXuccKVm6W4Lm03J/Lu
# GYitbXUBK7/ediPDgIQReAvcNIZNrzIDlU/oJr3NxZ9mvV3/hCLERLOsqyj5oqKQ
# jK/bvgziOE3neadV39ZF7kfGOGs2P7IKoPuiq15v+62s+qA0093WCVEegQIQdkUH
# VOwV5dyu4x6YItbJMJm9LfSoXCmZFlFx5lUjwD7mxzK1wEjltdOMkpOCEe3B48KG
# RYroYdMhNeg881HWt3I1ZNO7gfWVa0Vfl6NMaHrGj3ItLifZodIGL7WC7X+O3Hpy
# u3zDISLXj0e9IykEm0f8J4xBHJBSQF4kQBTCC4iNNaedEhShghc/MIIXOwYKKwYB
# BAGCNwMDATGCFyswghcnBgkqhkiG9w0BBwKgghcYMIIXFAIBAzEPMA0GCWCGSAFl
# AwQCAQUAMHcGCyqGSIb3DQEJEAEEoGgEZjBkAgEBBglghkgBhv1sBwEwMTANBglg
# hkgBZQMEAgEFAAQg+Xws+wWY1SMdJzhZAJGq9khD7jXt6a5/nHbe22NQymYCEBSv
# Zb9hC23EzQOXLtwcQKUYDzIwMjQwMjE1MDgyMzM5WqCCEwkwggbCMIIEqqADAgEC
# AhAFRK/zlJ0IOaa/2z9f5WEWMA0GCSqGSIb3DQEBCwUAMGMxCzAJBgNVBAYTAlVT
# MRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkGA1UEAxMyRGlnaUNlcnQgVHJ1
# c3RlZCBHNCBSU0E0MDk2IFNIQTI1NiBUaW1lU3RhbXBpbmcgQ0EwHhcNMjMwNzE0
# MDAwMDAwWhcNMzQxMDEzMjM1OTU5WjBIMQswCQYDVQQGEwJVUzEXMBUGA1UEChMO
# RGlnaUNlcnQsIEluYy4xIDAeBgNVBAMTF0RpZ2lDZXJ0IFRpbWVzdGFtcCAyMDIz
# MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAo1NFhx2DjlusPlSzI+DP
# n9fl0uddoQ4J3C9Io5d6OyqcZ9xiFVjBqZMRp82qsmrdECmKHmJjadNYnDVxvzqX
# 65RQjxwg6seaOy+WZuNp52n+W8PWKyAcwZeUtKVQgfLPywemMGjKg0La/H8JJJSk
# ghraarrYO8pd3hkYhftF6g1hbJ3+cV7EBpo88MUueQ8bZlLjyNY+X9pD04T10Mf2
# SC1eRXWWdf7dEKEbg8G45lKVtUfXeCk5a+B4WZfjRCtK1ZXO7wgX6oJkTf8j48qG
# 7rSkIWRw69XloNpjsy7pBe6q9iT1HbybHLK3X9/w7nZ9MZllR1WdSiQvrCuXvp/k
# /XtzPjLuUjT71Lvr1KAsNJvj3m5kGQc3AZEPHLVRzapMZoOIaGK7vEEbeBlt5NkP
# 4FhB+9ixLOFRr7StFQYU6mIIE9NpHnxkTZ0P387RXoyqq1AVybPKvNfEO2hEo6U7
# Qv1zfe7dCv95NBB+plwKWEwAPoVpdceDZNZ1zY8SdlalJPrXxGshuugfNJgvOupr
# AbD3+yqG7HtSOKmYCaFxsmxxrz64b5bV4RAT/mFHCoz+8LbH1cfebCTwv0KCyqBx
# PZySkwS0aXAnDU+3tTbRyV8IpHCj7ArxES5k4MsiK8rxKBMhSVF+BmbTO77665E4
# 2FEHypS34lCh8zrTioPLQHsCAwEAAaOCAYswggGHMA4GA1UdDwEB/wQEAwIHgDAM
# BgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMCAGA1UdIAQZMBcw
# CAYGZ4EMAQQCMAsGCWCGSAGG/WwHATAfBgNVHSMEGDAWgBS6FtltTYUvcyl2mi91
# jGogj57IbzAdBgNVHQ4EFgQUpbbvE+fvzdBkodVWqWUxo97V40kwWgYDVR0fBFMw
# UTBPoE2gS4ZJaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3Rl
# ZEc0UlNBNDA5NlNIQTI1NlRpbWVTdGFtcGluZ0NBLmNybDCBkAYIKwYBBQUHAQEE
# gYMwgYAwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBYBggr
# BgEFBQcwAoZMaHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1
# c3RlZEc0UlNBNDA5NlNIQTI1NlRpbWVTdGFtcGluZ0NBLmNydDANBgkqhkiG9w0B
# AQsFAAOCAgEAgRrW3qCptZgXvHCNT4o8aJzYJf/LLOTN6l0ikuyMIgKpuM+AqNnn
# 48XtJoKKcS8Y3U623mzX4WCcK+3tPUiOuGu6fF29wmE3aEl3o+uQqhLXJ4Xzjh6S
# 2sJAOJ9dyKAuJXglnSoFeoQpmLZXeY/bJlYrsPOnvTcM2Jh2T1a5UsK2nTipgedt
# QVyMadG5K8TGe8+c+njikxp2oml101DkRBK+IA2eqUTQ+OVJdwhaIcW0z5iVGlS6
# ubzBaRm6zxbygzc0brBBJt3eWpdPM43UjXd9dUWhpVgmagNF3tlQtVCMr1a9TMXh
# RsUo063nQwBw3syYnhmJA+rUkTfvTVLzyWAhxFZH7doRS4wyw4jmWOK22z75X7BC
# 1o/jF5HRqsBV44a/rCcsQdCaM0qoNtS5cpZ+l3k4SF/Kwtw9Mt911jZnWon49qfH
# 5U81PAC9vpwqbHkB3NpE5jreODsHXjlY9HxzMVWggBHLFAx+rrz+pOt5Zapo1iLK
# O+uagjVXKBbLafIymrLS2Dq4sUaGa7oX/cR3bBVsrquvczroSUa31X/MtjjA2Owc
# 9bahuEMs305MfR5ocMB3CtQC4Fxguyj/OOVSWtasFyIjTvTs0xf7UGv/B3cfcZdE
# Qcm4RtNsMnxYL2dHZeUbc7aZ+WssBkbvQR7w8F/g29mtkIBEr4AQQYowggauMIIE
# lqADAgECAhAHNje3JFR82Ees/ShmKl5bMA0GCSqGSIb3DQEBCwUAMGIxCzAJBgNV
# BAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdp
# Y2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IFRydXN0ZWQgUm9vdCBHNDAeFw0y
# MjAzMjMwMDAwMDBaFw0zNzAzMjIyMzU5NTlaMGMxCzAJBgNVBAYTAlVTMRcwFQYD
# VQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkGA1UEAxMyRGlnaUNlcnQgVHJ1c3RlZCBH
# NCBSU0E0MDk2IFNIQTI1NiBUaW1lU3RhbXBpbmcgQ0EwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQDGhjUGSbPBPXJJUVXHJQPE8pE3qZdRodbSg9GeTKJt
# oLDMg/la9hGhRBVCX6SI82j6ffOciQt/nR+eDzMfUBMLJnOWbfhXqAJ9/UO0hNoR
# 8XOxs+4rgISKIhjf69o9xBd/qxkrPkLcZ47qUT3w1lbU5ygt69OxtXXnHwZljZQp
# 09nsad/ZkIdGAHvbREGJ3HxqV3rwN3mfXazL6IRktFLydkf3YYMZ3V+0VAshaG43
# IbtArF+y3kp9zvU5EmfvDqVjbOSmxR3NNg1c1eYbqMFkdECnwHLFuk4fsbVYTXn+
# 149zk6wsOeKlSNbwsDETqVcplicu9Yemj052FVUmcJgmf6AaRyBD40NjgHt1bicl
# kJg6OBGz9vae5jtb7IHeIhTZgirHkr+g3uM+onP65x9abJTyUpURK1h0QCirc0PO
# 30qhHGs4xSnzyqqWc0Jon7ZGs506o9UD4L/wojzKQtwYSH8UNM/STKvvmz3+Drhk
# Kvp1KCRB7UK/BZxmSVJQ9FHzNklNiyDSLFc1eSuo80VgvCONWPfcYd6T/jnA+bIw
# pUzX6ZhKWD7TA4j+s4/TXkt2ElGTyYwMO1uKIqjBJgj5FBASA31fI7tk42PgpuE+
# 9sJ0sj8eCXbsq11GdeJgo1gJASgADoRU7s7pXcheMBK9Rp6103a50g5rmQzSM7TN
# sQIDAQABo4IBXTCCAVkwEgYDVR0TAQH/BAgwBgEB/wIBADAdBgNVHQ4EFgQUuhbZ
# bU2FL3MpdpovdYxqII+eyG8wHwYDVR0jBBgwFoAU7NfjgtJxXWRM3y5nP+e6mK4c
# D08wDgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQMMAoGCCsGAQUFBwMIMHcGCCsGAQUF
# BwEBBGswaTAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEEG
# CCsGAQUFBzAChjVodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRU
# cnVzdGVkUm9vdEc0LmNydDBDBgNVHR8EPDA6MDigNqA0hjJodHRwOi8vY3JsMy5k
# aWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNybDAgBgNVHSAEGTAX
# MAgGBmeBDAEEAjALBglghkgBhv1sBwEwDQYJKoZIhvcNAQELBQADggIBAH1ZjsCT
# tm+YqUQiAX5m1tghQuGwGC4QTRPPMFPOvxj7x1Bd4ksp+3CKDaopafxpwc8dB+k+
# YMjYC+VcW9dth/qEICU0MWfNthKWb8RQTGIdDAiCqBa9qVbPFXONASIlzpVpP0d3
# +3J0FNf/q0+KLHqrhc1DX+1gtqpPkWaeLJ7giqzl/Yy8ZCaHbJK9nXzQcAp876i8
# dU+6WvepELJd6f8oVInw1YpxdmXazPByoyP6wCeCRK6ZJxurJB4mwbfeKuv2nrF5
# mYGjVoarCkXJ38SNoOeY+/umnXKvxMfBwWpx2cYTgAnEtp/Nh4cku0+jSbl3ZpHx
# cpzpSwJSpzd+k1OsOx0ISQ+UzTl63f8lY5knLD0/a6fxZsNBzU+2QJshIUDQtxMk
# zdwdeDrknq3lNHGS1yZr5Dhzq6YBT70/O3itTK37xJV77QpfMzmHQXh6OOmc4d0j
# /R0o08f56PGYX/sr2H7yRp11LB4nLCbbbxV7HhmLNriT1ObyF5lZynDwN7+YAN8g
# Fk8n+2BnFqFmut1VwDophrCYoCvtlUG3OtUVmDG0YgkPCr2B2RP+v6TR81fZvAT6
# gt4y3wSJ8ADNXcL50CN/AAvkdgIm2fBldkKmKYcJRyvmfxqkhQ/8mJb2VVQrH4D6
# wPIOK+XW+6kvRBVK5xMOHds3OBqhK/bt1nz8MIIFjTCCBHWgAwIBAgIQDpsYjvnQ
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
# c7cBqZ9Xql4o4rmUMYIDdjCCA3ICAQEwdzBjMQswCQYDVQQGEwJVUzEXMBUGA1UE
# ChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0IFRydXN0ZWQgRzQg
# UlNBNDA5NiBTSEEyNTYgVGltZVN0YW1waW5nIENBAhAFRK/zlJ0IOaa/2z9f5WEW
# MA0GCWCGSAFlAwQCAQUAoIHRMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAc
# BgkqhkiG9w0BCQUxDxcNMjQwMjE1MDgyMzM5WjArBgsqhkiG9w0BCRACDDEcMBow
# GDAWBBRm8CsywsLJD4JdzqqKycZPGZzPQDAvBgkqhkiG9w0BCQQxIgQgYENuqIy7
# gVQ3i1k0A/gSNyzY+an8//F68WRMNlGIxncwNwYLKoZIhvcNAQkQAi8xKDAmMCQw
# IgQg0vbkbe10IszR1EBXaEE2b4KK2lWarjMWr00amtQMeCgwDQYJKoZIhvcNAQEB
# BQAEggIAGJVoALFmo8f8Zza+shWMxnU9G8zSVpBHscv+HLwG1xzVET2vB8NXtZkd
# 2CPBUOc6OaA2eNFBAjib7m94806wV3pekvqp/YQNgrCGRIwy0YRPhnZE7bQcCLg+
# HVJQF2TAQgoXKZv3C6zE4IVg6TuzjpSlXicTuHl+Zk3//3oicJB6fBPzOPRC+TpG
# 7rpdacIV1eJ+LkatHrolP6t26LKmZq0cyMSKamwTWJ6Ct4UMhG5/JcHQT5T+PiLy
# wRzcP89HMyDFY3KS6HWwNQSpp4sVlq0Y7ohJV2vGW/NrSbZc1LAtI/qBkGqj0nZE
# 9YUlJarI0nXjir1OyEQIOFdP1o1epWfJ4MtOzlyXmhSS5pZcDxR9VdJPLWDjElZc
# 6cEZq7fHNpF/+aiRiPujnvOXz/PItN26fPqFpUFhsP/PgTOY+2/DC5IZM/KBHfKv
# VE4tYfSzgr40+gcKsXTyobpuL4+R7Y3qAMjrqmFxZwkBoN4TEs7+MNoj2VcSfm8D
# i4dOEu9CWNTEQmivgDk5mNwCKLMM7OdLc/BKr56qIuhJC3Qkw1dq0t/CM1GlrGjc
# 68gM+Ly/WviZpFZwz1Inysp6khZUuiVd5cMgoK6v/M7kJQxaULGYxbgKDPEvDI19
# sqmw2u4JRYQOXbnlWT+roiu1ZIySrL0PeGq9Y5jWeuEH4O1czl8=
# SIG # End signature block

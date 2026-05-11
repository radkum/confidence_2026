<#PSScriptInfo

.VERSION 2.0.3

.GUID dce195ab-f751-4d34-86a8-d45853e915b5

.AUTHOR Lenovo CDRT

.COMPANYNAME Lenovo

.COPYRIGHT

.TAGS

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
 - Initial release of Think BIOS Config Tool GUI V2

.PRIVATEDATA

#>

<#

.DESCRIPTION
 GUI companion script to the Lenovo.BIOS.Config Module

#>

#Requires -RunAsAdministrator

$ModuleName = 'Lenovo.BIOS.Config'
#Import the module
try {
    Import-Module -Name $ModuleName -ErrorAction Stop
} catch {
    Write-Output "Module '$ModuleName' not found. Installing from the PSGallery." | Out-Host

    $installed = $false
    #2 Install it from the PSGallery an import the module if it not already installed
    try{
        # Ensure NuGet provider (non-interactive)
        if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
            Write-Output "Installing NuGet provider..." | Out-Host
            Install-PackageProvider -Name NuGet -Force -Scope CurrentUser -ErrorAction Stop | Out-Null
        }

        # Ensure Install-Module exists (PowerShellGet)
        if (-not (Get-Command -Name Install-Module -ErrorAction SilentlyContinue)) {
            Write-Output "Installing/updating PowerShellGet..." | Out-Host
            Install-Module -Name PowerShellGet -Force -Scope CurrentUser -AllowClobber -ErrorAction Stop
        }

        Install-Module -Name $ModuleName -Force -Scope CurrentUser -ErrorAction Stop
        Import-Module -Name $ModuleName -Force -ErrorAction Stop
        $installed = $true
        Write-Output "Module '$moduleName' installed and imported from PSGallery." | Out-Host
    } catch {
        Write-Output "Failed to Install module '$ModuleName' from the PSGallery. Importing from the local path" | Out-Host
    }
    if (-not $installed) {
        # 3) Fallback: look in script root for a local module folder or a .psd1
        Write-Output "Falling back to local module lookup in script folder..." | Out-Host
        #3 else Install the module from a local path
        # Resolve script directory robustly
        $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }

        $importedLocal = $false

        if (-not $importedLocal) {
            # Last resort: search for any matching PSD1 under script directory
            $psd1Any = Get-ChildItem -Path $scriptDir -Filter '*.psd1' -Recurse -ErrorAction SilentlyContinue |
                      Where-Object { $_.Name -like "$($moduleName)*.psd1" } |
                      Sort-Object $_.Directory -Desc |
                      Select-Object -First 1
            if ($psd1Any) {
                try {
                    Import-Module -Name $psd1Any.FullName -Force -ErrorAction Stop
                    Write-Output "Imported $moduleName from $($psd1Any.FullName)" | Out-Host
                    $importedLocal = $true
                } catch {
                    Write-Output "Failed to import PSD1 $($psd1Any.FullName): $($_.Exception.Message)" | Out-Host
                }
            }
        }

        if (-not $importedLocal) {
            Write-Output "Unable to find or load module '$moduleName'. Ensure it is installed (Install-Module $moduleName) or present in the script folder." | Out-Host
            exit 1
        }
    }
}

#Load WPF Assemblies
Add-Type -AssemblyName PresentationFramework,PresentationCore

#PS7
Add-Type -AssemblyName System.Windows.Forms

$guiVersion = "2.0.3"

$base64_LenovoLogo = "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"
$base64_settings = "iVBORw0KGgoAAAANSUhEUgAAACYAAAAmBAMAAABaE/SdAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAwUExURQAAAP///////////////////////////////////////////////////////////ztNBDAAAAAQdFJOUwBQcBDPYCCAQJ/fv6+PMO/ERHVDAAAACXBIWXMAAA7DAAAOwwHHb6hkAAABAklEQVQoz2NgoCNgVBLAEDMJdcMQK2UIRxUIZTB3ZmBRYG5CCDFNX33IgIFB63RlAVws1oAPTD9gmAoXE4KzFOEsezjrGJzFkwBlsG2Ai1kDsdFNBSC5DC6mzsDAt/2ZdgMDQxBMyBzoA+sHDMwLGBisrkGEWDcZgJWCFUlBfM0UACSmAbENEHMUIMRAenIQYoyuQEIJiMWBuDsAYqClMzCoDBiYDwNdeg1msSrQLa7GIgIQpRBgBcTsZ4qB5Da4GDfMb8yofoMAhN8QpsD9xqDJwAymDcDegQDeS7u3Ag3r9i6/jIiQIgOmDwzcdQxBBmhx2YMRv/aC+zDEGMsDGOgIAPGVLO619dJDAAAAAElFTkSuQmCC"
$base64_actions = "iVBORw0KGgoAAAANSUhEUgAAACcAAAAmCAMAAABwIXKiAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAzUExURQAAAP///////////////////////////////////////////////////////////////7eV4oIAAAARdFJOUwAQIDBQgL/P799AcI//YK+fs3OY8QAAAAlwSFlzAAAOwwAADsMBx2+oZAAAANlJREFUOE/dk9mOwyAMRXFYbJYb+v9fO2JpJrjJvFWa9jxEwj5cAgJjPh3adEVD1vnAEnX9BKVcWABIYNHNzq/RvtlQgFVGWyY2QwC25IBiTGny2eghAIrdAiSZTRDJOAB+WHYanO3eI3yPqMDDh9aqMw0hO14iQsqPPle45ERz2ViPCHEpj3Th6tO6gyAOqGT9+MFhPENOFEQg9rOoJV8Zg7anGXVNGl46vBvcezyr65rV2+0L+5U3R2fWzpu8nV649O75Mo90XfM8WdaNFTluePqT24fwj/gBf+Qh3tOwktoAAAAASUVORK5CYII="
$base64_preferences = "iVBORw0KGgoAAAANSUhEUgAAACYAAAAmCAMAAACf4xmcAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAzUExURQAAAP///////////////////////////////////////////////////////////////7eV4oIAAAARdFJOUwAgUBCP7/9wr98wYIBAz7+fmjuSsQAAAAlwSFlzAAAOwwAADsMBx2+oZAAAANhJREFUOE/dk8GOwyAMRI2JJ2CC0///2lXIqgLTTVupl+47kdFg8OAQ/VsCc/TazCIAVq96GA32chrJyKoZOaVUOtt67u5YiJa22DpbddUEFoJN1TwFgADV657jQHnaKVEoJXjtParJ5Y1PthbAlS+oahXkJQOsA/3L/sYbKPYRN/p477bgXYONVJUB2wxSx0OnWM4Wht0PWXfZ/ex8gsjl6bMTqQEwr3ri8SMAyetuyA0o8Qa0j6shF7oH/feQG8Bxe1BtJOZWZ76bQ48e9umZZnh9Ibfv4gfcsQpuvuY/CQAAAABJRU5ErkJggg=="

function New-ImageFromBase64 {
    param (
        [string]$base64String
    )

    # Convert Base64 string to a byte array
    $imageBytes = [Convert]::FromBase64String($base64String)

    # Create a MemoryStream from the byte array
    $memoryStream = New-Object System.IO.MemoryStream
    $memoryStream.Write($imageBytes, 0, $imageBytes.Length)
    $memoryStream.Seek(0, [System.IO.SeekOrigin]::Begin) | Out-Null

    # Create a BitmapImage from the MemoryStream
    $image = New-Object System.Windows.Media.Imaging.BitmapImage
    $image.BeginInit()
    $image.StreamSource = $memoryStream
    $image.EndInit()
    $image.Freeze()

    return $image
}

$image_Logo = New-ImageFromBase64 $base64_LenovoLogo
$image_Settings = New-ImageFromBase64 $base64_settings
$image_Actions = New-ImageFromBase64 $base64_actions
$image_Preferences = New-ImageFromBase64 $base64_preferences


#region XAML
$inputXML = @'
<Window x:Class="ThinkBIOSConfigTool.MainWindow"
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
    xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
    xmlns:local="clr-namespace:ThinkBIOSConfigTool"
    mc:Ignorable="d"
    Title="Think BIOS Config Tool" Height="650" Width="1100" Background="Black" WindowStyle="ToolWindow" WindowStartupLocation="CenterScreen" ResizeMode="NoResize">

    <Window.Resources>
        <!-- Default Button Style -->
        <Style TargetType="Button">
            <Setter Property="Background" Value="#18181B" />
            <Setter Property="Foreground" Value="White" />
            <Setter Property="FontFamily" Value="Montserrat" />
            <Setter Property="FontSize" Value="12" />
            <Setter Property="BorderBrush" Value="#52525B" />
            <Setter Property="BorderThickness" Value="2" />
            <Setter Property="Padding" Value="8" />
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="10">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" />
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>

            <!-- Trigger for hover effect -->
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="BorderBrush" Value="#60A5FA" />
                    <Setter Property="Background" Value="#333333" />
                </Trigger>
                <Trigger Property="IsEnabled" Value="False">
                    <Setter Property="Background" Value="#52525B" />
                    <Setter Property="Foreground" Value="#A1A1AA" />
                </Trigger>
            </Style.Triggers>
        </Style>

        <!-- Custom Style For Main Left Nav Buttons -->
        <Style x:Key="NavButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="#18181B" />
            <Setter Property="Foreground" Value="#d4d4d8" />
            <Setter Property="FontFamily" Value="Montserrat" />
            <Setter Property="FontSize" Value="20" />
            <Setter Property="FontWeight" Value="Bold" />
            <Setter Property="Margin" Value="10,10,10,10" />
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}" CornerRadius="4" BorderThickness="4,0,0,0">
                            <ContentPresenter HorizontalAlignment="Left" VerticalAlignment="Center" />
                        </Border>

                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#2a2a2d" />
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="RoundedDarkTextBox" TargetType="TextBox">
            <Setter Property="Background" Value="#333" />
            <Setter Property="Foreground" Value="White" />
            <Setter Property="BorderBrush" Value="#555" />
            <Setter Property="BorderThickness" Value="1" />
            <Setter Property="Padding" Value="5" />
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TextBox">
                        <Border
                            x:Name="Border"
                            Background="{TemplateBinding Background}"
                            BorderBrush="{TemplateBinding BorderBrush}"
                            BorderThickness="{TemplateBinding BorderThickness}"
                            CornerRadius="8">
                            <ScrollViewer x:Name="PART_ContentHost" />
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="Border" Property="Background" Value="#555" />
                                <Setter TargetName="Border" Property="BorderBrush" Value="#777" />
                                <Setter Property="Foreground" Value="#CCC" />
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="RoundedDarkPasswordBox" TargetType="PasswordBox">
            <Setter Property="Background" Value="#333" />
            <Setter Property="Foreground" Value="White" />
            <Setter Property="BorderBrush" Value="#555" />
            <Setter Property="BorderThickness" Value="1" />
            <Setter Property="Padding" Value="5" />
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="PasswordBox">
                        <Border
                            x:Name="Border"
                            Background="{TemplateBinding Background}"
                            BorderBrush="{TemplateBinding BorderBrush}"
                            BorderThickness="{TemplateBinding BorderThickness}"
                            CornerRadius="8">
                            <ScrollViewer x:Name="PART_ContentHost" />
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="Border" Property="Background" Value="#555" />
                                <Setter TargetName="Border" Property="BorderBrush" Value="#777" />
                                <Setter Property="Foreground" Value="#CCC" />
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="55" />
            <RowDefinition Height="*" />
            <RowDefinition Height="45" />
        </Grid.RowDefinitions>

        <DockPanel x:Name="AppTitle" Grid.Row="0">
            <Image x:Name="LenovoLogo" Source="$image_Logo" Width="32" Height="32" Margin="10,10,0,0" VerticalAlignment="Top" HorizontalAlignment="Left"/>
            <TextBlock x:Name="appTitleText" Text="Think BIOS Config Tool" FontSize="22" FontFamily="Montserrat" Foreground="White" Padding="24" Margin="-10" />
            <TextBlock x:Name="appTitleRebootPending" Text="Restart Pending" FontSize="22" FontFamily="Montserrat" Foreground="Black" Padding="24" Margin="-10" Width="400" Visibility="Hidden" />
        </DockPanel>

        <DockPanel Grid.Row="2">
            <TextBlock Text="" x:Name="StatusBar" Margin="10,10,10,10" FontSize="11" FontFamily="Montserrat" Foreground="White" />
        </DockPanel>

        <DockPanel x:Name="dlgPasswordSaveChanges" Visibility="Hidden" Grid.Column="0" Grid.Row="0" Grid.RowSpan="3" Height="650" Width="1100" Panel.ZIndex="1">
            <Border Margin="0" Background="Transparent">
                <Border BorderBrush="#60A5FA" BorderThickness="2" CornerRadius="10" Background="Black" Margin="60" Height="220" Width="400">
                    <StackPanel Margin="20" Orientation="Vertical">
                        <TextBlock Text="A Supervisor Password is set on this device. Please enter the password below." FontFamily="Montserrat" Foreground="White" HorizontalAlignment="Center" VerticalAlignment="Center" FontSize="16" TextWrapping="Wrap" Margin="10"/>
                        <PasswordBox x:Name="pbPasswordSave" Style="{StaticResource RoundedDarkPasswordBox}" HorizontalAlignment="Center" VerticalAlignment="Center" Margin="0,10,0,10" Width="120" />
                        <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="10">
                            <Button x:Name="bnContinuePWSaveChanges" Content="Continue" Width="100" Height="30" Margin="0,10,0,10" />
                            <Button x:Name="bnCancelPWSaveChanges" Content="Cancel" Width="100" Height="30" Margin="10,10,0,10" />
                        </StackPanel>
                    </StackPanel>
                </Border>
            </Border>
        </DockPanel>

        <DockPanel x:Name="dlgFileImport" Visibility="Hidden" Grid.Column="0" Grid.Row="0" Grid.RowSpan="3" Height="450" Width="1100" Panel.ZIndex="1">
            <Border Margin="0" Background="Transparent">
                <Border BorderBrush="#60A5FA" BorderThickness="2" CornerRadius="10" Background="Black" Margin="60" Height="220" Width="400">
                    <StackPanel Margin="20" Orientation="Vertical">
                        <TextBlock Text="Please enter your passphrase below." FontFamily="Montserrat" Foreground="White" HorizontalAlignment="Center" VerticalAlignment="Center" FontSize="16" TextWrapping="Wrap" Margin="20"/>
                        <TextBox x:Name="tbImportPassphrase" Style="{StaticResource RoundedDarkTextBox}" Width="200" VerticalContentAlignment="Center" />
                        <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="10">
                            <Button x:Name="bnContinueImport" Content="Continue" Width="100" Height="30" Margin="0,10,0,10" />
                            <Button x:Name="bnCancelImport" Content="Cancel" Width="100" Height="30" Margin="10,10,0,10" />
                        </StackPanel>
                    </StackPanel>
                </Border>
            </Border>
        </DockPanel>

        <DockPanel x:Name="dlgPasswordGenerateINI" Visibility="Hidden" Grid.Column="0" Grid.Row="0" Grid.RowSpan="3" Panel.ZIndex="1">
            <Border Margin="0" Background="Transparent">
                <Border BorderBrush="#60A5FA" BorderThickness="2" CornerRadius="10" Background="Black" Height="400" Width="600">
                    <Grid>
                        <StackPanel Margin="20">
                            <TextBlock Text="When generating an INI file you may include a Supervisor Password. If you specify a password you must also specify a passphrase to encrypt the password. If you do not specify a folder to store the INI file, it will be placed in the Output folder defined in Preferences." FontFamily="Montserrat" Foreground="White" HorizontalAlignment="Left" FontSize="16" TextWrapping="Wrap" Margin="10"/>
                            <StackPanel Orientation="Horizontal" Margin="10,20,20,10">
                                <TextBlock Text="Password: " FontSize="14" Foreground="White" Margin="10"/>
                                <PasswordBox x:Name="pbPasswordINI" Style="{StaticResource RoundedDarkPasswordBox}" Width="200" VerticalContentAlignment="Center"/>
                            </StackPanel>

                            <StackPanel Orientation="Horizontal" Margin="10,10,20,10">
                                <TextBlock Text="Passphrase: " FontSize="14" Foreground="White" Margin="10"/>
                                <TextBox x:Name="tbPassphrase" Style="{StaticResource RoundedDarkTextBox}" Width="200" VerticalContentAlignment="Center" IsEnabled="False"/>
                                <Button x:Name="bnGeneratePassphrase" Width="180" Padding="8" Margin="10,0,0,0" >Generate Passphrase</Button>
                            </StackPanel>

                            <StackPanel Orientation="Horizontal" Margin="10">
                                <TextBlock Text="INI file: " FontSize="12" Foreground="White" Margin="10"/>
                                <TextBox x:Name="tbGenerateINIfilepath" Style="{StaticResource RoundedDarkTextBox}" Width="360" VerticalContentAlignment="Center"/>
                                <Button x:Name="bnGenerateBrowseINI" Padding="8" Width="60" Margin="10,0,0,0" FontSize="12">...</Button>
                            </StackPanel>

                            <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="10">
                                <Button x:Name="bnContinueDlgPWGenINI" Content="Continue" Width="100" Height="30" HorizontalAlignment="Center" VerticalAlignment="Center" Margin="0,10,0,10" Background="#d2d2df" Foreground="Black" FontFamily="Montserrat" FontSize="14"/>
                                <Button x:Name="bnCancelDlgPWGenINI" Content="Cancel" Width="100" Height="30" HorizontalAlignment="Center" VerticalAlignment="Center" Margin="10,10,0,10" Background="#d2d2df" Foreground="Black" FontFamily="Montserrat" FontSize="14"/>
                            </StackPanel>
                        </StackPanel>
                    </Grid>
                </Border>
            </Border>
        </DockPanel>

        <Grid Grid.Row="1">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="220"/>
                <ColumnDefinition Width="5" />
                <ColumnDefinition Width="*" />
            </Grid.ColumnDefinitions>

            <Grid.RowDefinitions>
                <RowDefinition Height="*" />
            </Grid.RowDefinitions>

            <Grid x:Name="NavLeft" Background="#18181B">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*" />
                </Grid.ColumnDefinitions>
                <Grid.RowDefinitions>
                    <RowDefinition Height="80" />
                    <RowDefinition Height="80" />
                    <RowDefinition Height="80" />
                    <RowDefinition Height="90" />
                    <RowDefinition Height="30" />
                    <RowDefinition Height="30" />
                    <RowDefinition Height="30" />
                </Grid.RowDefinitions>

                <Button x:Name="btnSettings" Grid.Row="0" Style="{StaticResource NavButtonStyle}" Margin="10">
                    <DockPanel>
                        <Image x:Name="imgSettings" Source="$image_Settings" Width="28" Height="28" Margin="10" VerticalAlignment="Center" HorizontalAlignment="Left"/>
                        <TextBlock Text="Settings" VerticalAlignment="Center"/>
                    </DockPanel>
                </Button>

                <Button x:Name="btnActions" Grid.Row="1" Style="{StaticResource NavButtonStyle}" Margin="10">
                    <DockPanel>
                        <Image x:Name="imgActions" Source="$image_Actions" Width="28" Height="28" Margin="10" VerticalAlignment="Center" HorizontalAlignment="Left"/>
                        <TextBlock Text="Actions" VerticalAlignment="Center"/>
                    </DockPanel>
                </Button>

                <Button x:Name="btnPreferences" Grid.Row="2" Style="{StaticResource NavButtonStyle}" Margin="10">
                    <DockPanel>
                        <Image x:Name="imgPreferences" Source="$image_Preferences" Width="28" Height="28" Margin="10" VerticalAlignment="Center" HorizontalAlignment="Left"/>
                        <TextBlock Text="Preferences" VerticalAlignment="Center"/>
                    </DockPanel>
                </Button>

                <!--
                <TextBlock Text="Target Remote" FontSize="16" FontFamily="Montserrat" FontWeight="Bold" Foreground="White" Margin="10,30,10,0" Grid.Row="3" HorizontalAlignment="Center" VerticalAlignment="Bottom"/>
                <TextBlock Text="Hostname:" FontSize="16" FontFamily="Montserrat" FontWeight="Bold" Foreground="White" Margin="10,4,10,4"  HorizontalAlignment="Center" Grid.Row="4"/>
                <TextBox x:Name="tbHostnameLeft" Style="{StaticResource RoundedDarkTextBox}" Background="#707070" FontSize="16" VerticalAlignment="Center" Margin="10,2,10,0" Grid.Row="5"/>
                <Button x:Name="bnConnectLeft" FontFamily="Montserrat" FontSize="14" FontWeight="Bold" Margin="10,2,10,0" Grid.Row="6">Connect</Button>
                -->
            </Grid>

            <Grid x:Name="MainContent" Grid.Column="2" Background="Black">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*" />
                </Grid.ColumnDefinitions>

                <Grid.RowDefinitions>
                    <RowDefinition Height="*" />
                </Grid.RowDefinitions>

                <DockPanel x:Name="dpSettings" Visibility="Visible" Grid.Column="0" Background="Black">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*" />
                        </Grid.ColumnDefinitions>

                        <DockPanel Grid.Column="0" HorizontalAlignment="Left" >
                            <StackPanel>
                                <TextBlock x:Name="tbTarget" Text="No computer targeted" FontFamily="Montserrat" FontSize="14" Foreground="White" Margin="18,10,0,0" Padding="8" />
                                <Grid>
                                    <Grid.RowDefinitions>
                                        <RowDefinition Height="400" />
                                        <RowDefinition Height="65" />
                                    </Grid.RowDefinitions>

                                    <Border BorderThickness="0,0,0,0" BorderBrush="#60A5FA">
                                        <ScrollViewer Grid.Row="0" ScrollViewer.VerticalScrollBarVisibility="Auto">
                                            <Grid>
                                                <Grid.RowDefinitions>
                                                    <RowDefinition Height="400*"/>
                                                </Grid.RowDefinitions>

                                                <Grid.ColumnDefinitions>
                                                    <ColumnDefinition Width="auto" />
                                                    <ColumnDefinition Width="*" />
                                                    <ColumnDefinition Width="auto" />
                                                    <ColumnDefinition Width="*" />
                                                </Grid.ColumnDefinitions>

                                                <StackPanel Grid.Row="0" Grid.Column="1"  Name="SettingCol1"/>
                                                <StackPanel Grid.Column="3" Grid.Row="0" Name="SettingCol2"/>
                                                <StackPanel Grid.Column="0" Grid.Row="0" Name="LabelCol1"/>
                                                <StackPanel Grid.Column="2" Grid.Row="0" Name="LabelCol2"/>
                                            </Grid>
                                        </ScrollViewer>
                                    </Border>

                                    <DockPanel Grid.Row="1" Margin="5,10,10,0" TextBlock.FontFamily="Montserrat" HorizontalAlignment="Center" Name="dpMainButtons">
                                        <Button x:Name="bnSaveChangedSettings" Width="100" Margin="10,5,5,0" >
                                            <TextBlock Text="Save Changed Settings" Foreground="White" TextWrapping="Wrap" TextAlignment="Center" />
                                        </Button>

                                        <Button x:Name="bnRevertChanges" Width="90" Margin="10,5,5,0" >
                                            <TextBlock Name="tbBnRevertChanges" Text="Revert Changes" Foreground="White" TextWrapping="Wrap" TextAlignment="Center" />
                                        </Button>

                                        <Button x:Name="bnResetFactory" Width="100" Margin="10,5,5,0" >
                                            <TextBlock Text="Reset to Factory Defaults" Foreground="White" TextWrapping="Wrap" TextAlignment="Center" />
                                        </Button>

                                        <Button x:Name="bnSaveCustom" Width="100" Margin="10,5,5,0">
                                            <TextBlock Text="Save Custom Defaults" Foreground="White" TextWrapping="Wrap" TextAlignment="Center" />
                                        </Button>

                                        <Button x:Name="bnResetCustom" Width="100" Margin="10,5,5,0">
                                            <TextBlock Text="Reset to Custom Defaults" Foreground="White" TextWrapping="Wrap" TextAlignment="Center" />
                                        </Button>

                                        <Button x:Name="bnGenerateINI" Width="100" Margin="10,5,5,0">
                                            <TextBlock Text="Generate INI" Foreground="White" TextWrapping="Wrap" TextAlignment="Center" />
                                        </Button>
                                    </DockPanel>
                                </Grid>
                            </StackPanel>
                        </DockPanel>
                    </Grid>
                </DockPanel>

                <DockPanel Name="dpActions" Visibility="Hidden" Grid.Column="0" Background="Black" >
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="420" />
                            <ColumnDefinition Width="420" />
                        </Grid.ColumnDefinitions>

                        <Grid.RowDefinitions>
                            <RowDefinition Height="180" />
                            <RowDefinition Height="180" />
                            <RowDefinition Height="180" />
                        </Grid.RowDefinitions>

                        <Border Grid.Row="0" Grid.Column="0" CornerRadius="20" BorderBrush="#27272A" BorderThickness="1" Background="#18181B" Margin="10" >
                            <StackPanel Background="#18181B" Grid.Column="0" Grid.Row="0" Margin="10" >
                                <TextBlock Text="Select a previously saved .INI file of BIOS settings to apply." FontFamily="Montserrat" FontSize="16" Foreground="White" TextWrapping="Wrap" HorizontalAlignment="Center" Margin="20"/>
                                <Button x:Name="btnApplySettings" IsEnabled="True" Width="200" Margin="10" >
                                    <TextBlock Text="Apply Settings" FontFamily="Montserrat" FontSize="16" Foreground="White" Padding="8" HorizontalAlignment="Center" />
                                </Button>
                            </StackPanel>
                        </Border>

                        <Border Grid.Row="0" Grid.Column="1" CornerRadius="20" BorderBrush="#27272A" BorderThickness="1" Background="#18181B" Margin="10" >
                            <StackPanel Background="#18181B" Grid.Column="0" Grid.Row="0" Margin="10" >
                                <TextBlock Text="Remove the Supervisor password or any stored Fingerprint Data." FontFamily="Montserrat" FontSize="16" Foreground="White" TextWrapping="Wrap" HorizontalAlignment="Center" Margin="20"/>
                                <Button x:Name="btnRemovePassword" IsEnabled="True" Width="320" Margin="10" >
                                    <TextBlock Text="Remove Password or Fingerprint Data" FontFamily="Montserrat" FontSize="16" Foreground="White" Padding="8" HorizontalAlignment="Center" />
                                </Button>
                            </StackPanel>
                        </Border>

                        <Border Grid.Row="1" Grid.Column="0" CornerRadius="20" BorderBrush="#27272A" BorderThickness="1" Background="#18181B" Margin="10" >
                            <StackPanel Background="#18181B" Grid.Column="0" Grid.Row="0" Margin="10" >
                                <TextBlock Text="Replace an existing Supervisor password with a new password." FontFamily="Montserrat" FontSize="16" Foreground="White" TextWrapping="Wrap" HorizontalAlignment="Center" Margin="20"/>
                                <Button x:Name="btnChangePassword" IsEnabled="True" Width="200" Margin="10" >
                                    <TextBlock Text="Change Password" FontFamily="Montserrat" FontSize="16" Foreground="White" Padding="8" HorizontalAlignment="Center" />
                                </Button>
                            </StackPanel>
                        </Border>

                        <Border Grid.Row="1" Grid.Column="1" CornerRadius="20" BorderBrush="#27272A" BorderThickness="1" Background="#18181B" Margin="10" >
                            <StackPanel Background="#18181B" Grid.Column="0" Grid.Row="0" Margin="10" >
                                <TextBlock Text="Create an Intune package from a settings INI file." FontFamily="Montserrat" FontSize="16" Foreground="White" TextWrapping="Wrap" HorizontalAlignment="Center" Margin="20"/>
                                <Button x:Name="btnIntuneAction" IsEnabled="True" Width="200" Margin="10" >
                                    <TextBlock Text="Create Intune Package" FontFamily="Montserrat" FontSize="16" Foreground="White" Padding="8" HorizontalAlignment="Center" />
                                </Button>
                            </StackPanel>
                        </Border>
                    </Grid>
                </DockPanel>

                <DockPanel Name="dpApplyINI" Visibility="Hidden" Grid.Column="0" Background="Black" >
                    <Border CornerRadius="20" BorderBrush="#27272A" BorderThickness="1" Background="#18181B" Margin="0,0,10,0" >
                        <StackPanel Margin="20,20,10,10">
                            <TextBlock Text="Apply settings from saved INI file:" FontFamily="Montserrat" FontSize="18" Foreground="White" TextWrapping="Wrap" Margin="10" />
                            <TextBlock Text="Select the INI file to be applied." HorizontalAlignment="Left" FontFamily="Montserrat" FontSize="14" Foreground="White" TextWrapping="Wrap" Width="830" Margin="10,10,10,0"/>

                            <DockPanel HorizontalAlignment="Left" Margin="10">
                                <TextBlock Text="INI file: " FontSize="12" Foreground="White" Margin="10"/>
                                <TextBox x:Name="tbINIfilepath" Style="{StaticResource RoundedDarkTextBox}" Width="500" VerticalContentAlignment="Center"/>
                                <Button x:Name="bnBrowseINI" Padding="8" Width="60" Margin="10,0,0,0" FontSize="12">...</Button>
                            </DockPanel>

                            <Border x:Name="spPasswordApplyINI" CornerRadius="20" BorderBrush="#18181B" BorderThickness="1" HorizontalAlignment="Left" Background="#000000" Width="800" Margin="10" Visibility="Visible" >
                                <StackPanel Margin="10,0,0,0">
                                    <TextBlock Text="This device has a Supervisor password set. Please enter the password here." FontSize="14" Foreground="White" Margin="10,30,10,10"/>
                                    <DockPanel HorizontalAlignment="Left" Margin="10">
                                        <TextBlock Text="Password: " FontSize="14" Foreground="White" Margin="10"/>
                                        <PasswordBox x:Name="pbPasswordApplyINI" Style="{StaticResource RoundedDarkPasswordBox}" Width="200" VerticalContentAlignment="Center"/>
                                    </DockPanel>
                                </StackPanel>
                            </Border>

                            <Border x:Name="spPassphraseApplyINI" CornerRadius="20" BorderBrush="#18181B" BorderThickness="1" HorizontalAlignment="Left" Background="#000000" Width="800" Margin="10" Visibility="Visible" >
                                <StackPanel Margin="10,0,0,0">
                                    <TextBlock Text="The INI file contains an encrypted password, enter the passphrase here to decrypt it." FontSize="14" Foreground="White" Margin="10,30,10,10"/>
                                    <DockPanel HorizontalAlignment="Left" Margin="10">
                                        <TextBlock Text="Passphrase: " FontSize="14" Foreground="White" Margin="10"/>
                                        <TextBox x:Name="tbPassphraseApplyINI" Style="{StaticResource RoundedDarkTextBox}" Width="200" VerticalContentAlignment="Center"/>
                                    </DockPanel>
                                </StackPanel>
                            </Border>

                            <Button x:Name="bnApplySettings" Margin="0,30,0,0" Width="120" Height="30">
                                <TextBlock Text="Apply Settings" Padding="8,0,8,0" />
                            </Button>
                        </StackPanel>
                    </Border>
                </DockPanel>

                <DockPanel x:Name="dpClearSVPFingerprint" Visibility="Hidden" Grid.Column="0" Background="Black" >

                    <Border CornerRadius="20" BorderBrush="#27272A" BorderThickness="1" Background="#18181B" Margin="0,0,10,0" >

                        <DockPanel x:Name="dpAction2" Width="900" Margin="4" HorizontalAlignment="Left" >

                            <StackPanel>

                                <TextBlock Text="Clear Supervisor Password or Fingerprint Data:" FontFamily="Montserrat" FontSize="18" Foreground="White" TextWrapping="Wrap" Margin="10"/>

                                <TextBlock Text="Specify the current Supervisor password and then select to either clear the password or fingerprint data." FontFamily="Montserrat" FontSize="14" Foreground="White" Margin="10" />

                                <TextBlock Text="Afterwards, BIOS Setup must be used to set another password." FontFamily="Montserrat" FontSize="14" Foreground="White" TextWrapping="Wrap" Margin="10" />

                                <StackPanel Margin="10,0,0,0">

                                    <DockPanel HorizontalAlignment="Left" Margin="10">

                                        <TextBlock Text="Password: " FontSize="14" Foreground="White" Margin="10"/>

                                        <PasswordBox x:Name="pbPasswordClearSVP" Style="{StaticResource RoundedDarkPasswordBox}" Width="200" VerticalContentAlignment="Center"/>

                                    </DockPanel>

                                </StackPanel>

                                <DockPanel HorizontalAlignment="Center" Margin="0,30,0,0" >

                                    <Button x:Name="bnClearSVP" Width="200" Margin="10">

                                        <TextBlock  Text="Clear Supervisor Password" Padding="8" />

                                    </Button>

                                    <Button x:Name="bnClearFingerprintData" Width="200" Margin="10">

                                        <TextBlock  Text="Clear Fingerprint Data" Padding="8" />

                                    </Button>

                                </DockPanel>

                            </StackPanel>

                        </DockPanel>

                    </Border>

                </DockPanel>

                <DockPanel x:Name="dpChangeSVP" Visibility="Hidden" Grid.Column="0" Background="Black" >

                    <Border CornerRadius="20" BorderBrush="#27272A" BorderThickness="1" Background="#18181B" Margin="0,0,10,0" >

                        <DockPanel x:Name="dpAction3"  Width="900" Margin="4" HorizontalAlignment="Left">

                            <StackPanel>

                                <TextBlock Text="Change Supervisor Password:" FontFamily="Montserrat" FontSize="18" Foreground="White" TextWrapping="Wrap" Margin="10" />

                                <TextBlock Text="Specify the current Supervisor password and then a new password. Then select to change the password on this device or create a Password Change INI file." HorizontalAlignment="Left" FontFamily="Montserrat" FontSize="14" Foreground="White" TextWrapping="Wrap" Margin="10" Width="800" />

                                <DockPanel HorizontalAlignment="Left" Margin="10">

                                    <TextBlock Text="Current Password: " FontSize="12" FontFamily="Montserrat" Foreground="White" Margin="10"/>

                                    <PasswordBox x:Name="pbCurrentPass" Style="{StaticResource RoundedDarkPasswordBox}" Width="200" VerticalContentAlignment="Center"/>

                                </DockPanel>

                                <DockPanel HorizontalAlignment="Left" Margin="10,30,0,0" >

                                    <TextBlock Text="New Password:" FontSize="12" FontFamily="Montserrat" Foreground="White" Margin="10" />

                                    <PasswordBox x:Name="pbNewPass" Style="{StaticResource RoundedDarkPasswordBox}" Width="180" Margin="10,0,0,0" VerticalContentAlignment="Center"/>

                                    <TextBlock Text="Confirm:" FontSize="12" FontFamily="Montserrat" Foreground="White" Margin="10" />

                                    <PasswordBox x:Name="pbConfirmPass" Style="{StaticResource RoundedDarkPasswordBox}" Width="180" Margin="10,0,0,0" VerticalContentAlignment="Center"/>

                                </DockPanel>

                                <DockPanel HorizontalAlignment="Center" Margin="0,30,0,0" >

                                    <Button x:Name="bnChangePassword" Width="200" Margin="10" >

                                        <TextBlock Text="Change Password" TextAlignment="Center" Padding="8" />

                                    </Button>

                                    <Button x:Name="bnPasswordChangeFile" Width="200" Margin="10" ToolTip="Both current password and passphrase are required">

                                        <TextBlock Text="Create Password Change File" TextAlignment="Center" Padding="8" />

                                    </Button>

                                </DockPanel>

                            </StackPanel>

                        </DockPanel>

                    </Border>

                </DockPanel>

                <DockPanel x:Name="dpCreateIntunePackage" Visibility="Hidden" Grid.Column="0" Background="Black" >

                    <Border CornerRadius="20" BorderBrush="#27272A" BorderThickness="1" Background="#18181B" Margin="0,0,10,0" >

                        <StackPanel Orientation="Vertical" >

                            <TextBlock Text="Create Intune Package:" FontFamily="Montserrat" FontSize="18" Foreground="White" TextWrapping="Wrap" Margin="10"/>

                            <TextBlock Text="Select the INI file to be used for the Intune package." FontFamily="Montserrat" FontSize="14" Foreground="White" TextWrapping="Wrap" Margin="10"/>

                            <StackPanel Orientation="Horizontal" Margin="10,0,0,0">

                                <TextBlock Text="INI file: " VerticalAlignment="Center" FontSize="14" Foreground="White" Margin="10,0,0,0"/>

                                <TextBox x:Name="tbIntuneINIFile" Style="{StaticResource RoundedDarkTextBox}" Width="500" VerticalContentAlignment="Center"/>

                                <Button x:Name="btnIntuneBrowseINI" Padding="8" Width="60" Margin="10,0,0,0" FontSize="12">...</Button>

                            </StackPanel>

                            <TextBlock Text="If needed, specify the passphrase to decrypt the Password in the selected INI file." FontFamily="Montserrat" FontSize="14" Foreground="White" TextWrapping="Wrap" Margin="10,20,10,10"/>

                            <StackPanel Orientation="Horizontal" Margin="10">

                                <TextBlock Text="Passphrase: " FontSize="14" VerticalAlignment="Center" Foreground="White" Margin="10,0,0,0"/>

                                <TextBox x:Name="tbIntunePassphrase2" Style="{StaticResource RoundedDarkTextBox}" Width="200" FontSize="14" VerticalContentAlignment="Center" Padding="4" Margin="10,4,0,4"/>

                            </StackPanel>

                            <TextBlock Text="Package Details:" FontFamily="Montserrat" FontSize="16" Foreground="White" TextWrapping="Wrap" Margin="10,20,10,10"/>

                            <StackPanel Orientation="Horizontal" Margin="20,10,10,10">

                                <TextBlock Text="Package name:" FontFamily="Montserrat" FontSize="14" Foreground="White" VerticalAlignment="Center" Margin="0,0,20,0"/>

                                <TextBox x:Name="tbPackageName" Style="{StaticResource RoundedDarkTextBox}" Width="250" Text="Lenovo BIOS Configuration" FontFamily="Montserrat" FontSize="14" ToolTip="Display name for package in Intune" Padding="4" Margin="10,0,0,0"/>

                                <TextBlock Text="Version:" FontFamily="Montserrat" FontSize="14" Foreground="White" VerticalAlignment="Center" Margin="10,0,0,0"/>

                                <TextBox x:Name="tbVersion" Style="{StaticResource RoundedDarkTextBox}" Text="1.0" FontFamily="Montserrat" FontSize="14" Padding="4" Width="120" Margin="10,0,0,0"/>

                            </StackPanel>

                            <Grid Margin="20,20,10,0">

                                <Grid.ColumnDefinitions>

                                    <ColumnDefinition Width="*" />

                                    <ColumnDefinition Width="*" />

                                </Grid.ColumnDefinitions>

                                <Grid.RowDefinitions>

                                    <RowDefinition Height="20" />

                                    <RowDefinition Height="*" />

                                </Grid.RowDefinitions>

                                <CheckBox x:Name="cbWin32Package" Grid.Column="0" Grid.Row="0" Content="Create a Win32 package for deployment" IsChecked="True" FontFamily="Montserrat" FontSize="14" Foreground="White" Margin="0,0,20,0"/>

                                <CheckBox x:Name="cbProactiveRemediation" Grid.Column="1" Grid.Row="0" Content="Create a Proactive Remediation" IsChecked="True" FontFamily="Montserrat" FontSize="14" Foreground="White"/>

                                <StackPanel Grid.Column="0" Grid.Row="1" Orientation="Horizontal" VerticalAlignment="Center">

                                    <Label Content="Tag File name:" FontFamily="Montserrat" FontSize="14" Foreground="White" Margin="0,10,10,0"/>

                                    <TextBox x:Name="tbTagFileName" Style="{StaticResource RoundedDarkTextBox}" Grid.Column="0" Grid.Row="1" FontSize="14" Padding="4" Width="180" Margin="0,10,0,0" ToolTip="Tag file name for detection"/>

                                    <Label Content=".tag" FontFamily="Montserrat" FontSize="14" Foreground="White" Margin="0,10,0,0"/>

                                </StackPanel>

                            </Grid>

                            <StackPanel Orientation="Horizontal" Margin="20,20,10,10">

                                <TextBlock Text="The Intune package(s) will be created in:" FontFamily="Montserrat" FontSize="12" Foreground="White" TextWrapping="Wrap" Margin="20,0,0,0"/>

                                <TextBlock x:Name="tblockOutputPath" Text="" FontFamily="Montserrat" FontSize="12" Foreground="White" TextWrapping="Wrap" Margin="4,0,0,0"/>

                            </StackPanel>

                            <Button x:Name="btnCreateIntunePackage" Margin="10,20,0,0" Width="200" Height="30">

                                <TextBlock Text="Create Intune Package" Padding="8,0,8,0" />

                            </Button>

                        </StackPanel>

                    </Border>

                </DockPanel>



                <DockPanel x:Name="dpPreferences" Visibility="Hidden" Grid.Column="0" Background="Black" >

                    <Grid>

                        <StackPanel>

                            <Border Grid.Row="0" CornerRadius="20" BorderBrush="#27272A" BorderThickness="1" Background="#18181B" Margin="10,0,10,10" >

                                <DockPanel Margin="10" HorizontalAlignment="Left">

                                    <StackPanel>

                                        <TextBlock Text="Output Location: " FontFamily="Montserrat" FontSize="18" Foreground="White" HorizontalAlignment="Left" Padding="10" />

                                        <TextBlock Text="Specify the output location for INI files generated." FontFamily="Montserrat" FontSize="14" Foreground="White" HorizontalAlignment="Left" Padding="10" Margin="10,0,0,0" />

                                        <Grid Margin="10,0,0,0" >

                                            <Grid.ColumnDefinitions>

                                                <ColumnDefinition Width="80" />

                                                <ColumnDefinition Width="410" />

                                                <ColumnDefinition Width="80" />

                                            </Grid.ColumnDefinitions>

                                            <TextBlock Grid.Column="0" Text="Path:" FontFamily="Montserrat" FontSize="14" Foreground="White" Padding="8" />

                                            <TextBox x:Name="tbFolderPath" Style="{StaticResource RoundedDarkTextBox}" Grid.Column="1" Width="400" VerticalContentAlignment="Center"/>

                                            <Button x:Name="bnFolderBrowse" Grid.Column="2" Width="80" >Browse...</Button>

                                        </Grid>

                                    </StackPanel>

                                </DockPanel>

                            </Border>

                            <Border CornerRadius="20" BorderBrush="#27272A" BorderThickness="1" Background="#18181B" Margin="10" >

                                <DockPanel Margin="10" HorizontalAlignment="Left">

                                    <StackPanel>

                                        <TextBlock Text="Logging: " FontFamily="Montserrat" FontSize="18" Foreground="White" HorizontalAlignment="Left" Padding="10" />

                                        <StackPanel Orientation="Horizontal" Margin="0,10,0,0">

                                            <CheckBox x:Name="cbLogging" Content="Enable Logging" IsChecked="False" FontFamily="Montserrat" FontSize="16" Foreground="White" Margin="10,10,40,10"/>

                                        </StackPanel>

                                        <Grid Margin="10,0,0,0">

                                            <Grid.ColumnDefinitions>

                                                <ColumnDefinition Width="80" />

                                                <ColumnDefinition Width="410" />

                                                <ColumnDefinition Width="80" />

                                            </Grid.ColumnDefinitions>

                                            <TextBlock Grid.Column="0" Text="Path:" FontFamily="Montserrat" FontSize="14" Foreground="White" Padding="8"/>

                                            <TextBox x:Name="tbLogPath" Style="{StaticResource RoundedDarkTextBox}" Grid.Column="1" VerticalContentAlignment="Center" Width="400"/>

                                            <Button x:Name="bnLogBrowse" Grid.Column="2" Width="80">Browse...</Button>

                                        </Grid>

                                    </StackPanel>

                                </DockPanel>

                            </Border>

                            <Grid Margin="20">

                                <Grid.ColumnDefinitions>

                                    <ColumnDefinition Width="*" />

                                    <ColumnDefinition Width="*" />

                                </Grid.ColumnDefinitions>

                                <Grid.RowDefinitions>

                                    <RowDefinition Height="*" />

                                </Grid.RowDefinitions>

                                <Button x:Name="bnSavePreferences" Grid.Column="0" Width="200" Height="30">Save Preferences</Button>

                                <Button x:Name="bnGenerateDebug" Grid.Column="1" Width="200" Height="30">Generate Debug File</Button>

                            </Grid>

                        </StackPanel>

                    </Grid>

                </DockPanel>

            </Grid>

        </Grid>

    </Grid>
</Window>
'@

#Convert the xaml for powershell usage
$inputXML = $inputXML -replace 'mc:Ignorable="d"','' -replace "x:N",'N'  -replace '^<Win.*', '<Window'
[xml]$xaml = $inputXML

#Read the xaml
$reader=(New-Object System.Xml.XmlNodeReader $xaml)
$Form = $null
try{$Form=[Windows.Markup.XamlReader]::Load( $reader )}
catch{Write-Output "Unable to load Windows.Markup.XamlReader. Some possible causes for this problem include: .NET Framework is missing PowerShell must be launched with PowerShell -sta, invalid XAML code was encountered."; exit}
$Form.WindowStartupLocation = "CenterScreen"
$Form.Cursor = [System.Windows.Input.Cursors]::Wait

#Store Form Objects In PowerShell
$xaml.SelectNodes("//*[@Name]") | ForEach-Object{Set-Variable -Name ($_.Name) -Value $Form.FindName($_.Name)}

# Reference the package type checkboxes
#$cbWin32 = $Form.FindName("cbWin32")
#$cbRemediation = $Form.FindName("cbRemediation")

#Placeholders in the textboxes
$FilterIni = "Configuration File|*.ini"

# Create icon image
$LenovoLogo.Source = $image_Logo
$imgSettings.Source = $image_Settings
$imgActions.Source = $image_Actions
$imgPreferences.Source = $image_Preferences

#endregion
#region HELPERS

Function Update-UI
{

    Begin {
        Add-Type -AssemblyName PresentationFramework
    }

    Process {
        # Define the XAML markup
        [XML]$Xaml = @"
        <Window
                xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
                x:Name="Window" Title="" Height="0" Width="0" WindowStartupLocation="CenterScreen" WindowStyle="None" ResizeMode="NoResize" AllowsTransparency="True" Background="Transparent" Opacity="1">
            <Window.Resources>
                <Style TargetType="{x:Type Button}">
                    <Setter Property="Template">
                        <Setter.Value>
                            <ControlTemplate TargetType="Button">
                                <Border>
                                    <Grid Background="{TemplateBinding Background}">
                                        <ContentPresenter />
                                    </Grid>
                                </Border>
                            </ControlTemplate>
                        </Setter.Value>
                    </Setter>
                </Style>
            </Window.Resources>
            <Border x:Name="MainBorder" Margin="10" CornerRadius="8" BorderThickness="0" BorderBrush="Black" Padding="0" >
                <Border.Effect>
                    <DropShadowEffect x:Name="DSE" Color="Black" Direction="270" BlurRadius="20" ShadowDepth="3" Opacity="0.6" />
                </Border.Effect>
                <Border.Triggers>
                    <EventTrigger RoutedEvent="Window.Loaded">
                        <BeginStoryboard>
                            <Storyboard>
                                <DoubleAnimation Storyboard.TargetName="DSE" Storyboard.TargetProperty="ShadowDepth" From="0" To="3" Duration="0:0:1" AutoReverse="False" />
                                <DoubleAnimation Storyboard.TargetName="DSE" Storyboard.TargetProperty="BlurRadius" From="0" To="20" Duration="0:0:1" AutoReverse="False" />
                            </Storyboard>
                        </BeginStoryboard>
                    </EventTrigger>
                </Border.Triggers>
                <Grid >
                    <Border Name="Mask" CornerRadius="8" Background="White" />
                    <Grid x:Name="Grid" Background="White">
                        <Grid.OpacityMask>
                            <VisualBrush Visual="{Binding ElementName=Mask}"/>
                        </Grid.OpacityMask>
                        <StackPanel Name="StackPanel" >
                            <TextBox Name="TitleBar" IsReadOnly="True" IsHitTestVisible="False" Text="Still shouldn't see this" Padding="10" FontFamily="Segoe UI" FontSize="14" Foreground="Black" FontWeight="Normal" Background="White" HorizontalAlignment="Stretch" VerticalAlignment="Center" Width="Auto" HorizontalContentAlignment="Center" BorderThickness="0"/>
                            <DockPanel Name="ContentHost" Margin="0,10,0,10"  >
                            </DockPanel>
                            <DockPanel Name="ButtonHost" LastChildFill="False" HorizontalAlignment="Center" >
                            </DockPanel>
                        </StackPanel>
                    </Grid>
                </Grid>
            </Border>
        </Window>
"@

        # Load the window from XAML
        $Window = [Windows.Markup.XamlReader]::Load((New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $Xaml))
        $Window.Add_Closed({
            If ($DispatcherTimer)
            {
                $DispatcherTimer.Stop()
            }
        })

        $Stopwatch = New-object System.Diagnostics.Stopwatch
        $TimerCode = {
            If ($Stopwatch.Elapsed.TotalMilliseconds -ge 1)
            {
                $Stopwatch.Stop()
                $Window.Close()
            }
        }
        $DispatcherTimer = New-Object -TypeName System.Windows.Threading.DispatcherTimer
        $DispatcherTimer.Interval = [TimeSpan]::FromMilliseconds(1)
        $DispatcherTimer.Add_Tick($TimerCode)
        $Stopwatch.Start()
        $DispatcherTimer.Start()

        $window.ShowActivated = $false
        $window.TopMost = $false

        # Display the window
        $null = $window.Dispatcher.InvokeAsync{$window.ShowDialog()}.Wait()
    }
}

# Function used on all browse buttons.
# Places the result in the appropriate textbox based on the caller
function Open-File {
    Param (
        [string] $InitialDirectory,
        [string] $Filter,
        [string] $Caller
    )
    try{
        $OpenFileDialog = New-Object Microsoft.Win32.OpenFileDialog
        $OpenFileDialog.initialDirectory = $initialDirectory
        $OpenFileDialog.filter = $Filter
        # Examples of other common filters: "Word Documents|*.doc|Excel Worksheets|*.xls|PowerPoint Presentations|*.ppt |Office Files|*.doc;*.xls;*.ppt |All Files|*.*"
        $OpenFileDialog.ShowDialog() | Out-Null
        if($null -ne $OpenFileDialog.filename)
        {
            $script:TBCSession.Logger.Log("Selected file: {0}" -f $OpenFileDialog.filename)
            switch($Caller)
            {
                "Import" {$tbINIfilepath.Text = $OpenFileDialog.filename}
                "Export" {$tbGenerateINIfilepath.Text = $OpenFileDialog.filename}
            }#end switch
        }#end if
    }#end try
    catch {
        Throw "Open-File Error $_"
    }#end catch
}#end Open-File

function Save-File {
    Param (
        [string] $InitialDirectory = $script:TBCSession.OutputFolder,
        [string] $FileName = (Get-CimInstance -Class "Win32_ComputerSystemProduct" -Namespace "root/cimv2").Name.Substring(0,4) + "_" + [Environment]::MachineNam
    )
    try{
        $SaveFileDialog = New-Object Microsoft.Win32.SaveFileDialog
        $SaveFileDialog.initialDirectory = $InitialDirectory
        $SaveFileDialog.filename = $FileName
        $SaveFileDialog.filter = "Configuration Files|*.ini|All Files|*.*"
        $SaveFileDialog.DefaultExt = "ini"
        $SaveFileDialog.RestoreDirectory = $true
        # Examples of other common filters: "Word Documents|*.doc|Excel Worksheets|*.xls|PowerPoint Presentations|*.ppt |Office Files|*.doc;*.xls;*.ppt |All Files|*.*"
        $SaveFileDialog.ShowDialog() | Out-Null
        if($null -ne $SaveFileDialog.filename)
        {
            $tbGenerateINIfilepath.Text = $SaveFileDialog.Filename
        }
    }#end try
    catch {
        Throw "Save-File Error $_"
    }#end catch
}#end Save-File

#Function to utilize the OpenFolderDialog
#Caller is used to return to the appropiate textbox
function Open-Folder
{
    Param (
        [string] $InitialDirectory,
        [string] $Caller
    )
    try{
        $OpenFolderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $OpenFolderDialog.Description = "Select a folder"
        $OpenFolderDialog.rootfolder = "MyComputer"
        $OpenFolderDialog.SelectedPath = $initialDirectory

        if($OpenFolderDialog.ShowDialog() -eq "OK")
        {
            $script:TBCSession.Logger.Log("Selected folder: {0}" -f $OpenFolderDialog.SelectedPath)
            switch($Caller)
            {
                "Output" {$tbFolderPath.Text = $OpenFolderDialog.SelectedPath}
                "Export" {$tbGenerateINIfilepath.Text = $OpenFolderDialog.SelectedPath}
                "Log" {$tbLogPath.Text = $OpenFolderDialog.SelectedPath}
            }#end switch
        }#end if
    }#end try
    catch {
        Throw "Open-Folder Error $_"
    }#end catch
}#end Open-Folder

#Function to utilize the SaveFileDialog
#Exports settings to the chosen folder
function New-ExportFile {
    Param (
        [string] $InitialDirectory = $script:TBCSession.OutputFolder,
        [string] $FileName = [Environment]::MachineName,
        [securestring] $pass = $null,
        [string] $key
    )
    try{
        <#$SaveFileDialog = New-Object Microsoft.Win32.SaveFileDialog
        $SaveFileDialog.initialDirectory = $InitialDirectory
        $SaveFileDialog.filename = $FileName
        $SaveFileDialog.filter = "Configuration Files|*.ini|All Files|*.*"
        $SaveFileDialog.DefaultExt = "ini"
        $SaveFileDialog.RestoreDirectory = $true
        # Examples of other common filters: "Word Documents|*.doc|Excel Worksheets|*.xls|PowerPoint Presentations|*.ppt |Office Files|*.doc;*.xls;*.ppt |All Files|*.*"
        $SaveFileDialog.ShowDialog() | Out-Null
        if($null -ne $SaveFileDialog.filename)
        {#>

        if (Test-Path -Path $InitialDirectory -PathType Container) {
            $fullPath = Join-Path $InitialDirectory "$FileName.ini"
        }
        else {
            $fullPath = $initialDirectory
        }
        $script:TBCSession.Logger.Log("Exporting settings to {0}" -f $fullPath)
            if($null -ne $pass -and -not ([string]::IsNullOrWhiteSpace($key)))
            {

                $script:TBCSession.Logger.Log("{0} will include password" -f $fullPath)
                #Export-LnvWmiSettings -ConfigFile $SaveFileDialog.filename -SVP $pbPasswordSettings.SecurePassword -K $tbPassphraseSettings.Text
                Export-LnvWmiSettings -ConfigFile $fullPath -SVP $pass -K $key
                $StatusBar.Text = "Settings exported to $fullPath (with password)"
            }
            else
            {
                #$script:TBCSession.Logger.Log("Exporting settings to {0}" -f $fullPath)
                #Export-LnvWmiSettings -ConfigFile $SaveFileDialog.filename -SVP $pbPasswordSettings.SecurePassword
                Export-LnvWmiSettings -ConfigFile $fullPath -NoKey
                $StatusBar.Text = "Settings exported to $fullPath"
            }
    }#end try
    catch {
        Throw "New-ExportFile Error $_"
    }#end catch
}#end New-ExportFile

function DisableButtons
{
    $script:buttonLock = $true
    foreach($child in $dpMainButtons.Children)
    {
        $child.IsEnabled = $false
    }
}

function EnableButtons
{
    $computer = Get-LnvTBCTargetComputer
    foreach($child in $dpMainButtons.Children)
    {
        switch($child.Name)
        {
            bnRevertChanges {$child.IsEnabled = $true}
            bnResetFactory {$child.IsEnabled = $true}
            bnSaveChangedSettings {$child.IsEnabled = $computer.SupportsASCII}
            bnSaveCustom {$child.IsEnabled = $computer.CanCustomDefault}
            bnResetCustom {$child.IsEnabled = $computer.CanCustomDefault}
            bnGenerateINI {$child.IsEnabled = $true}
            bnCreateIntunePackage {$child.IsEnabled = $true}
        }
    }
    $script:buttonLock = $false
}

#Creates a randomly generated key to encrypt data
function Request-EncryptingKey
{
    $text = ""
    $possible = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789".toCharArray()

    for($i=0; $i -lt 16; $i++)
    {
        $text += Get-Random -InputObject $possible
    }#end for
    $StatusBar.Text = "Encrypting key generated"
    $script:TBCSession.Logger.Log("Created encrypting key: {0}" -f $text)
    return $text
}#end New-EncryptingKey

#Loads the current WMI settings and generates the appropriate control
#Reload is used to rebind the names to the containers
function Read-SettingList
{
    param(
        [switch] $Reload
    )

    #Loads the settings into the LenovoSettings class
    $settings = Show-LnvWmiSettings -Force

    $computerInfo = Get-LnvTBCTargetComputer
    if($computerInfo.ComputerName -eq "")
    {
        $computerInfo.ComputerName = "Localhost ($([Environment]::MachineName))"
    }#end if
    #$bios = [LenovoSettings]::GetInstance().GetBiosVersion()
    if($computerInfo.CanCustomDefault)
    {
        $bnSaveCustom.IsEnabled = $true
        $bnResetCustom.IsEnabled = $true
    }#end if
    else
    {
        $bnSaveCustom.IsEnabled = $false
        $bnResetCustom.IsEnabled = $false
    }#end else

    $tbTarget.Text = "Accessing settings on $($computerInfo.ComputerName)  |  BIOS Version = $($computerInfo.BiosVersion)"

    #used to determine what column to put the setting in
    $counter = 0

    #Clears the containers of the children if needed
    if($Reload)
    {
        $SettingCol1.Children.Clear()
        $LabelCol1.Children.Clear()
        $SettingCol2.Children.Clear()
        $LabelCol2.Children.Clear()
    }#end if

    #Creates the appropriate control based on the WmiSetting class
    foreach($setting in $settings)
    {
        $settingType = $setting.GetType()
        $SettingLabel = New-Object System.Windows.Controls.Label
        $SettingLabel.Content = $setting.GetSettingName()
        $SettingLabel.Padding = "3,3,3,3"
        $SettingLabel.Foreground = "White"
        $SettingLabel.Name = "Label_$($setting.GetSettingName())"

        if($settingType -eq [AnalogSetting])
        {
            $SettingCombo = New-Object System.Windows.Controls.ComboBox
            $SettingCombo.Name = "Combo_$($setting.GetSettingName())"
            $SettingCombo.SelectedValuePath="Content"
            $SettingCombo.MaxWidth = 181
            $SettingCombo.MinWidth = 181
        }#end if
        elseif($settingType -eq [TimeSetting] -or
            $settingType -eq [DateSetting] -or
            $settingType -eq [BootOrderSetting])
        {
            [System.Windows.Controls.ToolTip]$tip = [System.Windows.Controls.ToolTip]::new()
            $tip.Placement = 2 #bottom
            $tip.PlacementTarget = $SettingCombo
            $tip.AddText($setting.GetSettingOptions() -join "`n")

            $SettingCombo = New-Object System.Windows.Controls.TextBox
            $SettingCombo.Name = "Combo_$($setting.GetSettingName())"
            $SettingCombo.MinWidth = 181
            $SettingCombo.MaxWidth = 181
            $SettingCombo.Padding = "2,2,2,2"
            $SettingCombo.ToolTip = $tip

        }#end elseif

        if($counter % 2 -eq 0)
        {
            if($reload)
            {
                $LabelCol1.UnregisterName($SettingLabel.Name)
                $SettingCol1.UnregisterName($SettingCombo.Name)
            }#end if reload
            $SettingCol1.Children.Add($SettingCombo)
            $LabelCol1.Children.Add($SettingLabel)
            $LabelCol1.RegisterName($SettingLabel.Name, $SettingLabel)
            $SettingCol1.RegisterName($SettingCombo.Name, $SettingCombo)
        }#end if
        else
        {
            if($reload)
            {
                $LabelCol2.UnregisterName($SettingLabel.Name)
                $SettingCol2.UnregisterName($SettingCombo.Name)
            }#end if reload
            $SettingCol2.Children.Add($SettingCombo)
            $LabelCol2.Children.Add($SettingLabel)
            $LabelCol2.RegisterName($SettingLabel.Name, $SettingLabel)
            $SettingCol2.RegisterName($SettingCombo.Name, $SettingCombo)
        }#end else

        #Change to the other column
        $counter++

        #Standard dropdown list content
        if($settingType -eq [AnalogSetting])
        {
            #Populate the combobox
            foreach($value in $setting.GetSettingOptions())
            {
                $ValueItem = New-Object System.Windows.Controls.ComboBoxItem
                $ValueItem.Content = $value
                $SettingCombo.Items.Add($ValueItem)
            }#enf foreach

            #Set the value of the combobox to the current value of the setting
            $SettingCombo.SelectedValue = $setting.GetCurrentValue()

            #Set up the listener for changes
            $SettingCombo.Add_SelectionChanged({
                #TODO: Add listener for enable\disable save and reset buttons
                $name = ($this.Name).Split("_")
                $mySetting = Get-LnvWmiSetting($name[1])

                #Need to find the label so we have to look at both columns
                $setlabel = $LabelCol1.FindName("Label_$($mySetting.GetSettingName())")
                if($null -eq $setlabel)
                {
                    $setlabel = $LabelCol2.FindName("Label_$($mySetting.GetSettingName())")
                }#end if
                if($mySetting.GetInitialValue() -ne $this.SelectedValue)
                {
                    $setlabel.Foreground = "Red"
                }#end if
                else
                {
                    $setlabel.Foreground = "White"
                }#end else

                $script:TBCSession.Logger.Log(("Attempting to set {0} to {1}" -f $mySetting.GetSettingName(), $this.SelectedValue))
                Set-LnvWmiSetting -Name $mySetting.GetSettingName() -Value $this.SelectedValue
            })#end Add_SelectionChanged
        }#end if AnalogSetting

        #Free form textboxes
        elseif($settingType -eq [TimeSetting] -or
            $settingType -eq [DateSetting] -or
            $settingType -eq [BootOrderSetting])
        {
            #Sets the text in the textbox to the current value of the setting
            $SettingCombo.Text = $setting.GetCurrentValue()

            #Adds the listener for when the text is changed
            $SettingCombo.Add_LostFocus({
                TextboxLostFocus $this
            })#end Add_OnLostFocus

            $SettingCombo.Add_KeyDown({
                #$script:TBCSession.Logger.Log($_.Key)
                if($_.Key -eq "Return")
                {
                    TextboxLostFocus $this
                    [System.Windows.Input.Keyboard]::ClearFocus()
                }#end if
            })#end Add_KeyDown
        }#end elseif
    }#end foreach setting
}#end Read-SettingList

#Function to hold code for when a Textbox loses focus
function TextboxLostFocus
{
    param(
        [System.Windows.Controls.Textbox]$box
    )
    $name = ($box.Name).Split("_")
    $mySetting = Get-LnvWmiSetting($name[1])

    #Need to find the label so we have to look at both columns
    $setlabel = $LabelCol1.FindName("Label_$($mySetting.GetSettingName())")
    if($null -eq $setlabel)
    {
        $setlabel = $LabelCol2.FindName("Label_$($mySetting.GetSettingName())")
    }#end if
    $value = $box.Text.Trim()

    if([string]::IsNullOrWhiteSpace($value))
    {
        $box.Text = $mySetting.GetCurrentValue()
        $script:TBCSession.Logger.Log(("No value entered - Reverting to {0}" -f $mySetting.GetCurrentValue()))
        return
    }#end if

    $script:TBCSession.Logger.Log(("Attempting to set {0} to {1}" -f $mySetting.GetSettingName(), $value))
    $results = Set-LnvWmiSetting -Name $mySetting.GetSettingName() -Value $value
    $StatusBar.Text = $results

    if($results -ne "Success")
    {
        $box.Text = $mySetting.GetCurrentValue()
        $script:TBCSession.Logger.Log(("$results - Reverting to {0}" -f $mySetting.GetCurrentValue()))
        return
    }#end if

    if($mySetting.GetInitialValue() -ne $value)
    {
        $setlabel.Foreground = "Red"
    }#end if
    else
    {
        $setlabel.Foreground = "White"
    }#end else
}#end TextboxLostFocus

#Compares 2 SecureStrings to see if they are the same
function Compare-SecureString
{
    param(
    [Security.SecureString]
    $secureString1,

    [Security.SecureString]
    $secureString2
    )
    try
    {
        if ($null -eq $secureString1 -or $null -eq $secureString2) { return $false }
        $bstr1 = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString1)
        $bstr2 = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString2)
        $length1 = [Runtime.InteropServices.Marshal]::ReadInt32($bstr1,-4)
        $length2 = [Runtime.InteropServices.Marshal]::ReadInt32($bstr2,-4)
        if ( $length1 -ne $length2 )
        {
            return $false
        }
        for ( $i = 0; $i -lt $length1; ++$i )
        {
            $b1 = [Runtime.InteropServices.Marshal]::ReadByte($bstr1,$i)
            $b2 = [Runtime.InteropServices.Marshal]::ReadByte($bstr2,$i)
            if ( $b1 -ne $b2 )
            {
                return $false
            }
        }
        return $true
    }
    finally
    {
        if ( $bstr1 -ne [IntPtr]::Zero )
        {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr1)
        }#end if
        if ( $bstr2 -ne [IntPtr]::Zero )
        {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr2)
        }#end if
    }#end finally
}#end Compare-SecureString

function SwitchPanels {
    param(
        [Parameter(Mandatory=$true)]
        [string]$PanelName,
        [Parameter(Mandatory=$false)]
        [string]$Origin
    )

    $panels = @('dpSettings', 'dpActions', 'dpPreferences', 'dpApplyINI', 'dpClearSVPFingerprint', 'dpChangeSVP', 'dpCreateIntunePackage')
    $buttonsNav = @('btnSettings', 'btnActions', 'btnPreferences')

    # Hide all panels
    $panels | ForEach-Object {
        $panel = $Form.FindName($_)
        if ($panel) {
            $panel.Visibility = "Hidden"
        }
    }

    # Check if Sender was passed for Nav buttons
    if ($PSBoundParameters.ContainsKey('Origin')) {
        $buttonsNav | ForEach-Object {
            $button = $Form.FindName($_)
            if ($button) {
                # Reset properties for all navigation buttons
                $border = $button.Template.FindName("border", $button)
                if ($border) {
                    $border.ClearValue([System.Windows.Controls.Border]::BackgroundProperty)
                    $border.ClearValue([System.Windows.Controls.Border]::BorderBrushProperty)
                }
                $button.ClearValue([System.Windows.Controls.Control]::ForegroundProperty)
                $button.ClearValue([System.Windows.Controls.Control]::BackgroundProperty)
            }
        }

        # Apply styles to the target button
        $targetButton = $Form.FindName($Origin)
        if ($targetButton) {
            $border = $targetButton.Template.FindName("border", $targetButton)
            if ($border) {
                $border.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#2a2a2b")
                $border.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#60A5FA")
            }
            $targetButton.Foreground = "#60A5FA"
        }
    }

    # Show the target panel
    $targetPanel = $Form.FindName($PanelName)
    if ($targetPanel) {
        $targetPanel.Visibility = "Visible"
    }
}

#region LISTENERS
$script:buttonClicks = 0
$script:buttonClicked = ""
[System.Windows.RoutedEventHandler]$mainButtonsHandler = {
    $script:buttonClicks = $script:buttonClicks + 1
    if($script:buttonClicks -le 1)
    {
        DisableButtons
        $Form.Cursor = [System.Windows.Input.Cursors]::Wait
        Update-UI
        $script:buttonClicked = $_.OriginalSource.Name
        switch ($_.OriginalSource.Name) {
            'bnRevertChanges' {
                Reset-LnvWmiSettings
                Read-SettingList -Reload
                $Form.Cursor = [System.Windows.Input.Cursors]::Arrow
                EnableButtons
            }
            'bnResetFactory' {
                $message = "Would you like to reset to factory defaults?"
                $caption = "Revert to defaults"
                $button = [System.Windows.MessageBoxButton]::YesNo
                $image = [System.Windows.MessageBoxImage]::Question
                $result = [System.Windows.MessageBox]::Show($message, $caption, $button, $image)

                if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
                    if ((Get-LnvTBCTargetComputer).PasswordFound) {
                        $dlgPasswordSaveChanges.Visibility = "Visible"
                    }
                    else {
                        $bnContinuePWSaveChanges.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))
                    }
                    $Form.Cursor = [System.Windows.Input.Cursors]::Arrow
                }
                else {
                    $script:TBCSession.Logger.Log("User canceled defaults")
                }
            }
            'bnSaveChangedSettings' {
                #Force-UIUpdate
                $StatusBar.Text = "Saving..."
                $Form.Cursor = [System.Windows.Input.Cursors]::Wait
                if ((Get-LnvTBCTargetComputer).PasswordFound) {
                    $dlgPasswordSaveChanges.Visibility = "Visible"
                }
                else {
                    $bnContinuePWSaveChanges.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))
                }
            }
            'bnSaveCustom' {
                if ((Get-LnvTBCTargetComputer).PasswordFound) {
                    $dlgPasswordSaveChanges.Visibility = "Visible"
                }
                else {
                    $bnContinuePWSaveChanges.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))
                }
            }
            'bnResetCustom' {
                $message = "Would you like to reset to custom defaults?"
                $caption = "Revert to custom defaults"
                $button = [System.Windows.MessageBoxButton]::YesNo
                $image = [System.Windows.MessageBoxImage]::Question
                $result = [System.Windows.MessageBox]::Show($message, $caption, $button, $image)

                if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
                    if ((Get-LnvTBCTargetComputer).PasswordFound) {
                        $dlgPasswordSaveChanges.Visibility = "Visible"
                    }
                    else {
                        $bnContinuePWSaveChanges.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))
                    }
                }
                else {
                    $script:TBCSession.Logger.Log("User canceled custom defaults")
                }
                $Form.Cursor = [System.Windows.Input.Cursors]::Arrow
                EnableButtons
            }
            'bnGenerateINI' {
                $dlgPasswordGenerateINI.Visibility = "Visible"
                $Form.Cursor = [System.Windows.Input.Cursors]::Arrow
            }
        }
    }
    $_.Handled = $true
    $script:buttonClicks = 0
}

$dpMainButtons.AddHandler([System.Windows.Controls.Button]::ClickEvent, $mainButtonsHandler)

#Listner for the generate passphrase button
$bnGeneratePassphrase.Add_Click({
    if($tbPassphrase.IsEnabled)
    {
        $tbPassphrase.Text = Request-EncryptingKey
    }
})#end Add_click

$btnSettings.Add_Click( {
    SwitchPanels -PanelName "dpSettings" -Origin "btnSettings"
    #$StatusBar.Text = ""
})

$btnActions.Add_Click( {
    $dlgPasswordSaveChanges.Visibility = "Hidden"
    $dlgPasswordGenerateINI.Visibility = "Hidden"
    $dpCreateIntunePackage.Visibility = "Hidden"
    SwitchPanels -PanelName "dpActions" -Origin "btnActions"
    $StatusBar.Text = ""
})

$btnPreferences.Add_Click( {
    SwitchPanels -PanelName "dpPreferences" -Origin "btnPreferences"
    $StatusBar.Text = ""
})

$btnApplySettings.Add_Click( {
    SwitchPanels -PanelName "dpApplyINI"
    $StatusBar.Text = ""
})

$btnRemovePassword.Add_Click( {
    SwitchPanels -PanelName "dpClearSVPFingerprint"
    $StatusBar.Text = ""

})

$btnChangePassword.Add_Click( {
    SwitchPanels -PanelName "dpChangeSVP"
    $StatusBar.Text = ""
})

$btnIntuneAction.Add_Click({

    SwitchPanels -PanelName "dpCreateIntunePackage"
    $tbTagFileName.Text = (Get-Date).ToString('yyyyMMdd_HHmmss')
    $tblockOutputPath.Text = $script:TBCSession.OutputFolder
    $StatusBar.Text = ""
})

$bnBrowseINI.Add_Click({
    Open-File -InitialDirectory $script:TBCSession.OutputFolder -Filter $FilterIni -Caller "Import"
})#end Add_Click

$bnGenerateBrowseINI.Add_Click({
    Save-File -InitialDirectory $script:TBCSession.OutputFolder -FileName $TBCSession.ComputerName
})#end Add_Click

$bnFolderBrowse.Add_Click({
    Open-Folder -InitialDirectory $script:TBCSession.OutputFolder -Caller "Output"
})

$bnLogBrowse.Add_Click({
    Open-Folder -InitialDirectory $script:TBCSession.LogFolder -Caller "Log"
})

$bnCancelDlgPWGenINI.Add_Click({
    #TODO: clear the inputs
    $pbPasswordINI.Clear()
    $tbGenerateINIfilepath.Clear()
    $tbPassphrase.Clear()
    $dlgPasswordGenerateINI.Visibility = "Hidden"
    EnableButtons
})#end Add_Click

$bnContinueDlgPWGenINI.Add_Click({
    #TODO: clear the inputs
    #TODO: validate input
    if(-not [string]::IsNullOrWhitespace($pbPasswordINI.Password) -and [string]::IsNullOrWhitespace($tbPassphrase.Text))
    {
        $StatusBar.Text = "Password provided without a key."
        $script:TBCSession.Logger.Log("Password provided without a key.")
        return
    }

    $path = $tbGenerateINIfilepath.Text
    if([string]::IsNullOrWhiteSpace($path))
    {
        $path = $script:TBCSession.OutputFolder
    }#end if

    $folder = Split-Path $path -Parent

    if (-not (Test-Path $folder -PathType Container)) {
        $StatusBar.Text = "Please select a valid file path."
        $script:TBCSession.Logger.Log("Invalid file path: {0}" -f $folder)
        return
    }

    $key  = $tbPassphrase.Text
    $tbPassphrase.Clear()
    $pass = $pbPasswordINI.SecurePassword
    $pbPasswordINI.Clear()
    $tbGenerateINIfilepath.Clear()

    $dlgPasswordGenerateINI.Visibility = "Hidden"

    if([string]::IsNullOrWhiteSpace($path))
    {
        New-ExportFile -Pass $pass -Key $key
    }
    else {
        New-ExportFile -InitialDirectory $path -Pass $pass -Key $key
    }
    EnableButtons
})#end Add_Click

$pbPasswordINI.Add_PasswordChanged({
    if (-not [string]::IsNullOrWhiteSpace($pbPasswordINI.Password)) {
        $tbPassphrase.IsEnabled = $true
    } else {
        $tbPassphrase.Clear()
        $tbPassphrase.IsEnabled = $false
    }
})

$bnContinuePWSaveChanges.Add_Click({
    #validate input
    #if visible check

    if($dlgPasswordSaveChanges.Visibility -eq "Visible" -and [string]::IsNullOrWhiteSpace($pbPasswordSave.Password))
    {
        $StatusBar.Text = "Please enter a password for the machine"
        return
    }

    switch($script:buttonClicked)
    {
        bnResetFactory {
            $results = Restore-LnvDefaultSettings -Current $pbPasswordSave.SecurePassword
            $StatusBar.Text = $results | Select-Object -last 1
        }
        bnSaveChangedSettings {
            $output = Save-LnvWmiSettings -Current $pbPasswordSave.SecurePassword
            $pbPasswordSave.Clear()
            if ($output -eq "No settings modified.") {
                $StatusBar.Text = $output
            } else {
                $StatusBar.Text = "Save result: $output`nPlease restart for settings to take effect"
            }
            if(Test-LnvTBCPendingReboot)
            {
                $appTitleRebootPending.Visibility = "Visible"
            }
            if($output -like "*Success*"){
                Read-SettingList -Reload
            }
            $Form.Cursor = [System.Windows.Input.Cursors]::Arrow
        }
        bnSaveCustom {
            $results = Save-LnvCustomDefault -Current $pbPasswordSave.SecurePassword
            $StatusBar.Text = $results | Select-Object -last 1
            $Form.Cursor = [System.Windows.Input.Cursors]::Arrow
        }
        bnResetCustom {
            $results = Restore-LnvCustomDefault -Current $pbPasswordSave.SecurePassword
            $StatusBar.Text = $results | Select-Object -last 1
            Read-SettingList -Reload
        }
        default {
            $StatusBar.Text = "No action selected"
            $script:TBCSession.Logger.Log("No action selected")
            return
        }
    }
    $dlgPasswordSaveChanges.Visibility = "Hidden"
    $script:buttonClicked = ""
    $pbPasswordSave.Clear()
    EnableButtons
})

$bnCancelPWSaveChanges.Add_Click({
    $pbPasswordSave.Clear()
    $Form.Cursor = [System.Windows.Input.Cursors]::Arrow
    $dlgPasswordSaveChanges.Visibility = "Hidden"
    EnableButtons
})

$bnCancelImport.Add_Click({
    $Form.Cursor = [System.Windows.Input.Cursors]::Arrow
    $pbCurrentPass.Clear()
    $pbNewPass.Clear()
    $pbConfirmPass.Clear()
    $tbImportPassphrase.Clear()
    $dlgFileImport.Visibility = "Hidden"
    $StatusBar.Text = "Export cancelled"
})

$bnContinueImport.Add_Click({
    $passphrase = $tbImportPassphrase.Text
    $results = Export-LnvPasswordChangeFile -O $pbCurrentPass.SecurePassword -N $pbNewPass.SecurePassword -K $passphrase -F (Join-Path $script:TBCSession.OutputFolder "Password.ini") -Ty "pap"

    $script:TBCSession.Logger.Log("File created: $results")
    if($results)
    {
        $StatusBar.Text = "Successfully created the file"
    }#end if
    else
    {
        $StatusBar.Text = "Error creating the file"
    }#end else
    $dlgFileImport.Visibility = "Hidden"
    $pbCurrentPass.Clear()
    $pbNewPass.Clear()
    $pbConfirmPass.Clear()
    $tbImportPassphrase.Clear()
})

$btnIntuneBrowseINI.Add_Click({
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Filter = "INI Files (*.ini)|*.ini|All Files (*.*)|*.*"
    $openFileDialog.Title = "Select INI file for Intune package"
    if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $tbIntuneINIFile.Text = $openFileDialog.FileName
    }
})

Add-Type -AssemblyName PresentationCore, PresentationFramework
$badchars = '[<>";&'']'
 $correctInput=({
    if ($this.Text -match $badchars) {
        $this.BorderBrush= [System.Windows.Media.Brushes]::Red
        $this.BorderThickness = '2'
        $this.ToolTip = "Invalid character entered."
        $this.Opacity = 0.8
        $this.SelectionStart = $this.text.length
        $btnCreateIntunePackage.IsEnabled = $false
    }else{
        $this.BorderBrush= $null
        $this.BorderThickness = '1'
        $this.ToolTip = $null
        $this.Opacity = 1.0
        if(($tbPackageName.Text -match $badchars) -or ($tbTagFileName.Text -match $badchars) -or ($tbVersion.Text -match $badchars)){
            $btnCreateIntunePackage.IsEnabled = $false
        }
            else{
        $btnCreateIntunePackage.IsEnabled = $true
            }
    }
})
$tbPackageName.add_TextChanged($correctInput)
$tbTagFileName.add_TextChanged($correctInput)
$tbVersion.add_TextChanged($correctInput)


$btnCreateIntunePackage.Add_Click({
    try{

        # Gather user input from the form controls in the dpCreateIntunePackage panel
        $iniFilePath = $tbIntuneINIFile.Text
        $outputFolder = $script:TBCSession.OutputFolder
        $doWin32 = $cbWin32Package.IsChecked
        $doRemediation = $cbProactiveRemediation.IsChecked
        $passphrase = $tbIntunePassphrase2.Text
        $version = $tbVersion.text
        $Tagfile = $tbTagFileName.text
        $packageName = $tbPackageName.text

        # Validate required fields
        $iniFilePath = $iniFilePath.Trim('"')

        Write-Output "INI File Path: $iniFilePath" | Out-Host
        $script:TBCSession.Logger.Log("INI File Path: $iniFilePath")
        if ([string]::IsNullOrWhiteSpace($iniFilePath) -or -not (Test-Path $iniFilePath)) {
            [System.Windows.Forms.MessageBox]::Show("Please select a valid INI file.", "Missing INI File", "OK", "Warning")
            $StatusBar.Text = "No valid INI file selected."
            $script:TBCSession.Logger.Log("No valid INI file selected.")
            return
        }

        if (-not $doWin32 -and -not $doRemediation) {
            [System.Windows.Forms.MessageBox]::Show("Please select at least one package type (Win32 or Proactive Remediation).", "No Package Type Selected", "OK", "Warning")
            $StatusBar.Text = "Please select at least one package type."
            $script:TBCSession.Logger.Log("No package type selected.")
            return
        }

        if($doWin32){
        # Locate or download IntuneWinAppUtil.exe
            $intuneWinAppUtilPath = Find-IntuneWinAppUtil
            if ([string]::IsNullOrWhiteSpace($intuneWinAppUtilPath) -or -not (Test-Path $intuneWinAppUtilPath)) {
                #Puts the intune in ProgramData\lenovo\ThinkBiosConfig folder
                $ProgramDataDownloads = "$env:ProgramData\lenovo\ThinkBiosConfig\Downloads"
                if (!(Test-Path $ProgramDataDownloads)) {
                    $script:TBCSession.Logger.Log("Creating directory: $ProgramDataDownloads")
                    New-Item -ItemType Directory -Path $ProgramDataDownloads -Force
                }
                $downloadUrl = "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/raw/master/IntuneWinAppUtil.exe"
                $downloadPath = Join-Path -Path $ProgramDataDownloads -ChildPath "IntuneWinAppUtil.exe"
                $StatusBar.Text = "IntuneWinAppUtil.exe not found. Downloading..."
                $script:TBCSession.Logger.Log("IntuneWinAppUtil.exe not found. Downloading from $downloadUrl to $downloadPath")
                try {
                    Write-Output "Downloading IntuneWinAppUtil.exe from $downloadUrl to $downloadPath" | Out-Host
                    Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath -UseBasicParsing
                    $intuneWinAppUtilPath = $downloadPath
                    if (-not (Test-Path $intuneWinAppUtilPath)) {
                        $StatusBar.Text = "Failed to download IntuneWinAppUtil.exe."
                        $script:TBCSession.Logger.Log("Failed to download IntuneWinAppUtil.exe to $downloadPath")
                        return
                    }
                    $StatusBar.Text ="Downloaded IntuneWinAppUtil.exe successfully."
                    $script:TBCSession.Logger.Log("Downloaded IntuneWinAppUtil.exe successfully to $downloadPath")
                } catch {
                    $StatusBar.Text = "Error downloading IntuneWinAppUtil.exe: $_"
                    $script:TBCSession.Logger.Log("Error downloading IntuneWinAppUtil.exe: $_")
                    return
                }
            }
        }
        # Validate the output folder again

        if ( -not (Test-Path $outputFolder)) {
            $StatusBar.Text = "Output folder is not set or does not exist."
            $script:TBCSession.Logger.Log("Output folder is not set or does not exist: $outputFolder")
            return
        }


        # Validate the INI file again
        if (-not $iniFilePath) {
            $StatusBar.Text = "Failed to convert INI file to script."
            $script:TBCSession.Logger.Log("INI file path is empty.")
            return
        }
        # Validate password and passphrase

        $keyphrase = $passphrase # Default to passphrase if provided
        if (-not [string]::IsNullOrWhiteSpace($passphrase)) {
            $keyphrase = $passphrase
        }
        # Convert INI to PowerShell script
        Convert-LnvConfigFileToScript -FilePath $iniFilePath  -Keyphrase $keyphrase  -Tagfile $Tagfile

        # remediation starts here
            if ($doRemediation){
                New-LnvRemediationScript -FilePath $iniFilePath
                $filename = [IO.Path]::GetFileNameWithoutExtension($iniFilePath)

                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $PRsubfolder = Join-Path $outputFolder "PRpackage_$timestamp"


                if (-not (Test-Path $PRsubfolder)) {
                    New-Item -ItemType Directory -Path $PRsubfolder | Out-Null
                }

                $detectScript = Join-Path $script:TBCSession.OutputFolder "Detect_$filename.ps1"
                $remediateScript = Join-Path $script:TBCSession.OutputFolder "Remediate_$filename.ps1"
                Copy-Item -Path $detectScript -Destination $PRsubfolder -Force
                Copy-Item -Path $remediateScript -Destination $PRsubfolder -Force

                #Create the Proactive Remediation JSON payload

                $detectionScriptPath   = Join-Path $PRsubfolder "Detect_$filename.ps1"
                $remediationScriptPath = Join-Path $PRsubfolder "Remediate_$filename.ps1"


                $payloadParams = @{
                    Name = $PackageName
                    Description = "Remediation for $PackageName BIOS package"
                    Publisher = "Lenovo"
                    version = $version
                    DetectionScriptPath = $detectionScriptPath
                    RemediationScriptPath = $remediationScriptPath
                    outputFolder = $outputFolder
                }


                # Generate the JSON payload
                $jsonFilePath = New-RemediationPayload @payloadParams

                Copy-Item -Path $jsonFilePath -Destination $PRsubfolder -Force
                $PRfilename = Split-Path -Path $jsonFilePath -Leaf
                $PRJsonpath = Join-Path -Path $PRsubfolder -ChildPath $PRfilename
                Write-Output " new path: $PRJsonpath" | Out-Host
                if ($jsonFilePath) {
                    remove-Item -Path $detectScript -Force
                    remove-Item -Path $remediateScript -Force
                    remove-Item -Path $jsonFilePath
                    $StatusBar.Text=  "Local packaging completed ..."
                    $script:TBCSession.Logger.Log("Remediation JSON payload created at $PRJsonpath")

                } else{
                    $StatusBar.Text= "Remediation failed: $_"
                    $script:TBCSession.Logger.Log("Failed to create remediation JSON payload.")
                }
        } # end if doRemediation


        if ($doWin32){
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $subfolder = Join-Path $outputFolder "Win32package_$timestamp"
            if (-not (Test-Path $outputFolder)) {
                New-Item -ItemType Directory -Path $outputFolder | Out-Null
            }
            if (-not (Test-Path $subfolder)) {
                New-Item -ItemType Directory -Path $subfolder | Out-Null
            }
            # Copy config script and ini file to the subfolder
            $configpath = Join-Path $outputFolder "ConfigScript.ps1"
            Copy-Item -Path $configpath -Destination $subfolder -Force
            Copy-Item -Path $iniFilePath -Destination $subfolder -Force
            $iniFilePath = Join-Path -Path $subfolder -ChildPath (Split-Path -Path $iniFilePath -Leaf)
            $setupFile = Join-Path $subfolder "ConfigScript.ps1"
            $sourceFolder = $subfolder


            $cmd = "& `"$intuneWinAppUtilPath`" -c `"$sourceFolder`" -s `"$setupFile`" -o `"$subfolder`""
            Write-Output ">> Executing: $cmd" | Out-Host
            $result = Invoke-Expression $cmd
            $StatusBar.Text = "Local packaging completed "

        }

        try {
            Write-Output " >> packaging Complete " | Out-Host
            $script:TBCSession.Logger.Log("Packaging completed successfully.")
        } catch {
            Write-Output " >> Error...: $_" | Out-Host
            $script:TBCSession.Logger.Log("Error during packaging: $_")
            Throw
        }

        # Prompt to upload to Intune
        [int]$dialog = [System.Windows.Forms.MessageBox]::Show(
            "Package built. Upload to Intune now?",
            "Intune Upload",
            "YesNo",
            "Question"
        )

        if ($dialog -eq [System.Windows.Forms.DialogResult]::Yes) {

            if (-not (IsGraphModuleInstalled)) {
                $message = "The Microsoft.Graph.Authentication module is not installed. Would you like to install it now?"
                $caption = "Install Microsoft.Graph.Authenticaton"
                $result = [System.Windows.Forms.MessageBox]::Show($message, $caption, [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
                if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
                    try {
                        Install-GraphModule
                        [System.Windows.Forms.MessageBox]::Show("Microsoft.Graph.Authentication module installed via the command line.","Installation complete",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information)
                        $StatusBar.Text = "Microsoft.Graph module installed successfully."
                        $script:TBCSession.Logger.Log("Microsoft.Graph module installed successfully.")
                    } catch {
                        $StatusBar.Text = "Failed to install Microsoft.Graph module: $_"
                        $script:TBCSession.Logger.Log("Failed to install Microsoft.Graph module: $_")
                        return
                    }
                } else {
                    $StatusBar.Text = "Microsoft.Graph module installation canceled."
                    $script:TBCSession.Logger.Log("Microsoft.Graph module installation canceled by user.")
                    return
                }
            }

            Write-Output "Checking required modules..." -ForegroundColor Cyan | Out-Host
            $StatusBar.Text = " Uploading to Intune.."
            $modules = @("Microsoft.Graph.Authentication")
            foreach ($module in $modules) {
                if (!(Get-Module -ListAvailable -Name $module)) {
                    Write-Output "Installing $module..." -ForegroundColor Yellow | Out-Host
                    Install-Module $module -Scope CurrentUser -Force -AllowClobber
                }
            }

            # Import modules
            Import-Module Microsoft.Graph.Authentication -Force

            # Connect to Graph
            Write-Output "`nConnecting to Microsoft Graph..." -ForegroundColor Cyan | Out-Host
            $scopes = @(
                "DeviceManagementApps.ReadWrite.All",
                "DeviceManagementConfiguration.ReadWrite.All"
            )
            Connect-MgGraph -Scopes $scopes -NoWelcome

            # Verify connection
            $context = Get-MgContext

            if (!$context) {
                [System.Windows.Forms.MessageBox]::Show("Connection failed, Please try again","Connection Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
                ) | Out-Null

                $StatusBar.Text = "Not connected to Microsoft Graph."
                Write-Output "ERROR: Failed to connect to Graph" -ForegroundColor Red | Out-Host
                return
            }
            Write-Output "Connected to tenant: $($context.TenantId)" -ForegroundColor Green | Out-Host

            # Upload remediation if selected
            if ($doRemediation) {
                $StatusBar.Text = "Uploading remediation to Intune..."
                Invoke-RemediationPayloadtoGraph -JsonPayload $PRJsonpath
                $StatusBar.Text = "Remediation uploaded to intune."
                Write-Output "Remediation uploaded"-ForegroundColor Green | Out-Host
            }

            #Upload win32 if selected
            if ($doWin32) {
                $StatusBar.Text = "Uploading win32 to intune, check the commandline for details "
                $script:TBCSession.Logger.Log("Uploading Win32 package to Intune...")
                # creation of the win 32 app body
                $filePath = Join-Path $subfolder "ConfigScript.intunewin"
                $win32LobBody = @{
                    "@odata.type" = "#microsoft.graph.win32LobApp"
                    "applicableArchitectures" = "x64"
                    "allowAvailableUninstall" = $false
                    "categories" = @()
                    "description" = "This app applies BIOS configuration settings for Lenovo  devices using the Lenovo BIOS Config Tool."
                    "developer" = "CDRT"
                    "displayName" = "$packageName"
                    "displayVersion" = "$version"
                    "fileName" = "ConfigScript.intunewin"

                    "installCommandLine" = 'powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File ConfigScript.ps1'
                    "installExperience" = @{
                        "deviceRestartBehavior" = "allow"
                        "runAsAccount" = "system"
                    }
                    "informationUrl" = "https://www.lenovo.com/support"
                    "isFeatured" = $false
                    "roleScopeTagIds" = @()
                    "notes" = "Lenovo BIOS Configuration Tool"
                    "minimumSupportedWindowsRelease" = "21H1"
                    "msiInformation" = $null
                    "owner" = "IT Admin"
                    "privacyInformationUrl" = ""
                    "publisher" = "Lenovo"
                    "returnCodes" = @(
                        @{ "returnCode" = 0; "type" = "success" },
                        @{ "returnCode" = 1707; "type" = "success" },
                        @{ "returnCode" = 3010; "type" = "softReboot" },
                        @{ "returnCode" = 1641; "type" = "hardReboot" },
                        @{ "returnCode" = 1; "type" = "Failed" }
                    )
                    "rules" = @(
                        @{
                            "@odata.type" = "#microsoft.graph.win32LobAppFileSystemRule"
                            "ruleType" = "detection"
                            "operator" = "notConfigured"
                            "check32BitOn64System" = $false
                            "operationType" = "exists"
                            "comparisonValue" = $null

                            "fileOrFolderName" = "$Tagfile.tag"
                            "path" = "C:\ProgramData\Lenovo\ThinkBiosConfig"
                        }
                    )
                    "runAs32Bit" = $false
                    "setupFilePath" = "ConfigScript.intunewin"

                    "uninstallCommandLine" = 'cmd.exe /c echo "No uninstall required"'
                } | ConvertTo-Json -Depth 10

                # Create the app using Graph API
                Write-Output "Creating Win32 app..." -ForegroundColor Yellow | Out-Host
                try {
                    $win32LobUrl = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps"
                    $win32LobApp = Invoke-MgGraphRequest -Method POST -Uri $win32LobUrl -Body $win32LobBody -ContentType 'application/json'
                    Write-Output "App created successfully. ID: $($win32LobApp.id)" -ForegroundColor Green | Out-Host
                    $script:TBCSession.Logger.Log("Win32 app created successfully in Intune. App ID: $($win32LobApp.id)")
                    Write-Output "App Name: $($win32LobApp.displayName)" -ForegroundColor Green | Out-Host
                    $script:TBCSession.Logger.Log("App Name: $($win32LobApp.displayName)")
                } catch {
                    Write-Error "Failed to create app: $($_.Exception.Message)"
                    $script:TBCSession.Logger.Log("Failed to create Win32 app in Intune: $($_.Exception.Message)")
                    return #exit
                }

                # Create a content version
                Write-Output "Creating content version..." -ForegroundColor Yellow | Out-Host
                $script:TBCSession.Logger.Log("Creating content version for app ID: $($win32LobApp.id)")
                $Win32LobVersionUrl = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$($win32LobApp.id)/microsoft.graph.win32LobApp/contentVersions"
                $win32LobAppVersionRequest = Invoke-MgGraphRequest -Method POST -Uri $Win32LobVersionUrl -Body "{}" -ContentType 'application/json'
                Write-Output "Content version created. ID: $($win32LobAppVersionRequest.id)" -ForegroundColor Green | Out-Host
                $script:TBCSession.Logger.Log("Content version created. ID: $($win32LobAppVersionRequest.id)")

                # Extract and process the .intunewin file to get detection.xml and encrypted payload
                Write-Output "Processing .intunewin file..." -ForegroundColor Yellow | Out-Host
                $script:TBCSession.Logger.Log("Processing .intunewin file at $filePath")
                $__parsed = Get-InnerPayloadAndDetectionXml -IntuneWinPath $filePath
                $DetectionXMLContent    = $__parsed.DetectionXml
                $ExtractedIntuneWinFile = $__parsed.ExtractedPath

                # Display extracted info
                Write-Output "Inner payload chosen: $ExtractedIntuneWinFile" -ForegroundColor Cyan | Out-Host
                Write-Output "Inner payload size : $((Get-Item $ExtractedIntuneWinFile).Length) bytes" -ForegroundColor Cyan | Out-Host
                Write-Output "Detection fileName : $($DetectionXMLContent.ApplicationInfo.FileName)" -ForegroundColor Cyan | Out-Host
                Write-Output "Unencrypted size   : $($DetectionXMLContent.ApplicationInfo.UnencryptedContentSize)" -ForegroundColor Cyan | Out-Host
                $script:TBCSession.Logger.Log("Inner payload chosen: $ExtractedIntuneWinFile")
                $script:TBCSession.Logger.Log("Inner payload size : $((Get-Item $ExtractedIntuneWinFile).Length) bytes")
                $script:TBCSession.Logger.Log("Detection fileName : $($DetectionXMLContent.ApplicationInfo.FileName)")
                $script:TBCSession.Logger.Log("Unencrypted size   : $($DetectionXMLContent.ApplicationInfo.UnencryptedContentSize)")

                #Read detection.xml from the .intunewin archive
                $IntuneWin32AppFile = [System.IO.Compression.ZipFile]::OpenRead($filePath)
                $DetectionXMLFile = $IntuneWin32AppFile.Entries | Where-Object { $_.Name -like "detection.xml" }
                $FileStream = $DetectionXMLFile.Open()
                $StreamReader = New-Object -TypeName "System.IO.StreamReader" -ArgumentList $FileStream -ErrorAction Stop
                $DetectionXMLContent = [xml]($StreamReader.ReadToEnd())
                $FileStream.Close()
                $StreamReader.Close()
                $IntuneWin32AppFile.Dispose()

                # Create a file placeholder in the content version to prepare for upload
                $Win32LobFileBody = @{
                    "@odata.type"   = "#microsoft.graph.mobileAppContentFile"
                    "name" = $DetectionXMLContent.ApplicationInfo.FileName
                    "size" = [int64]$DetectionXMLContent.ApplicationInfo.UnencryptedContentSize
                    "sizeEncrypted" = (Get-Item -Path $ExtractedIntuneWinFile).Length
                    "manifest"      = $null
                    "isDependency"  = $false
                } | ConvertTo-Json

                # Create the file placeholder in Intune
                $Win32LobFileUrl = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$($win32LobApp.id)/microsoft.graph.win32LobApp/contentVersions/$($win32LobAppVersionRequest.id)/files"
                $Win32LobPlaceHolder = Invoke-MgGraphRequest -Uri $Win32LobFileUrl -Method "POST" -Body $Win32LobFileBody -ContentType 'application/json'
                # we get the azure storage uri
                $storageCheckUrl = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$($win32LobApp.id)/microsoft.graph.win32LobApp/contentVersions/$($win32LobAppVersionRequest.id)/files/$($Win32LobPlaceHolder.id)"
                $storageCheck = Invoke-MgGraphRequest -Uri $storageCheckUrl -Method "GET"
                Write-Output "Waiting for Azure Storage URI..." -ForegroundColor Yellow | Out-Host
                $script:TBCSession.Logger.Log("Waiting for Azure Storage URI...")
                do {
                    Start-Sleep -Seconds 5
                    $storageCheck = Invoke-MgGraphRequest -Uri $storageCheckUrl -Method "GET"
                } while ($storageCheck.uploadState -ne "azureStorageUriRequestSuccess")
                Write-Output "Azure Storage URI received" -ForegroundColor Green | Out-Host
                $script:TBCSession.Logger.Log("Azure Storage URI received.")

                # Extract the encrypted content from .intunewin

                $ExtractedIntuneWinFile = $FilePath + ".extracted"
                $ZipFile = [System.IO.Compression.ZipFile]::OpenRead($FilePath)
                $IntuneWinFileName = $DetectionXMLContent.ApplicationInfo.FileName
                $ZipFile.Entries | Where-Object { $_.Name -like $IntuneWinFileName } | ForEach-Object {
                    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($_, $ExtractedIntuneWinFile, $true)
                }
                $ZipFile.Dispose()

                # Upload the extracted file in chunks to Azure Blob Storage
                $ChunkSizeInBytes = 1024l * 1024l * 6l
                $FileSize = (Get-Item -Path $filePath).Length
                $ChunkCount = [System.Math]::Ceiling($FileSize / $ChunkSizeInBytes)
                $BinaryReader = New-Object System.IO.BinaryReader([System.IO.File]::Open($ExtractedIntuneWinFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite))
                Write-Output "Uploading file in $ChunkCount chunks..." -ForegroundColor Yellow | Out-Host
                $script:TBCSession.Logger.Log("Uploading file in $ChunkCount chunks to Azure Blob Storage...")

                $ChunkIDs = @()
                # Upload each chunk
                for ($Chunk = 0; $Chunk -lt $ChunkCount; $Chunk++) {
                    $ChunkID = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($Chunk.ToString("0000")))
                    $ChunkIDs += $ChunkID
                    $Start = $Chunk * $ChunkSizeInBytes
                    $Length = [System.Math]::Min($ChunkSizeInBytes, $FileSize - $Start)
                    $Bytes = $BinaryReader.ReadBytes($Length)
                    $CurrentChunk = $Chunk + 1
                    #Upload the chunks to azure
                    Write-Progress -Activity "Uploading chunks" -Status "Chunk $CurrentChunk of $ChunkCount" -PercentComplete (($CurrentChunk / $ChunkCount) * 100)
                    $Uri = "$($storageCheck.azureStorageUri)&comp=block&blockid=$ChunkID"
                    $Headers = @{ "x-ms-blob-type" = "BlockBlob" }
                    Invoke-RestMethod -Uri $Uri -Method Put -Headers $Headers -Body $Bytes -ContentType 'application/octet-stream' -ErrorAction Stop
                }
                Write-Progress -Completed -Activity "Uploading chunks"
                Write-Output "File chunks uploaded successfully" -ForegroundColor Green | Out-Host
                $script:TBCSession.Logger.Log("File chunks uploaded successfully.")


                Write-Output " uploading process with details " -ForegroundColor Green | Out-Host
                $script:TBCSession.Logger.Log("Starting detailed verification steps...")

                # 1. Verify extracted file exists and size
                Write-Output "1. Checking extracted file..." -ForegroundColor Yellow | Out-Host
                Write-Output "ExtractedIntuneWinFile path: $ExtractedIntuneWinFile" | Out-Host
                Write-Output "File exists: $(Test-Path $ExtractedIntuneWinFile)" | Out-Host
                if (Test-Path $ExtractedIntuneWinFile) {
                    $extractedSize = (Get-Item $ExtractedIntuneWinFile).Length
                    Write-Output "Extracted file size: $extractedSize bytes" | Out-Host
                    $script:TBCSession.Logger.Log("Extracted file size: $extractedSize bytes")
                } else {
                    Write-Output "ERROR: Extracted file not found!" -ForegroundColor Red | Out-Host
                    $script:TBCSession.Logger.Log("ERROR: Extracted file not found!")
                    return #exit
                }

                # 2. Compare with expected sizes from detection.xml
                Write-Output "`n2. Comparing with detection.xml..." -ForegroundColor Yellow | Out-Host
                $expectedUnencryptedSize = [int64]$DetectionXMLContent.ApplicationInfo.UnencryptedContentSize
                $expectedEncryptedSize = [int64]$DetectionXMLContent.ApplicationInfo.EncryptedContentSize
                Write-Output "Expected unencrypted size: $expectedUnencryptedSize" | Out-Host
                Write-Output "Expected encrypted size: $expectedEncryptedSize" | Out-Host
                Write-Output "Actual extracted size: $extractedSize" | Out-Host

                # 3. Verify the intunewin file structure
                Write-Output "`n3. Verifying .intunewin structure..." -ForegroundColor Yellow | Out-Host
                $zipFile = [System.IO.Compression.ZipFile]::OpenRead($filePath)
                Write-Output "Contents of .intunewin file:" | Out-Host
                $zipFile.Entries | ForEach-Object {
                    Write-Output "  - $($_.Name) ($($_.Length) bytes)" | Out-Host
                }
                $zipFile.Dispose()

                # 4. Check encryption info values
                Write-Output "`n4. Encryption information:" -ForegroundColor Yellow | Out-Host
                Write-Output "EncryptionKey length: $($DetectionXMLContent.ApplicationInfo.EncryptionInfo.EncryptionKey.Length)" | Out-Host
                Write-Output "MAC length: $($DetectionXMLContent.ApplicationInfo.EncryptionInfo.Mac.Length)" | Out-Host
                Write-Output "FileDigest length: $($DetectionXMLContent.ApplicationInfo.EncryptionInfo.FileDigest.Length)" | Out-Host
                Write-Output "ProfileIdentifier: $($DetectionXMLContent.ApplicationInfo.EncryptionInfo.ProfileIdentifier)" | Out-Host

                # 5. Alternative extraction method (more reliable)
                Write-Output "`n5. Using alternative extraction..." -ForegroundColor Yellow | Out-Host
                $alternativeExtractPath = "$filePath.alt_extracted"
                # Clean extraction
                if (Test-Path $alternativeExtractPath) { Remove-Item $alternativeExtractPath -Force }

                $zipFile = [System.IO.Compression.ZipFile]::OpenRead($filePath)
                $intuneWinEntry = $zipFile.Entries | Where-Object { $_.Name -eq "IntunePackage.intunewin" }

                if ($intuneWinEntry) {
                    Write-Output "Found IntunePackage.intunewin entry" | Out-Host
                    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($intuneWinEntry, $alternativeExtractPath, $true)
                    $altSize = (Get-Item $alternativeExtractPath).Length
                    Write-Output "Alternative extracted size: $altSize bytes" | Out-Host
                } else {
                    Write-Output "IntunePackage.intunewin not found in archive" | Out-Host
                }
                $zipFile.Dispose()

                # 6. Modified chunk upload with better error handling
                Write-Output "`n6. Starting chunk upload with debugging..." -ForegroundColor Yellow | Out-Host
                $ChunkSizeInBytes = 1024l * 1024l * 6l
                $FileSize = (Get-Item -Path $alternativeExtractPath).Length
                $ChunkCount = [System.Math]::Ceiling($FileSize / $ChunkSizeInBytes)

                Write-Output "File size for upload: $FileSize" | Out-Host
                Write-Output "Chunk size: $ChunkSizeInBytes" | Out-Host
                Write-Output "Total chunks: $ChunkCount" | Out-Host

                # Use the alternative extracted file
                $BinaryReader = New-Object -TypeName System.IO.BinaryReader([System.IO.File]::Open($alternativeExtractPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite))
                $ChunkIDs = @()
                $TotalBytesUploaded = 0

                for ($Chunk = 0; $Chunk -lt $ChunkCount; $Chunk++) {
                    $ChunkID = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($Chunk.ToString("0000")))
                    $ChunkIDs += $ChunkID
                    $Start = $Chunk * $ChunkSizeInBytes
                    $Length = [System.Math]::Min($ChunkSizeInBytes, $FileSize - $Start)
                    $Bytes = $BinaryReader.ReadBytes($Length)
                    $CurrentChunk = $Chunk + 1
                    $TotalBytesUploaded += $Length

                    Write-Output "Uploading chunk $CurrentChunk/$ChunkCount (Size: $Length bytes)" | Out-Host

                    $Uri = "$($storageCheck.azureStorageUri)&comp=block&blockid=$ChunkID"
                    $Headers = @{ "x-ms-blob-type" = "BlockBlob" }
                    Invoke-RestMethod -Uri $Uri -Method Put -Headers $Headers -Body $Bytes -ContentType 'application/octet-stream' -ErrorAction Stop
                    Write-Output "  Chunk $CurrentChunk uploaded successfully (Status: $($UploadResponse.StatusCode))" | Out-Host
                }

                Write-Output "Total bytes uploaded: $TotalBytesUploaded (Expected: $FileSize)" | Out-Host
                $script:TBCSession.Logger.Log("Total bytes uploaded: $TotalBytesUploaded (Expected: $FileSize)")

                # 7. Commit chunks with verification
                Write-Output "`n7. Committing chunks..." -ForegroundColor Yellow | Out-Host
                $finalChunkUri = "$($storageCheck.azureStorageUri)&comp=blocklist"
                $XML = '<?xml version="1.0" encoding="utf-8"?><BlockList>'
                foreach ($ChunkID in $ChunkIDs) {
                    $XML += "<Latest>$ChunkID</Latest>"
                }
                $XML += '</BlockList>'

                Write-Output "BlockList XML length: $($XML.Length)" | Out-Host
                $script:TBCSession.Logger.Log("BlockList XML length: $($XML.Length)")
                Write-Output "Number of chunks in list: $($ChunkIDs.Count)" | Out-Host
                $script:TBCSession.Logger.Log("Committing $($ChunkIDs.Count) chunks to Azure Blob Storage.")

                try {
                    Invoke-RestMethod -Uri $finalChunkUri -Method "Put" -Body $XML -ContentType 'text/plain;charset=UTF-8' -ErrorAction Stop
                    Write-Output "Block list committed successfully" | Out-Host
                    $script:TBCSession.Logger.Log("Block list committed successfully.")
                } catch {
                    Write-Output "ERROR committing block list: $($_.Exception.Message)" -ForegroundColor Red | Out-Host
                    $script:TBCSession.Logger.Log("ERROR committing block list: $($_.Exception.Message)")
                    throw
                }

                $BinaryReader.Close()
                $BinaryReader.Dispose()

                # 8. Wait and verify upload state before commit
                Write-Output "`n8. Verifying upload state..." -ForegroundColor Yellow | Out-Host
                Start-Sleep -Seconds 10
                $preCommitStatus = Invoke-MgGraphRequest -Uri $storageCheckUrl -Method GET
                Write-Output "Pre-commit upload state: $($preCommitStatus.uploadState)" | Out-Host
                $script:TBCSession.Logger.Log("Pre-commit upload state: $($preCommitStatus.uploadState)")
                Write-Output "Pre-commit is committed: $($preCommitStatus.isCommitted)" | Out-Host
                $script:TBCSession.Logger.Log("Pre-commit is committed: $($preCommitStatus.isCommitted)")

                # 9. Enhanced commit with exact encryption info format
                Write-Output "`n9. Preparing commit with exact format..." -ForegroundColor Yellow | Out-Host

                # Get exact values from detection.xml
                $encInfo = $DetectionXMLContent.ApplicationInfo.EncryptionInfo

                $Win32FileEncryptionInfo = @{
                    fileEncryptionInfo = @{
                        "@odata.type"             = "#microsoft.graph.fileEncryptionInfo"
                        encryptionKey             = $encInfo.EncryptionKey
                        macKey                    = $encInfo.MacKey
                        initializationVector      = $encInfo.InitializationVector
                        mac                       = $encInfo.Mac
                        profileIdentifier         = $encInfo.ProfileIdentifier
                        fileDigest                = $encInfo.FileDigest
                        fileDigestAlgorithm       = $encInfo.FileDigestAlgorithm
                    }
                    fileName = $DetectionXMLContent.ApplicationInfo.FileName

                } | ConvertTo-Json -Depth 10

                Write-Output "Commit payload prepared:" | Out-Host
                Write-Output $Win32FileEncryptionInfo | Out-Host

                # 10. Attempt commit
                Write-Output "`n10. Attempting commit..." -ForegroundColor Yellow | Out-Host
                $CommitResourceUri = "$storageCheckUrl/commit"

                try {
                    Invoke-MgGraphRequest -Uri $CommitResourceUri -Method "POST" -Body $Win32FileEncryptionInfo -ContentType 'application/json'

                    Write-Output "Commit request sent successfully" -ForegroundColor Green | Out-Host
                    $script:TBCSession.Logger.Log("Commit request sent successfully.")
                } catch {
                    Write-Output "Commit failed with detailed error:" -ForegroundColor Red | Out-Host
                    $script:TBCSession.Logger.Log("Commit failed with detailed error: $($_.Exception.Message)")
                    Write-Output "Status Code: $($_.Exception.Response.StatusCode)" | Out-Host
                    $script:TBCSession.Logger.Log("Status Code: $($_.Exception.Response.StatusCode)")
                    Write-Output "Status Description: $($_.Exception.Response.StatusDescription)" | Out-Host
                    $script:TBCSession.Logger.Log("Status Description: $($_.Exception.Response.StatusDescription)")
                    # Try to get response content
                    try {
                        $errorStream = $_.Exception.Response.GetResponseStream()
                        $reader = New-Object System.IO.StreamReader($errorStream)
                        $errorContent = $reader.ReadToEnd()
                        Write-Output "Error Response: $errorContent" -ForegroundColor Red | Out-Host
                        $script:TBCSession.Logger.Log("Error Response: $errorContent")
                    } catch {
                        Write-Output "Could not read error response" | Out-Host
                        $script:TBCSession.Logger.Log("Could not read error response")
                    }

                    throw
                }

                # 11. Monitor commit status
                Write-Output "`n11. Monitoring commit status..." -ForegroundColor Yellow | Out-Host
                $maxWaitTime = 120
                $waitTime = 0

                do {
                    Start-Sleep -Seconds 25
                    $waitTime += 5
                    $CommitStatus = Invoke-MgGraphRequest -Uri $storageCheckUrl -Method GET
                    Write-Output "Waiting for commit to complete... get on : $($storageCheckUrl)" -ForegroundColor Cyan | Out-Host
                    $script:TBCSession.Logger.Log("Waiting for commit to complete... Current status: $($CommitStatus.uploadState)")
                    Write-Output "Commit status: $($CommitStatus.uploadState) (waited $waitTime seconds)" | Out-Host
                    $script:TBCSession.Logger.Log("Commit status: $($CommitStatus.uploadState) (waited $waitTime seconds)")

                    if ($CommitStatus.uploadState -eq "commitFileFailed") {
                        Write-Output "COMMIT FAILED - Detailed status:" -ForegroundColor Red | Out-Host
                        $script:TBCSession.Logger.Log("COMMIT FAILED - Detailed status:")
                        Write-Output ($CommitStatus | ConvertTo-Json -Depth 5) | Out-Host
                        $script:TBCSession.Logger.Log("" + ($CommitStatus | ConvertTo-Json -Depth 5))
                        break
                    }

                } while ($CommitStatus.uploadState -notin @("commitFileSuccess", "commitFileFailed") -and $waitTime -lt $maxWaitTime)

                if ($CommitStatus.uploadState -eq "commitFileSuccess") {
                    Write-Output "SUCCESS: File committed successfully!" -ForegroundColor Green | Out-Host
                    $script:TBCSession.Logger.Log("SUCCESS: File committed successfully!")
                } else {
                    Write-Output "FAILED: Commit did not succeed within timeout" -ForegroundColor Red | Out-Host
                    $script:TBCSession.Logger.Log("FAILED: Commit did not succeed within timeout")

                }
                # Patch the app with content version
                $updateBody = @{
                    "@odata.type" = "#microsoft.graph.win32LobApp"
                    committedContentVersion = $win32LobAppVersionRequest.id
                    fileName = $DetectionXMLContent.ApplicationInfo.FileName
                } | ConvertTo-Json -Depth 10
                $updateUrl = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$($win32LobApp.id)"

                Write-Output "--Patching app with body: $updateBody" -ForegroundColor Yellow | Out-Host
                $script:TBCSession.Logger.Log("Patching app with body: $updateBody")
                try {
                    Invoke-MgGraphRequest -Method PATCH -Uri "$updateUrl" -Body $updateBody -ContentType "application/json"
                    Write-Output "Patch sent successfully" -ForegroundColor Green | Out-Host
                    $script:TBCSession.Logger.Log("Patch sent successfully.")
                    Write-Output "App uploaded to Intune successfully!" -ForegroundColor Green | Out-Host
                    $StatusBar.Text = "Package uploaded to Intune successfully"
                    $script:TBCSession.Logger.Log("Package uploaded to Intune successfully. App ID: $($win32LobApp.id)")
                } catch {
                    Write-Output "Patch failed with detailed error:" -ForegroundColor Red | Out-Host
                    Write-Output "Status Code: $($_.Exception.Response.StatusCode)" | Out-Host
                    Write-Output "Status Description: $($_.Exception.Response.StatusDescription)" | Out-Host
                }

                # Cleanup unnecessary files
                if (Test-Path $alternativeExtractPath) { Remove-Item $alternativeExtractPath -Force }
            }
        }
    } catch {
        $StatusBar.Text = "An error occurred during Intune package creation: $_"
        $script:TBCSession.Logger.Log("An error occurred during Intune package creation: $_")
    }
})

$cbWin32Package.Add_Checked({
    $tbTagFileName.IsEnabled = $true
})

$cbWin32Package.Add_Unchecked({
    $tbTagFileName.IsEnabled = $false
})

$bnApplySettings.Add_Click({
    $Form.Cursor = [System.Windows.Input.Cursors]::Wait
    $configPath = $tbINIfilepath.Text
    $key = $tbPassphraseApplyINI.Text
    $count = Get-Content $configPath | Measure-Object -Word
    if($count.Words -eq 1)
    {
        $script:TBCSession.Logger.Log("Found password change file")
        $results = Import-LnvPasswordChangeFile -ConfigFile $configPath -Key $key
        $StatusBar.Text = $results.Replace("`t","")
    }#end if
    else
    {
        $script:TBCSession.Logger.Log("Found settings change file")
        $results = Import-LnvWmiSettings -ConfigFile $configPath -K $key -Current $pbPasswordApplyINI.SecurePassword
        $results = $results -split "`n"
        if($results.Count -gt 1)
        {
            $temp = $results | Select-Object -last ($results.Count - 1)
            $results = "Please see the log for more details.`n$temp"
        }
        $StatusBar.Text = $results.Replace("`t","")

        Read-SettingList -Reload
    }#end else
    $Form.Cursor = [System.Windows.Input.Cursors]::Arrow
})#end Add_Click

#Listener for the clear supervisor password button
$bnClearSVP.Add_Click({
    if(-not (Get-LnvTBCTargetComputer).PasswordFound)
    {
        $StatusBar.Text = "No password found on the machine."
        $script:TBCSession.Logger.Log("No password found on the machine.")
        return
    }#end it
    if([string]::IsNullOrWhitespace($pbPasswordClearSVP.Password))
    {
        $StatusBar.Text = "Current password is not provided."
        $script:TBCSession.Logger.Log("Current password is not provided.")
        return
    }#end if
    $results = Update-LnvPassword -Old $pbPasswordClearSVP.SecurePassword -New $null -Ty "pap"

    $StatusBar.Text = $results | Select-Object -last 1
    $script:TBCSession.Logger.Log($results)
})#end Add_Click

#Listener for the clear fingerprint data button
$bnClearFingerprintData.Add_Click({
    if(-not (Get-LnvTBCTargetComputer).PasswordFound)
    {
        $StatusBar.Text = "No password found on the machine."
        $script:TBCSession.Logger.Log("No password found on the machine.")
        return
    }#end it
    if([string]::IsNullOrWhitespace($pbPasswordClearSVP.Password))
    {
        $StatusBar.Text = "Current password is not provided."
        $script:TBCSession.Logger.Log("Current password is not provided.")
        return
    }#end if
    $results = Submit-LnvFunctionRequest -C $pbPasswordClearSVP.SecurePassword -M "ResetFingerprintData" -V "Yes"

    $StatusBar.Text = $results | Select-Object -last 1
    $script:TBCSession.Logger.Log($results)
})#end Add_Click

#Listener or changing the password button
#TODO: Compare securestrings rather than password field
$bnChangePassword.Add_Click({
    if([string]::IsNullOrWhitespace($pbCurrentPass.Password))
    {
        $script:TBCSession.Logger.Log("Current password is blank!")
        $StatusBar.Text = "Current password is blank!"
        return
    }#end ifs
    if([string]::IsNullOrWhitespace($pbNewPass.Password))
    {
        $script:TBCSession.Logger.Log("New password is blank!")
        $StatusBar.Text = "New password is blank!"
        return
    }#end if
    if([string]::IsNullOrWhitespace($pbConfirmPass.Password))
    {
        $script:TBCSession.Logger.Log("Confirm password is blank!")
        $StatusBar.Text = "Confirm password is blank!"
        return
    }#end if
    if($pbNewPass.Password -ne $pbConfirmPass.Password)
    {
        $script:TBCSession.Logger.Log("New passwords do not match!")
        $StatusBar.Text = "New passwords do not match!"
        return
    }#end if
    $results = Update-LnvPassword -Old $pbCurrentPass.SecurePassword -New $pbConfirmPass.SecurePassword -Ty "pap"

    $StatusBar.Text = $results | Select-Object -last 1
    $script:TBCSession.Logger.Log($results)
})#end Add_Click

#Listener for the password change file
$bnPasswordChangeFile.Add_Click({
    if([string]::IsNullOrWhitespace($pbNewPass.Password))
    {
        $script:TBCSession.Logger.Log("New password is blank!")
        $StatusBar.Text = "New password is blank!"
        return
    }#end if
    if([string]::IsNullOrWhitespace($pbConfirmPass.Password))
    {
        $script:TBCSession.Logger.Log("Confirm password is blank!")
        $StatusBar.Text = "Confirm password is blank!"
        return
    }#end if
    if($pbNewPass.Password -ne $pbConfirmPass.Password)
    {
        $script:TBCSession.Logger.Log("New passwords do not match!")
        $StatusBar.Text = "New passwords do not match!"
        return
    }#end if
    <#if([string]::IsNullOrWhitespace($tbPassphraseActions.Text))
    {
        $script:TBCSession.Logger.Log("Encrypting passphrase is blank!")
        $StatusBar.Text = "Encrypting passphrase is blank!"
        return
    }#end if#>
    if([string]::IsNullOrWhitespace($pbCurrentPass.Password))
    {
        $message = "The current password is blank. Do you want to continue with a System Deployment Boot Mode file?"
        $caption = "Create System Deployment Boot Mode File"
        $button = [System.Windows.MessageBoxButton]::YesNo
        $image = [System.Windows.MessageBoxImage]::Question
        $result = [System.Windows.MessageBox]::Show($message, $caption, $button, $image)

        if($result -eq [System.Windows.MessageBoxResult]::Yes)
        {

            if(Compare-SecureString $pbConfirmPass.SecurePassword $pbNewPass.SecurePassword)
            {
                $dlgFileImport.Visibility = "Visible"
            }#end if
            else {
                $script:TBCSession.Logger.Log("New passwords are not the same!")
                $StatusBar.Text = "New passwords are not the same!"
            }
        }#end if
        else
        {
            return
        }#end else
    }#end if
    else {
        if(Compare-SecureString $pbConfirmPass.SecurePassword $pbNewPass.SecurePassword)
        {
            $dlgFileImport.Visibility = "Visible"
        }#end if
        else {
            $script:TBCSession.Logger.Log("New passwords are not the same!")
            $StatusBar.Text = "New passwords are not the same!"
        }
    }
})#end Add_Click

$bnSavePreferences.Add_Click({
    Update-LnvTBCPreferenceFile -Logging $cbLogging.IsChecked -Output $tbFolderPath.Text -LogFolder $tbLogPath.Text
    $script:TBCSession = Read-LnvTBCPreferenceFile
    $StatusBar.Text = "Preferences saved"
})#end Add_Click

#Listener for the connect to another computer button
#TODO: validate textbox
<#
$bnConnectLeft.Add_Click({
    $creds = Get-Credential
    $target = $tbHostnameLeft.Text
    Open-LnvTBCRemoteComputer -Hostname $target -Credential $creds
    $script:TBCSession.Logger.Log(("Attempting to connect to {0} using {1}" -f $target,$creds.UserName))
})#end Add_Click

#>
#Remove all additional classes used when the GUI is closed
#TODO: Close cimsession
$Form.Add_Closing({
    if(Test-LnvTBCPendingChanges)
    {
        $message = "There are pending changes. Would you like to continue exiting?"
        $caption = "Pending Changes"
        $button = [System.Windows.MessageBoxButton]::YesNo
        $image = [System.Windows.MessageBoxImage]::Question
        $result = [System.Windows.MessageBox]::Show($message, $caption, $button, $image)

        if($result -eq [System.Windows.MessageBoxResult]::Yes)
        {
            $script:TBCSession.Logger.Log("Closing ThinkBiosConfig...")

            Remove-Module $ModuleName

        }#end if
        else
        {
            $_.Cancel = $true
        }#end else
    }#end if
    else {
        Remove-Module $ModuleName
    }
})#end Add_Closing

$form.Add_Loaded( {
    $Form.Topmost = $true  # Bring the form to the top
    Start-Sleep -Milliseconds 200  # Optional: Small delay to ensure it takes effect
    $Form.Topmost = $false  # Allow other windows to come on top afterward
    # Simulate a click on the btnSettings button
    #$btnSettings.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))
    $Form.Cursor = [System.Windows.Input.Cursors]::Wait
        if(Test-LnvTBCPendingReboot)
        {
            $appTitleRebootPending.Visibility = "Visible"
        }
        $StatusBar.Text += "Gui v{0} Module v{1}" -f $guiVersion,(Get-Module $ModuleName | Sort-Object Version -Descending | Select-Object -First 1 ).Version

        #Populate the TBC module
        Read-SettingList

        #Load the preferences and fill the appropriate fields
        $script:TBCSession = Read-LnvTBCPreferenceFile
    $tbFolderPath.Text = $script:TBCSession.OutputFolder
    $cbLogging.IsChecked = $script:TBCSession.EnableLogging
    # Populate the Preferences panel log path textbox with the saved default
    $tbLogPath.Text = $script:TBCSession.LogFolder
    $script:TBCSession.Logger.Log("Loading current WMI settings")
    EnableButtons
    $Form.Cursor = [System.Windows.Input.Cursors]::Arrow
    SwitchPanels -PanelName "dpSettings" -Origin "btnSettings"
})
#endregion

$Form.ShowDialog() | out-null
# SIG # Begin signature block
# MIItugYJKoZIhvcNAQcCoIItqzCCLacCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUWowRYQcR4IGEXqbPXjz3Nc6j
# fSGggibcMIIFjTCCBHWgAwIBAgIQDpsYjvnQLefv21DiCEAYWjANBgkqhkiG9w0B
# AQwFADBlMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1cmVk
# IElEIFJvb3QgQ0EwHhcNMjIwODAxMDAwMDAwWhcNMzExMTA5MjM1OTU5WjBiMQsw
# CQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cu
# ZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQw
# ggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC/5pBzaN675F1KPDAiMGkz
# 7MKnJS7JIT3yithZwuEppz1Yq3aaza57G4QNxDAf8xukOBbrVsaXbR2rsnnyyhHS
# 5F/WBTxSD1Ifxp4VpX6+n6lXFllVcq9ok3DCsrp1mWpzMpTREEQQLt+C8weE5nQ7
# bXHiLQwb7iDVySAdYyktzuxeTsiT+CFhmzTrBcZe7FsavOvJz82sNEBfsXpm7nfI
# SKhmV1efVFiODCu3T6cw2Vbuyntd463JT17lNecxy9qTXtyOj4DatpGYQJB5w3jH
# trHEtWoYOAMQjdjUN6QuBX2I9YI+EJFwq1WCQTLX2wRzKm6RAXwhTNS8rhsDdV14
# Ztk6MUSaM0C/CNdaSaTC5qmgZ92kJ7yhTzm1EVgX9yRcRo9k98FpiHaYdj1ZXUJ2
# h4mXaXpI8OCiEhtmmnTK3kse5w5jrubU75KSOp493ADkRSWJtppEGSt+wJS00mFt
# 6zPZxd9LBADMfRyVw4/3IbKyEbe7f/LVjHAsQWCqsWMYRJUadmJ+9oCw++hkpjPR
# iQfhvbfmQ6QYuKZ3AeEPlAwhHbJUKSWJbOUOUlFHdL4mrLZBdd56rF+NP8m800ER
# ElvlEFDrMcXKchYiCd98THU/Y+whX8QgUWtvsauGi0/C1kVfnSD8oR7FwI+isX4K
# Jpn15GkvmB0t9dmpsh3lGwIDAQABo4IBOjCCATYwDwYDVR0TAQH/BAUwAwEB/zAd
# BgNVHQ4EFgQU7NfjgtJxXWRM3y5nP+e6mK4cD08wHwYDVR0jBBgwFoAUReuir/SS
# y4IxLVGLp6chnfNtyA8wDgYDVR0PAQH/BAQDAgGGMHkGCCsGAQUFBwEBBG0wazAk
# BggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAC
# hjdodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURS
# b290Q0EuY3J0MEUGA1UdHwQ+MDwwOqA4oDaGNGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0
# LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwEQYDVR0gBAowCDAGBgRV
# HSAAMA0GCSqGSIb3DQEBDAUAA4IBAQBwoL9DXFXnOF+go3QbPbYW1/e/Vwe9mqyh
# hyzshV6pGrsi+IcaaVQi7aSId229GhT0E0p6Ly23OO/0/4C5+KH38nLeJLxSA8hO
# 0Cre+i1Wz/n096wwepqLsl7Uz9FDRJtDIeuWcqFItJnLnU+nBgMTdydE1Od/6Fmo
# 8L8vC6bp8jQ87PcDx4eo0kxAGTVGamlUsLihVo7spNU96LHc/RzY9HdaXFSMb++h
# UD38dglohJ9vytsgjTVgHAIDyyCwrFigDkBjxZgiwbJZ9VVrzyerbHbObyMt9H5x
# aiNrIv8SuFQtJ37YOtnwtoeW/VvRXKwYw02fc7cBqZ9Xql4o4rmUMIIFkDCCA3ig
# AwIBAgIQBZsbV56OITLiOQe9p3d1XDANBgkqhkiG9w0BAQwFADBiMQswCQYDVQQG
# EwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNl
# cnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQwHhcNMTMw
# ODAxMTIwMDAwWhcNMzgwMTE1MTIwMDAwWjBiMQswCQYDVQQGEwJVUzEVMBMGA1UE
# ChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSEwHwYD
# VQQDExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQwggIiMA0GCSqGSIb3DQEBAQUA
# A4ICDwAwggIKAoICAQC/5pBzaN675F1KPDAiMGkz7MKnJS7JIT3yithZwuEppz1Y
# q3aaza57G4QNxDAf8xukOBbrVsaXbR2rsnnyyhHS5F/WBTxSD1Ifxp4VpX6+n6lX
# FllVcq9ok3DCsrp1mWpzMpTREEQQLt+C8weE5nQ7bXHiLQwb7iDVySAdYyktzuxe
# TsiT+CFhmzTrBcZe7FsavOvJz82sNEBfsXpm7nfISKhmV1efVFiODCu3T6cw2Vbu
# yntd463JT17lNecxy9qTXtyOj4DatpGYQJB5w3jHtrHEtWoYOAMQjdjUN6QuBX2I
# 9YI+EJFwq1WCQTLX2wRzKm6RAXwhTNS8rhsDdV14Ztk6MUSaM0C/CNdaSaTC5qmg
# Z92kJ7yhTzm1EVgX9yRcRo9k98FpiHaYdj1ZXUJ2h4mXaXpI8OCiEhtmmnTK3kse
# 5w5jrubU75KSOp493ADkRSWJtppEGSt+wJS00mFt6zPZxd9LBADMfRyVw4/3IbKy
# Ebe7f/LVjHAsQWCqsWMYRJUadmJ+9oCw++hkpjPRiQfhvbfmQ6QYuKZ3AeEPlAwh
# HbJUKSWJbOUOUlFHdL4mrLZBdd56rF+NP8m800ERElvlEFDrMcXKchYiCd98THU/
# Y+whX8QgUWtvsauGi0/C1kVfnSD8oR7FwI+isX4KJpn15GkvmB0t9dmpsh3lGwID
# AQABo0IwQDAPBgNVHRMBAf8EBTADAQH/MA4GA1UdDwEB/wQEAwIBhjAdBgNVHQ4E
# FgQU7NfjgtJxXWRM3y5nP+e6mK4cD08wDQYJKoZIhvcNAQEMBQADggIBALth2X2p
# bL4XxJEbw6GiAI3jZGgPVs93rnD5/ZpKmbnJeFwMDF/k5hQpVgs2SV1EY+CtnJYY
# ZhsjDT156W1r1lT40jzBQ0CuHVD1UvyQO7uYmWlrx8GnqGikJ9yd+SeuMIW59mdN
# Oj6PWTkiU0TryF0Dyu1Qen1iIQqAyHNm0aAFYF/opbSnr6j3bTWcfFqK1qI4mfN4
# i/RN0iAL3gTujJtHgXINwBQy7zBZLq7gcfJW5GqXb5JQbZaNaHqasjYUegbyJLkJ
# EVDXCLG4iXqEI2FCKeWjzaIgQdfRnGTZ6iahixTXTBmyUEFxPT9NcCOGDErcgdLM
# MpSEDQgJlxxPwO5rIHQw0uA5NBCFIRUBCOhVMt5xSdkoF1BN5r5N0XWs0Mr7QbhD
# parTwwVETyw2m+L64kW4I1NsBm9nVX9GtUw/bihaeSbSpKhil9Ie4u1Ki7wb/UdK
# Dd9nZn6yW0HQO+T0O/QEY+nvwlQAUaCKKsnOeMzV6ocEGLPOr0mIr/OSmbaz5mEP
# 0oUA51Aa5BuVnRmhuZyxm7EAHu/QD09CbMkKvO5D+jpxpchNJqU1/YldvIViHTLS
# oCtU7ZpXwdv6EM8Zt4tKG48BtieVU+i2iW1bvGjUI+iLUaJW+fCmgKDWHrO8Dw9T
# dSmq6hN35N6MgSGtBxBHEa2HPQfRdbzP82Z+MIIGsDCCBJigAwIBAgIQCK1AsmDS
# nEyfXs2pvZOu2TANBgkqhkiG9w0BAQwFADBiMQswCQYDVQQGEwJVUzEVMBMGA1UE
# ChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSEwHwYD
# VQQDExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQwHhcNMjEwNDI5MDAwMDAwWhcN
# MzYwNDI4MjM1OTU5WjBpMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQs
# IEluYy4xQTA/BgNVBAMTOERpZ2lDZXJ0IFRydXN0ZWQgRzQgQ29kZSBTaWduaW5n
# IFJTQTQwOTYgU0hBMzg0IDIwMjEgQ0ExMIICIjANBgkqhkiG9w0BAQEFAAOCAg8A
# MIICCgKCAgEA1bQvQtAorXi3XdU5WRuxiEL1M4zrPYGXcMW7xIUmMJ+kjmjYXPXr
# NCQH4UtP03hD9BfXHtr50tVnGlJPDqFX/IiZwZHMgQM+TXAkZLON4gh9NH1MgFcS
# a0OamfLFOx/y78tHWhOmTLMBICXzENOLsvsI8IrgnQnAZaf6mIBJNYc9URnokCF4
# RS6hnyzhGMIazMXuk0lwQjKP+8bqHPNlaJGiTUyCEUhSaN4QvRRXXegYE2XFf7JP
# hSxIpFaENdb5LpyqABXRN/4aBpTCfMjqGzLmysL0p6MDDnSlrzm2q2AS4+jWufcx
# 4dyt5Big2MEjR0ezoQ9uo6ttmAaDG7dqZy3SvUQakhCBj7A7CdfHmzJawv9qYFSL
# ScGT7eG0XOBv6yb5jNWy+TgQ5urOkfW+0/tvk2E0XLyTRSiDNipmKF+wc86LJiUG
# soPUXPYVGUztYuBeM/Lo6OwKp7ADK5GyNnm+960IHnWmZcy740hQ83eRGv7bUKJG
# yGFYmPV8AhY8gyitOYbs1LcNU9D4R+Z1MI3sMJN2FKZbS110YU0/EpF23r9Yy3IQ
# KUHw1cVtJnZoEUETWJrcJisB9IlNWdt4z4FKPkBHX8mBUHOFECMhWWCKZFTBzCEa
# 6DgZfGYczXg4RTCZT/9jT0y7qg0IU0F8WD1Hs/q27IwyCQLMbDwMVhECAwEAAaOC
# AVkwggFVMBIGA1UdEwEB/wQIMAYBAf8CAQAwHQYDVR0OBBYEFGg34Ou2O/hfEYb7
# /mF7CIhl9E5CMB8GA1UdIwQYMBaAFOzX44LScV1kTN8uZz/nupiuHA9PMA4GA1Ud
# DwEB/wQEAwIBhjATBgNVHSUEDDAKBggrBgEFBQcDAzB3BggrBgEFBQcBAQRrMGkw
# JAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBBBggrBgEFBQcw
# AoY1aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZFJv
# b3RHNC5jcnQwQwYDVR0fBDwwOjA4oDagNIYyaHR0cDovL2NybDMuZGlnaWNlcnQu
# Y29tL0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5jcmwwHAYDVR0gBBUwEzAHBgVngQwB
# AzAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIBADojRD2NCHbuj7w6mdNW4AIa
# pfhINPMstuZ0ZveUcrEAyq9sMCcTEp6QRJ9L/Z6jfCbVN7w6XUhtldU/SfQnuxaB
# RVD9nL22heB2fjdxyyL3WqqQz/WTauPrINHVUHmImoqKwba9oUgYftzYgBoRGRjN
# YZmBVvbJ43bnxOQbX0P4PpT/djk9ntSZz0rdKOtfJqGVWEjVGv7XJz/9kNF2ht0c
# sGBc8w2o7uCJob054ThO2m67Np375SFTWsPK6Wrxoj7bQ7gzyE84FJKZ9d3OVG3Z
# XQIUH0AzfAPilbLCIXVzUstG2MQ0HKKlS43Nb3Y3LIU/Gs4m6Ri+kAewQ3+ViCCC
# cPDMyu/9KTVcH4k4Vfc3iosJocsL6TEa/y4ZXDlx4b6cpwoG1iZnt5LmTl/eeqxJ
# zy6kdJKt2zyknIYf48FWGysj/4+16oh7cGvmoLr9Oj9FpsToFpFSi0HASIRLlk2r
# REDjjfAVKM7t8RhWByovEMQMCGQ8M4+uKIw8y4+ICw2/O/TOHnuO77Xry7fwdxPm
# 5yg/rBKupS8ibEH5glwVZsxsDsrFhsP2JjMMB0ug0wcCampAMEhLNKhRILutG4UI
# 4lkNbcoFUCvqShyepf2gpx8GdOfy1lKQ/a+FSCH5Vzu0nAPthkX0tGFuv2jiJmCG
# 6sivqf6UHedjGzqGVnhOMIIGtDCCBJygAwIBAgIQDcesVwX/IZkuQEMiDDpJhjAN
# BgkqhkiG9w0BAQsFADBiMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQg
# SW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2Vy
# dCBUcnVzdGVkIFJvb3QgRzQwHhcNMjUwNTA3MDAwMDAwWhcNMzgwMTE0MjM1OTU5
# WjBpMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/BgNV
# BAMTOERpZ2lDZXJ0IFRydXN0ZWQgRzQgVGltZVN0YW1waW5nIFJTQTQwOTYgU0hB
# MjU2IDIwMjUgQ0ExMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAtHgx
# 0wqYQXK+PEbAHKx126NGaHS0URedTa2NDZS1mZaDLFTtQ2oRjzUXMmxCqvkbsDpz
# 4aH+qbxeLho8I6jY3xL1IusLopuW2qftJYJaDNs1+JH7Z+QdSKWM06qchUP+AbdJ
# gMQB3h2DZ0Mal5kYp77jYMVQXSZH++0trj6Ao+xh/AS7sQRuQL37QXbDhAktVJMQ
# bzIBHYJBYgzWIjk8eDrYhXDEpKk7RdoX0M980EpLtlrNyHw0Xm+nt5pnYJU3Gmq6
# bNMI1I7Gb5IBZK4ivbVCiZv7PNBYqHEpNVWC2ZQ8BbfnFRQVESYOszFI2Wv82wnJ
# RfN20VRS3hpLgIR4hjzL0hpoYGk81coWJ+KdPvMvaB0WkE/2qHxJ0ucS638ZxqU1
# 4lDnki7CcoKCz6eum5A19WZQHkqUJfdkDjHkccpL6uoG8pbF0LJAQQZxst7VvwDD
# jAmSFTUms+wV/FbWBqi7fTJnjq3hj0XbQcd8hjj/q8d6ylgxCZSKi17yVp2NL+cn
# T6Toy+rN+nM8M7LnLqCrO2JP3oW//1sfuZDKiDEb1AQ8es9Xr/u6bDTnYCTKIsDq
# 1BtmXUqEG1NqzJKS4kOmxkYp2WyODi7vQTCBZtVFJfVZ3j7OgWmnhFr4yUozZtqg
# PrHRVHhGNKlYzyjlroPxul+bgIspzOwbtmsgY1MCAwEAAaOCAV0wggFZMBIGA1Ud
# EwEB/wQIMAYBAf8CAQAwHQYDVR0OBBYEFO9vU0rp5AZ8esrikFb2L9RJ7MtOMB8G
# A1UdIwQYMBaAFOzX44LScV1kTN8uZz/nupiuHA9PMA4GA1UdDwEB/wQEAwIBhjAT
# BgNVHSUEDDAKBggrBgEFBQcDCDB3BggrBgEFBQcBAQRrMGkwJAYIKwYBBQUHMAGG
# GGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBBBggrBgEFBQcwAoY1aHR0cDovL2Nh
# Y2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5jcnQwQwYD
# VR0fBDwwOjA4oDagNIYyaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0
# VHJ1c3RlZFJvb3RHNC5jcmwwIAYDVR0gBBkwFzAIBgZngQwBBAIwCwYJYIZIAYb9
# bAcBMA0GCSqGSIb3DQEBCwUAA4ICAQAXzvsWgBz+Bz0RdnEwvb4LyLU0pn/N0IfF
# iBowf0/Dm1wGc/Do7oVMY2mhXZXjDNJQa8j00DNqhCT3t+s8G0iP5kvN2n7Jd2E4
# /iEIUBO41P5F448rSYJ59Ib61eoalhnd6ywFLerycvZTAz40y8S4F3/a+Z1jEMK/
# DMm/axFSgoR8n6c3nuZB9BfBwAQYK9FHaoq2e26MHvVY9gCDA/JYsq7pGdogP8HR
# trYfctSLANEBfHU16r3J05qX3kId+ZOczgj5kjatVB+NdADVZKON/gnZruMvNYY2
# o1f4MXRJDMdTSlOLh0HCn2cQLwQCqjFbqrXuvTPSegOOzr4EWj7PtspIHBldNE2K
# 9i697cvaiIo2p61Ed2p8xMJb82Yosn0z4y25xUbI7GIN/TpVfHIqQ6Ku/qjTY6hc
# 3hsXMrS+U0yy+GWqAXam4ToWd2UQ1KYT70kZjE4YtL8Pbzg0c1ugMZyZZd/BdHLi
# Ru7hAWE6bTEm4XYRkA6Tl4KSFLFk43esaUeqGkH/wyW4N7OigizwJWeukcyIPbAv
# jSabnf7+Pu0VrFgoiovRDiyx3zEdmcif/sYQsfch28bZeUz2rtY/9TCA6TD8dC3J
# E3rYkrhLULy7Dc90G6e8BlqmyIjlgp2+VqsS9/wQD7yFylIz0scmbKvFoW2jNrbM
# 1pD2T7m3XDCCBu0wggTVoAMCAQICEAqA7xhLjfEFgtHEdqeVdGgwDQYJKoZIhvcN
# AQELBQAwaTELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMUEw
# PwYDVQQDEzhEaWdpQ2VydCBUcnVzdGVkIEc0IFRpbWVTdGFtcGluZyBSU0E0MDk2
# IFNIQTI1NiAyMDI1IENBMTAeFw0yNTA2MDQwMDAwMDBaFw0zNjA5MDMyMzU5NTla
# MGMxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkGA1UE
# AxMyRGlnaUNlcnQgU0hBMjU2IFJTQTQwOTYgVGltZXN0YW1wIFJlc3BvbmRlciAy
# MDI1IDEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDQRqwtEsae0Oqu
# YFazK1e6b1H/hnAKAd/KN8wZQjBjMqiZ3xTWcfsLwOvRxUwXcGx8AUjni6bz52fG
# Tfr6PHRNv6T7zsf1Y/E3IU8kgNkeECqVQ+3bzWYesFtkepErvUSbf+EIYLkrLKd6
# qJnuzK8Vcn0DvbDMemQFoxQ2Dsw4vEjoT1FpS54dNApZfKY61HAldytxNM89PZXU
# P/5wWWURK+IfxiOg8W9lKMqzdIo7VA1R0V3Zp3DjjANwqAf4lEkTlCDQ0/fKJLKL
# kzGBTpx6EYevvOi7XOc4zyh1uSqgr6UnbksIcFJqLbkIXIPbcNmA98Oskkkrvt6l
# PAw/p4oDSRZreiwB7x9ykrjS6GS3NR39iTTFS+ENTqW8m6THuOmHHjQNC3zbJ6nJ
# 6SXiLSvw4Smz8U07hqF+8CTXaETkVWz0dVVZw7knh1WZXOLHgDvundrAtuvz0D3T
# +dYaNcwafsVCGZKUhQPL1naFKBy1p6llN3QgshRta6Eq4B40h5avMcpi54wm0i2e
# PZD5pPIssoszQyF4//3DoK2O65Uck5Wggn8O2klETsJ7u8xEehGifgJYi+6I03Uu
# T1j7FnrqVrOzaQoVJOeeStPeldYRNMmSF3voIgMFtNGh86w3ISHNm0IaadCKCkUe
# 2LnwJKa8TIlwCUNVwppwn4D3/Pt5pwIDAQABo4IBlTCCAZEwDAYDVR0TAQH/BAIw
# ADAdBgNVHQ4EFgQU5Dv88jHt/f3X85FxYxlQQ89hjOgwHwYDVR0jBBgwFoAU729T
# SunkBnx6yuKQVvYv1Ensy04wDgYDVR0PAQH/BAQDAgeAMBYGA1UdJQEB/wQMMAoG
# CCsGAQUFBwMIMIGVBggrBgEFBQcBAQSBiDCBhTAkBggrBgEFBQcwAYYYaHR0cDov
# L29jc3AuZGlnaWNlcnQuY29tMF0GCCsGAQUFBzAChlFodHRwOi8vY2FjZXJ0cy5k
# aWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkRzRUaW1lU3RhbXBpbmdSU0E0MDk2
# U0hBMjU2MjAyNUNBMS5jcnQwXwYDVR0fBFgwVjBUoFKgUIZOaHR0cDovL2NybDMu
# ZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0VGltZVN0YW1waW5nUlNBNDA5
# NlNIQTI1NjIwMjVDQTEuY3JsMCAGA1UdIAQZMBcwCAYGZ4EMAQQCMAsGCWCGSAGG
# /WwHATANBgkqhkiG9w0BAQsFAAOCAgEAZSqt8RwnBLmuYEHs0QhEnmNAciH45PYi
# T9s1i6UKtW+FERp8FgXRGQ/YAavXzWjZhY+hIfP2JkQ38U+wtJPBVBajYfrbIYG+
# Dui4I4PCvHpQuPqFgqp1PzC/ZRX4pvP/ciZmUnthfAEP1HShTrY+2DE5qjzvZs7J
# IIgt0GCFD9ktx0LxxtRQ7vllKluHWiKk6FxRPyUPxAAYH2Vy1lNM4kzekd8oEARz
# FAWgeW3az2xejEWLNN4eKGxDJ8WDl/FQUSntbjZ80FU3i54tpx5F/0Kr15zW/mJA
# xZMVBrTE2oi0fcI8VMbtoRAmaaslNXdCG1+lqvP4FbrQ6IwSBXkZagHLhFU9HCrG
# /syTRLLhAezu/3Lr00GrJzPQFnCEH1Y58678IgmfORBPC1JKkYaEt2OdDh4GmO0/
# 5cHelAK2/gTlQJINqDr6JfwyYHXSd+V08X1JUPvB4ILfJdmL+66Gp3CSBXG6IwXM
# ZUXBhtCyIaehr0XkBoDIGMUG1dUtwq1qmcwbdUfcSYCn+OwncVUXf53VJUNOaMWM
# ts0VlRYxe5nK+At+DI96HAlXHAL5SlfYxJ7La54i71McVWRP66bW+yERNpbJCjyC
# YG2j+bdpxo/1Cy4uPcU3AWVPGrbn5PhDBf3Froguzzhk++ami+r3Qrx5bIbY3TVz
# giFI7Gq3zWcwggdWMIIFPqADAgECAhADMlFYfN/evhzf5XYSzZUnMA0GCSqGSIb3
# DQEBCwUAMGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjFB
# MD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBDb2RlIFNpZ25pbmcgUlNBNDA5
# NiBTSEEzODQgMjAyMSBDQTEwHhcNMjUwMzIwMDAwMDAwWhcNMjYwNjAzMjM1OTU5
# WjBeMQswCQYDVQQGEwJVUzEXMBUGA1UECBMOTm9ydGggQ2Fyb2xpbmExFDASBgNV
# BAcTC01vcnJpc3ZpbGxlMQ8wDQYDVQQKEwZMZW5vdm8xDzANBgNVBAMTBkxlbm92
# bzCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAOPjJ/+Kdi4SqmdpYRYm
# 5E/ctl9H/KHwC3GK10hQmHGetCCuJkcx+STyvxLIuuzh6CIupbxzDPXQ2x2/5jA6
# 2EROThgMKl/0fV+hwvZhVl45idBUi0qo+91jYeK9kXjjLrxXEsX6A5Uu4Lgl56vr
# 8h6cGZg/te9ozF3k2JN80MIzSj/F769/ZpuGq9i4j1HQ7xq/aoXFlrTD86zSC7YG
# AVU5PSU06ZOOTMAAvGm7ifKv/xQyeO8EE4acIgFB5a8RRC0JQj19eIRBhtfkh1dy
# TX/ocPdsBQICpqo0VXvRb/9iaHj3+r9CWSPtx0kQxRkpHMv/qCtM7kBscljbejLA
# VOXuhWKmNemNGIu7UMIZyro3+XzI4s1biJlGp6bTShs02EbmzlyUJTgithsYgC5n
# X/WRcaHbshvy5S1EJo8m1fi5v/4bj9OTBUOjaYAVKvOjzYE7QR4PhuN/ww8HpGdR
# jLS/eS8Sz3Jxz7EVApPNSzwycDkxAR6Y0w4ymaGy3ZnTOUJjESfwqJvqigjYMcbZ
# +LJOqbLE6bQEmQ+tZiclcdoU4FhleAqQlfksb9kLc5GcU23uIp1aKQ1nji6pxMif
# IHtE5OcMgJzy60tyX/dPpxBGbR3l6+K02v5KI1/GtrVSWxvJHKlXnIMQ4EcgIZBz
# U+NPRgmPG7ZSzYRhpZl/+PrhAgMBAAGjggIDMIIB/zAfBgNVHSMEGDAWgBRoN+Dr
# tjv4XxGG+/5hewiIZfROQjAdBgNVHQ4EFgQUcBJh2GrEdlUHxwi/fkRtYI55VfAw
# PgYDVR0gBDcwNTAzBgZngQwBBAEwKTAnBggrBgEFBQcCARYbaHR0cDovL3d3dy5k
# aWdpY2VydC5jb20vQ1BTMA4GA1UdDwEB/wQEAwIHgDATBgNVHSUEDDAKBggrBgEF
# BQcDAzCBtQYDVR0fBIGtMIGqMFOgUaBPhk1odHRwOi8vY3JsMy5kaWdpY2VydC5j
# b20vRGlnaUNlcnRUcnVzdGVkRzRDb2RlU2lnbmluZ1JTQTQwOTZTSEEzODQyMDIx
# Q0ExLmNybDBToFGgT4ZNaHR0cDovL2NybDQuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0
# VHJ1c3RlZEc0Q29kZVNpZ25pbmdSU0E0MDk2U0hBMzg0MjAyMUNBMS5jcmwwgZQG
# CCsGAQUFBwEBBIGHMIGEMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2Vy
# dC5jb20wXAYIKwYBBQUHMAKGUGh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9E
# aWdpQ2VydFRydXN0ZWRHNENvZGVTaWduaW5nUlNBNDA5NlNIQTM4NDIwMjFDQTEu
# Y3J0MAkGA1UdEwQCMAAwDQYJKoZIhvcNAQELBQADggIBACeB1ob7bkUKbCC40mTr
# HpXQHQbaeE7ymacNpXKyHefcQij+Op9DsduyOHNLbEojHm24k8GiGjx3ZnaZGKTh
# RQHiijGN+H8Qy27SDvw2MzLnyB7XNg+uCPqIf6xWLdtdQ65T7MaBon6BIX/shzxQ
# t+Jpkr1+qcAP6wWCQ0Q0W5I0w5PKb19dMaT26mw6mnGd06pnTvgpCVRnVy8UJtb7
# Ltt7dfE1G0Cz3LdWW9iBVCI73n/DGWhO8fbiK4D4NpdiNnWVfsxhJ7DSb+6RKJXP
# eG3GwGbmuyDD3D2N9mJnW/6VYAiBwnewGRqwA6D20QKPB0QFHlqVHwkyoYIynVcE
# dfM4K3dtxP8mh6IrEEbWfctNLRgnvRsEE/GnAEmpHxLyzWRx+FILzlaZmRPSyYAO
# O8bE4nWNOTKLdpa/OMum6r/qDJmjcLs80aqMlRiG1k4F2grobscDV+lzy65du9+W
# a8qUeY6rZsnHK02DGOf4iWLqEgaUf36QH10MUpGgj/dkK5cwLCpA1+/d+mySgEF3
# 1N2RHkf5bRVq0DsR8AGT76npVtpyRdnIlIHksfB0G8dDjioKEzCneATEUkketoL1
# ML+ZOcM8t2uURmjK8ZecklHZF74jmrkYVyve2HrxcHOr2qPuwOkRQ5NLnYluYKQo
# Qv4KrbHKxS/bQKd55kJZVzTbMYIGSDCCBkQCAQEwfTBpMQswCQYDVQQGEwJVUzEX
# MBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/BgNVBAMTOERpZ2lDZXJ0IFRydXN0
# ZWQgRzQgQ29kZSBTaWduaW5nIFJTQTQwOTYgU0hBMzg0IDIwMjEgQ0ExAhADMlFY
# fN/evhzf5XYSzZUnMAkGBSsOAwIaBQCgeDAYBgorBgEEAYI3AgEMMQowCKACgACh
# AoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAM
# BgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBQfE+/Qsd6U6lVNNzBOHN/2lq1h
# eTANBgkqhkiG9w0BAQEFAASCAgDIslV3VKWsmGy7n1W+VPdROfteY04iCHGvC7eI
# IpW34pB5yIooEi97W9qU7Nra7g3G7yMudkSjMe7s3PrIIqWzgQbC1/pSdoSbup8C
# zvlPRW5AgAkP+4XyuFcL2TMbJtByacdFRFuxXVk1+uOoJfUZ7NqVbKIJRTt0Bo8j
# w99qeZybGmmTwUAu6fgBEHlICZ6/bKIvPguohE8XHxYVQUEGWZUacj5pMOFIUgDx
# 3O2KD10pkfLt2a6p+ZF0HbJcIFIJZHtefKbUbT3SJ7scfxym3SGhdquce+1HVlQ4
# Munhbta0OF0iiVw8MVN8rVwcR+O+BGCkIPgHEEfS9OXV4pusyeV0lSspNHakW0Hv
# cB8RBAMYb7/kU0WAPFG/bQkNYNZnEBbcTJawDCY6Q96Q2+kJB+6vQQCKxlvmBaXG
# czAKk30h5TmNqAqTj4NH6JNvox5AqiqcA9yeJFG9Y8tYOLmY7g0DcrU18arZOCCs
# sUORA/VwFZpaA66m3Hvi3YuwRU80fQnu99UuwryI64WpECKP3AB4tVq8h0bvJFV4
# X9dnNLu3YSsvqRwzZOVBM3fzseFKbbKbTeQlveL6IVZTYxXQMnNzajSPG9o83YG9
# 1EvM+00eiTLKG69JBVzawiE8n6HmoRuwdXT4GYZqejta+T31v2DesfAwTqxMdLj9
# KB+vTaGCAyYwggMiBgkqhkiG9w0BCQYxggMTMIIDDwIBATB9MGkxCzAJBgNVBAYT
# AlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQg
# VHJ1c3RlZCBHNCBUaW1lU3RhbXBpbmcgUlNBNDA5NiBTSEEyNTYgMjAyNSBDQTEC
# EAqA7xhLjfEFgtHEdqeVdGgwDQYJYIZIAWUDBAIBBQCgaTAYBgkqhkiG9w0BCQMx
# CwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0yNjA0MDcxNjA2NDhaMC8GCSqG
# SIb3DQEJBDEiBCCQe+msuneAtawJw0cngVVJBWbyKXNdOq42f+PocqwWTTANBgkq
# hkiG9w0BAQEFAASCAgB9+YD5p8/lLfgFDJIxE6sqGdNEucoQxs6Sa6XA5se1AyN1
# RrYkk2x2pZPgPPNMNWC7cvdHXNDuAqusSZoVG8OBV7SW4UhiL6m0QWVO54ij2mmC
# ZPI6rWrGNy49AlLPak/bT6eB0XRvKQOSbXViQNNFgB9mYGrERUDxtr1VECO4mKhR
# 1wG661ZTKszK/aerl+/uMSrlG3tgCe+JbPTS+OM5x1LGszerYyfzAjdjJzUZFoyU
# OmLx2XYyl+b4xauYvY5BLxJE2AEilYywekLyacnRvW2QYgeMDt9lijvtLf8RQkCL
# r6SDOTGIFYPieYSWcAx1u2vADGKVR2G+zyUt30L0xcfEnNSEm3KLr7X/IgvXwZfd
# Cb1w6qw07aXq81Mvfj5+BJiPTv0PoNE9W631Ur51DzxfjqcvrjGbcboOseivHOhc
# 8D+Oj8cv2P6pIfIl+c5CzwSkLxe5sOW+lFdxn201TNgRGie53Dw7s/jWgGAPR0sC
# WR2x0hEhxf6ZmY8YAczyFOelI1dBOdTLrV/Ebn1o5wYXS1ifJ3jUZasdPjnGW/uF
# m0uP4QbJsCp4ZiRV7CJoSpQeg9zIKaE0GQGIYzNM/qIUchZr9gMOGOdIJKjeinsp
# 1P9NsgNERGq24dE55nA4k6p7iXXxobktqxBw8NyVg/kFpNUrJhSIuBGEJWBq6g==
# SIG # End signature block

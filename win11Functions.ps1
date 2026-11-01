#!/usr/bin/env pwsh

# ---------------------------------------------------------------
# File:     win11Functions.ps1
# Purpose:  PowerShell functions for Windows 11 setup, debloating, and maintenance tasks
# Project:  Windows 11 Setup Script
# Author:   sgt7 LLC
# ---------------------------------------------------------------

# ============================================================================================
# INSTALLATION FUNCTIONS (Menu options 1-10)
# ============================================================================================

# 1. Rename Windows PC
function Rename-WindowsPC {
    param(
        [switch]$AutoConfirm
    )

    Write-Host "Current computer name: $env:COMPUTERNAME"
    Write-Host
    if (-not $AutoConfirm) {
        $confirm = Read-Host "Are you sure you want to rename this PC? (This may not be appropriate for work-managed computers) [y/N]"
        if ($confirm -notin @('y', 'Y', 'yes', 'Yes')) {
            Write-Host "Rename cancelled."
            return
        }
    }

    $newComputerName = Read-Host "Enter the new computer name"
    Rename-Computer -NewName $newComputerName -Force
    Write-Host "Computer renamed successfully to $newComputerName. You will need to restart for the change to take effect."
}

# 2. Install winget (Windows Package Manager)
function Install-Winget {
    Write-Host "Checking for and installing Windows Package Manager (winget)..."

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "winget is already installed."
        return
    }

    Write-Host "winget not found. Installing Windows Package Manager..."

    # Install App Installer from Microsoft Store (which includes winget)
    try {
        "Y" | & winget install Microsoft.DesktopAppInstaller --no-upgrade --accept-source-agreements
        Write-Host "Windows Package Manager installed successfully!"
    } catch {
        Write-Error "Failed to install Windows Package Manager. You may need to install it manually from the Microsoft Store."
        exit
    }
}

# 3. Update and patch Windows
function Update-Patch-Windows {
    Write-Host "Updating and patching Windows..."
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Install-Module -Name PSWindowsUpdate -Force
    Import-Module PSWindowsUpdate
    Add-WUServiceManager -MicrosoftUpdate
    Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -IgnoreReboot | Out-File "C:\$($env:COMPUTERNAME)_$(Get-Date -f yyyy-MM-dd)_MSUpdates.log" -Force
    Write-Host "Windows patched successfully! Rebooting was suppressed, but you should probably reboot..."
}

# 4. Install winget packages
function Install-WingetPackages {
    param(
        [string]$ScriptDir
    )

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Error "winget is not installed. Please install Windows Package Manager."
        exit
    }

    Write-Host "Installing winget packages..."
    $PackagesInstallFilePath = Join-Path $ScriptDir "winget_install.txt"

    if (-not (Test-Path $PackagesInstallFilePath)) {
        Write-Error "Warning: winget_install.txt not found!"
        exit
    }

    $LogDir = Join-Path $ScriptDir 'logs'
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
    $LogFile = Join-Path $LogDir 'winget_install.log'

    $InstallPackages = Get-Content -Path $PackagesInstallFilePath

    foreach ($Package in $InstallPackages) {
        $Package = $Package.Trim()
        if ([string]::IsNullOrWhiteSpace($Package) -or $Package.StartsWith('#')) {
            continue
        }

        Write-Host "Checking $Package..."
        $installedCheck = & winget list "$Package" --no-upgrade 2>&1 | Where-Object { $_ -match [regex]::Escape($Package) }
        if ($installedCheck) {
            Write-Host "Skipping $Package (already installed)"
            Add-Content -Path $LogFile -Value "$(Get-Date -Format o) SKIP: $Package - already installed"
            continue
        }

        Write-Host "Installing $Package..."
        try {
            # Pipe "Y" to accept license agreements
            $output = "Y" | & winget install $Package -e --no-upgrade --accept-source-agreements 2>&1
            # Check output for success instead of exit code (exit code is unreliable with piped input)
            if ($output -match "Successfully installed") {
                Write-Host "Successfully installed $Package"
                Add-Content -Path $LogFile -Value "$(Get-Date -Format o) INSTALLED: $Package"
            } elseif ($output -match "already installed") {
                Write-Host "Package $Package already installed"
                Add-Content -Path $LogFile -Value "$(Get-Date -Format o) SKIP: $Package - already installed"
            } else {
                Write-Host "Failed to install $Package"
                Add-Content -Path $LogFile -Value "$(Get-Date -Format o) FAILED: $Package - $output"
            }
        } catch {
            Write-Host ("Exception installing {0}: {1}" -f $Package, $_)
            Add-Content -Path $LogFile -Value ('{0} EXCEPTION: {1} - {2}' -f (Get-Date -Format o), $Package, $_)
        }
    }
    Write-Host "Packages processing completed. See $LogFile for details."
}

# 5. Uninstall winget packages
function Uninstall-WingetPackages {
    param(
        [string]$ScriptDir
    )

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Error "winget is not installed. Please install Windows Package Manager."
        exit
    }

    Write-Host "Uninstalling winget packages..."
    $PackagesUninstallFilePath = Join-Path $ScriptDir "winget_uninstall.txt"

    if (-not (Test-Path $PackagesUninstallFilePath)) {
        Write-Error "Warning: winget_uninstall.txt not found!"
        exit
    }

    $LogDir = Join-Path $ScriptDir 'logs'
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
    $LogFile = Join-Path $LogDir 'winget_uninstall.log'

    $UninstallPackages = Get-Content -Path $PackagesUninstallFilePath

    foreach ($Package in $UninstallPackages) {
        $Package = $Package.Trim()
        if ([string]::IsNullOrWhiteSpace($Package) -or $Package.StartsWith('#')) {
            continue
        }

        Write-Host "Uninstalling $Package..."
        try {
            # Pipe "Y" to accept license agreements
            $output = "Y" | & winget uninstall $Package -e --accept-source-agreements 2>&1
            # Check output for success instead of exit code (exit code is unreliable with piped input)
            if ($output -match "Successfully uninstalled") {
                Write-Host "Successfully uninstalled $Package"
                Add-Content -Path $LogFile -Value "$(Get-Date -Format o) UNINSTALLED: $Package"
            } elseif ($output -match "not installed|No matching package could be found") {
                Write-Host "Package $Package not installed"
                Add-Content -Path $LogFile -Value "$(Get-Date -Format o) SKIP: $Package - not installed"
            } else {
                Write-Host "Failed to uninstall $Package"
                Add-Content -Path $LogFile -Value "$(Get-Date -Format o) FAILED: $Package - $output"
            }
        } catch {
            Write-Host ("Exception uninstalling {0}: {1}" -f $Package, $_)
            Add-Content -Path $LogFile -Value ('{0} EXCEPTION: {1} - {2}' -f (Get-Date -Format o), $Package, $_)
        }
    }
    Write-Host "Packages processing completed. See $LogFile for details."
}

# 6. Install Google Chrome
function Install-Chrome {
    Write-Host "Installing Google Chrome..."
    $ChromePath = $env:TEMP
    $ChromeInstaller = "chrome_installer.exe"
    Invoke-WebRequest "http://dl.google.com/chrome/chrome_installer.exe" -OutFile "$ChromePath\$ChromeInstaller"
    Start-Process -FilePath "$ChromePath\$ChromeInstaller" -Args "/silent /install" -Verb RunAs -Wait
    Remove-Item "$ChromePath\$ChromeInstaller"
    Write-Host "Google Chrome installed successfully!"
}

# 8. Install Windows Terminal, Oh My Posh, and configure settings
function Install-OhMyPosh {
    param(
        [string]$ScriptDir
    )

    Write-Host "Installing Windows Terminal and Oh My Posh..."

    # Install Windows Terminal
    "Y" | & winget install Microsoft.WindowsTerminal -e --no-upgrade --accept-source-agreements

    # Install Oh My Posh via winget
    "Y" | & winget install JanDeDobbeleer.OhMyPosh -e --no-upgrade --accept-source-agreements

    # Oh My Posh v29+ requires PSReadLine 2.1+ for its init script.
    # Windows PowerShell 5.1 ships with PSReadLine 2.0 which is incompatible.
    Write-Host "Updating PSReadLine module..."
    Install-Module -Name PSReadLine -Scope CurrentUser -Force -SkipPublisherCheck

    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

    # Ensure Fira Code Nerd Font is actually registered with Windows before Windows Terminal
    # settings (which reference it by name) get applied - otherwise Terminal fails to launch
    # with "Unable to find the following fonts". A prior run of Install-Fonts (option 7) may
    # cover this already, but don't assume it - check and self-install if needed.
    if (-not (Test-FontInstalled -FontFamilyName "FiraCode Nerd Font")) {
        Write-Host "FiraCode Nerd Font not found. Installing it now..."

        try {
            & oh-my-posh font install FiraCode
        } catch {
            Write-Host "oh-my-posh font install failed or is unavailable: $_"
        }

        if (-not (Test-FontInstalled -FontFamilyName "FiraCode Nerd Font")) {
            # Fall back to the copy bundled in this repo (no internet required)
            Write-Host "Falling back to the bundled FiraCode Nerd Font files..."
            $BundledFontsDir = Join-Path $ScriptDir "fonts\FiraCode"
            if (Test-Path $BundledFontsDir) {
                Get-ChildItem -Path $BundledFontsDir -Include "*.ttf", "*.otf" -Recurse | ForEach-Object {
                    Install-SystemFont -FontFilePath $_.FullName | Out-Null
                }
            } else {
                Write-Host "Warning: no bundled fonts found at $BundledFontsDir either. Run 'Install Fonts' (option 7) first, or Windows Terminal will fail to find FiraCode Nerd Font."
            }
        }

        if (Test-FontInstalled -FontFamilyName "FiraCode Nerd Font") {
            Write-Host "FiraCode Nerd Font installed successfully."
        }
    }

    # Copy the bundled theme to a stable user-local directory
    $OmpTheme = "catppuccin_macchiato"
    $SourceTheme = Join-Path $ScriptDir "configs\OhMyPosh\$OmpTheme.omp.json"
    $UserThemeDir = Join-Path $env:USERPROFILE ".oh-my-posh\themes"
    $UserThemePath = Join-Path $UserThemeDir "$OmpTheme.omp.json"

    if (-not (Test-Path $UserThemeDir)) {
        New-Item -Path $UserThemeDir -ItemType Directory -Force | Out-Null
    }

    if (Test-Path $SourceTheme) {
        Copy-Item -Path $SourceTheme -Destination $UserThemePath -Force
        Write-Host "Theme copied to $UserThemePath."
    } else {
        # Fall back to the theme bundled with the Oh My Posh package
        $OmpPackage = Get-AppxPackage -Name '*ohmyposh*' -ErrorAction SilentlyContinue
        if ($OmpPackage) {
            $PackageTheme = Join-Path $OmpPackage.InstallLocation "themes\$OmpTheme.omp.json"
            if (Test-Path $PackageTheme) {
                Copy-Item -Path $PackageTheme -Destination $UserThemePath -Force
                Write-Host "Theme copied from package to $UserThemePath."
            }
        }
    }

    if (-not (Test-Path $UserThemePath)) {
        Write-Host "Warning: Could not find $OmpTheme theme. Oh My Posh will use default theme."
        $OmpInitLine = "oh-my-posh init pwsh | Invoke-Expression"
    } else {
        $OmpInitLine = "oh-my-posh init pwsh --config `"$UserThemePath`" | Invoke-Expression"
    }

    # Build the full initialization block including mise
    $MiseInit = @"
# Initialize mise for tool version management
if (Test-Path "`$env:USERPROFILE\.mise\bin") {
    `$env:PATH = "`$env:USERPROFILE\.mise\bin;`$env:PATH"
}

if (Get-Command mise -ErrorAction SilentlyContinue) {
    @(& mise activate --shims pwsh 2>`$null) | Out-String | Where-Object { `$_ } | Invoke-Expression
}

# Initialize Oh My Posh
$OmpInitLine
"@

    # Configure profiles for both Windows PowerShell (5.x) and PowerShell 7+
    $ProfilePaths = @(
        "$env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1",
        "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
    )

    foreach ($ProfilePath in $ProfilePaths) {
        $ProfileDir = Split-Path -Parent $ProfilePath
        if (-not (Test-Path $ProfileDir)) {
            New-Item -Path $ProfileDir -ItemType Directory -Force | Out-Null
        }

        if (Test-Path $ProfilePath) {
            $ProfileContent = Get-Content -Path $ProfilePath -Raw
            if ($ProfileContent -match 'Initialize mise|oh-my-posh') {
                # Replace existing initialization section with the new one
                $UpdatedContent = ($ProfileContent -split "`n" | ForEach-Object {
                    if ($_ -match 'Initialize mise|oh-my-posh|`$env:USERPROFILE\\\.mise\\bin|mise activate') { "" } else { $_ }
                }) -join "`n"
                # Clean up any duplicate empty lines
                $UpdatedContent = $UpdatedContent -replace "`n`n+", "`n"
                $UpdatedContent = $UpdatedContent.TrimEnd() + "`n`n" + $MiseInit
                Set-Content -Path $ProfilePath -Value $UpdatedContent -NoNewline
                Write-Host "Updated mise and Oh My Posh configuration in $ProfilePath."
            } else {
                Add-Content -Path $ProfilePath -Value "`n$MiseInit"
                Write-Host "Added mise and Oh My Posh configuration to $ProfilePath."
            }
        } else {
            Set-Content -Path $ProfilePath -Value $MiseInit
            Write-Host "Created $ProfilePath with mise and Oh My Posh configuration."
        }
    }

    # Configure Windows Terminal settings
    Write-Host "Configuring Windows Terminal settings..."
    $SourceSettings = Join-Path $ScriptDir "configs\Terminal\settings.json"
    $DestDir = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"

    if (-not (Test-Path $SourceSettings)) {
        Write-Host "Warning: configs\Terminal\settings.json not found!"
    } else {
        if (-not (Test-Path $DestDir)) {
            New-Item -Path $DestDir -ItemType Directory -Force | Out-Null
            Write-Host "Created Windows Terminal settings directory."
        }

        # Copy settings with FiraCode Nerd Font configuration
        $SettingsContent = Get-Content -Path $SourceSettings -Raw
        $DestSettingsPath = Join-Path $DestDir "settings.json"
        Set-Content -Path $DestSettingsPath -Value $SettingsContent -Force
        Write-Host "Windows Terminal settings configured successfully!"
    }

    Write-Host "Windows Terminal and Oh My Posh installed and configured successfully!"
}

# 9. Install wallpapers
function Install-Wallpapers {
    param(
        [string]$ScriptDir
    )

    Write-Host "Installing wallpapers..."
    $SourceWallpapersDir = Join-Path $ScriptDir "wallpapers"
    $DestWallpapersDir = Join-Path $env:USERPROFILE "Pictures\Wallpapers"

    if (-not (Test-Path $SourceWallpapersDir)) {
        Write-Host "Warning: No wallpapers directory found!"
        return
    }

    if (-not (Test-Path $DestWallpapersDir)) {
        New-Item -Path $DestWallpapersDir -ItemType Directory -Force | Out-Null
        Write-Host "Created Wallpapers directory in Pictures."
    }

    $WallpaperFiles = Get-ChildItem -Path $SourceWallpapersDir -File
    foreach ($File in $WallpaperFiles) {
        try {
            Copy-Item -Path $File.FullName -Destination $DestWallpapersDir -Force
            Write-Host "Copied wallpaper: $($File.Name)"
        } catch {
            Write-Error "Failed to copy wallpaper: $($File.Name)"
        }
    }

    # Set 01.png as the default desktop wallpaper
    $DefaultWallpaper = Join-Path $DestWallpapersDir "01.png"
    if (Test-Path $DefaultWallpaper) {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@
        [Wallpaper]::SystemParametersInfo(0x0014, 0, $DefaultWallpaper, 0x0003) | Out-Null
        Write-Host "Default wallpaper set to 01.png."
    } else {
        Write-Host "Warning: 01.png not found in wallpapers. Default wallpaper not set."
    }

    Write-Host "Wallpapers installed successfully!"
}

# 10. Configure Git
function Install-Git-Config {
    param(
        [string]$ScriptDir
    )

    Write-Host "Configuring Git..."
    $GitIgnoreGlobalPath = Join-Path $ScriptDir "configs\Git\.gitignore_global"

    if (Test-Path $GitIgnoreGlobalPath) {
        Copy-Item -Path $GitIgnoreGlobalPath -Destination "$env:USERPROFILE\.gitignore_global" -Force
        Write-Host ".gitignore_global copied to $env:USERPROFILE"
    } else {
        Write-Host "Warning: configs\Git\.gitignore_global not found!"
    }

    git config --global init.defaultBranch main
    git config --global color.ui auto
    git config --global core.editor "code"
    git config --global pull.rebase false
    git config --global core.excludesfile "$env:USERPROFILE\.gitignore_global"
    git config --global core.excludesfile "%USERPROFILE%\.gitignore_global"
    git config --global --list
    Write-Host "Base configuration for Git completed. Ensure you set your username and email!"
}

# ============================================================================================
# FONT INSTALLATION HELPERS (Support for option 7: Install Fonts)
# ============================================================================================

# SECURITY: Win32 P/Invoke is needed because copying .ttf/.otf to C:\Windows\Fonts is not
# enough to register a font with Windows. Apps looking up fonts by family name (like Windows
# Terminal) won't find a font until it's both copied to the Fonts directory AND registered in
# the registry, with a GDI notification sent to running apps. Using P/Invoke to call AddFontResource
# and SendMessageTimeout achieves immediate registration and notification without requiring a reboot.
if (-not ([System.Management.Automation.PSTypeName]'Win32FontHelper.NativeMethods').Type) {
    Add-Type -Namespace Win32FontHelper -Name NativeMethods -MemberDefinition @"
[DllImport("gdi32.dll", CharSet = CharSet.Auto, SetLastError = true)]
public static extern int AddFontResource(string lpFileName);

[DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
"@
}

# Helper: Register a font in the Windows registry and notify GDI of the change.
# This allows apps to find fonts by family name immediately, without requiring a reboot.
function Install-SystemFont {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FontFilePath
    )

    $DestFontsDir = "$env:WINDIR\Fonts"
    $RegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
    $FontFileName = Split-Path -Path $FontFilePath -Leaf
    $DestPath = Join-Path $DestFontsDir $FontFileName

    try {
        Copy-Item -Path $FontFilePath -Destination $DestPath -Force

        Add-Type -AssemblyName System.Drawing
        $PrivateFonts = New-Object System.Drawing.Text.PrivateFontCollection
        $PrivateFonts.AddFontFile($DestPath)
        $FontFamilyName = $PrivateFonts.Families[0].Name
        $PrivateFonts.Dispose()

        $Extension = [System.IO.Path]::GetExtension($FontFileName).ToLower()
        $RegistryValueName = if ($Extension -eq ".otf") { "$FontFamilyName (OpenType)" } else { "$FontFamilyName (TrueType)" }

        if (-not (Test-Path $RegistryPath)) {
            New-Item -Path $RegistryPath -Force | Out-Null
        }
        New-ItemProperty -Path $RegistryPath -Name $RegistryValueName -Value $FontFileName -PropertyType String -Force | Out-Null

        [Win32FontHelper.NativeMethods]::AddFontResource($DestPath) | Out-Null
        $Result = [UIntPtr]::Zero
        [Win32FontHelper.NativeMethods]::SendMessageTimeout([IntPtr]0xffff, 0x001D, [UIntPtr]::Zero, $null, 2, 1000, [ref]$Result) | Out-Null

        return $FontFamilyName
    } catch {
        Write-Error "Failed to install font ${FontFileName}: $_"
        return $null
    }
}

# Helper: Check if a font is properly registered in Windows.
function Test-FontInstalled {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FontFamilyName
    )

    $RegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
    $Fonts = Get-ItemProperty -Path $RegistryPath -ErrorAction SilentlyContinue
    if (-not $Fonts) {
        return $false
    }
    return [bool]($Fonts.PSObject.Properties | Where-Object { $_.Name -like "$FontFamilyName*" })
}

# 7. Install fonts
function Install-Fonts {
    param(
        [string]$ScriptDir
    )

    Write-Host "Installing fonts..."
    $SourceFontsDir = Join-Path $ScriptDir "fonts"
    $SourceFontsFiraCodeDir = Join-Path $SourceFontsDir "FiraCode"
    $DestFontsDir = "$env:WINDIR\Fonts"
    $TempDir = Join-Path $env:TEMP "nerd-fonts-download"

    # Create fonts directory if it doesn't exist
    if (-not (Test-Path $SourceFontsDir)) {
        New-Item -Path $SourceFontsDir -ItemType Directory -Force | Out-Null
        Write-Host "Created fonts directory at $SourceFontsDir"
    }

    # Create FiraCode subdirectory if it doesn't exist
    if (-not (Test-Path $SourceFontsFiraCodeDir)) {
        New-Item -Path $SourceFontsFiraCodeDir -ItemType Directory -Force | Out-Null
        Write-Host "Created FiraCode subdirectory at $SourceFontsFiraCodeDir"
    }

    # Create temporary directory for download
    if (-not (Test-Path $TempDir)) {
        New-Item -Path $TempDir -ItemType Directory -Force | Out-Null
    }

    try {
        Write-Host "Fetching latest Fira Code Nerd font from GitHub..."

        # Get the latest release info from GitHub API
        $ApiUrl = "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest"
        $ReleaseInfo = Invoke-RestMethod -Uri $ApiUrl -ErrorAction Stop

        # Find the FiraCode.zip asset
        $FiraCodeAsset = $ReleaseInfo.assets | Where-Object { $_.name -eq "FiraCode.zip" }

        if (-not $FiraCodeAsset) {
            Write-Error "Could not find FiraCode.zip in the latest release. Please check https://github.com/ryanoasis/nerd-fonts/releases"
            return
        }

        $DownloadUrl = $FiraCodeAsset.browser_download_url
        $ZipPath = Join-Path $TempDir "FiraCode.zip"

        Write-Host "Downloading Fira Code Nerd Font from: $DownloadUrl"
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath -ErrorAction Stop
        Write-Host "Download completed."

        # Extract to temporary directory first
        Write-Host "Extracting fonts..."
        $ExtractDir = Join-Path $TempDir "FiraCode"
        if (Test-Path $ExtractDir) {
            Remove-Item -Path $ExtractDir -Recurse -Force
        }
        Expand-Archive -Path $ZipPath -DestinationPath $ExtractDir -Force

        # Copy font files to the fonts directory, overwriting existing
        $FontFiles = Get-ChildItem -Path $ExtractDir -Include "*.ttf", "*.otf" -Recurse

        if ($FontFiles.Count -eq 0) {
            Write-Error "No font files found in the extracted archive."
            return
        }

        Write-Host "Found $($FontFiles.Count) font files. Copying to $SourceFontsFiraCodeDir..."
        foreach ($FontFile in $FontFiles) {
            try {
                Copy-Item -Path $FontFile.FullName -Destination $SourceFontsFiraCodeDir -Force
                Write-Host "Copied font: $($FontFile.Name)"
            } catch {
                Write-Error "Failed to copy font: $($FontFile.Name) - $_"
            }
        }

        # Install fonts from the FiraCode subdirectory to the system Fonts directory,
        # registering each one so apps can actually find it by family name
        Write-Host "Installing fonts to system directory..."
        $InstalledFonts = Get-ChildItem -Path $SourceFontsFiraCodeDir -Include "*.ttf", "*.otf"

        foreach ($Font in $InstalledFonts) {
            $InstalledName = Install-SystemFont -FontFilePath $Font.FullName
            if ($InstalledName) {
                Write-Host "Installed system font: $($Font.Name) (registered as '$InstalledName')"
            }
        }

        Write-Host "Fonts installed successfully!"

    } catch {
        Write-Error "Error downloading or installing fonts: $_"
    } finally {
        # Cleanup temporary files
        if (Test-Path $TempDir) {
            Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Cleaned up temporary files."
        }
    }
}

# ============================================================================================
# DEBLOATING & OPTIMIZATION FUNCTIONS (Helpers for option 11)
# ============================================================================================

# Helper: Remove OneDrive (separate from Remove-Bloatware because it requires special handling)
# OneDrive is a Win32 application, not an Appx package. Feature updates and Microsoft 365 installs
# can silently reinstall OneDrive no matter what, so beyond uninstalling, this function also applies
# a Group Policy block to make OneDrive inert if it gets reinstalled, and removes the reinstall
# trigger from the Default user profile to prevent new accounts from getting it at first logon.
function Remove-OneDrive {
    Write-Host "Removing OneDrive..."
    Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    $OneDriveSetup = Join-Path $env:SystemRoot "SysWOW64\OneDriveSetup.exe"
    if (-not (Test-Path $OneDriveSetup)) {
        $OneDriveSetup = Join-Path $env:SystemRoot "System32\OneDriveSetup.exe"
    }

    if (Test-Path $OneDriveSetup) {
        Start-Process -FilePath $OneDriveSetup -ArgumentList "/uninstall" -Wait -NoNewWindow
        Write-Host "OneDrive uninstalled. Note: any files already synced to disk remain in your user profile - review them yourself before deleting anything."
    } else {
        Write-Host "OneDriveSetup.exe not found; OneDrive may already be removed, or was installed via the Microsoft Store instead."
    }

    # Policy block: the official "Prevent the usage of OneDrive for file storage"
    # Group Policy setting. Windows respects this even after an update
    # reinstalls OneDrive, so it just sits there and won't launch or sync.
    Write-Host "Applying policy to block OneDrive from running..."
    try {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" -Force | Out-Null
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" -Name "DisableFileSyncNGSC" -Value 1 -Type DWord
    } catch {
        Write-Host "Failed to set OneDrive policy block: $_"
    }

    # Remove the reinstall trigger from the Default user profile so new
    # accounts don't get OneDrive installed at their first logon.
    Write-Host "Removing OneDrive reinstall trigger from Default user profile..."
    $defaultHive = Join-Path $env:SystemDrive "Users\Default\NTUSER.DAT"
    if (Test-Path $defaultHive) {
        $loadKey = "HKU\WindowsSetupSgt7_DefaultUser"
        try {
            & reg.exe load $loadKey $defaultHive 2>&1 | Out-Null
            & reg.exe delete "$loadKey\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "OneDriveSetup" /f 2>&1 | Out-Null
        } catch {
            Write-Host "Failed to edit Default user profile hive: $_"
        } finally {
            # Ensure no lingering handles keep the hive locked, then unload it
            [gc]::Collect()
            [gc]::WaitForPendingFinalizers()
            & reg.exe unload $loadKey 2>&1 | Out-Null
        }
    } else {
        Write-Host "Default user hive not found at $defaultHive; skipping."
    }

    # Remove OneDrive's scheduled tasks (the updater that checks in and
    # repairs the install) and unpin it from the Explorer sidebar.
    Get-ScheduledTask -TaskName "OneDrive*" -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "Registry::HKEY_CLASSES_ROOT\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" -Name "System.IsPinnedToNameSpaceTree" -Value 0 -ErrorAction SilentlyContinue

    Write-Host "OneDrive is now uninstalled and blocked from reinstalling/running via policy."
}

# Helper: Remove built-in Windows bloatware (Xbox, consumer Teams/Chat, Widgets, etc.)
# Uses the debloat_list.txt file for a customizable list of packages to remove.
function Remove-Bloatware {
    param(
        [string]$ScriptDir
    )

    Write-Host "Removing bloatware..."
    $ListPath = Join-Path $ScriptDir "debloat_list.txt"

    if (-not (Test-Path $ListPath)) {
        Write-Error "Warning: debloat_list.txt not found!"
        return
    }

    $LogDir = Join-Path $ScriptDir 'logs'
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
    $LogFile = Join-Path $LogDir 'debloat.log'

    $Entries = Get-Content -Path $ListPath

    foreach ($Entry in $Entries) {
        $Entry = $Entry.Trim()
        if ([string]::IsNullOrWhiteSpace($Entry) -or $Entry.StartsWith('#')) {
            continue
        }

        # OneDrive is a special case - not an Appx package
        if ($Entry -eq 'OneDrive') {
            Remove-OneDrive
            Add-Content -Path $LogFile -Value "$(Get-Date -Format o) HANDLED: OneDrive (via OneDriveSetup.exe /uninstall)"
            continue
        }

        $Found = $false

        # Remove for all existing user profiles
        Get-AppxPackage -Name $Entry -AllUsers -ErrorAction SilentlyContinue | ForEach-Object {
            $Found = $true
            try {
                Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction Stop
                Write-Host "Removed installed package: $($_.Name)"
                Add-Content -Path $LogFile -Value "$(Get-Date -Format o) REMOVED: $($_.Name)"
            } catch {
                Write-Host "Failed to remove installed package $($_.Name): $_"
                Add-Content -Path $LogFile -Value "$(Get-Date -Format o) FAILED: $($_.Name) - $_"
            }
        }

        # De-provision so it doesn't come back for new profiles or after a feature update
        Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $Entry } | ForEach-Object {
            $Found = $true
            try {
                Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction Stop | Out-Null
                Write-Host "De-provisioned: $($_.DisplayName)"
                Add-Content -Path $LogFile -Value "$(Get-Date -Format o) DEPROVISIONED: $($_.DisplayName)"
            } catch {
                Write-Host "Failed to de-provision $($_.DisplayName): $_"
                Add-Content -Path $LogFile -Value "$(Get-Date -Format o) FAILED: $($_.DisplayName) - $_"
            }
        }

        if (-not $Found) {
            Write-Host "Skipping $Entry (not found/already removed)"
            Add-Content -Path $LogFile -Value "$(Get-Date -Format o) SKIP: $Entry - not found"
        }
    }

    # Stop Windows from re-suggesting/reinstalling consumer apps after feature updates
    $CloudContentPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
    if (-not (Test-Path $CloudContentPath)) {
        New-Item -Path $CloudContentPath -Force | Out-Null
    }
    Set-ItemProperty -Path $CloudContentPath -Name "DisableWindowsConsumerFeatures" -Value 1 -Type DWord
    Set-ItemProperty -Path $CloudContentPath -Name "DisableConsumerAccountStateContent" -Value 1 -Type DWord
    Set-ItemProperty -Path $CloudContentPath -Name "DisableCloudOptimizedContent" -Value 1 -Type DWord

    Write-Host "Bloatware removal completed. See $LogFile for details."
}

# Helper: Remove additional bloatware apps not covered by debloat_list.txt
# These are common optional app packages (News, Weather, Copilot, etc.) that might not be
# in every user's debloat_list.txt but should be removed when doing a comprehensive debloat.
function Remove-AdditionalBloatware {
    Write-Host "Removing additional bloatware packages..."

    $AdditionalApps = @(
        "*Microsoft.News*",
        "*Microsoft.Weather*",
        "*Microsoft.MicrosoftTeams*",
        "*Microsoft.GamingApp*",
        "*Microsoft.Copilot*"
    )

    $LogDir = Join-Path $env:TEMP 'logs'
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
    $LogFile = Join-Path $LogDir 'additional_debloat.log'

    foreach ($App in $AdditionalApps) {
        Get-AppxPackage -Name $App -AllUsers -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction Stop
                Write-Host "Removed: $($_.Name)"
                Add-Content -Path $LogFile -Value "$(Get-Date -Format o) REMOVED: $($_.Name)"
            } catch {
                Write-Host "Failed to remove $($_.Name): $_"
            }
        }

        Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $App } | ForEach-Object {
            try {
                Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction Stop | Out-Null
                Write-Host "De-provisioned: $($_.DisplayName)"
                Add-Content -Path $LogFile -Value "$(Get-Date -Format o) DEPROVISIONED: $($_.DisplayName)"
            } catch {
                Write-Host "Failed to de-provision $($_.DisplayName): $_"
            }
        }
    }

    Write-Host "Additional bloatware removal completed."
}

# Helper: Apply privacy/performance tweaks (telemetry, Start menu clutter, Recall, dev QoL settings)
function Optimize-WindowsPrivacyPerformance {
    Write-Host "Applying privacy and performance tweaks..."

    # --- Telemetry: set to the minimum level the SKU allows ---
    $TelemetryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
    if (-not (Test-Path $TelemetryPath)) {
        New-Item -Path $TelemetryPath -Force | Out-Null
    }
    Set-ItemProperty -Path $TelemetryPath -Name "AllowTelemetry" -Value 1 -Type DWord

    # --- Start menu / search clutter ---
    $ExplorerPolicyPath = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
    if (-not (Test-Path $ExplorerPolicyPath)) {
        New-Item -Path $ExplorerPolicyPath -Force | Out-Null
    }
    Set-ItemProperty -Path $ExplorerPolicyPath -Name "DisableSearchBoxSuggestions" -Value 1 -Type DWord

    $SearchPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search"
    if (-not (Test-Path $SearchPath)) {
        New-Item -Path $SearchPath -Force | Out-Null
    }
    Set-ItemProperty -Path $SearchPath -Name "BingSearchEnabled" -Value 0 -Type DWord
    Set-ItemProperty -Path $SearchPath -Name "CortanaConsent" -Value 0 -Type DWord

    # --- Suggested content / "ads" in Start and lock screen ---
    $ContentDeliveryPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    if (-not (Test-Path $ContentDeliveryPath)) {
        New-Item -Path $ContentDeliveryPath -Force | Out-Null
    }
    $ContentDeliverySettings = @(
        "SubscribedContent-338388Enabled",
        "SubscribedContent-338389Enabled",
        "SubscribedContent-353694Enabled",
        "SubscribedContent-353696Enabled",
        "SubscribedContent-338387Enabled",
        "SystemPaneSuggestionsEnabled",
        "SoftLandingEnabled",
        "RotatingLockScreenOverlayEnabled"
    )
    foreach ($Setting in $ContentDeliverySettings) {
        Set-ItemProperty -Path $ContentDeliveryPath -Name $Setting -Value 0 -Type DWord -ErrorAction SilentlyContinue
    }

    # --- Taskbar: hide Widgets and Chat icons (apps are also removed by Remove-Bloatware) ---
    $AdvancedPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    if (-not (Test-Path $AdvancedPath)) {
        New-Item -Path $AdvancedPath -Force | Out-Null
    }
    Set-ItemProperty -Path $AdvancedPath -Name "TaskbarDa" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $AdvancedPath -Name "TaskbarMn" -Value 0 -Type DWord -ErrorAction SilentlyContinue

    # --- Dev-friendly Explorer settings: show file extensions and hidden files ---
    Set-ItemProperty -Path $AdvancedPath -Name "HideFileExt" -Value 0 -Type DWord
    Set-ItemProperty -Path $AdvancedPath -Name "Hidden" -Value 1 -Type DWord

    # --- Long path support (helps with deeply nested node_modules, etc.) ---
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -Type DWord

    # --- Developer Mode ---
    $DevModePath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
    if (-not (Test-Path $DevModePath)) {
        New-Item -Path $DevModePath -Force | Out-Null
    }
    Set-ItemProperty -Path $DevModePath -Name "AllowDevelopmentWithoutDevLicense" -Value 1 -Type DWord

    # --- Game DVR / background recording (frees up background CPU/GPU usage) ---
    $GameDvrPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
    if (-not (Test-Path $GameDvrPolicyPath)) {
        New-Item -Path $GameDvrPolicyPath -Force | Out-Null
    }
    Set-ItemProperty -Path $GameDvrPolicyPath -Name "AllowGameDVR" -Value 0 -Type DWord

    $GameConfigPath = "HKCU:\System\GameConfigStore"
    if (-not (Test-Path $GameConfigPath)) {
        New-Item -Path $GameConfigPath -Force | Out-Null
    }
    Set-ItemProperty -Path $GameConfigPath -Name "GameDVR_Enabled" -Value 0 -Type DWord

    # --- Storage Sense (automatic temp-file cleanup) ---
    $StorageSensePath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy"
    if (-not (Test-Path $StorageSensePath)) {
        New-Item -Path $StorageSensePath -Force | Out-Null
    }
    Set-ItemProperty -Path $StorageSensePath -Name "01" -Value 1 -Type DWord

    # --- Recall (Copilot+ PCs only) - disable via policy, and remove the optional feature if present ---
    $AiPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
    if (-not (Test-Path $AiPolicyPath)) {
        New-Item -Path $AiPolicyPath -Force | Out-Null
    }
    Set-ItemProperty -Path $AiPolicyPath -Name "DisableAIDataAnalysis" -Value 1 -Type DWord
    try {
        $RecallFeature = Get-WindowsOptionalFeature -Online -FeatureName "Recall" -ErrorAction Stop
        if ($RecallFeature -and $RecallFeature.State -eq "Enabled") {
            Disable-WindowsOptionalFeature -Online -FeatureName "Recall" -NoRestart -ErrorAction Stop | Out-Null
            Write-Host "Recall optional feature disabled."
        }
    } catch {
        # Not a Copilot+ PC / feature not present - nothing to do
    }

    # --- Edge integration (disable telemetry & suggestions) ---
    $EdgePath = "HKCU:\SOFTWARE\Microsoft\Edge"
    if (-not (Test-Path $EdgePath)) {
        New-Item -Path $EdgePath -Force | Out-Null
    }
    Set-ItemProperty -Path $EdgePath -Name "AllowSurfaceIntegrationExtension" -Value 0 -Type DWord -ErrorAction SilentlyContinue

    $EdgePolicyPath = "HKCU:\SOFTWARE\Policies\Microsoft\Edge"
    if (-not (Test-Path $EdgePolicyPath)) {
        New-Item -Path $EdgePolicyPath -Force | Out-Null
    }
    Set-ItemProperty -Path $EdgePolicyPath -Name "MetricsReportingEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $EdgePolicyPath -Name "SendIntranetToInternetExplorer" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $EdgePolicyPath -Name "PersonalizationReportingEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue

    # --- Cortana (disable suggestions & telemetry, but keep app functional) ---
    $CortanaPath = "HKCU:\SOFTWARE\Microsoft\Personalization\Settings"
    if (-not (Test-Path $CortanaPath)) {
        New-Item -Path $CortanaPath -Force | Out-Null
    }
    Set-ItemProperty -Path $CortanaPath -Name "AcceptedPrivacyPolicy" -Value 0 -Type DWord

    $CortanaSearchPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search"
    Set-ItemProperty -Path $CortanaSearchPath -Name "AllowSearchToUseLocation" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $CortanaSearchPath -Name "DeviceHistoryEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue

    # --- File Explorer customizations ---
    $ExplorerAdvancedPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    # Hide Quick Access (but don't remove it, just hide from sidebar)
    Set-ItemProperty -Path $ExplorerAdvancedPath -Name "NavPaneExpandToCurrentFolder" -Value 1 -Type DWord
    # Show full file paths in title bar
    Set-ItemProperty -Path $ExplorerAdvancedPath -Name "FullPath" -Value 1 -Type DWord

    # Clear Quick Access history (frequently used files & folders)
    $QuickAccessPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MRU"
    if (Test-Path $QuickAccessPath) {
        try {
            Get-Item -Path $QuickAccessPath -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Quick Access history cleared."
        } catch {
            Write-Host "Could not clear Quick Access history (non-critical): $_"
        }
    }

    # --- Search refinements (disable cloud search, activity history) ---
    $SearchCloudPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search"
    Set-ItemProperty -Path $SearchCloudPath -Name "IsAADCloudSearchEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $SearchCloudPath -Name "BingSearchEnabled" -Value 0 -Type DWord  # redundant but thorough

    # Disable activity history for search
    $ActivityHistoryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
    if (-not (Test-Path $ActivityHistoryPath)) {
        New-Item -Path $ActivityHistoryPath -Force | Out-Null
    }
    Set-ItemProperty -Path $ActivityHistoryPath -Name "EnableActivityFeed" -Value 0 -Type DWord -ErrorAction SilentlyContinue

    Write-Host "Privacy and performance tweaks applied. Some settings take effect after sign-out or restart."
}

# Helper: Disable a small set of non-essential services
# Intentionally NOT touched: Windows Defender (WinDefend), Windows Update (wuauserv),
# BITS, the firewall (mpssvc), WMI (Winmgmt), Event Log, Print Spooler, Remote Desktop,
# or any networking/hardware-related services.
# Only services that are purely telemetry, optional features, or consumer-focused are disabled.
function Disable-UnneededServices {
    Write-Host "Disabling non-essential services..."

    $ServicesToDisable = @(
        "DiagTrack",              # Connected User Experiences and Telemetry
        "dmwappushservice",       # WAP Push Message Routing (telemetry-adjacent)
        "RetailDemo",             # Retail Demo Service
        "Fax",                    # Fax
        "wisvc",                  # Windows Insider Service
        "xbgm",                   # Xbox Game Monitoring (only if game mode not needed)
        "XboxNetApiSvc",          # Xbox Networking Service (only if Xbox app not used)
        "PcaSvc",                 # Program Compatibility Assistant (optional)
        "DusmSvc",                # Data Usage Measurement Service (optional telemetry)
        "WerSvc"                  # Windows Error Reporting (optional)
    )

    foreach ($ServiceName in $ServicesToDisable) {
        $Service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if (-not $Service) {
            Write-Host "Skipping $ServiceName (not present on this system)"
            continue
        }

        try {
            Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
            Set-Service -Name $ServiceName -StartupType Disabled -ErrorAction Stop
            Write-Host "Disabled service: $ServiceName"
        } catch {
            Write-Host "Failed to disable service ${ServiceName}: $_"
        }
    }

    Write-Host "Service cleanup completed."
}

# Helper: Remove unnecessary items from Windows Explorer context menu (conservative approach)
# Only removes items known to be safe to remove without breaking functionality
function Optimize-ContextMenu {
    Write-Host "Optimizing Windows Explorer context menu..."

    # Disable "Share with" submenu (safe to disable, sharing apps can be reinstalled if needed)
    try {
        New-Item -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked" -Force -ErrorAction SilentlyContinue | Out-Null
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked" -Name "{E2BF9676-5F8F-435C-97EB-11607A5BEDF7}" -Value "" -Type String -ErrorAction SilentlyContinue
        Write-Host "Disabled 'Share with' context menu."
    } catch {
        Write-Host "Could not disable 'Share with' menu (non-critical): $_"
    }

    # Remove "Send to" items for OneDrive if it's been removed
    try {
        $SendToPath = "$env:APPDATA\Microsoft\Windows\SendTo"
        if (Test-Path $SendToPath) {
            Get-ChildItem -Path $SendToPath -Filter "*OneDrive*" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
            Write-Host "Cleaned up OneDrive 'Send to' shortcuts."
        }
    } catch {
        Write-Host "Could not clean Send To folder (non-critical): $_"
    }

    # Disable "Open with Cloud Storage" option if available (Windows 11 22H2+)
    try {
        $ExplorerPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer"
        Set-ItemProperty -Path $ExplorerPath -Name "AltStartButtonBalloonTip" -Value 0 -Type DWord -ErrorAction SilentlyContinue
        Write-Host "Context menu optimizations applied."
    } catch {
        Write-Host "Context menu optimization completed with some skips."
    }
}

# Helper: Set a power plan appropriate for this machine (laptop vs desktop)
function Set-PowerPlan {
    Write-Host "Configuring power plan..."

    $Battery = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue
    if ($Battery) {
        Write-Host "Battery detected (laptop) - setting Balanced power plan and keeping hibernation enabled."
        powercfg /setactive SCHEME_BALANCED
        powercfg /hibernate on
    } else {
        Write-Host "No battery detected (desktop) - setting High Performance power plan and disabling hibernation to reclaim disk space."
        powercfg /setactive SCHEME_MIN
        powercfg /hibernate off
    }
}

# ============================================================================================
# ORCHESTRATORS (Multi-step runners for menu options 11, 12, 13)
# ============================================================================================

# 11. Debloat & Optimize Windows (orchestrator)
function Invoke-DebloatAndOptimize {
    param(
        [string]$ScriptDir
    )

    Write-Host
    Write-Host "WARNING: This will:"
    Write-Host "  - Remove bloatware from debloat_list.txt (Xbox, Teams, OneDrive, Widgets, etc.)"
    Write-Host "  - Remove additional optional apps (News, Weather, Microsoft Teams, Copilot)"
    Write-Host "  - Apply comprehensive privacy/performance tweaks:"
    Write-Host "    * Telemetry and tracking (DiagTrack, connected experiences)"
    Write-Host "    * Start menu, search, and Cortana suggestions (app stays functional)"
    Write-Host "    * Edge telemetry and personalization"
    Write-Host "    * Game DVR, Recall, Storage Sense, taskbar clutter"
    Write-Host "    * File Explorer customizations (Quick Access, full paths)"
    Write-Host "    * Search refinements (cloud search, activity history)"
    Write-Host "  - Disable non-essential services (telemetry, fax, retail demo, Xbox)"
    Write-Host "  - Optimize context menu (remove Share with, OneDrive Send To shortcuts)"
    Write-Host "  - Set power plan (auto-detected: Balanced for laptop, High Performance for desktop)"
    Write-Host
    Write-Host "This does NOT touch: Windows Defender, Windows Update, Firewall, UAC, Print Spooler,"
    Write-Host "Remote Desktop, Networking services, or any hardware-related services."
    Write-Host
    $confirm = Read-Host "Are you sure you want to proceed? [y/N]"
    if ($confirm -notin @('y', 'Y', 'yes', 'Yes')) {
        Write-Host "Cancelled. Returning to menu."
        return
    }

    Remove-Bloatware -ScriptDir $ScriptDir
    Remove-AdditionalBloatware
    Optimize-WindowsPrivacyPerformance
    Disable-UnneededServices
    Optimize-ContextMenu
    Set-PowerPlan

    Write-Host
    Write-Host "Debloat and optimization completed. A sign-out or restart is recommended for all changes to fully take effect."
}

# 12. Schedule Automated Maintenance Tasks (orchestrator)
function Schedule-MaintenanceTask {
    Write-Host "Setting up automated Windows maintenance tasks..." -ForegroundColor Cyan
    Write-Host

    # Determine installation directory
    $SetupDir = "C:\windows-setup"
    $UserLocalSetupDir = Join-Path $env:USERPROFILE 'AppData\Local\windows-setup'
    $SourceMaintenanceScript = Join-Path (Split-Path -Parent $MyInvocation.PSCommandPath) 'scripts\win11-maintenance.ps1'

    # Prefer system-wide directory, fall back to user local
    if (Test-Path 'C:\Program Files') {
        $InstallDir = $SetupDir
    } else {
        $InstallDir = $UserLocalSetupDir
    }

    # Create installation directory
    if (-not (Test-Path $InstallDir)) {
        try {
            New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null
            Write-Host "Created directory: $InstallDir" -ForegroundColor Gray
        } catch {
            Write-Error "Failed to create installation directory: $_"
            return
        }
    }

    # Copy maintenance script
    $DestMaintenanceScript = Join-Path $InstallDir 'win11-maintenance.ps1'
    if (-not (Test-Path $SourceMaintenanceScript)) {
        Write-Error "Source maintenance script not found at: $SourceMaintenanceScript"
        return
    }

    try {
        Copy-Item -Path $SourceMaintenanceScript -Destination $DestMaintenanceScript -Force
        Write-Host "[OK] Copied maintenance script to: $DestMaintenanceScript" -ForegroundColor Green
    } catch {
        Write-Error "Failed to copy maintenance script: $_"
        return
    }

    # Create logs directory
    $LogsDir = Join-Path $InstallDir 'logs'
    if (-not (Test-Path $LogsDir)) {
        New-Item -Path $LogsDir -ItemType Directory -Force | Out-Null
    }

    Write-Host
    Write-Host "Registering scheduled tasks..." -ForegroundColor Yellow

    # --- Weekly Maintenance Task (Every Sunday at 2 AM) ---
    $WeeklyTaskName = "Windows 11 Maintenance - Weekly"
    $WeeklyTaskPath = "\windows-setup\$WeeklyTaskName"

    try {
        # Create task trigger for every Sunday at 2 AM
        $WeeklyTrigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At "02:00" -ErrorAction Stop

        # Create task action
        $WeeklyAction = New-ScheduledTaskAction `
            -Execute "powershell.exe" `
            -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$DestMaintenanceScript`" -Mode Weekly -LogDir `"$LogsDir`"" `
            -ErrorAction Stop

        # Create task settings (run with highest privilege, don't stop if user logs off)
        $WeeklySettings = New-ScheduledTaskSettingsSet `
            -StartWhenAvailable `
            -ErrorAction Stop

        # Register the task
        Register-ScheduledTask -TaskName $WeeklyTaskName `
            -TaskPath "\windows-setup\" `
            -Trigger $WeeklyTrigger `
            -Action $WeeklyAction `
            -Settings $WeeklySettings `
            -Principal (New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest) `
            -Force `
            -ErrorAction Stop | Out-Null

        Write-Host "[OK] Weekly task registered: Sundays at 2:00 AM" -ForegroundColor Green
    } catch {
        Write-Host "[FAIL] Failed to register weekly task: $_" -ForegroundColor Red
        return
    }

    # --- Monthly Maintenance Task (1st Sunday at 3 AM) ---
    $MonthlyTaskName = "Windows 11 Maintenance - Monthly"

    try {
        # Create custom trigger for 1st Sunday of each month
        # Note: ScheduledTask doesn't have built-in 1st-Sunday trigger, so we use a workaround
        $MonthlyTrigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -WeeksInterval 4 -At "03:00" -ErrorAction Stop

        # Create task action
        $MonthlyAction = New-ScheduledTaskAction `
            -Execute "powershell.exe" `
            -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$DestMaintenanceScript`" -Mode Monthly -LogDir `"$LogsDir`"" `
            -ErrorAction Stop

        # Create task settings
        $MonthlySettings = New-ScheduledTaskSettingsSet `
            -StartWhenAvailable `
            -ErrorAction Stop

        # Register the task
        Register-ScheduledTask -TaskName $MonthlyTaskName `
            -TaskPath "\windows-setup\" `
            -Trigger $MonthlyTrigger `
            -Action $MonthlyAction `
            -Settings $MonthlySettings `
            -Principal (New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest) `
            -Force `
            -ErrorAction Stop | Out-Null

        Write-Host "[OK] Monthly task registered: 1st Sunday of each month at 3:00 AM" -ForegroundColor Green
    } catch {
        Write-Host "[FAIL] Failed to register monthly task: $_" -ForegroundColor Red
        return
    }

    Write-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Maintenance Tasks Scheduled Successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host
    Write-Host "Configuration:" -ForegroundColor Yellow
    Write-Host "  * Script location: $DestMaintenanceScript"
    Write-Host "  * Logs location: $LogsDir"
    Write-Host "  * Weekly task: Every Sunday at 2:00 AM (registry + services + context menu)"
    Write-Host "  * Monthly task: Every Sunday at 3:00 AM (includes OneDrive check)"
    Write-Host "  * Privilege level: SYSTEM (highest)"
    Write-Host
    Write-Host "To manage tasks:" -ForegroundColor Yellow
    Write-Host "  * Open Task Scheduler"
    Write-Host "  * Navigate to: Task Scheduler Library > windows-setup"
    Write-Host "  * View logs in: $LogsDir"
    Write-Host
    Write-Host "To remove tasks (if needed):" -ForegroundColor Yellow
    Write-Host "  * Run as admin: Unregister-ScheduledTask -TaskName 'Windows 11 Maintenance - Weekly' -Confirm:`$false"
    Write-Host "  * Run as admin: Unregister-ScheduledTask -TaskName 'Windows 11 Maintenance - Monthly' -Confirm:`$false"
    Write-Host
}

# 13. Execute all setup steps (orchestrator)
function Invoke-All-Install-Tasks {
    param(
        [string]$ScriptDir
    )

    Write-Host
    Write-Host "WARNING: This will execute ALL setup steps automatically:"
    Write-Host "  - Rename PC, install winget, update Windows, install packages,"
    Write-Host "  - install Chrome, fonts, Windows Terminal with Oh My Posh and configuration,"
    Write-Host "  - install wallpapers, and configure Git."
    Write-Host
    $confirm = Read-Host "Are you sure you want to proceed? [y/N]"
    if ($confirm -notin @('y', 'Y', 'yes', 'Yes')) {
        Write-Host "Cancelled. Returning to menu."
        return
    }

    Rename-WindowsPC -AutoConfirm
    Install-Winget
    Update-Patch-Windows
    Install-WingetPackages -ScriptDir $ScriptDir
    Install-Chrome
    Install-Fonts -ScriptDir $ScriptDir
    Install-OhMyPosh -ScriptDir $ScriptDir
    Install-Wallpapers -ScriptDir $ScriptDir
    Install-Git-Config -ScriptDir $ScriptDir
}

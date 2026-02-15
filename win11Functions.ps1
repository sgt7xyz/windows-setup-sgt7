#!/usr/bin/env pwsh

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

        # Copy fonts from the FiraCode subdirectory to system Fonts directory
        Write-Host "Installing fonts to system directory..."
        $InstalledFonts = Get-ChildItem -Path $SourceFontsFiraCodeDir -Include "*.ttf", "*.otf"
        
        foreach ($Font in $InstalledFonts) {
            try {
                Copy-Item -Path $Font.FullName -Destination $DestFontsDir -Force
                Write-Host "Installed system font: $($Font.Name)"
            } catch {
                Write-Error "Failed to install system font: $($Font.Name) - $_"
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

    # Note: Fira Code Nerd Font should be installed via Install-Fonts before this function is called
    # This is required for Oh My Posh theme glyphs to render properly

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

# 9. Configure Windows Terminal (now integrated into Install-OhMyPosh)
function Install-TerminalConfig {
    param(
        [string]$ScriptDir
    )

    Write-Host "Windows Terminal configuration is now handled by 'Install Windows Terminal and Oh My Posh' (option 8)."
    Write-Host "Please run option 8 to install and configure Windows Terminal."
}

# 10. Install wallpapers
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

# 11. Configure Git
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
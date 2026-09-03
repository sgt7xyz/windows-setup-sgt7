![Win Logo](images/winlogo.png)

<a rel="license" href="http://creativecommons.org/licenses/by-nc/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc/4.0/88x31.png"/></a><br/>This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc/4.0/">Creative Commons Attribution-NonCommercial 4.0 International License</a>.

# Windows 11 Post-Install Setup Script

This repository contains scripts to automate the setup and configuration of a new Windows 11 environment. The setup process is streamlined through two main PowerShell scripts: `win11Setup.ps1` and `win11Functions.ps1`.

## Overview

- `win11Setup.ps1`: This script provides a user-friendly menu to execute various setup tasks such as installing winget, updating Windows, renaming the PC, installing applications and tools, managing packages, and configuring development tools.
- `win11Functions.ps1`: Contains all the functions called by `win11Setup.ps1`, modularizing the setup process and making the codebase easier to maintain and update.

## Getting Started

1. **Prepare Your Environment**: Ensure that PowerShell is set to allow scripts to run by executing `Set-ExecutionPolicy RemoteSigned` from an elevated PowerShell prompt.

```Powershell
PS C:\Users\%username%\code\windows-setup-sgt7> Get-ExecutionPolicy
Restricted
PS C:\Users\%username%\code\windows-setup-sgt7> Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Execution Policy Change
The execution policy helps protect you from scripts that you do not trust. Changing the execution policy might expose you to the security risks described in the
about_Execution_Policies help topic at https:/go.microsoft.com/fwlink/?LinkID=135170. Do you want to change the execution policy?
[Y] Yes  [A] Yes to All  [N] No  [L] No to All  [S] Suspend  [?] Help (default is "N"): A
PS C:\Users\%username%\code\windows-setup-sgt7> Get-ExecutionPolicy
RemoteSigned
PS C:\Users\%username%\code\windows-setup-sgt7>
```

2. **Download the Scripts**: Clone this repository or download the scripts directly into your local machine.
3. **Running `win11Setup.ps1`**: Navigate to the directory containing the scripts and run `.\win11Setup.ps1` from an elevated PowerShell prompt. Follow the on-screen prompts to select the setup tasks you wish to execute.

## Features

The `win11Setup.ps1` script offers the following options:

### System Configuration

1. **Rename Windows PC** (`Rename-WindowsPC`)
   - Changes the computer's name.
   - Prompts user for the new computer name interactively.
   - Requires system restart for changes to take effect.

2. **Install Windows Package Manager (winget)** (`Install-Winget`)
   - Installs the Windows Package Manager if not already present.
   - Checks if winget is already installed and skips installation if found.
   - Requires administrator privileges.
   - Installs via the Microsoft Desktop App Installer package.

3. **Update and Patch Windows** (`Update-Patch-Windows`)
   - Applies the latest Windows updates and patches using PSWindowsUpdate module.
   - Installs NuGet package provider if not present.
   - Configures Microsoft Update as a service manager.
   - Suppresses automatic reboot but recommends manual restart after completion.
   - Logs all updates to a timestamped file at `C:\<ComputerName>_<Date>_MSUpdates.log`.

### Package Management

4. **Install winget Packages** (`Install-WingetPackages`)
   - Installs applications using the Windows Package Manager from a predefined list in `winget_install.txt`.
   - Checks if each package is already installed before attempting installation.
   - Skips packages marked with `#` (comments) or empty lines.
   - Generates detailed logs in `logs/winget_install.log` with timestamps.
   - Reports success/failure/skip status for each package installation attempt.
   - Supports silent installation for all packages.

5. **Uninstall winget Packages** (`Uninstall-WingetPackages`)
   - Removes applications using the Windows Package Manager from a predefined list in `winget_uninstall.txt`.
   - Checks if each package is installed before attempting uninstallation.
   - Skips packages marked with `#` (comments) or empty lines.
   - Generates detailed logs in `logs/winget_uninstall.log` with timestamps.
   - Reports success/failure/skip status for each package uninstallation attempt.
   - Supports silent uninstallation for all packages.

### Applications & Tools

6. **Install Google Chrome** (`Install-Chrome`)
   - Downloads and installs the Google Chrome web browser.
   - Performs silent installation using `/silent /install` parameters.
   - Automatically cleans up the installer file after installation.

7. **Install Fonts** (`Install-Fonts`)
   - Adds custom fonts (`.ttf` and `.otf` files) to your system from the `fonts/` directory.
   - Copies fonts to the Windows System Fonts directory (`C:\Windows\Fonts`) and registers each one (registry entry, GDI notification) so apps can find it by family name immediately — not just a file copy.
   - Skips installation if no `fonts/` directory is found.
   - Reports success/failure for each font file.

8. **Install Windows Terminal and Oh My Posh** (`Install-OhMyPosh`)
   - Installs Windows Terminal for a modern terminal experience.
   - Installs Oh My Posh for customizable command-line prompts and themes.
   - Checks whether Fira Code Nerd Font is already registered with Windows; if not, installs it via `oh-my-posh font install`, falling back to the copy bundled in `fonts/FiraCode/` if that's unavailable (no internet, etc.) — either way, the font is registered (not just copied) so Windows Terminal can find it, and no reboot is required.
   - Applies Windows Terminal settings configuration (colors, opacity, font "FiraCode Nerd Font", keybindings).
   - Configures PowerShell profiles with **mise** initialization for tool version management.
   - Mise allows you to install and manage multiple versions of tools like Terraform, Node.js, Python, and more.
   - Automatically adds mise-managed tools to the `$PATH` so they're available in PowerShell immediately after installation.
   - Copies the `catppuccin_macchiato` Oh My Posh theme to the user's profile.
   - **Note:** This step replaces the separate "Configure Windows Terminal" option for a streamlined setup experience.
   - All installations are performed silently via winget.

9. **Install Wallpapers** (`Install-Wallpapers`)
   - Copies wallpaper files from the `wallpapers/` directory to the user's Pictures folder.
   - Sets the first wallpaper (01.png) as the default desktop background.
   - Creates the Wallpapers directory if it doesn't exist.

10. **Configure Git** (`Install-Git-Config`)
    - Configures Git with essential global settings:
      - Sets default branch to `main`.
      - Enables colored output for better readability.
      - Sets VS Code as the default editor.
      - Configures pull strategy to merge (not rebase).
      - Copies `.gitignore_global` from `configs/` directory if available.
      - Applies global git excludes file configuration.
    - Displays all configured git settings upon completion.
    - Recommends manual configuration of username and email after setup.

### Tool Version Management with mise

The setup script automatically configures **mise** integration in your PowerShell profiles. mise is a polyglot runtime manager that simplifies version management for multiple languages and tools.

**What is mise?**

- A tool version manager that supports Terraform, Node.js, Python, Ruby, Go, Rust, and many other tools.
- Allows you to install and manage multiple versions of the same tool without conflict.
- Configured in `.mise.toml` files per project for version pinning and consistency.
- Automatically activates the correct tool version when you enter a directory with a `.mise.toml` configuration.

**Integration with Setup:**

- The setup script adds mise bin path (`$env:USERPROFILE\.mise\bin`) to PowerShell's `$PATH`.
- Initializes mise activation hooks so tool shims are available in PowerShell sessions.
- After setup, all tools installed via mise (e.g., `mise install terraform`) will be immediately accessible in PowerShell.
- No need to manually add paths or restart shells—mise integration is automatic.

### Script Improvements

- **Consolidated Terminal Setup**: The "Install Windows Terminal and Oh My Posh" step now includes terminal configuration, eliminating the need for a separate step and ensuring fonts are properly installed before applying settings.
- **Robust Font Installation**: `Install-SystemFont` and `Test-FontInstalled` properly register fonts (registry entry + immediate refresh, not just a file copy), and `Install-OhMyPosh` checks registration before applying terminal settings to prevent "Unable to find the following fonts" errors.
- **Intelligent Font Management**: Supports both custom fonts (via option 7) and nerd fonts for terminal themes (via option 8).

### System Cleanup & Optimization

11. **Debloat & Optimize Windows** (`Invoke-DebloatAndOptimize`)
    - Not included in "Execute all steps" — this is an explicit, opt-in step since it changes default OS behavior more than the other options do.
    - Prompts for confirmation before making any changes, and clearly states up front what it will and will not touch.
    - Removes built-in Windows bloatware (`Remove-Bloatware`):
      - Deletes the packages listed in `debloat_list.txt` (Xbox app/overlays, consumer Teams/Chat, Widgets, Solitaire, Bing news/weather/finance/sports tiles, 3D Viewer, Mixed Reality Portal, Paint 3D, Skype, People, Feedback Hub, Get Help, Tips, Clipchamp, Family Safety, Office Hub, Cortana app).
      - Removes them both for existing user profiles (`Get-AppxPackage -AllUsers`) and de-provisions them (`Get-AppxProvisionedPackage`) so they don't reappear for new profiles or after a Windows feature update.
      - Uninstalls OneDrive via its own uninstaller (it's a regular Win32 install, not an Appx package) — synced files already on disk are left in place for you to review.
      - Sets the `DisableWindowsConsumerFeatures` policy so Windows stops re-suggesting/reinstalling consumer apps.
      - Logs every action to `logs/debloat.log`.
      - Fully customizable: edit `debloat_list.txt` (one Appx package name per line, wildcards supported, `#` to skip) to change what gets removed.
    - Applies privacy/performance tweaks (`Optimize-WindowsPrivacyPerformance`):
      - Sets telemetry to the minimum level the Windows edition allows.
      - Disables Start menu web search/suggestions, Start/lock-screen "ad" content, and hides the Widgets/Chat taskbar icons.
      - Disables Recall (Copilot+ PCs) via policy, and removes the optional feature if present.
      - Disables Game DVR/background game recording.
      - Enables developer-friendly settings: show file extensions, show hidden files, `LongPathsEnabled`, Developer Mode, Storage Sense.
    - Disables a small set of non-essential services (`Disable-UnneededServices`): `DiagTrack`, `dmwappushservice`, `RetailDemo`, `Fax`, `wisvc` (Windows Insider Service).
      - Deliberately does **not** touch Windows Defender, Windows Update, the firewall, WMI, Event Log, or Print Spooler.
    - Sets an appropriate power plan (`Set-PowerPlan`): detects battery presence at runtime — Balanced with hibernation on for laptops, High Performance with hibernation off for desktops.

### Execute All

12. **Execute All** (`Invoke-All-Install-Tasks`)
    - Runs all setup tasks in the following sequence (does **not** include Debloat & Optimize — run that separately if you want it):
      1. Rename Windows PC
      2. Install winget
      3. Update and Patch Windows
      4. Install winget packages
      5. Install Google Chrome
      6. Install custom fonts
      7. Install Windows Terminal, Oh My Posh, configure settings, and mise integration
      8. Install wallpapers
      9. Configure Git

### Exit

0. **Exit**: Closes the script.

## Configuration Files

- `winget_install.txt`: A list of applications to install via winget, grouped into commented categories (Browsers, CLI utilities, Editors/IDEs, etc.). Edit this file to customize which packages are installed during the "Install winget Packages" operation.
- `winget_uninstall.txt`: A list of applications to uninstall via winget, using the same categorized format as `winget_install.txt`. Edit this file to customize which packages are removed during the "Uninstall winget Packages" operation.
- `debloat_list.txt`: A list of built-in Windows apps to remove during "Debloat & Optimize Windows", grouped into commented categories (Xbox/gaming, Consumer chat/social, etc.). Edit this file to customize which apps are removed — comment out (`#`) or delete any line you want to keep.
- `configs/Terminal/settings.json`: Configuration file for Windows Terminal settings (colors, font, opacity, keybindings).

## Customization

You can customize the `win11Functions.ps1` script to modify existing tasks or add new ones according to your preferences. Each function in the script corresponds to a task in the `win11Setup.ps1` menu, making it easy to tailor the setup process to your needs. Additionally, edit the `winget_install.txt` and `winget_uninstall.txt` files to customize the packages that are installed or uninstalled.

## Contributing

Contributions to improve the scripts or add new functionality are welcome. Please feel free to fork the repository, make your changes, and submit a pull request.

## License

This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc/4.0/">Creative Commons Attribution-NonCommercial 4.0 International License</a>. See the LICENSE file for details.

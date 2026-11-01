# Functionality

This document explains how the Windows 11 Setup Script works. Read this to understand how the code connects, how data flows, and what each function does.

## System Overview

The Windows 11 Setup Script is a collection of PowerShell functions that automate a fresh Windows 11 Pro installation. It transforms a default Windows 11 system into a developer-friendly, privacy-conscious environment by:

1. Installing essential developer tools (Git, terminal, fonts, packages via winget).
2. Removing consumer-oriented bloatware and telemetry.
3. Applying privacy and performance optimizations via registry edits and service disabling.
4. Scheduling automated maintenance tasks to restore cleanliness after Windows updates.

The script is interactive — users select which tasks to run from a menu, execute them individually, or run all steps at once (excluding the destructive "Debloat" option, which must be opted into explicitly).

## How the Pieces Connect

```
┌─────────────────────────────────────────────────────────────────┐
│ win11Setup.ps1 (entry point & menu driver)                      │
│ • Checks for admin privileges                                   │
│ • Displays interactive menu in a loop                           │
│ • Sources all functions from win11Functions.ps1                 │
│ • Routes menu choices to appropriate functions                  │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ├─> Rename-WindowsPC
                           ├─> Install-Winget
                           ├─> Update-Patch-Windows
                           ├─> Install-WingetPackages
                           ├─> Uninstall-WingetPackages
                           ├─> Install-Chrome
                           ├─> Install-Fonts
                           ├─> Install-OhMyPosh
                           ├─> Install-Wallpapers
                           ├─> Install-Git-Config
                           ├─> Invoke-DebloatAndOptimize (orchestrator)
                           │   ├─> Remove-Bloatware
                           │   ├─> Optimize-WindowsPrivacyPerformance
                           │   ├─> Disable-UnneededServices
                           │   ├─> Optimize-ContextMenu
                           │   ├─> Remove-OneDrive
                           │   └─> Set-PowerPlan
                           ├─> Schedule-MaintenanceTask (orchestrator)
                           │   └─> Copies scripts/win11-maintenance.ps1
                           │       └─> Registers two scheduled tasks
                           └─> Invoke-All-Install-Tasks (orchestrator)
                               └─> Calls options 1-10 in sequence

┌─────────────────────────────────────────────────────────────────┐
│ scripts/win11-maintenance.ps1 (scheduled maintenance)           │
│ Runs via Windows Task Scheduler (Sunday 2 AM + 3 AM)            │
│ • Re-applies privacy tweaks if Windows updates reset them       │
│ • Re-disables services if updates re-enabled them              │
│ • Weekly mode: tweaks + services + context menu                │
│ • Monthly mode: weekly + OneDrive policy verification           │
│ • Logs all actions to timestamped log files                    │
└─────────────────────────────────────────────────────────────────┘
```

**Data flow:** Configuration files (`winget_install.txt`, `debloat_list.txt`, etc.) are read by their corresponding functions. Registry edits are applied locally to HKCU (user) or HKLM (system). Service states are queried and modified via PowerShell's `Get-Service` / `Set-Service`. Logs are written to the `logs/` directory.

## File by File Walkthrough

### win11Setup.ps1

**Purpose:** Entry point. Displays an interactive menu in a loop, checks admin privileges, and sources functions.

**Depends on:** win11Functions.ps1

**Key patterns:**
- Lines 12-16: Admin privilege check. Exits with error if not elevated.
- Lines 19-110: Infinite loop displaying menu, reading user choice, routing to functions via switch statement.
- Line 9: Sources all functions from win11Functions.ps1 into the current scope.

### win11Functions.ps1

**Purpose:** Contains all setup, debloating, and optimization functions. Organized into three sections: INSTALLATION FUNCTIONS, DEBLOATING & OPTIMIZATION FUNCTIONS, and ORCHESTRATORS.

**Depends on:** External tools (winget, PowerShell modules, registry access), configuration files (winget_install.txt, debloat_list.txt, configs/ directory).

**Key patterns:**
- Error handling: Most functions use `-ErrorAction SilentlyContinue` or `-ErrorAction Stop` to control behavior on failure.
- Logging: Functions write to log files in the `logs/` directory.
- User interaction: Some functions prompt the user (Rename-WindowsPC, Invoke-DebloatAndOptimize); others run silently.
- Idempotency: Most functions check if work is already done before proceeding (e.g., checking if winget is installed).

### scripts/win11-maintenance.ps1

**Purpose:** Standalone script that runs unattended via Windows Task Scheduler. Re-applies privacy tweaks and disables services if Windows updates reset them.

**Depends on:** No external dependencies. Contains inline copies of four key functions.

**Key patterns:**
- Parameters: Accepts `-Mode` (Weekly or Monthly) and `-LogDir` (defaults to user's AppData).
- Self-contained: Includes inline definitions of `Optimize-WindowsPrivacyPerformance`, `Disable-UnneededServices`, `Optimize-ContextMenu`, and `Remove-OneDrive` so it can run independently.
- Logging: All output is written to timestamped log files, not displayed to user.
- Non-interactive: No `Read-Host` or user prompts; runs unattended as SYSTEM.

## Function Entries

### Installation Functions (Menu Options 1-10)

#### Rename-WindowsPC

**Does:** Prompts the user for a new computer name and renames the Windows PC.

**Inputs:** Optional `-AutoConfirm` switch (used by `Invoke-All-Install-Tasks` to skip confirmation).

**Outputs:** Displays status messages; renames the computer via `Rename-Computer`. Requires restart to take effect.

**Why it exists:** First step in setting up a new machine; human-readable name for network identification.

**Side effects:** Computer name is changed; requires system restart.

---

#### Install-Winget

**Does:** Checks if Windows Package Manager (winget) is installed; if not, installs it from the Microsoft Desktop App Installer package.

**Inputs:** None.

**Outputs:** Displays status messages. Returns early if winget is already installed.

**Why it exists:** Foundation for all package management operations. Winget is not always present on fresh Windows 11 installs.

**Side effects:** Installs Windows Package Manager if missing.

---

#### Update-Patch-Windows

**Does:** Installs the PSWindowsUpdate module if missing, configures Microsoft Update as a service manager, and applies latest Windows updates and patches.

**Inputs:** None.

**Outputs:** Logs all updates to `C:\<ComputerName>_<Date>_MSUpdates.log`. Displays status messages.

**Why it exists:** Ensures the system has the latest security patches before other setup steps.

**Side effects:** Installs PowerShell modules, applies system updates, suppresses automatic reboot (user must restart manually).

---

#### Install-WingetPackages

**Does:** Reads application package IDs from `winget_install.txt`, installs each via winget if not already installed, logs results to `logs/winget_install.log`.

**Inputs:** `-ScriptDir` (path to script directory, used to locate `winget_install.txt`).

**Outputs:** Detailed log file with timestamp for each install attempt (success/failure/skip).

**Why it exists:** Bulk-installs developer tools and utilities. Customizable via `winget_install.txt`.

**Side effects:** Installs applications; creates/appends to log file.

---

#### Uninstall-WingetPackages

**Does:** Reads package IDs from `winget_uninstall.txt`, uninstalls each via winget if installed, logs results to `logs/winget_uninstall.log`.

**Inputs:** `-ScriptDir` (path to script directory, used to locate `winget_uninstall.txt`).

**Outputs:** Detailed log file with timestamp for each uninstall attempt.

**Why it exists:** Removes unwanted applications. Customizable via `winget_uninstall.txt`.

**Side effects:** Uninstalls applications; creates/appends to log file.

---

#### Install-Chrome

**Does:** Downloads Google Chrome installer and runs it silently; cleans up the installer file afterward.

**Inputs:** None.

**Outputs:** Displays status messages.

**Why it exists:** Installs a modern web browser as an alternative to Edge.

**Side effects:** Downloads and installs Chrome.

---

#### Install-Fonts

**Does:** Copies `.ttf` and `.otf` files from the `fonts/` directory to the Windows Fonts directory and registers them via registry (GDI notification) so apps find them by family name immediately without rebooting.

**Inputs:** `-ScriptDir` (path to script directory, used to locate `fonts/` folder).

**Outputs:** Status messages for each font; skips if no `fonts/` directory found.

**Why it exists:** Installs custom fonts (e.g., for terminal, code editors). Registration ensures immediate availability.

**Side effects:** Copies font files; modifies registry to notify GDI of new fonts.

---

#### Install-OhMyPosh

**Does:** Installs Windows Terminal and Oh My Posh via winget, attempts to install Fira Code Nerd Font, configures Windows Terminal settings, configures PowerShell profiles with mise initialization, copies the catppuccin_macchiato theme.

**Inputs:** `-ScriptDir` (path to script directory, used to locate Terminal settings and fallback font).

**Outputs:** Displays status messages; creates/overwrites PowerShell profile files.

**Why it exists:** Provides a modern terminal experience with customizable prompt. Mise integration enables tool version management.

**Side effects:** Installs packages, creates/modifies profile files, applies terminal configuration.

---

#### Install-Wallpapers

**Does:** Copies wallpaper files from `wallpapers/` directory to the user's Pictures folder, sets the first wallpaper (01.png) as the desktop background.

**Inputs:** `-ScriptDir` (path to script directory, used to locate `wallpapers/` folder).

**Outputs:** Displays status messages; sets wallpaper as background.

**Why it exists:** Customizes desktop appearance.

**Side effects:** Copies files, sets registry entries for desktop background.

---

#### Install-Git-Config

**Does:** Configures Git global settings (default branch, colors, editor, pull strategy), copies `.gitignore_global` from `configs/` if available, applies global excludes configuration.

**Inputs:** `-ScriptDir` (path to script directory, used to locate `.gitignore_global`).

**Outputs:** Displays final git config via `git config --list --global`.

**Why it exists:** Establishes consistent Git workflows across the machine. User must manually set username and email.

**Side effects:** Modifies git global configuration.

---

### Debloating & Optimization Functions (Helpers)

#### Remove-Bloatware

**Does:** Reads package names from `debloat_list.txt`, removes each Appx package via `Remove-AppxPackage` (for current user) and `Remove-AppxProvisionedPackage` (system-wide, so new accounts don't get them). Also uninstalls OneDrive via its uninstaller, applies OneDrive policy block, removes scheduled tasks, and disables consumer feature reinstallation via `DisableWindowsConsumerFeatures` policy.

**Inputs:** `-ScriptDir` (path to script directory, used to locate `debloat_list.txt`).

**Outputs:** Logs every action to `logs/debloat.log`.

**Why it exists:** Removes consumer bloatware and telemetry packages. Highly customizable via `debloat_list.txt`.

**Side effects:** Removes Appx packages, uninstalls OneDrive, modifies registry policies, removes scheduled tasks.

---

#### Optimize-WindowsPrivacyPerformance

**Does:** Applies ~20 registry tweaks to reduce telemetry, disable unwanted suggestions, improve privacy, and enable developer-friendly settings. Covers: telemetry level, Start menu suggestions, Cortana, Edge telemetry, Game DVR, developer mode, storage sense, Recall, OneDrive, Search cloud features, activity history, file explorer settings, taskbar widgets/chat, etc.

**Inputs:** None.

**Outputs:** Displays status messages; modifies registry.

**Why it exists:** Reduces data collection and UI clutter without breaking Windows functionality.

**Side effects:** Modifies HKCU and HKLM registry keys (idempotent — safe to re-run).

---

#### Disable-UnneededServices

**Does:** Disables a curated list of non-essential Windows services: DiagTrack, dmwappushservice, RetailDemo, Fax, wisvc, xbgm, XboxNetApiSvc, PcaSvc, DusmSvc, WerSvc. Stops each service and sets its startup type to Disabled.

**Inputs:** None.

**Outputs:** Displays status for each service; logs to console.

**Why it exists:** Reduces background telemetry and unnecessary resource consumption. Conservative selection avoids critical services.

**Side effects:** Stops and disables services (reversible via Services app).

---

#### Optimize-ContextMenu

**Does:** Disables unnecessary items in the Windows Explorer context menu (specifically, the "Share with" submenu via registry).

**Inputs:** None.

**Outputs:** Displays status messages.

**Why it exists:** Reduces UI clutter in right-click menus.

**Side effects:** Modifies registry (reversible).

---

#### Remove-OneDrive

**Does:** Stops the OneDrive process, uninstalls OneDrive via its uninstaller, applies the `DisableFileSyncNGSC` policy to block re-sync if Windows reinstalls it, removes OneDrive from the user's Default profile registry to prevent it from appearing for new accounts, removes OneDrive scheduled tasks, and unpins it from Explorer sidebar.

**Inputs:** None.

**Outputs:** Displays status messages; logs to console.

**Why it exists:** Removes Microsoft's cloud storage sync service while preserving local files for review.

**Side effects:** Uninstalls OneDrive, modifies registry policies, removes scheduled tasks.

---

#### Set-PowerPlan

**Does:** Detects whether the machine is a laptop (battery present) or desktop (no battery). Sets the power plan to "Balanced" with hibernation enabled for laptops, or "High Performance" with hibernation disabled for desktops.

**Inputs:** None.

**Outputs:** Displays status messages.

**Why it exists:** Optimizes power consumption and performance based on machine type.

**Side effects:** Changes Windows power plan settings.

---

### Orchestrator Functions

#### Invoke-DebloatAndOptimize

**Does:** Displays a confirmation prompt showing exactly what will be changed (lists of apps removed, services disabled, registry tweaks, etc.). On confirmation, calls in sequence: `Remove-Bloatware`, `Optimize-WindowsPrivacyPerformance`, `Disable-UnneededServices`, `Optimize-ContextMenu`, `Remove-OneDrive`, `Set-PowerPlan`.

**Inputs:** `-ScriptDir` (passed to `Remove-Bloatware`).

**Outputs:** Displays confirmation prompt and status messages from each sub-function.

**Why it exists:** Bundles all debloating and optimization tasks. Explicit confirmation prevents accidental system changes.

**Side effects:** All side effects of the six sub-functions listed above.

---

#### Schedule-MaintenanceTask

**Does:** Determines a safe installation directory (`C:\ProgramFiles\WindowsSetup` with fallback to user's AppData), copies `scripts/win11-maintenance.ps1` there, creates a `logs/` subdirectory, registers two scheduled tasks:
1. "Windows 11 Maintenance - Weekly": Triggers every Sunday at 2:00 AM, runs in Weekly mode.
2. "Windows 11 Maintenance - Monthly": Triggers every Sunday at 3:00 AM (every 4 weeks as approximation), runs in Monthly mode.

Both tasks run as `NT AUTHORITY\SYSTEM` with highest privilege level, won't stop if user logs off, and run even if network is unavailable.

**Inputs:** None.

**Outputs:** Displays configuration summary showing script location, logs location, task schedule, and management instructions.

**Why it exists:** Automates the maintenance process so privacy/performance tweaks are re-applied if Windows updates reset them.

**Side effects:** Copies script file, creates directories, registers scheduled tasks.

---

#### Invoke-All-Install-Tasks

**Does:** Calls options 1-10 in sequence with automatic confirmations where needed (e.g., passes `-AutoConfirm` to `Rename-WindowsPC`).

**Inputs:** `-ScriptDir` (passed to functions that need it).

**Outputs:** Status messages from each sub-function.

**Why it exists:** Bulk-runs all installation and configuration steps without user intervention between each step.

**Side effects:** All side effects of options 1-10.

---

## Known Limitations or Sharp Edges

1. **OneDrive Reinstall Handling:** The maintenance script re-applies the policy block, but if Windows feature updates later remove the policy, OneDrive may sync again. The `DisableFileSyncNGSC` policy is persistent but can be overridden by cumulative updates.

2. **Service Disabling is Not Removal:** Disabled services can be re-enabled manually via the Services app or by scripts. They are not permanently removed from the system. This is intentional for reversibility.

3. **Cortana App Kept Installed:** The debloat function does not remove the Cortana app itself (only disables its suggestions and tracking). Removing Cortana can break Windows Search. If you need Search to work, leave Cortana installed.

4. **Registry Tweaks Idempotent but not Authoritative:** Registry tweaks are safe to re-run, but a future Windows update may re-enable telemetry by resetting a registry key. The scheduled maintenance tasks help mitigate this.

5. **Task Scheduler Time Approximation:** The monthly task is scheduled for "every 4 weeks on Sunday at 3 AM" as an approximation of the first Sunday of each month, since Windows Task Scheduler does not natively support "first Sunday of the month" as a native recurrence. If precise first-Sunday scheduling is critical, manually adjust in Task Scheduler.

6. **No Automatic Rollback:** If a function fails partway through, there is no automatic rollback. Most changes are registry-based or service-disabling (easily reversible), but app removal is permanent unless the app is reinstalled via Microsoft Store or winget.

7. **Admin Privileges Required:** All functions require running as administrator. The entry point (`win11Setup.ps1`) checks for this and exits if privileges are insufficient.

8. **No Multi-User Support:** Registry tweaks apply to the current user (HKCU). System-wide settings (HKLM, services) are applied globally. If multiple users need the same customizations, run the script for each user.

---

## Changelog

| Date       | Change                                                                                                      |
| ---------- | ----------------------------------------------------------------------------------------------------------- |
| 2024-11-01 | Added scheduled maintenance task automation with weekly/monthly modes and comprehensive logging.             |
| 2024-10-31 | Expanded privacy tweaks to cover Edge, Cortana, File Explorer, Search; added 5 additional services.         |
| 2024-10-30 | Reorganized function file into three sections; fixed menu/function number alignment; removed deprecated functions. |
| 2024-10-29 | Initial comprehensive debloating and optimization implementation.                                           |


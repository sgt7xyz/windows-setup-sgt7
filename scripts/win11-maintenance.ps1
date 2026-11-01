#!/usr/bin/env pwsh

# ---------------------------------------------------------------
# File:     win11-maintenance.ps1
# Purpose:  Automated maintenance script that runs via Task Scheduler to maintain Windows 11 cleanliness
# Project:  Windows 11 Setup Script
# Author:   sgt7 LLC
# ---------------------------------------------------------------

<#
.SYNOPSIS
Windows 11 Maintenance Script - Periodically maintains Windows cleanliness

.DESCRIPTION
This script re-applies non-destructive privacy/performance tweaks that Windows updates
may have reset or reversed. It's designed to run unattended via Windows Task Scheduler.

Runs in two modes:
- WEEKLY: Re-applies registry tweaks, disables services, optimizes context menu
- MONTHLY: Includes weekly tasks plus re-applies OneDrive removal/blocking

.PARAMETER Mode
'Weekly' or 'Monthly' - determines what maintenance tasks to run

.PARAMETER LogDir
Directory for maintenance logs (defaults to %USERPROFILE%\AppData\Local\WindowsSetup\logs)

.EXAMPLE
.\win11-maintenance.ps1 -Mode Weekly
.\win11-maintenance.ps1 -Mode Monthly -LogDir "C:\Logs"

.NOTES
Requires: Administrator privileges
Run as: SYSTEM (via Task Scheduler)
#>

param(
    [ValidateSet('Weekly', 'Monthly')]
    [string]$Mode = 'Weekly',

    [string]$LogDir = $(Join-Path $env:USERPROFILE 'AppData\Local\WindowsSetup\logs')
)

# Ensure running as administrator
$isAdmin = [Security.Principal.WindowsIdentity]::GetCurrent().Groups -contains 'S-1-5-32-544'
if (-not $isAdmin) {
    Write-Error "This script requires administrator privileges."
    exit 1
}

# Create log directory if it doesn't exist
if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}

$LogFile = Join-Path $LogDir "maintenance_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"

Write-Host "Windows 11 Maintenance Task - $Mode Mode" -ForegroundColor Cyan
Write-Host "Logging to: $LogFile" -ForegroundColor Gray
Write-Host "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host

# ============================================================================================
# Inline Function Definitions (copied from win11Functions.ps1)
# These are included here so the script can run independently
# ============================================================================================

# Apply privacy/performance tweaks (telemetry, Start menu clutter, Recall, dev QoL settings)
function Optimize-WindowsPrivacyPerformance {
    Write-Host "Re-applying privacy and performance tweaks..." -ForegroundColor Yellow
    Add-Content -Path $LogFile -Value "$(Get-Date -Format o) INFO: Starting privacy/performance optimizations"

    try {
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

        # --- Taskbar: hide Widgets and Chat icons ---
        $AdvancedPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        if (-not (Test-Path $AdvancedPath)) {
            New-Item -Path $AdvancedPath -Force | Out-Null
        }
        Set-ItemProperty -Path $AdvancedPath -Name "TaskbarDa" -Value 0 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $AdvancedPath -Name "TaskbarMn" -Value 0 -Type DWord -ErrorAction SilentlyContinue

        # --- Dev-friendly Explorer settings ---
        Set-ItemProperty -Path $AdvancedPath -Name "HideFileExt" -Value 0 -Type DWord
        Set-ItemProperty -Path $AdvancedPath -Name "Hidden" -Value 1 -Type DWord

        # --- Long path support ---
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -Type DWord

        # --- Developer Mode ---
        $DevModePath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
        if (-not (Test-Path $DevModePath)) {
            New-Item -Path $DevModePath -Force | Out-Null
        }
        Set-ItemProperty -Path $DevModePath -Name "AllowDevelopmentWithoutDevLicense" -Value 1 -Type DWord

        # --- Game DVR / background recording ---
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

        # --- Storage Sense ---
        $StorageSensePath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy"
        if (-not (Test-Path $StorageSensePath)) {
            New-Item -Path $StorageSensePath -Force | Out-Null
        }
        Set-ItemProperty -Path $StorageSensePath -Name "01" -Value 1 -Type DWord

        # --- Recall (Copilot+ PCs) ---
        $AiPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
        if (-not (Test-Path $AiPolicyPath)) {
            New-Item -Path $AiPolicyPath -Force | Out-Null
        }
        Set-ItemProperty -Path $AiPolicyPath -Name "DisableAIDataAnalysis" -Value 1 -Type DWord

        # --- Edge integration ---
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
        Set-ItemProperty -Path $EdgePolicyPath -Name "PersonalizationReportingEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue

        # --- Cortana ---
        $CortanaPath = "HKCU:\SOFTWARE\Microsoft\Personalization\Settings"
        if (-not (Test-Path $CortanaPath)) {
            New-Item -Path $CortanaPath -Force | Out-Null
        }
        Set-ItemProperty -Path $CortanaPath -Name "AcceptedPrivacyPolicy" -Value 0 -Type DWord

        $CortanaSearchPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search"
        Set-ItemProperty -Path $CortanaSearchPath -Name "AllowSearchToUseLocation" -Value 0 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $CortanaSearchPath -Name "DeviceHistoryEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue

        # --- File Explorer ---
        Set-ItemProperty -Path $AdvancedPath -Name "NavPaneExpandToCurrentFolder" -Value 1 -Type DWord
        Set-ItemProperty -Path $AdvancedPath -Name "FullPath" -Value 1 -Type DWord

        # --- Search refinements ---
        Set-ItemProperty -Path $CortanaSearchPath -Name "IsAADCloudSearchEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue

        $ActivityHistoryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
        if (-not (Test-Path $ActivityHistoryPath)) {
            New-Item -Path $ActivityHistoryPath -Force | Out-Null
        }
        Set-ItemProperty -Path $ActivityHistoryPath -Name "EnableActivityFeed" -Value 0 -Type DWord -ErrorAction SilentlyContinue

        Write-Host "[OK] Privacy and performance tweaks re-applied" -ForegroundColor Green
        Add-Content -Path $LogFile -Value "$(Get-Date -Format o) SUCCESS: Privacy/performance optimizations completed"
    } catch {
        Write-Host "[FAIL] Error applying privacy tweaks: $_" -ForegroundColor Red
        Add-Content -Path $LogFile -Value "$(Get-Date -Format o) ERROR: Privacy tweaks failed - $_"
    }
}

# Disable a small set of non-essential services
function Disable-UnneededServices {
    Write-Host "Re-disabling non-essential services..." -ForegroundColor Yellow
    Add-Content -Path $LogFile -Value "$(Get-Date -Format o) INFO: Starting service optimization"

    $ServicesToDisable = @(
        "DiagTrack",
        "dmwappushservice",
        "RetailDemo",
        "Fax",
        "wisvc",
        "xbgm",
        "XboxNetApiSvc",
        "PcaSvc",
        "DusmSvc",
        "WerSvc"
    )

    $DisabledCount = 0
    foreach ($ServiceName in $ServicesToDisable) {
        $Service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if (-not $Service) {
            continue
        }

        try {
            Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
            Set-Service -Name $ServiceName -StartupType Disabled -ErrorAction Stop
            Write-Host "  [OK] Disabled: $ServiceName" -ForegroundColor Green
            Add-Content -Path $LogFile -Value "$(Get-Date -Format o) DISABLED: $ServiceName"
            $DisabledCount++
        } catch {
            Write-Host "  [FAIL] Failed to disable $ServiceName (non-critical)" -ForegroundColor Yellow
            Add-Content -Path $LogFile -Value "$(Get-Date -Format o) SKIP: $ServiceName - $_"
        }
    }

    Write-Host "[OK] Service optimization completed ($DisabledCount services processed)" -ForegroundColor Green
    Add-Content -Path $LogFile -Value "$(Get-Date -Format o) SUCCESS: Service optimization completed - $DisabledCount services"
}

# Remove unnecessary items from Windows Explorer context menu
function Optimize-ContextMenu {
    Write-Host "Optimizing context menu..." -ForegroundColor Yellow
    Add-Content -Path $LogFile -Value "$(Get-Date -Format o) INFO: Starting context menu optimization"

    try {
        New-Item -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked" -Force -ErrorAction SilentlyContinue | Out-Null
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked" -Name "{E2BF9676-5F8F-435C-97EB-11607A5BEDF7}" -Value "" -Type String -ErrorAction SilentlyContinue
        Write-Host "[OK] Context menu optimizations applied" -ForegroundColor Green
        Add-Content -Path $LogFile -Value "$(Get-Date -Format o) SUCCESS: Context menu optimization completed"
    } catch {
        Write-Host "[FAIL] Context menu optimization skipped (non-critical): $_" -ForegroundColor Yellow
        Add-Content -Path $LogFile -Value "$(Get-Date -Format o) SKIP: Context menu - $_"
    }
}

# Remove OneDrive (for monthly maintenance)
function Remove-OneDrive {
    Write-Host "Checking OneDrive status..." -ForegroundColor Yellow
    Add-Content -Path $LogFile -Value "$(Get-Date -Format o) INFO: Checking OneDrive"

    try {
        Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue

        # Re-apply policy block
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" -Force -ErrorAction SilentlyContinue | Out-Null
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" -Name "DisableFileSyncNGSC" -Value 1 -Type DWord -ErrorAction SilentlyContinue

        Write-Host "[OK] OneDrive policy block re-applied" -ForegroundColor Green
        Add-Content -Path $LogFile -Value "$(Get-Date -Format o) SUCCESS: OneDrive policy block verified/re-applied"
    } catch {
        Write-Host "[FAIL] OneDrive check failed (non-critical): $_" -ForegroundColor Yellow
        Add-Content -Path $LogFile -Value "$(Get-Date -Format o) WARNING: OneDrive check - $_"
    }
}

# ============================================================================================
# Main Execution
# ============================================================================================

Write-Host "Running $Mode maintenance mode..." -ForegroundColor Cyan
Add-Content -Path $LogFile -Value "$(Get-Date -Format o) ============= START: $Mode Maintenance ============="

# Always run these
Optimize-WindowsPrivacyPerformance
Disable-UnneededServices
Optimize-ContextMenu

# Run OneDrive check only in Monthly mode
if ($Mode -eq 'Monthly') {
    Remove-OneDrive
}

Write-Host
Write-Host "Maintenance completed successfully!" -ForegroundColor Green
Write-Host "Log file: $LogFile" -ForegroundColor Gray
Add-Content -Path $LogFile -Value "$(Get-Date -Format o) ============= END: $Mode Maintenance ============="
Add-Content -Path $LogFile -Value ""

exit 0

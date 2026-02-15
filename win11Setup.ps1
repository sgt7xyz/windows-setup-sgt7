#!/usr/bin/env pwsh

# PowerShell script for Windows 11 setup

# Get the script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Source the functions from win11Functions.ps1
. (Join-Path $scriptDir "win11Functions.ps1")

# Check if running as administrator
$isAdmin = [Security.Principal.WindowsIdentity]::GetCurrent().Groups -contains 'S-1-5-32-544'
if (-not $isAdmin) {
    Write-Error "This script requires administrator privileges. Please run PowerShell as Administrator and try again."
    exit 1
}

# Menu for selecting the installation steps
while ($true) {
    Write-Host
    Write-Host "==============================================="
    Write-Host "         Windows 11 Setup Script"
    Write-Host "==============================================="
    Write-Host "Please select an option:"
    Write-Host
    Write-Host "  System Configuration:"
    Write-Host "1.  Rename Windows PC"
    Write-Host "2.  Install Windows Package Manager (winget)"
    Write-Host "3.  Update and patch Windows"
    Write-Host
    Write-Host "  Package Management:"
    Write-Host "4.  Install winget Packages"
    Write-Host "5.  Uninstall winget Packages"
    Write-Host
    Write-Host "  Applications & Tools:"
    Write-Host "6.  Install Google Chrome"
    Write-Host "7.  Install Fonts"
    Write-Host "8.  Install Windows Terminal and Oh My Posh (with settings)"
    Write-Host "9.  Install Wallpapers"
    Write-Host "10. Configure Git"
    Write-Host
    Write-Host "11. Execute all steps"
    Write-Host "0.  Exit"
    Write-Host
    $choice = Read-Host "Enter the number of your choice"

    switch ($choice) {
        "1" {
            Rename-WindowsPC
        }
        "2" {
            Install-Winget
        }
        "3" {
            Update-Patch-Windows
        }
        "4" {
            Install-WingetPackages -ScriptDir $scriptDir
        }
        "5" {
            Uninstall-WingetPackages -ScriptDir $scriptDir
        }
        "6" {
            Install-Chrome
        }
        "7" {
            Install-Fonts -ScriptDir $scriptDir
        }
        "8" {
            Install-OhMyPosh -ScriptDir $scriptDir
        }
        "9" {
            Install-Wallpapers -ScriptDir $scriptDir
        }
        "10" {
            Install-Git-Config -ScriptDir $scriptDir
        }
        "11" {
            Write-Host "Executing all setup steps..."
            Write-Host
            Invoke-All-Install-Tasks -ScriptDir $scriptDir
            Write-Host
            Write-Host "All setup steps completed!"
        }
        "0" {
            Write-Host "Exiting."
            exit
        }
        default {
            Write-Host "Invalid option. Please try again."
        }
    }

    if ($choice -ne "0") {
        Write-Host
        Write-Host "Press Enter to continue..."
        Read-Host
    }
}
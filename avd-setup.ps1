<#
.SYNOPSIS
    Windows 11 Development Environment Setup Script
.DESCRIPTION
    This script automates the installation and updates for:
    - Windows Subsystem for Linux (WSL) with Ubuntu
    - Software via winget
    - VS Code Extensions
    - Hack Nerd Font
.PARAMETER Mode
    'init' - Performs initial installation
    'update' - Performs system updates
.EXAMPLE
    .\setup-dev-env.ps1 -Mode init
    .\setup-dev-env.ps1 -Mode update
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('init', 'update', 'help')]
    [string]$Mode
)

# Global variables
$ErrorActionPreference = "Stop"
$configFiles = @{
    Software = ".\software_packages.txt"
    VSCodeExtensions = ".\vscode_extensions.txt"
}

function Install-WSL {
    <#
    .DESCRIPTION
        Installs and configures WSL2 with Ubuntu
    #>
    Write-Host "#### WSL Installation and Configuration ####" -ForegroundColor Green
    try {
        # Check if WSL is already installed
        $wslStatus = wsl --status
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Installing WSL..." -ForegroundColor Yellow
            wsl --install
            wsl --set-default-version 2
        }
        
        # Check if Ubuntu is already installed
        $ubuntuInstalled = wsl -l | Select-String "Ubuntu-24.04"
        if (-not $ubuntuInstalled) {
            Write-Host "Installing Ubuntu 24.04..." -ForegroundColor Yellow
            wsl --install -d Ubuntu-24.04
        }
    }
    catch {
        Write-Host "Error during WSL installation: $_" -ForegroundColor Red
        throw
    }
}

function Install-HackNerdFont {
    <#
    .DESCRIPTION
        Downloads and installs the latest Hack Nerd Font without prompting
    #>
    Write-Host "#### Hack Nerd Font Installation ####" -ForegroundColor Green
    
    $tempDir = Join-Path $env:TEMP "NerdFonts"
    $hackFontUrl = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip"
    $zipPath = Join-Path $tempDir "Hack.zip"
    $fontDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
    
    try {
        # Prepare directory
        if (Test-Path $tempDir) { Remove-Item -Path $tempDir -Recurse -Force }
        New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
        
        # Download and extract font
        Write-Host "Downloading Hack Nerd Font..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $hackFontUrl -OutFile $zipPath
        Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force
        
        # Install fonts
        Get-ChildItem -Path $tempDir -Filter "*.ttf" | ForEach-Object {
            Write-Host "Installing Font: $($_.Name)" -ForegroundColor Yellow
            
            # Target path for font file
            $fontPath = Join-Path $fontDir $_.Name
            
            try {
                # Try to remove existing font file if it exists
                if (Test-Path $fontPath) {
                    # Wait for file to be free
                    $retryCount = 0
                    $maxRetries = 3
                    $success = $false

                    while (-not $success -and $retryCount -lt $maxRetries) {
                        try {
                            Remove-Item -Path $fontPath -Force
                            $success = $true
                        }
                        catch {
                            $retryCount++
                            if ($retryCount -lt $maxRetries) {
                                Write-Host "Font file in use, retrying in 2 seconds..." -ForegroundColor Yellow
                                Start-Sleep -Seconds 2
                            }
                        }
                    }

                    if (-not $success) {
                        Write-Host "Warning: Could not remove existing font file: $($_.Name)" -ForegroundColor Yellow
                        continue
                    }
                }

                # Copy font file
                Copy-Item -Path $_.FullName -Destination $fontPath -Force
                
                # Register font in system
                $fontRegistryPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
                $fontRegistryName = $_.Name -replace ".ttf$", " (TrueType)"
                
                # Remove existing registry entry if present
                Remove-ItemProperty -Path $fontRegistryPath -Name $fontRegistryName -ErrorAction SilentlyContinue
                
                # Create new registry entry
                New-ItemProperty -Path $fontRegistryPath -Name $fontRegistryName -Value $fontPath -PropertyType String -Force | Out-Null
            }
            catch {
                Write-Host "Warning: Could not install font: $($_.Name) - $_" -ForegroundColor Yellow
            }
        }
        
        Write-Host "Hack Nerd Font installation completed!" -ForegroundColor Green
    }
    catch {
        Write-Host "Error during font installation: $_" -ForegroundColor Red
        throw
    }
    finally {
        if (Test-Path $tempDir) { Remove-Item -Path $tempDir -Recurse -Force }
    }
}


function Install-SoftwarePackages {
    <#
    .DESCRIPTION
        Installs software packages via winget from software_packages.txt
        Automatically runs with admin rights
    #>
    Write-Host "#### Software Installation via winget ####" -ForegroundColor Green
    
    try {
        # Check configuration file existence
        $softwareListPath = (Resolve-Path $configFiles.Software).Path
        if (-not (Test-Path $softwareListPath)) {
            throw "Software package list not found: $softwareListPath"
        }

        # Create temporary script for admin execution
        $tempScriptPath = Join-Path $env:TEMP "InstallSoftware.ps1"
        $scriptContent = @"
`$ErrorActionPreference = 'Stop'
Write-Host "Starting software installation with admin rights..." -ForegroundColor Green

Get-Content "$softwareListPath" | Where-Object { `$_.Trim() -ne "" } | ForEach-Object {
    `$package = `$_.Trim()
    Write-Host "Installing `$package..." -ForegroundColor Yellow
    winget install `$package --accept-source-agreements --accept-package-agreements
}

Write-Host "Software installation completed." -ForegroundColor Green
"@
        
        # Write temporary script
        Set-Content -Path $tempScriptPath -Value $scriptContent

        # Execute script with admin rights
        Write-Host "Requesting admin rights for software installation..." -ForegroundColor Yellow
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tempScriptPath`"" -Verb RunAs -Wait

        # Cleanup
        Remove-Item -Path $tempScriptPath -Force
    }
    catch {
        Write-Host "Error during software installation: $_" -ForegroundColor Red
        throw
    }
}

function Install-VSCodeExtensions {
    <#
    .DESCRIPTION
        Installs VS Code Extensions from vscode_extensions.txt
    #>
    Write-Host "#### VS Code Extensions Installation ####" -ForegroundColor Green
    
    try {
        # Check VS Code availability
        $vscodePath = (Get-Command code -ErrorAction Stop).Path
        Write-Host "VS Code found: $vscodePath" -ForegroundColor Green
        
        if (-not (Test-Path $configFiles.VSCodeExtensions)) {
            throw "Extensions list not found: $($configFiles.VSCodeExtensions)"
        }
        
        Get-Content $configFiles.VSCodeExtensions | Where-Object { $_.Trim() -ne "" } | ForEach-Object {
            $extension = $_.Trim()
            Write-Host "Installing/Updating Extension: $extension" -ForegroundColor Yellow
            
            # First try to install normally
            $result = & $vscodePath --install-extension $extension 2>&1
            
            # If the extension is already installed, try with --force
            if ($result -match "already installed") {
                Write-Host "Extension $extension already installed, updating..." -ForegroundColor Cyan
                & $vscodePath --install-extension $extension --force
            }
            
            # Small delay to prevent potential race conditions
            Start-Sleep -Milliseconds 500
        }
    }
    catch {
        Write-Host "Error during extension installation: $_" -ForegroundColor Red
        throw
    }
}


function Update-Software {
    <#
    .DESCRIPTION
        Performs system updates (winget and Nerd Fonts)
        Updates only packages from software_packages.txt
    #>
    Write-Host "#### System Updates ####" -ForegroundColor Green
    
    try {
        # Check configuration file existence
        $softwareListPath = (Resolve-Path $configFiles.Software).Path
        if (-not (Test-Path $softwareListPath)) {
            throw "Software package list not found: $softwareListPath"
        }

        # Create temporary script for admin execution
        $tempScriptPath = Join-Path $env:TEMP "UpdateSoftware.ps1"
        $scriptContent = @"
`$ErrorActionPreference = 'Stop'
Write-Host "Starting system updates with admin rights..." -ForegroundColor Green

# Read package list
`$packages = Get-Content "$softwareListPath" | Where-Object { `$_.Trim() -ne "" }

foreach (`$package in `$packages) {
    `$package = `$package.Trim()
    Write-Host "Checking updates for `$package..." -ForegroundColor Yellow
    
    `$installed = winget list --exact -q `$package
    if (`$installed -match `$package) {
        Write-Host "Updating `$package..." -ForegroundColor Cyan
        winget upgrade `$package --accept-source-agreements --accept-package-agreements
    } else {
        Write-Host "`$package is not installed, skipping update." -ForegroundColor Yellow
    }
}

Write-Host "System updates completed." -ForegroundColor Green
"@
        
        # Write temporary script
        Set-Content -Path $tempScriptPath -Value $scriptContent

        # Execute updates with admin rights
        Write-Host "Requesting admin rights for system updates..." -ForegroundColor Yellow
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tempScriptPath`"" -Verb RunAs -Wait

        # Cleanup
        Remove-Item -Path $tempScriptPath -Force

        Install-VSCodeExtensions
        
        # Nerd Font Update (runs as normal user)
        Install-HackNerdFont
    }
    catch {
        Write-Host "Error during update: $_" -ForegroundColor Red
        throw
    }
}

function Show-Help {
    Write-Host @"
Windows 11 Development Environment Setup Script
===============================================

DESCRIPTION
-----------
This script automates the installation and configuration of a development environment
on Windows 11, including WSL, software packages, VS Code extensions, and Nerd Fonts.

USAGE
-----
.\setup-dev-env.ps1 -Mode <mode>

Modes:
    init   : Performs initial installation
    update : Updates installed components
    help   : Shows this help message

REQUIRED FILES
-------------
1. software_packages.txt
   Location: Same directory as script
   Content: One package ID per line for winget installations
   Example:
    Microsoft.VisualStudioCode
    Git.Git
    Microsoft.PowerShell
    Microsoft.WindowsTerminal

2. vscode_extensions.txt
   Location: Same directory as script
   Content: One extension ID per line
   Example:
    ms-vscode-remote.remote-wsl
    ms-python.python
    GitHub.copilot

EXAMPLES
--------
Initial setup:
    .\setup-dev-env.ps1 -Mode init

Update existing installation:
    .\setup-dev-env.ps1 -Mode update

Show this help:
    .\setup-dev-env.ps1 -Mode help

NOTES
-----
- Script requires administrator rights for some operations
- WSL installation may require a system restart
- Internet connection required for downloads
"@
    exit 0
}

# Main program
try {
    if ($Mode -eq 'help') {
        Show-Help
    }
    
    Write-Host "Starting Development Environment Setup in mode: $Mode" -ForegroundColor Cyan
    
    switch ($Mode) {
        'init' {
            Install-WSL
            Install-SoftwarePackages
            Install-VSCodeExtensions
            Install-HackNerdFont
        }
        'update' {
            Update-Software
        }
    }
    
    Write-Host "Setup completed successfully!" -ForegroundColor Green
}
catch {
    Write-Host "Critical error during setup: $_" -ForegroundColor Red
    exit 1
}

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("init", "update")]
    [string]$Mode
)

if ($Mode -eq "init") {
    # 1. Install WSL and Ubuntu 24.04 (only if not present)
    $wslInstalled = wsl -l -q | Where-Object { $_ -eq "Ubuntu-24.04" }
    if (-not $wslInstalled) {
        wsl --install -d Ubuntu-24.04

        # Wait until WSL is installed
        Write-Host "Please wait, WSL and Ubuntu 24.04 are being installed..."
        $wslReady = $false
        while (-not $wslReady) {
            Start-Sleep -Seconds 5
            $dists = wsl --list --online 2>$null
            if ($dists -match "Ubuntu-24.04") {
                $wslReady = $true
            }
        }
        # Note for user: On first start of Ubuntu-24.04, username and password will be requested
        Write-Host "On first start of Ubuntu 24.04, please set username and password."
    } else {
        Write-Host "WSL with Ubuntu 24.04 is already installed."
    }

    # 2. Install Chocolatey (only if not present)
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "Installing Chocolatey..."
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    } else {
        Write-Host "Chocolatey is already installed."
    }

    # 3. Install tools via Chocolatey
    $tools = @(
        # Rancher Desktop with auto-updates disabled
        "rancher-desktop --params=\"/NoAutoUpdates:true\"",
        "vscode",
        "git",
        # Azure Data Studio with auto-updates disabled
        # "azure-data-studio --params=\"/NoAutoUpdates:true\"",
    )
    $vscodeExtensions = @(
        "ms-vscode-remote.remote-containers",
        # "ms-azuretools.vscode-containers"
    )

    foreach ($tool in $tools) {
        Write-Host "Installing $tool ..."
        choco install $tool -y --ignore-checksums
    }

    # Install VS Code Extensions (only if VS Code is installed)
    if (Get-Command code -ErrorAction SilentlyContinue) {
        Write-Host "Installing VS Code extensions..."
        $installed = code --list-extensions
        foreach ($ext in $vscodeExtensions) {
            if ($installed -notcontains $ext) {
                code --install-extension $ext --force
            }
        }
    } else {
        Write-Host "VS Code is not installed, skipping extensions."
    }

    Write-Host "Done! All tools have been installed."
}
elseif ($Mode -eq "update") {
    # Check prerequisites
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "Error: Chocolatey is not installed. Please run 'init' first."
        exit 1
    }
    if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
        Write-Host "Error: Visual Studio Code is not installed. Please run 'init' first."
        exit 1
    }

    # Update components
    Write-Host "Upgrading Chocolatey itself..."
    choco upgrade chocolatey -y

    # Upgrade all installed Chocolatey packages
    Write-Host "Upgrading all installed Chocolatey packages..."
    choco upgrade all -y --ignore-checksums

    # Upgrade all installed VS Code extensions
    Write-Host "Upgrading all installed VS Code extensions..."
    $installedExtensions = code --list-extensions
    foreach ($ext in $installedExtensions) {
        code --install-extension $ext --force
    }

    Write-Host "Running update for Ubuntu 24.04 (WSL)..."
    wsl -d Ubuntu-24.04 -- sh -c "sudo apt update && sudo apt upgrade -y"

    Write-Host "Update completed."
}
else {
    Write-Host "Invalid mode. Please specify 'init' or 'update'."
}

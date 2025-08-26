# Parameter für Init oder Update
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('init', 'update')]
    [string]$Mode
)

# Funktion zur WSL-Aktivierung und Update
function Install-WSL {
    Write-Host "Aktiviere und aktualisiere WSL..." -ForegroundColor Green
    # WSL aktivieren und auf Version 2 setzen [[1]]
    wsl --install
    wsl --set-default-version 2
    
    # Ubuntu installieren [[2]]
    wsl --install -d Ubuntu-24.04
}

# Funktion zur Software-Installation via winget
function Install-SoftwarePackages {
    Write-Host "Installiere Software über winget..." -ForegroundColor Green
    # Lese Software-Pakete aus der Datei
    $packages = Get-Content ".\software_packages.txt"
    
    foreach ($package in $packages) {
        if ($package.Trim() -ne "") {
            Write-Host "Installiere $package..."
            winget install $package --accept-source-agreements --accept-package-agreements
        }
    }
}

# Funktion zur Installation von VS Code Extensions
function Install-VSCodeExtensions {
    Write-Host "Prüfe VS Code Installation..." -ForegroundColor Green
    
    # Prüfe ob VS Code installiert ist
    if (Test-Path "C:\Users\$env:USERNAME\AppData\Local\Programs\Microsoft VS Code\code.exe") {
        Write-Host "Installiere VS Code Extensions..." -ForegroundColor Green
        $extensions = Get-Content ".\vscode_extensions.txt"
        
        foreach ($extension in $extensions) {
            if ($extension.Trim() -ne "") {
                Write-Host "Installiere Extension: $extension"
                code --install-extension $extension
            }
        }
    } else {
        Write-Host "VS Code ist nicht installiert." -ForegroundColor Yellow
    }
}

# Funktion für Updates
function Update-Software {
    Write-Host "Führe winget-Updates durch..." -ForegroundColor Green
    winget upgrade --all
}

# Hauptlogik
switch ($Mode) {
    'init' {
        Install-WSL
        Install-SoftwarePackages
        Install-VSCodeExtensions
    }
    'update' {
        Update-Software
    }
}

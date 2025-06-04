param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("init", "update")]
    [string]$Mode
)

if ($Mode -eq "init") {
    # 1. WSL und Ubuntu 24.04 installieren (nur wenn nicht vorhanden)
    $wslInstalled = wsl --list --quiet | Select-String -SimpleMatch "Ubuntu-24.04"
    if (-not $wslInstalled) {
        wsl --install -d Ubuntu-24.04

        # Warten, bis WSL installiert ist
        Write-Host "Bitte warten, WSL und Ubuntu 24.04 werden installiert..."
        $wslReady = $false
        while (-not $wslReady) {
            Start-Sleep -Seconds 5
            $dists = wsl --list --online 2>$null
            if ($dists -match "Ubuntu-24.04") {
                $wslReady = $true
            }
        }
        # Hinweis für User: Beim ersten Start von Ubuntu-24.04 wird das Passwort abgefragt
        Write-Host "Beim ersten Start von Ubuntu 24.04 bitte Benutzername und Passwort festlegen."
    } else {
        Write-Host "WSL mit Ubuntu 24.04 ist bereits installiert."
    }

    # 2. Chocolatey installieren (nur wenn nicht vorhanden)
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "Installiere Chocolatey..."
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    } else {
        Write-Host "Chocolatey ist bereits installiert."
    }

    # 3. Tools via Chocolatey installieren
    $tools = @(
        # Rancher Desktop mit deaktivierten Auto-Updates
        "rancher-desktop --params=\"/NoAutoUpdates:true\"",
        "vscode",
        "git",
        # Azure Data Studio mit deaktivierten Auto-Updates
        # "azure-data-studio --params=\"/NoAutoUpdates:true\"",
    )
    $vscodeExtensions = @(
        "ms-vscode-remote.remote-containers",
        # "ms-azuretools.vscode-containers"
    )

    foreach ($tool in $tools) {
        Write-Host "Installiere $tool ..."
        choco install $tool -y --ignore-checksums
    }

    # VS Code Extensions installieren (nur wenn VS Code installiert ist)
    if (Get-Command code -ErrorAction SilentlyContinue) {
        Write-Host "Installiere VS Code Extensions..."
        foreach ($ext in $vscodeExtensions) {
            code --install-extension $ext --force
        }
    } else {
        Write-Host "VS Code ist nicht installiert, Extensions werden übersprungen."
    }

    Write-Host "Fertig! Alle Tools wurden installiert."
}
elseif ($Mode -eq "update") {
    # Vorbedingungen prüfen
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "Fehler: Chocolatey ist nicht installiert. Bitte zuerst 'init' ausführen."
        exit 1
    }
    if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
        Write-Host "Fehler: Visual Studio Code ist nicht installiert. Bitte zuerst 'init' ausführen."
        exit 1
    }

    # Komponenten aktualisieren
    Write-Host "Aktualisiere Chocolatey selbst..."
    choco upgrade chocolatey -y

    # Alle installierten Chocolatey-Pakete aktualisieren
    Write-Host "Aktualisiere alle installierten Chocolatey-Pakete..."
    choco upgrade all -y --ignore-checksums

    # Alle installierten VS Code Extensions aktualisieren
    Write-Host "Aktualisiere alle installierten VS Code Extensions..."
    $installedExtensions = code --list-extensions
    foreach ($ext in $installedExtensions) {
        code --install-extension $ext --force
    }

    Write-Host "Führe Update für Ubuntu 24.04 (WSL) aus..."
    wsl -d Ubuntu-24.04 -- sh -c "sudo apt update && sudo apt upgrade -y"

    Write-Host "Update abgeschlossen."
}
else {
    Write-Host "Ungültiger Modus. Bitte 'init' oder 'update' angeben."
}

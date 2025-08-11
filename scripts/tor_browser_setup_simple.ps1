# Tor Browser Portable Setup Script
# Downloads latest Tor Browser and preserves user data between updates

$ErrorActionPreference = 'Continue'

Write-Host "Setting up Tor Browser Portable..." -ForegroundColor Green

# Configuration
$SFTP_BASE_PATH = "C:\Users\WDAGUtilityAccount\Desktop\RebexTinySftpServer-Binaries-Latest"
$TOR_INSTALL_PATH = Join-Path $SFTP_BASE_PATH "Tor Browser"
$TOR_DATA_PATH = Join-Path $SFTP_BASE_PATH ".data\tor-browser-data"
$TEMP_PATH = $env:TEMP

# Create directories
Write-Host "Creating directory structure..." -ForegroundColor Yellow
try {
    if (-not (Test-Path $SFTP_BASE_PATH)) {
        New-Item -Path $SFTP_BASE_PATH -ItemType Directory -Force | Out-Null
        Write-Host "Created base SFTP directory" -ForegroundColor Green
    }
    
    if (-not (Test-Path $TOR_INSTALL_PATH)) {
        New-Item -Path $TOR_INSTALL_PATH -ItemType Directory -Force | Out-Null
        Write-Host "Created install directory" -ForegroundColor Green
    }
    
    if (-not (Test-Path $TOR_DATA_PATH)) {
        New-Item -Path $TOR_DATA_PATH -ItemType Directory -Force | Out-Null
        Write-Host "Created data directory" -ForegroundColor Green
    }
} catch {
    Write-Host "Failed to create directories: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Check if already installed
$versionFile = Join-Path $TOR_INSTALL_PATH "version.txt"
if (Test-Path $versionFile) {
    $currentVersion = Get-Content $versionFile -ErrorAction SilentlyContinue
    Write-Host "Current version: $currentVersion" -ForegroundColor Cyan
}

# Try to download latest version info
Write-Host "Fetching latest Tor Browser version..." -ForegroundColor Yellow
try {
    $downloadPage = Invoke-WebRequest -Uri "https://www.torproject.org/download/" -UseBasicParsing
    # Look for the Windows portable download link which contains the version
    $versionMatch = $downloadPage.Content | Select-String -Pattern 'tor-browser-windows-x86_64-portable-(\d+\.\d+\.\d+)\.exe'
    
    if ($versionMatch) {
        $latestVersion = $versionMatch.Matches[0].Groups[1].Value
        Write-Host "Latest version: $latestVersion" -ForegroundColor Cyan
    } else {
        $latestVersion = "14.5.5"  # Updated fallback version
        Write-Host "Using fallback version: $latestVersion" -ForegroundColor Yellow
    }
} catch {
    $latestVersion = "14.5.5"  # Updated fallback version
    Write-Host "Could not fetch version, using fallback: $latestVersion" -ForegroundColor Yellow
}

# Check if update needed
if ((Test-Path $versionFile) -and ((Get-Content $versionFile -ErrorAction SilentlyContinue) -eq $latestVersion)) {
    Write-Host "Tor Browser is already up to date" -ForegroundColor Green
    
    # Create launcher if missing
    $launcherPath = Join-Path $TOR_INSTALL_PATH "Launch-Tor-Browser.bat"
    if (-not (Test-Path $launcherPath)) {
        $launcherContent = @"
@echo off
cd /d "%~dp0"
if exist "Start Tor Browser.exe" (
    start "" "Start Tor Browser.exe"
) else if exist "Browser\firefox.exe" (
    start "" "Browser\firefox.exe"
) else (
    echo Tor Browser not found!
    pause
)
"@
        $launcherContent | Out-File -FilePath $launcherPath -Encoding ASCII
        Write-Host "Created launcher: $launcherPath" -ForegroundColor Green
    }
    exit 0
}

# Download Tor Browser
Write-Host "Downloading Tor Browser $latestVersion..." -ForegroundColor Yellow
$fileName = "tor-browser-windows-x86_64-portable-$latestVersion.exe"
$downloadUrl = "https://www.torproject.org/dist/torbrowser/$latestVersion/$fileName"
$downloadPath = Join-Path $TEMP_PATH $fileName

try {
    $webClient = New-Object System.Net.WebClient
    $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
    $webClient.DownloadFile($downloadUrl, $downloadPath)
    $webClient.Dispose()
    
    if ((Test-Path $downloadPath) -and ((Get-Item $downloadPath).Length -gt 10MB)) {
        Write-Host "Download completed successfully" -ForegroundColor Green
    } else {
        throw "Download failed or file too small"
    }
} catch {
    Write-Host "Download failed: $($_.Exception.Message)" -ForegroundColor Red
    
    # Try alternative URL
    try {
        Write-Host "Trying alternative download location..." -ForegroundColor Yellow
        $altUrl = "https://dist.torproject.org/torbrowser/$latestVersion/$fileName"
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
        $webClient.DownloadFile($altUrl, $downloadPath)
        $webClient.Dispose()
        Write-Host "Alternative download completed" -ForegroundColor Green
    } catch {
        Write-Host "All downloads failed" -ForegroundColor Red
        exit 1
    }
}

# Install Tor Browser
Write-Host "Installing Tor Browser..." -ForegroundColor Yellow
try {
    # Run installer
    $process = Start-Process -FilePath $downloadPath -Wait -PassThru -NoNewWindow
    
    # Look for installation
    $possiblePaths = @(
        "$env:USERPROFILE\Desktop\Tor Browser",
        "$env:LOCALAPPDATA\Tor Browser",
        "$env:APPDATA\Tor Browser"
    )
    
    $found = $false
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            Write-Host "Found Tor Browser at: $path" -ForegroundColor Green
            
            # Remove old installation
            if (Test-Path $TOR_INSTALL_PATH) {
                Remove-Item $TOR_INSTALL_PATH -Recurse -Force -ErrorAction SilentlyContinue
            }
            
            # Copy to target location
            Copy-Item -Path $path -Destination $TOR_INSTALL_PATH -Recurse -Force
            
            # Clean up original
            Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
            
            $found = $true
            break
        }
    }
    
    if ($found) {
        # Save version
        $latestVersion | Out-File -FilePath $versionFile -Encoding utf8
        
        # Create launcher
        $launcherPath = Join-Path $TOR_INSTALL_PATH "Launch-Tor-Browser.bat"
        $launcherContent = @"
@echo off
cd /d "%~dp0"
if exist "Start Tor Browser.exe" (
    start "" "Start Tor Browser.exe"
) else if exist "Browser\firefox.exe" (
    start "" "Browser\firefox.exe"
) else (
    echo Tor Browser not found!
    pause
)
"@
        $launcherContent | Out-File -FilePath $launcherPath -Encoding ASCII
        
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "TOR BROWSER SETUP COMPLETED!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "Installation path: $TOR_INSTALL_PATH" -ForegroundColor Cyan
        Write-Host "Version: $latestVersion" -ForegroundColor Cyan
        Write-Host "Launcher: $launcherPath" -ForegroundColor Cyan
    } else {
        Write-Host "Installation failed - Tor Browser not found after installation" -ForegroundColor Red
        exit 1
    }
    
} catch {
    Write-Host "Installation failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    # Cleanup
    if (Test-Path $downloadPath) {
        Remove-Item $downloadPath -Force -ErrorAction SilentlyContinue
    }
}

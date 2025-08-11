# Brave Browser Portable Setup Script
# Downloads latest Brave and preserves user data between updates

$ErrorActionPreference = 'Continue'

Write-Host "[INFO] Setting up Brave Browser Portable..." -ForegroundColor Green

# Configuration - Use paths that work in sandbox environment
$SFTP_BASE_PATH = "C:\Users\WDAGUtilityAccount\Desktop\RebexTinySftpServer-Binaries-Latest"
$BRAVE_INSTALL_PATH = if (Test-Path $SFTP_BASE_PATH) { 
    Join-Path $SFTP_BASE_PATH "brave-portable" 
} else { 
    Join-Path $env:USERPROFILE "Desktop\brave-portable" 
}
$BRAVE_DATA_PATH = if (Test-Path $SFTP_BASE_PATH) { 
    Join-Path $SFTP_BASE_PATH ".data\brave-user-data" 
} else { 
    Join-Path $env:USERPROFILE "Documents\brave-user-data" 
}
$GITHUB_API_URL = "https://api.github.com/repos/brave/brave-browser/releases/latest"
$TEMP_PATH = $env:TEMP

# Ensure directories exist with robust error handling
Write-Host "[INFO] Creating directory structure..." -ForegroundColor Yellow
Write-Host "  → Install path: $BRAVE_INSTALL_PATH" -ForegroundColor Cyan
Write-Host "  → Data path: $BRAVE_DATA_PATH" -ForegroundColor Cyan

try {
    # Create install directory
    if (-not (Test-Path $BRAVE_INSTALL_PATH)) {
        New-Item -Path $BRAVE_INSTALL_PATH -ItemType Directory -Force -ErrorAction Stop | Out-Null
        Write-Host "  ✓ Install directory created" -ForegroundColor Green
    } else {
        Write-Host "  ✓ Install directory exists" -ForegroundColor Green
    }
    
    # Create data directory
    if (-not (Test-Path $BRAVE_DATA_PATH)) {
        New-Item -Path $BRAVE_DATA_PATH -ItemType Directory -Force -ErrorAction Stop | Out-Null
        Write-Host "  ✓ Data directory created" -ForegroundColor Green
    } else {
        Write-Host "  ✓ Data directory exists" -ForegroundColor Green
    }
    
    Write-Host "[SUCCESS] Directory structure ready" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to create directories: $($_.Exception.Message)" -ForegroundColor Red
    return
}

# Function to get latest release info
function Get-LatestBraveRelease {
    try {
        Write-Host "[INFO] Fetching latest release information..." -ForegroundColor Yellow
        $response = Invoke-RestMethod -Uri $GITHUB_API_URL -UseBasicParsing -ErrorAction Stop
        
        Write-Host "[DEBUG] Available assets:" -ForegroundColor Gray
        $response.assets | ForEach-Object { Write-Host "  - $($_.name)" -ForegroundColor Gray }
        
        # Look for Windows portable zip files first (64-bit preferred)
        $windowsAsset = $response.assets | Where-Object { 
            $_.name -like "*brave-v*-win32-x64.zip" -and
            $_.name -notlike "*symbols*"
        } | Select-Object -First 1
        
        # Fall back to 32-bit portable zip if 64-bit not available
        if (-not $windowsAsset) {
            $windowsAsset = $response.assets | Where-Object { 
                $_.name -like "*brave-v*-win32-ia32.zip" -and
                $_.name -notlike "*symbols*"
            } | Select-Object -First 1
        }
        
        # If no portable zip found, look for Windows installer/executable releases
        if (-not $windowsAsset) {
            $windowsAsset = $response.assets | Where-Object { 
                ($_.name -like "*BraveBrowser*Setup*.exe" -or
                 $_.name -like "*brave-browser*win*.exe" -or
                 $_.name -like "*brave*win*setup*.exe") -and
                $_.name -notlike "*arm64*" -and
                $_.name -notlike "*mac*" -and
                $_.name -notlike "*linux*" -and
                $_.name -notlike "*darwin*"
            } | Select-Object -First 1
        }
        
        # Fallback to any Windows archive files
        if (-not $windowsAsset) {
            $windowsAsset = $response.assets | Where-Object { 
                ($_.name -like "*brave*win*.zip" -or
                 $_.name -like "*brave*x64*.zip" -or
                 $_.name -like "*brave*windows*.zip") -and
                $_.name -notlike "*arm64*" -and
                $_.name -notlike "*mac*" -and
                $_.name -notlike "*linux*" -and
                $_.name -notlike "*darwin*" -and
                $_.name -notlike "*symbols*"
            } | Select-Object -First 1
        }
        
        if ($windowsAsset) {
            return @{
                Version = $response.tag_name
                DownloadUrl = $windowsAsset.browser_download_url
                FileName = $windowsAsset.name
                Size = $windowsAsset.size
                IsInstaller = $windowsAsset.name -like "*.exe"
            }
        } else {
            Write-Host "[WARNING] No suitable Windows release found in assets:" -ForegroundColor Yellow
            $response.assets | ForEach-Object { Write-Host "  - $($_.name) ($($_.size / 1MB) MB)" -ForegroundColor Gray }
            return $null
        }
    } catch {
        Write-Host "[ERROR] Failed to fetch release info: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Check if update is needed
function Test-UpdateNeeded {
    param($LatestVersion)
    
    $versionFile = Join-Path $BRAVE_INSTALL_PATH "version.txt"
    if (Test-Path $versionFile) {
        $currentVersion = Get-Content $versionFile -ErrorAction SilentlyContinue
        if ($currentVersion -eq $LatestVersion) {
            Write-Host "[INFO] Brave is already up to date (version: $currentVersion)" -ForegroundColor Green
            return $false
        } else {
            Write-Host "[INFO] Update available: $currentVersion → $LatestVersion" -ForegroundColor Yellow
            return $true
        }
    } else {
        Write-Host "[INFO] Brave not installed, proceeding with fresh installation" -ForegroundColor Yellow
        return $true
    }
}

# Download and install/extract Brave
function Install-BravePortable {
    param($ReleaseInfo)
    
    $downloadPath = Join-Path $TEMP_PATH $ReleaseInfo.FileName
    $extractPath = Join-Path $TEMP_PATH "brave-extract"
    
    try {
        # Download with better error handling and integrity checks
        Write-Host "[INFO] Downloading Brave $($ReleaseInfo.Version)..." -ForegroundColor Yellow
        Write-Host "  → File: $($ReleaseInfo.FileName)" -ForegroundColor Cyan
        Write-Host "  → Size: $([math]::Round($ReleaseInfo.Size / 1MB, 2)) MB" -ForegroundColor Cyan
        Write-Host "  → Type: $(if ($ReleaseInfo.IsInstaller) { 'Windows Installer' } else { 'Archive' })" -ForegroundColor Cyan
        
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        
        # Download with progress and retry logic
        $maxRetries = 3
        $retryCount = 0
        $downloadSuccess = $false
        
        while ($retryCount -lt $maxRetries -and -not $downloadSuccess) {
            try {
                if ($retryCount -gt 0) {
                    Write-Host "[INFO] Retry attempt $retryCount of $($maxRetries - 1)..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 2
                }
                
                # Remove partial download if exists
                if (Test-Path $downloadPath) {
                    Remove-Item $downloadPath -Force -ErrorAction SilentlyContinue
                }
                
                # Download with better parameters
                $webClient = New-Object System.Net.WebClient
                $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
                $webClient.DownloadFile($ReleaseInfo.DownloadUrl, $downloadPath)
                $webClient.Dispose()
                
                # Verify file size
                $downloadedSize = (Get-Item $downloadPath).Length
                if ($downloadedSize -eq $ReleaseInfo.Size) {
                    $downloadSuccess = $true
                    Write-Host "[SUCCESS] Downloaded in $($stopwatch.Elapsed.TotalSeconds.ToString('F1'))s" -ForegroundColor Green
                } else {
                    throw "File size mismatch: expected $($ReleaseInfo.Size) bytes, got $downloadedSize bytes"
                }
                
            } catch {
                $retryCount++
                Write-Host "[WARNING] Download attempt failed: $($_.Exception.Message)" -ForegroundColor Yellow
                if ($retryCount -ge $maxRetries) {
                    throw "Download failed after $maxRetries attempts: $($_.Exception.Message)"
                }
            }
        }
        
        $stopwatch.Stop()
        
        if ($ReleaseInfo.IsInstaller) {
            # Handle Windows installer (.exe)
            Write-Host "[INFO] Installing Brave from Windows installer..." -ForegroundColor Yellow
            
            # Try to extract installer contents using 7-zip-like approach or run silent install
            $installResult = Install-FromWindowsInstaller -InstallerPath $downloadPath -ExtractPath $extractPath
            
            if (-not $installResult) {
                Write-Host "[WARNING] Could not extract portable version from installer" -ForegroundColor Yellow
                Write-Host "[INFO] Attempting system installation instead..." -ForegroundColor Yellow
                
                # Run installer silently to system location, then copy to portable location
                $process = Start-Process -FilePath $downloadPath -ArgumentList "/S", "/silent" -Wait -PassThru -NoNewWindow
                
                if ($process.ExitCode -eq 0) {
                    # Try to find installed Brave and copy to portable location
                    $systemBravePath = Find-SystemBraveInstallation
                    if ($systemBravePath) {
                        Copy-Item -Path "$systemBravePath\*" -Destination $BRAVE_INSTALL_PATH -Recurse -Force
                        $ReleaseInfo.Version | Out-File -FilePath (Join-Path $BRAVE_INSTALL_PATH "version.txt") -Encoding utf8
                        return $true
                    }
                }
                return $false
            }
        } else {
            # Handle archive (.zip)
            Write-Host "[INFO] Extracting Brave archive..." -ForegroundColor Yellow
            return Install-FromArchive -ArchivePath $downloadPath -ExtractPath $extractPath
        }
        
    } catch {
        Write-Host "[ERROR] Installation failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    } finally {
        # Comprehensive cleanup of temporary files
        Write-Host "[INFO] Cleaning up temporary files..." -ForegroundColor Yellow
        
        # Remove downloaded file
        if (Test-Path $downloadPath) {
            Remove-Item $downloadPath -Force -ErrorAction SilentlyContinue
            Write-Host "  ✓ Removed download file" -ForegroundColor Green
        }
        
        # Remove extraction directory
        if (Test-Path $extractPath) {
            Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "  ✓ Removed extraction directory" -ForegroundColor Green
        }
        
        # Clean up any old temporary Brave files in TEMP directory
        Get-ChildItem $TEMP_PATH -Filter "*brave*" -ErrorAction SilentlyContinue | Where-Object {
            $_.LastWriteTime -lt (Get-Date).AddDays(-1)  # Older than 1 day
        } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Helper function to install from Windows installer
function Install-FromWindowsInstaller {
    param($InstallerPath, $ExtractPath)
    
    try {
        # Some installers can be extracted as zip files
        if (Test-Path $ExtractPath) {
            Remove-Item $ExtractPath -Recurse -Force
        }
        New-Item -Path $ExtractPath -ItemType Directory -Force | Out-Null
        
        # Try to extract as archive first
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        try {
            [System.IO.Compression.ZipFile]::ExtractToDirectory($InstallerPath, $ExtractPath)
            return Install-FromExtractedFiles -ExtractPath $ExtractPath
        } catch {
            Write-Host "[INFO] Installer is not a self-extracting archive" -ForegroundColor Yellow
            return $false
        }
    } catch {
        return $false
    }
}

# Helper function to install from archive
function Install-FromArchive {
    param($ArchivePath, $ExtractPath)
    
    try {
        Write-Host "[INFO] Validating downloaded archive..." -ForegroundColor Yellow
        
        # Validate ZIP file integrity
        if (-not (Test-Path $ArchivePath)) {
            throw "Archive file not found: $ArchivePath"
        }
        
        # Check if file is a valid ZIP by trying to read it
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        try {
            $archive = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)
            $entryCount = $archive.Entries.Count
            $archive.Dispose()
            Write-Host "[INFO] Archive contains $entryCount files" -ForegroundColor Cyan
        } catch {
            throw "Invalid or corrupted ZIP file: $($_.Exception.Message)"
        }
        
        # Clean up extraction directory
        if (Test-Path $ExtractPath) {
            Remove-Item $ExtractPath -Recurse -Force
        }
        New-Item -Path $ExtractPath -ItemType Directory -Force | Out-Null
        
        Write-Host "[INFO] Extracting archive..." -ForegroundColor Yellow
        
        # Extract with error handling
        try {
            [System.IO.Compression.ZipFile]::ExtractToDirectory($ArchivePath, $ExtractPath)
            Write-Host "[SUCCESS] Archive extracted successfully" -ForegroundColor Green
        } catch {
            # Try alternative extraction method using Shell.Application
            Write-Host "[WARNING] Standard extraction failed, trying alternative method..." -ForegroundColor Yellow
            
            $shell = New-Object -ComObject Shell.Application
            $zip = $shell.NameSpace($ArchivePath)
            $destination = $shell.NameSpace($ExtractPath)
            
            if ($zip -and $destination) {
                $destination.CopyHere($zip.Items(), 4) # 4 = Do not display progress dialog
                Write-Host "[SUCCESS] Archive extracted using alternative method" -ForegroundColor Green
            } else {
                throw "Both extraction methods failed"
            }
        }
        
        return Install-FromExtractedFiles -ExtractPath $ExtractPath
        
    } catch {
        Write-Host "[ERROR] Failed to extract archive: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "[DEBUG] Archive path: $ArchivePath" -ForegroundColor Gray
        Write-Host "[DEBUG] Extract path: $ExtractPath" -ForegroundColor Gray
        if (Test-Path $ArchivePath) {
            $fileSize = (Get-Item $ArchivePath).Length
            Write-Host "[DEBUG] Archive size: $([math]::Round($fileSize / 1MB, 2)) MB" -ForegroundColor Gray
        }
        return $false
    }
}

# Helper function to install from extracted files
function Install-FromExtractedFiles {
    param($ExtractPath)
    
    try {
        # Find the actual Brave executable in extracted files
        $braveExe = Get-ChildItem -Path $ExtractPath -Recurse -Name "brave.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $braveExe) {
            $braveExe = Get-ChildItem -Path $ExtractPath -Recurse -Name "*.exe" -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*brave*" } | Select-Object -First 1 | ForEach-Object { $_.Name }
        }
        
        if ($braveExe) {
            $braveFolder = Split-Path (Join-Path $ExtractPath $braveExe) -Parent
            
            Write-Host "[INFO] Installing Brave to $BRAVE_INSTALL_PATH..." -ForegroundColor Yellow
            
            # Clean up old installation files but preserve user data and version info
            Write-Host "[INFO] Cleaning up previous installation..." -ForegroundColor Yellow
            $preserveItems = @("User Data", "version.txt", "launch-brave.bat")
            
            Get-ChildItem $BRAVE_INSTALL_PATH -ErrorAction SilentlyContinue | Where-Object { 
                $_.Name -notin $preserveItems 
            } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            
            Write-Host "[INFO] Installing new version..." -ForegroundColor Yellow
            
            # Copy new files
            Copy-Item -Path "$braveFolder\*" -Destination $BRAVE_INSTALL_PATH -Recurse -Force
            
            Write-Host "[SUCCESS] Brave installed successfully" -ForegroundColor Green
            return $true
        } else {
            Write-Host "[ERROR] Could not find Brave executable in extracted files" -ForegroundColor Red
            Write-Host "[DEBUG] Available files:" -ForegroundColor Gray
            Get-ChildItem -Path $ExtractPath -Recurse -Name "*.exe" | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
            return $false
        }
    } catch {
        Write-Host "[ERROR] Failed to install from extracted files: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Helper function to find system Brave installation
function Find-SystemBraveInstallation {
    $commonPaths = @(
        "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\Application",
        "$env:PROGRAMFILES\BraveSoftware\Brave-Browser\Application",
        "${env:PROGRAMFILES(X86)}\BraveSoftware\Brave-Browser\Application"
    )
    
    foreach ($path in $commonPaths) {
        if (Test-Path (Join-Path $path "brave.exe")) {
            Write-Host "[INFO] Found system Brave installation at: $path" -ForegroundColor Green
            return $path
        }
    }
    
    Write-Host "[WARNING] Could not find system Brave installation" -ForegroundColor Yellow
    return $null
}

# Helper function to clean up old files and downloads
function Clear-OldBraveFiles {
    Write-Host "[INFO] Cleaning up old downloads and temporary files..." -ForegroundColor Yellow
    
    # Clean up old downloads in TEMP directory
    $oldDownloads = Get-ChildItem $TEMP_PATH -Filter "*brave-v*" -ErrorAction SilentlyContinue | Where-Object {
        $_.LastWriteTime -lt (Get-Date).AddDays(-2) -and ($_.Name -like "*.zip" -or $_.Name -like "*.exe")
    }
    
    if ($oldDownloads) {
        $oldDownloads | ForEach-Object {
            Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
            Write-Host "  ✓ Removed old download: $($_.Name)" -ForegroundColor Green
        }
    }
    
    # Clean up old extraction directories
    $oldExtracts = Get-ChildItem $TEMP_PATH -Filter "*brave-extract*" -Directory -ErrorAction SilentlyContinue | Where-Object {
        $_.LastWriteTime -lt (Get-Date).AddHours(-6)
    }
    
    if ($oldExtracts) {
        $oldExtracts | ForEach-Object {
            Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "  ✓ Removed old extraction directory: $($_.Name)" -ForegroundColor Green
        }
    }
}

# Create launcher script
function New-BraveLauncher {
    $launcherPath = Join-Path $BRAVE_INSTALL_PATH "launch-brave.bat"
    $braveExe = Join-Path $BRAVE_INSTALL_PATH "brave.exe"
    
    if (Test-Path $braveExe) {
        $launcherContent = @"
@echo off
REM Brave Browser Portable Launcher
REM Ensures user data is stored in persistent location

set "BRAVE_USER_DATA=$BRAVE_DATA_PATH"
set "BRAVE_INSTALL=%~dp0"

echo Starting Brave Browser Portable...
echo User Data: %BRAVE_USER_DATA%
echo Install Path: %BRAVE_INSTALL%

"%BRAVE_INSTALL%brave.exe" --user-data-dir="%BRAVE_USER_DATA%" %*
"@
        
        $launcherContent | Out-File -FilePath $launcherPath -Encoding ascii
        Write-Host "[SUCCESS] Created launcher: $launcherPath" -ForegroundColor Green
        
        # Create desktop shortcut
        try {
            $desktopPath = [Environment]::GetFolderPath("Desktop")
            $shortcutPath = Join-Path $desktopPath "Brave Browser Portable.lnk"
            
            $WshShell = New-Object -ComObject WScript.Shell
            $Shortcut = $WshShell.CreateShortcut($shortcutPath)
            $Shortcut.TargetPath = $launcherPath
            $Shortcut.WorkingDirectory = $BRAVE_INSTALL_PATH
            $Shortcut.IconLocation = "$braveExe,0"
            $Shortcut.Description = "Brave Browser Portable"
            $Shortcut.Save()
            
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($WshShell) | Out-Null
            Write-Host "[SUCCESS] Desktop shortcut created" -ForegroundColor Green
        } catch {
            Write-Host "[WARNING] Could not create desktop shortcut: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# Pin to taskbar function
function Set-BraveTaskbarPin {
    param(
        [string]$LauncherPath,
        [string]$BraveExe
    )
    
    try {
        Write-Host "[INFO] Pinning Brave to taskbar..." -ForegroundColor Yellow
        
        # Method 1: Use the launcher shortcut for pinning
        if (Test-Path $LauncherPath) {
            # Create a shortcut in a known location first
            $tempShortcutPath = Join-Path $env:TEMP "BraveBrowserPortable.lnk"
            
            $WshShell = New-Object -ComObject WScript.Shell
            $Shortcut = $WshShell.CreateShortcut($tempShortcutPath)
            $Shortcut.TargetPath = $LauncherPath
            $Shortcut.WorkingDirectory = $BRAVE_INSTALL_PATH
            $Shortcut.IconLocation = "$BraveExe,0"
            $Shortcut.Description = "Brave Browser Portable"
            $Shortcut.Save()
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($WshShell) | Out-Null
            
            # Try to pin using Shell.Application
            try {
                $shell = New-Object -ComObject Shell.Application
                $folder = $shell.Namespace((Split-Path $tempShortcutPath))
                $item = $folder.ParseName((Split-Path $tempShortcutPath -Leaf))
                
                # Get the "Pin to taskbar" verb (this varies by OS language/version)
                $pinVerb = $item.Verbs() | Where-Object { $_.Name -match "taskbar|Pin to Start" } | Select-Object -First 1
                
                if ($pinVerb) {
                    $pinVerb.DoIt()
                    Write-Host "[SUCCESS] Brave pinned to taskbar" -ForegroundColor Green
                    return $true
                } else {
                    Write-Host "[WARNING] Pin to taskbar verb not found" -ForegroundColor Yellow
                }
                
                [System.Runtime.Interopservices.Marshal]::ReleaseComObject($shell) | Out-Null
            } catch {
                Write-Host "[WARNING] Shell.Application pin method failed: $($_.Exception.Message)" -ForegroundColor Yellow
            }
            
            # Method 2: Copy shortcut to Quick Launch or Start Menu for manual pinning
            try {
                $startMenuPath = [Environment]::GetFolderPath("StartMenu")
                $programsPath = Join-Path $startMenuPath "Programs"
                $finalShortcutPath = Join-Path $programsPath "Brave Browser Portable.lnk"
                
                Copy-Item $tempShortcutPath $finalShortcutPath -Force
                Write-Host "[SUCCESS] Shortcut added to Start Menu. You can manually pin to taskbar from there." -ForegroundColor Green
                
                # Clean up temp shortcut
                Remove-Item $tempShortcutPath -Force -ErrorAction SilentlyContinue
                
                return $true
            } catch {
                Write-Host "[WARNING] Could not add to Start Menu: $($_.Exception.Message)" -ForegroundColor Yellow
            }
            
            # Method 3: Registry method (Windows 10/11)
            try {
                $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband"
                if (-not (Test-Path $regPath)) {
                    New-Item -Path $regPath -Force | Out-Null
                }
                
                # This is a more advanced method that would require additional registry manipulation
                Write-Host "[INFO] Alternative: Right-click on Brave in Start Menu and select 'Pin to taskbar'" -ForegroundColor Cyan
                
                return $true
            } catch {
                Write-Host "[WARNING] Registry pin method failed: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        
        return $false
        
    } catch {
        Write-Host "[ERROR] Failed to pin Brave to taskbar: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Main execution
Write-Host "[INFO] Checking for latest Brave release..." -ForegroundColor Yellow

# Clean up old files first
Clear-OldBraveFiles

$releaseInfo = Get-LatestBraveRelease
if (-not $releaseInfo) {
    Write-Host "[ERROR] Could not fetch release information" -ForegroundColor Red
    return
}

Write-Host "[INFO] Latest version: $($releaseInfo.Version)" -ForegroundColor Cyan

if (Test-UpdateNeeded -LatestVersion $releaseInfo.Version) {
    $installSuccess = Install-BravePortable -ReleaseInfo $releaseInfo
    
    if ($installSuccess) {
        # Save version info after successful installation
        $releaseInfo.Version | Out-File -FilePath (Join-Path $BRAVE_INSTALL_PATH "version.txt") -Encoding utf8
        
        New-BraveLauncher
        
        # Pin to taskbar
        $launcherPath = Join-Path $BRAVE_INSTALL_PATH "launch-brave.bat"
        $braveExe = Join-Path $BRAVE_INSTALL_PATH "brave.exe"
        Set-BraveTaskbarPin -LauncherPath $launcherPath -BraveExe $braveExe
        
        Write-Host ""
        Write-Host "[SUMMARY] Brave Browser Portable setup completed!" -ForegroundColor Green
        Write-Host "  → Version: $($releaseInfo.Version)" -ForegroundColor Cyan
        Write-Host "  → Install Path: $BRAVE_INSTALL_PATH" -ForegroundColor Cyan
        Write-Host "  → User Data: $BRAVE_DATA_PATH" -ForegroundColor Cyan
        Write-Host "  → Launcher: launch-brave.bat" -ForegroundColor Cyan
        Write-Host "  → Desktop shortcut created" -ForegroundColor Cyan
        Write-Host "  → Taskbar pinning attempted" -ForegroundColor Cyan
    } else {
        Write-Host "[ERROR] Failed to install Brave Browser" -ForegroundColor Red
    }
} else {
    Write-Host "[INFO] Brave Browser is already up to date" -ForegroundColor Green
    # Ensure launcher exists even if no update
    New-BraveLauncher
    
    # Try to pin to taskbar even if no update
    $launcherPath = Join-Path $BRAVE_INSTALL_PATH "launch-brave.bat"
    $braveExe = Join-Path $BRAVE_INSTALL_PATH "brave.exe"
    if (Test-Path $braveExe) {
        Set-BraveTaskbarPin -LauncherPath $launcherPath -BraveExe $braveExe
    }
}

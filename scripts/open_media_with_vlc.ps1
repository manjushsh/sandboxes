# VLC Media Player Setup Script
# Configures VLC as default media player with file associations

$ErrorActionPreference = 'Continue'

# VLC search locations (in order of preference)
$vlcSearchPaths = @(
    "C:\Users\WDAGUtilityAccount\Desktop\RebexTinySftpServer-Binaries-Latest\.data\vlc-3.0.21\vlc.exe",
    "C:\Users\WDAGUtilityAccount\Desktop\RebexTinySftpServer-Binaries-Latest\vlc-3.0.21\vlc.exe",
    "C:\Program Files\VideoLAN\VLC\vlc.exe",
    "C:\Program Files (x86)\VideoLAN\VLC\vlc.exe"
)

# Find VLC executable
$vlcPath = $null
foreach ($path in $vlcSearchPaths) {
    if (Test-Path $path) {
        $vlcPath = $path
        Write-Host "[SUCCESS] Found VLC at: $vlcPath" -ForegroundColor Green
        break
    }
}

if (-not $vlcPath) {
    Write-Host "[ERROR] VLC not found in any of the expected locations:" -ForegroundColor Red
    $vlcSearchPaths | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
    Write-Host "[INFO] Skipping VLC setup" -ForegroundColor Yellow
    return
}

Write-Host "[INFO] Setting up VLC as default media player..." -ForegroundColor Green

# Optimized media file extensions (grouped by type for better organization)
$mediaExtensions = @{
    'Video' = @('.mp4', '.avi', '.mkv', '.mov', '.wmv', '.flv', '.webm', '.m4v', '.mpg', '.mpeg', '.3gp', '.asf', '.rm', '.rmvb', '.vob', '.ts', '.mts', '.m2ts', '.divx', '.xvid')
    'Audio' = @('.mp3', '.wav', '.flac', '.aac', '.ogg', '.wma', '.m4a')
}

# Flatten for registry operations
$allExtensions = $mediaExtensions.Values | ForEach-Object { $_ }

# Constants
$VLC_PROG_ID = "VLC.MediaFile"
$VLC_DISPLAY_NAME = "VLC Media File"

# Function to create registry key safely
function New-RegistryKey {
    param([string]$Path, [hashtable]$Properties = @{})

    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }

        foreach ($prop in $Properties.GetEnumerator()) {
            Set-ItemProperty -Path $Path -Name $prop.Key -Value $prop.Value -ErrorAction Stop
        }
        return $true
    }
    catch {
        Write-Host "[WARNING] Failed to create registry key: $Path - $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }
}

Write-Host "[INFO] Configuring VLC program registration..." -ForegroundColor Yellow

# Register VLC as a program (batch operations)
$vlcKeyPath = "HKCU:\SOFTWARE\Classes\$VLC_PROG_ID"
$registrySuccess = New-RegistryKey -Path $vlcKeyPath -Properties @{
    '(Default)' = $VLC_DISPLAY_NAME
}

if ($registrySuccess) {
    # Set icon and command in batch
    New-RegistryKey -Path "$vlcKeyPath\DefaultIcon" -Properties @{
        '(Default)' = "`"$vlcPath`",0"
    } | Out-Null

    New-RegistryKey -Path "$vlcKeyPath\shell\open\command" -Properties @{
        '(Default)' = "`"$vlcPath`" `"%1`""
    } | Out-Null

    Write-Host "[SUCCESS] VLC program registration completed" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Failed to register VLC program" -ForegroundColor Red
}

# Optimized file association with progress tracking
Write-Host "[INFO] Associating file extensions with VLC..." -ForegroundColor Yellow

$associationCount = 0
$totalExtensions = $allExtensions.Count

foreach ($extension in $allExtensions) {
    $associationCount++
    $percentage = [math]::Round(($associationCount / $totalExtensions) * 100)

    Write-Progress -Activity "Associating file extensions" -Status "$extension ($associationCount/$totalExtensions)" -PercentComplete $percentage

    # Batch create extension associations
    $extKeyPath = "HKCU:\SOFTWARE\Classes\$extension"
    $success = New-RegistryKey -Path $extKeyPath -Properties @{
        '(Default)' = $VLC_PROG_ID
    }

    if ($success) {
        # Add to OpenWithProgids
        New-RegistryKey -Path "$extKeyPath\OpenWithProgids" -Properties @{
            $VLC_PROG_ID = ""
        } | Out-Null
    }
}

Write-Progress -Activity "Associating file extensions" -Completed
Write-Host "[SUCCESS] Associated $associationCount file extensions with VLC" -ForegroundColor Green

# Add VLC to context menu for all files
Write-Host "[INFO] Adding VLC to context menu..." -ForegroundColor Yellow

$contextMenuSuccess = New-RegistryKey -Path "HKCU:\SOFTWARE\Classes\*\shell\VLC" -Properties @{
    '(Default)' = "Open with VLC"
    'Icon' = "`"$vlcPath`",0"
}

if ($contextMenuSuccess) {
    New-RegistryKey -Path "HKCU:\SOFTWARE\Classes\*\shell\VLC\command" -Properties @{
        '(Default)' = "`"$vlcPath`" `"%1`""
    } | Out-Null
    Write-Host "[SUCCESS] Context menu integration completed" -ForegroundColor Green
}

# Create desktop shortcut efficiently
Write-Host "[INFO] Creating desktop shortcut..." -ForegroundColor Yellow

try {
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $shortcutPath = "$desktopPath\VLC Media Player.lnk"

    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($shortcutPath)
    $Shortcut.TargetPath = $vlcPath
    $Shortcut.WorkingDirectory = Split-Path $vlcPath -Parent
    $Shortcut.IconLocation = "$vlcPath,0"
    $Shortcut.Description = "VLC Media Player"
    $Shortcut.Save()

    # Release COM object
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($WshShell) | Out-Null

    Write-Host "[SUCCESS] Desktop shortcut created" -ForegroundColor Green
}
catch {
    Write-Host "[WARNING] Could not create desktop shortcut: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Refresh file associations efficiently
Write-Host "[INFO] Refreshing file associations..." -ForegroundColor Yellow

try {
    $shellCode = @'
using System;
using System.Runtime.InteropServices;
public class Shell32 {
    [DllImport("shell32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern void SHChangeNotify(uint wEventId, uint uFlags, IntPtr dwItem1, IntPtr dwItem2);
}
'@

    Add-Type $shellCode -ErrorAction Stop
    [Shell32]::SHChangeNotify(0x08000000, 0x0000, [IntPtr]::Zero, [IntPtr]::Zero)
    Write-Host "[SUCCESS] File associations refreshed" -ForegroundColor Green
}
catch {
    Write-Host "[INFO] File associations will be refreshed on next login" -ForegroundColor Yellow
}

# Final summary
Write-Host ""
Write-Host "[SUMMARY] VLC Media Player setup completed successfully!" -ForegroundColor Green
Write-Host "  ✓ Associated $($allExtensions.Count) media file extensions" -ForegroundColor Cyan
Write-Host "  ✓ Added context menu integration" -ForegroundColor Cyan
Write-Host "  ✓ Created desktop shortcut" -ForegroundColor Cyan
Write-Host "  ✓ Refreshed system file associations" -ForegroundColor Cyan

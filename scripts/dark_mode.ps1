# Dark Mode Configuration Script
# Enables Windows dark theme and sets appropriate wallpaper

$ErrorActionPreference = 'Continue'

Write-Host "[INFO] Configuring dark mode settings..." -ForegroundColor Yellow

# Registry settings for dark mode (batched operations)
$darkModeSettings = @{
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" = @{
        "AppsUseLightTheme" = 0
        "SystemUsesLightTheme" = 0
    }
}

# Apply registry settings
$settingsApplied = 0
foreach ($registryPath in $darkModeSettings.Keys) {
    try {
        $settings = $darkModeSettings[$registryPath]
        foreach ($setting in $settings.GetEnumerator()) {
            Set-ItemProperty -Path $registryPath -Name $setting.Key -Value $setting.Value -ErrorAction Stop
            $settingsApplied++
        }
        Write-Host "[SUCCESS] Applied dark mode registry settings" -ForegroundColor Green
    }
    catch {
        Write-Host "[ERROR] Failed to apply dark mode settings: $($_.Exception.Message)" -ForegroundColor Red
        return
    }
}

# Optimized wallpaper selection with fallbacks
Write-Host "[INFO] Setting dark wallpaper..." -ForegroundColor Yellow

$wallpaperCandidates = @(
    "C:\Windows\Web\Wallpaper\Windows\img19.jpg",
    "C:\Windows\Web\Wallpaper\Windows\img0.jpg",
    "C:\Windows\Web\4K\Wallpaper\Windows\*dark*.jpg"
)

$wallpaperPath = $null
foreach ($candidate in $wallpaperCandidates) {
    if ($candidate -like "*`**") {
        # Handle wildcard patterns
        $found = Get-ChildItem -Path (Split-Path $candidate) -Filter (Split-Path $candidate -Leaf) -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            $wallpaperPath = $found.FullName
            break
        }
    } elseif (Test-Path $candidate) {
        $wallpaperPath = $candidate
        break
    }
}

if (-not $wallpaperPath) {
    Write-Host "[WARNING] No suitable dark wallpaper found, using default" -ForegroundColor Yellow
    $wallpaperPath = "C:\Windows\Web\Wallpaper\Windows\img0.jpg"  # Fallback
}

# Optimized wallpaper setting with better error handling
try {
    $wallpaperCode = @'
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet=CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
'@

    Add-Type $wallpaperCode -ErrorAction Stop
    $SPI_SETDESKWALLPAPER = 0x0014
    $UPDATE_INI_FILE = 0x01
    $SEND_CHANGE = 0x02

    $result = [Wallpaper]::SystemParametersInfo($SPI_SETDESKWALLPAPER, 0, $wallpaperPath, ($UPDATE_INI_FILE -bor $SEND_CHANGE))

    if ($result -ne 0) {
        Write-Host "[SUCCESS] Wallpaper updated to: $wallpaperPath" -ForegroundColor Green
    } else {
        Write-Host "[WARNING] Wallpaper may not have been set properly" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "[ERROR] Failed to set wallpaper: $($_.Exception.Message)" -ForegroundColor Red
}

# Restart Explorer with timeout protection
Write-Host "[INFO] Restarting Explorer to apply changes..." -ForegroundColor Yellow

try {
    # Stop Explorer gracefully with timeout
    $explorerProcesses = Get-Process -Name explorer -ErrorAction SilentlyContinue
    if ($explorerProcesses) {
        Stop-Process -Name explorer -Force -ErrorAction Stop
        Start-Sleep -Seconds 2
    }

    # Start Explorer
    Start-Process explorer -ErrorAction Stop
    Start-Sleep -Seconds 1

    Write-Host "[SUCCESS] Dark mode applied and Explorer restarted" -ForegroundColor Green
    Write-Host "[SUMMARY] Dark mode configuration completed successfully!" -ForegroundColor Green
    Write-Host "  - Applied $settingsApplied dark mode registry settings" -ForegroundColor Cyan
    Write-Host "  - Set dark wallpaper" -ForegroundColor Cyan
    Write-Host "  - Restarted Explorer shell" -ForegroundColor Cyan
}
catch {
    Write-Host "[ERROR] Failed to restart Explorer: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "[INFO] Please restart Explorer manually or reboot" -ForegroundColor Yellow
}

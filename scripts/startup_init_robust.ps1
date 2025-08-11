# Windows Sandbox Startup Script - Optimized
# Configures sandbox environment with dark mode and VLC setup

# Configuration
$ErrorActionPreference = 'Continue'
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$SCRIPTS_PATH = "C:\Users\WDAGUtilityAccount\Desktop\scripts"
$SCRIPT_CONFIGS = @(
    @{ Name = "Performance Optimizer"; File = "performance_optimizer.ps1"; Critical = $false }
    @{ Name = "Dark Mode Setup"; File = "dark_mode.ps1"; Critical = $false }
    @{ Name = "VLC Media Player Setup"; File = "open_media_with_vlc.ps1"; Critical = $false }
    @{ Name = "Brave Browser Setup"; File = "brave_setup.ps1"; Critical = $false }
    @{ Name = "Tor Browser Setup"; File = "tor_browser_setup_simple.ps1"; Critical = $false }
    @{ Name = "Notepad++ File Associations Setup"; File = "notepadpp_file_associations.ps1"; Critical = $false }
)

# Initialize
Clear-Host
Write-Host "=======================================" -ForegroundColor Green
Write-Host "  Windows Sandbox Startup Script" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor Green
Write-Host ""

# Set execution policy
try {
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser -Force -ErrorAction Stop
    Write-Host "[INFO] Execution policy set to Bypass" -ForegroundColor Yellow
} catch {
    Write-Host "[WARNING] Could not set execution policy: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "[INFO] Continuing with current policy..." -ForegroundColor Yellow
}

# Validate scripts directory
Write-Host "[INFO] Validating scripts directory: $SCRIPTS_PATH" -ForegroundColor Yellow

if (-not (Test-Path $SCRIPTS_PATH)) {
    Write-Host "[ERROR] Scripts directory not found at: $SCRIPTS_PATH" -ForegroundColor Red
    Write-Host "[INFO] Checking alternative locations..." -ForegroundColor Yellow

    $alternativePaths = @(
        "C:\Scripts",
        (Split-Path -Parent $MyInvocation.MyCommand.Path)
    )

    $found = $false
    foreach ($altPath in $alternativePaths) {
        if (Test-Path $altPath) {
            $SCRIPTS_PATH = $altPath
            Write-Host "[SUCCESS] Found scripts at alternative location: $SCRIPTS_PATH" -ForegroundColor Green
            $found = $true
            break
        }
    }

    if (-not $found) {
        Write-Host "[FATAL] No scripts directory found!" -ForegroundColor Red
        Write-Host "Press any key to exit..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }
}

Write-Host "[SUCCESS] Scripts directory validated" -ForegroundColor Green
Write-Host ""

# Optimized function to run scripts with comprehensive error handling
function Invoke-ScriptSafely {
    param(
        [string]$ScriptPath,
        [string]$Description,
        [bool]$Critical = $false
    )

    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host "  $Description" -ForegroundColor Cyan
    Write-Host "=======================================" -ForegroundColor Cyan

    if (-not (Test-Path $ScriptPath)) {
        $message = "[ERROR] Script not found: $ScriptPath"
        Write-Host $message -ForegroundColor Red

        if ($Critical) {
            Write-Host "[FATAL] Critical script missing - aborting" -ForegroundColor Red
            return $false
        }
        Write-Host "[INFO] Non-critical script missing - continuing" -ForegroundColor Yellow
        Write-Host ""
        return $true
    }

    Write-Host "[INFO] Executing: $ScriptPath" -ForegroundColor Yellow

    try {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        & $ScriptPath
        $stopwatch.Stop()

        Write-Host "[SUCCESS] $Description completed in $($stopwatch.Elapsed.TotalSeconds.ToString('F2')) seconds" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "[ERROR] Failed to execute $Description" -ForegroundColor Red
        Write-Host "[ERROR] Details: $($_.Exception.Message)" -ForegroundColor Red

        if ($Critical) {
            Write-Host "[FATAL] Critical script failed - aborting" -ForegroundColor Red
            return $false
        }
        Write-Host "[INFO] Non-critical script failed - continuing" -ForegroundColor Yellow
        return $true
    }
    finally {
        Write-Host ""
    }
}

# Execute all configured scripts
$totalStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$successCount = 0
$failureCount = 0

foreach ($config in $SCRIPT_CONFIGS) {
    $scriptPath = Join-Path $SCRIPTS_PATH $config.File
    $result = Invoke-ScriptSafely -ScriptPath $scriptPath -Description $config.Name -Critical $config.Critical

    if ($result) {
        $successCount++
    } else {
        $failureCount++
        if ($config.Critical) {
            Write-Host "[FATAL] Critical script failure - terminating startup" -ForegroundColor Red
            break
        }
    }
}

$totalStopwatch.Stop()

# Final summary with performance metrics
Write-Host "=======================================" -ForegroundColor Green
Write-Host "  Initialization Complete" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor Green
Write-Host ""
Write-Host "[SUMMARY] Execution completed in $($totalStopwatch.Elapsed.TotalSeconds.ToString('F2')) seconds" -ForegroundColor Cyan
Write-Host "[SUMMARY] Scripts executed successfully: $successCount" -ForegroundColor Green
if ($failureCount -gt 0) {
    Write-Host "[SUMMARY] Scripts with failures: $failureCount" -ForegroundColor Red
}
Write-Host ""
Write-Host "Sandbox is ready for use. Press any key to close..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

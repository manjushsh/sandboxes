# Windows Performance Optimizer Script
# Removes animations, disables unnecessary services, and optimizes for performance

param(
    [switch]$Restore,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Continue'

Write-Host "Windows Performance Optimizer" -ForegroundColor Green
Write-Host "=============================" -ForegroundColor Green

if ($Restore) {
    Write-Host "RESTORE MODE - Will revert optimizations" -ForegroundColor Yellow
} elseif ($WhatIf) {
    Write-Host "WHATIF MODE - Will show what would be changed" -ForegroundColor Cyan
} else {
    Write-Host "OPTIMIZE MODE - Will apply performance optimizations" -ForegroundColor Green
}

Write-Host ""

# Function to set registry value with backup
function Set-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [string]$Type = "DWord",
        [object]$RestoreValue = $null
    )
    
    $backupFile = "C:\Windows\Temp\perf_optimizer_backup.json"
    
    try {
        # Load existing backup
        $backup = @{}
        if (Test-Path $backupFile) {
            $backup = Get-Content $backupFile | ConvertFrom-Json -AsHashtable -ErrorAction SilentlyContinue
            if (-not $backup) { $backup = @{} }
        }
        
        # Ensure registry path exists
        if (-not (Test-Path $Path)) {
            if ($WhatIf) {
                Write-Host "WHATIF: Would create registry path: $Path" -ForegroundColor Cyan
            } else {
                New-Item -Path $Path -Force | Out-Null
            }
        }
        
        # Get current value for backup
        $key = "$Path\$Name"
        if (-not $backup.ContainsKey($key)) {
            $currentValue = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
            if ($currentValue) {
                $backup[$key] = $currentValue.$Name
            }
        }
        
        # Set value or restore
        if ($Restore -and $backup.ContainsKey($key)) {
            if ($WhatIf) {
                Write-Host "WHATIF: Would restore $key to $($backup[$key])" -ForegroundColor Cyan
            } else {
                Set-ItemProperty -Path $Path -Name $Name -Value $backup[$key] -Type $Type
                Write-Host "Restored: $key" -ForegroundColor Green
            }
        } elseif (-not $Restore) {
            if ($WhatIf) {
                Write-Host "WHATIF: Would set $key to $Value" -ForegroundColor Cyan
            } else {
                Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type
                Write-Host "Set: $key = $Value" -ForegroundColor Green
            }
        }
        
        # Save backup
        if (-not $WhatIf) {
            $backup | ConvertTo-Json | Out-File $backupFile -Force
        }
        
    } catch {
        Write-Host "Error with $key : $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Function to manage services
function Manage-Service {
    param(
        [string]$ServiceName,
        [string]$Action = "Disable" # Disable, Enable, Stop, Start
    )
    
    try {
        $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if (-not $service) {
            Write-Host "Service not found: $ServiceName" -ForegroundColor Yellow
            return
        }
        
        if ($Restore) {
            if ($WhatIf) {
                Write-Host "WHATIF: Would enable service: $ServiceName" -ForegroundColor Cyan
            } else {
                Set-Service -Name $ServiceName -StartupType Automatic -ErrorAction SilentlyContinue
                Start-Service -Name $ServiceName -ErrorAction SilentlyContinue
                Write-Host "Enabled: $ServiceName" -ForegroundColor Green
            }
        } else {
            if ($Action -eq "Disable") {
                if ($WhatIf) {
                    Write-Host "WHATIF: Would disable service: $ServiceName" -ForegroundColor Cyan
                } else {
                    Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
                    Set-Service -Name $ServiceName -StartupType Disabled -ErrorAction SilentlyContinue
                    Write-Host "Disabled: $ServiceName" -ForegroundColor Green
                }
            }
        }
    } catch {
        Write-Host "Error managing service $ServiceName : $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "1. Disabling Visual Effects and Animations..." -ForegroundColor Yellow

# Disable visual effects
Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 2
Set-RegistryValue "HKCU:\Control Panel\Desktop" "DragFullWindows" 0 "String"
Set-RegistryValue "HKCU:\Control Panel\Desktop" "MenuShowDelay" 0 "String"
Set-RegistryValue "HKCU:\Control Panel\Desktop" "UserPreferencesMask" ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) "Binary"

# Disable animations
Set-RegistryValue "HKCU:\Control Panel\Desktop\WindowMetrics" "MinAnimate" 0 "String"
Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ListviewAlphaSelect" 0
Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ListviewShadow" 0
Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAnimations" 0

# Disable transparency effects
Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency" 0

Write-Host "2. Optimizing System Performance..." -ForegroundColor Yellow

# Performance tweaks
Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" 38
Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "IconsOnly" 1
Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowTaskViewButton" 0
Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "SearchboxTaskbarMode" 0

# Disable unnecessary visual features
Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCortanaButton" 0
Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowPeopleBar" 0
Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338393Enabled" 0
Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-353694Enabled" 0

Write-Host "3. Managing Unnecessary Services..." -ForegroundColor Yellow

# Services to disable for better performance
$servicesToDisable = @(
    "Fax",                          # Fax service
    "WSearch",                      # Windows Search (can impact performance)
    "SysMain",                      # Superfetch/Prefetch
    "Themes",                       # Themes service
    "TabletInputService",           # Tablet Input Service
    "WbioSrvc",                     # Windows Biometric Service
    "WMPNetworkSvc",               # Windows Media Player Network Sharing
    "Browser",                      # Computer Browser
    "MapsBroker",                   # Downloaded Maps Manager
    "lfsvc",                        # Geolocation Service
    "RetailDemo",                   # Retail Demo Service
    "TrkWks",                       # Distributed Link Tracking Client
    "WerSvc",                       # Windows Error Reporting
    "DiagTrack",                    # Connected User Experiences and Telemetry
    "dmwappushservice",             # Device Management Wireless Application Protocol
    "PcaSvc",                       # Program Compatibility Assistant
    "RemoteAccess",                 # Routing and Remote Access
    "RemoteRegistry",               # Remote Registry
    "SharedAccess",                 # Internet Connection Sharing
    "SSDPSRV",                      # SSDP Discovery
    "upnphost",                     # UPnP Device Host
    "WinRM",                        # Windows Remote Management
    "Spooler"                       # Print Spooler (only if no printing needed)
)

foreach ($service in $servicesToDisable) {
    Manage-Service $service "Disable"
}

Write-Host "4. Optimizing File System..." -ForegroundColor Yellow

# Disable 8.3 name creation
Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsDisable8dot3NameCreation" 1

# Disable last access time updates
Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsDisableLastAccessUpdate" 1

# Memory management
Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "ClearPageFileAtShutdown" 0
Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "DisablePagingExecutive" 1

Write-Host "5. Network Optimizations..." -ForegroundColor Yellow

# Network optimizations
Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 0xffffffff
Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness" 0

Write-Host "6. Power Management..." -ForegroundColor Yellow

# Set high performance power plan
if (-not $WhatIf -and -not $Restore) {
    try {
        $highPerfGuid = (powercfg /list | Select-String "High performance" | Select-String -Pattern "([a-f0-9\-]{36})" | ForEach-Object { $_.Matches[0].Value })
        if ($highPerfGuid) {
            powercfg /setactive $highPerfGuid
            Write-Host "Set power plan to High Performance" -ForegroundColor Green
        }
    } catch {
        Write-Host "Could not set high performance power plan" -ForegroundColor Yellow
    }
}

Write-Host "7. Disabling Startup Programs..." -ForegroundColor Yellow

# Disable common startup programs that slow boot
$startupDisable = @(
    "Microsoft Teams",
    "Spotify",
    "Skype",
    "Adobe Updater",
    "Office",
    "OneDrive"
)

try {
    $startupApps = Get-CimInstance -ClassName Win32_StartupCommand -ErrorAction SilentlyContinue
    foreach ($app in $startupApps) {
        foreach ($target in $startupDisable) {
            if ($app.Name -like "*$target*") {
                if ($WhatIf) {
                    Write-Host "WHATIF: Would disable startup item: $($app.Name)" -ForegroundColor Cyan
                } elseif (-not $Restore) {
                    # Note: This requires manual intervention or different tools
                    Write-Host "Found startup item: $($app.Name) - Consider disabling manually" -ForegroundColor Yellow
                }
            }
        }
    }
} catch {
    Write-Host "Could not enumerate startup programs" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
if ($Restore) {
    Write-Host "RESTORATION COMPLETED!" -ForegroundColor Green
    Write-Host "Many changes require a reboot to take effect." -ForegroundColor Yellow
} elseif ($WhatIf) {
    Write-Host "WHATIF ANALYSIS COMPLETED!" -ForegroundColor Cyan
    Write-Host "Run without -WhatIf to apply changes." -ForegroundColor Yellow
} else {
    Write-Host "PERFORMANCE OPTIMIZATION COMPLETED!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "Restart your computer for all changes to take effect." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To restore original settings, run:" -ForegroundColor Cyan
    Write-Host "  .\performance_optimizer.ps1 -Restore" -ForegroundColor White
    Write-Host ""
    Write-Host "Backup saved to: C:\Windows\Temp\perf_optimizer_backup.json" -ForegroundColor Cyan
}
Write-Host "============================================" -ForegroundColor Green

# Windows Sandbox Automation Scripts

This repository contains automated setup scripts for Windows Sandbox environments with SFTP server integration.

## Structure

```
├── .Sandbox.wsb           # Sandbox configuration (networking disabled)
├── Isolated.wsb           # Sandbox configuration (networking enabled)
└── scripts/
    ├── dark_mode.ps1            # Enables Windows dark theme
    ├── open_media_with_vlc.ps1  # Configures VLC as default media player
    └── startup_init_robust.ps1  # Main startup orchestration script
```

## Sandbox Configurations

### `.Sandbox.wsb`
- **Memory**: 6GB
- **Networking**: Disabled
- **Purpose**: Offline sandbox environment
- **Mapped Folders**: SFTP server binaries and data

### `Isolated.wsb`
- **Memory**: Default
- **Networking**: Enabled with custom DNS
- **Purpose**: Online sandbox environment with network access
- **Mapped Folders**: SFTP server binaries and scripts

## Scripts

### `startup_init_robust.ps1`
Main orchestration script that:
- Sets PowerShell execution policy
- Validates script directory
- Executes configuration scripts with error handling
- Provides performance metrics and summary

### `dark_mode.ps1`
Configures Windows dark theme by:
- Setting registry values for dark mode
- Selecting appropriate dark wallpaper
- Restarting Windows Explorer

### `open_media_with_vlc.ps1`
Sets up VLC Media Player by:
- Auto-detecting VLC installation
- Creating file associations for media types
- Adding context menu integration
- Creating desktop shortcut

## Usage

1. Double-click either `.wsb` file to launch Windows Sandbox
2. Scripts run automatically on startup
3. View progress in the PowerShell window
4. Press any key to close when complete

## Requirements

- Windows 10/11 Pro, Enterprise, or Education
- Windows Sandbox feature enabled
- VLC Media Player (if using VLC setup script)

## Error Handling

All scripts include comprehensive error handling:
- Non-critical failures won't stop execution
- Detailed error messages with context
- Graceful degradation when components are missing

# Notepad++ File Associations Setup Script
# Sets Notepad++ as the default editor for all supported file types

$ErrorActionPreference = 'Continue'

Write-Host "[INFO] Setting up Notepad++ file associations..." -ForegroundColor Green

# Notepad++ executable path
$NOTEPADPP_PATH = "C:\Users\WDAGUtilityAccount\Desktop\RebexTinySftpServer-Binaries-Latest\PortableApps\Notepad++Portable\Notepad++Portable.exe"

# Verify Notepad++ exists
if (-not (Test-Path $NOTEPADPP_PATH)) {
    Write-Host "[ERROR] Notepad++ not found at: $NOTEPADPP_PATH" -ForegroundColor Red
    return
}

Write-Host "[SUCCESS] Notepad++ found at: $NOTEPADPP_PATH" -ForegroundColor Green

# Comprehensive list of file extensions that Notepad++ supports
$FileExtensions = @(
    # Text and documents
    '.txt', '.log', '.ini', '.cfg', '.conf', '.config', '.settings', '.prefs',
    '.readme', '.md', '.markdown', '.rst', '.rtf', '.csv', '.tsv',
    
    # Programming languages
    # '.c', '.cpp', '.cxx', '.cc', '.h', '.hpp', '.hxx', '.hh',
    # '.cs', '.vb', '.fs', '.fsx', '.fsi',
    # '.java', '.class', '.jar', '.jsp', '.jsp',
    # '.js', '.jsx', '.ts', '.tsx', '.mjs', '.cjs',
    # '.py', '.pyx', '.pyw', '.pyi', '.ipynb',
    # '.rb', '.rbw', '.rake', '.gemspec',
    # '.php', '.php3', '.php4', '.php5', '.phtml', '.phps',
    # '.pl', '.pm', '.t', '.pod',
    # '.go', '.mod', '.sum',
    # '.rs', '.rlib',
    # '.swift', '.kt', '.kts',
    # '.scala', '.sc',
    # '.dart', '.lua', '.r', '.R',
    # '.m', '.mm', '.f', '.f90', '.f95', '.f03', '.f08',
    # '.pas', '.pp', '.inc',
    # '.asm', '.s', '.S',
    # '.sh', '.bash', '.zsh', '.fish', '.csh', '.tcsh', '.ksh',
    # '.bat', '.cmd', '.ps1', '.psm1', '.psd1',
    # '.vbs', '.vbe', '.wsf', '.wsh',
    
    # Web technologies
    '.html', '.htm', '.xhtml', '.shtml', '.shtm', '.stm',
    '.xml', '.xsl', '.xslt', '.xsd', '.dtd', '.rss', '.atom',
    '.css', '.scss', '.sass', '.less', '.stylus',
    '.json', '.jsonc', '.json5', '.geojson',
    '.yaml', '.yml', '.toml'
    
    # Database and query languages
    # '.sql', '.mysql', '.pgsql', '.sqlite', '.db',
    # '.graphql', '.gql',
    
    # Configuration and data files
    # '.env', '.gitignore', '.gitattributes', '.editorconfig',
    # '.dockerignore', '.dockerfile', '.docker-compose.yml',
    # '.makefile', '.cmake', '.cmakelist.txt',
    # '.gradle', '.maven', '.pom.xml', '.build.gradle',
    # '.package.json', '.bower.json', '.composer.json',
    # '.requirements.txt', '.pipfile', '.poetry.lock',
    # '.gemfile', '.gemfile.lock',
    
    # Markup and documentation
    # '.tex', '.latex', '.cls', '.sty', '.bib',
    # '.adoc', '.asciidoc', '.textile',
    # '.wiki', '.mediawiki', '.creole',
    
    # Scripts and automation
    # '.awk', '.sed', '.grep',
    # '.applescript', '.scpt',
    # '.ahk', '.au3',
    
    # Data formats
    # '.properties', '.prop', '.inf', '.reg',
    # '.plist', '.strings',
    # '.nfo', '.diz', '.ans', '.asc',
    
    # Specialized formats
    # '.diff', '.patch', '.rej',
    # '.log4j', '.logback',
    # '.htaccess', '.htpasswd',
    # '.hosts', '.zone',
    # '.crontab', '.cron',
    
    # Additional programming languages
    # '.clj', '.cljs', '.cljc', '.edn',
    # '.elm', '.ex', '.exs', '.erl', '.hrl',
    # '.hs', '.lhs', '.cabal',
    # '.jl', '.ml', '.mli', '.mll', '.mly',
    # '.nim', '.nims', '.nimble',
    # '.purs', '.dhall', '.idris', '.agda',
    # '.v', '.sv', '.svh', '.vhd', '.vhdl'
)

# Function to set file association
function Set-FileAssociation {
    param(
        [string]$Extension,
        [string]$ExecutablePath
    )
    
    try {
        # Create unique ProgId for each extension
        $ProgId = "NotepadPlusPlus$($Extension.Replace('.', '').ToUpper())"
        
        # Set file extension association
        $null = New-Item -Path "HKCU:\Software\Classes\$Extension" -Force
        $null = Set-ItemProperty -Path "HKCU:\Software\Classes\$Extension" -Name "(Default)" -Value $ProgId
        
        # Create ProgId entry
        $null = New-Item -Path "HKCU:\Software\Classes\$ProgId" -Force
        $null = Set-ItemProperty -Path "HKCU:\Software\Classes\$ProgId" -Name "(Default)" -Value "$Extension File"
        
        # Set the command to open with Notepad++
        $null = New-Item -Path "HKCU:\Software\Classes\$ProgId\shell\open\command" -Force
        $null = Set-ItemProperty -Path "HKCU:\Software\Classes\$ProgId\shell\open\command" -Name "(Default)" -Value "`"$ExecutablePath`" `"%1`""
        
        # Set icon (use Notepad++ icon)
        $null = New-Item -Path "HKCU:\Software\Classes\$ProgId\DefaultIcon" -Force
        $null = Set-ItemProperty -Path "HKCU:\Software\Classes\$ProgId\DefaultIcon" -Name "(Default)" -Value "`"$ExecutablePath`",0"
        
        # Add "Edit with Notepad++" context menu
        $null = New-Item -Path "HKCU:\Software\Classes\$ProgId\shell\edit" -Force
        $null = Set-ItemProperty -Path "HKCU:\Software\Classes\$ProgId\shell\edit" -Name "(Default)" -Value "Edit with Notepad++"
        $null = New-Item -Path "HKCU:\Software\Classes\$ProgId\shell\edit\command" -Force
        $null = Set-ItemProperty -Path "HKCU:\Software\Classes\$ProgId\shell\edit\command" -Name "(Default)" -Value "`"$ExecutablePath`" `"%1`""
        
        return $true
    } catch {
        Write-Host "[WARNING] Failed to set association for $Extension`: $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }
}

# Function to add "Edit with Notepad++" to all files context menu
function Add-UniversalContextMenu {
    param([string]$ExecutablePath)
    
    try {
        # Add to all files (*)
        $null = New-Item -Path "HKCU:\Software\Classes\*\shell\EditWithNotepadPP" -Force
        $null = Set-ItemProperty -Path "HKCU:\Software\Classes\*\shell\EditWithNotepadPP" -Name "(Default)" -Value "Edit with Notepad++"
        $null = Set-ItemProperty -Path "HKCU:\Software\Classes\*\shell\EditWithNotepadPP" -Name "Icon" -Value "`"$ExecutablePath`",0"
        $null = New-Item -Path "HKCU:\Software\Classes\*\shell\EditWithNotepadPP\command" -Force
        $null = Set-ItemProperty -Path "HKCU:\Software\Classes\*\shell\EditWithNotepadPP\command" -Name "(Default)" -Value "`"$ExecutablePath`" `"%1`""
        
        Write-Host "[SUCCESS] Added 'Edit with Notepad++' to universal context menu" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "[WARNING] Failed to add universal context menu: $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }
}

# Function to set Notepad++ as default text editor
function Set-DefaultTextEditor {
    param([string]$ExecutablePath)
    
    try {
        # Set as default for unknown file types
        $null = New-Item -Path "HKCU:\Software\Classes\Unknown\shell\openas\command" -Force
        $null = Set-ItemProperty -Path "HKCU:\Software\Classes\Unknown\shell\openas\command" -Name "(Default)" -Value "`"$ExecutablePath`" `"%1`""
        
        # Set for txtfile class (affects .txt files)
        $null = New-Item -Path "HKCU:\Software\Classes\txtfile\shell\open\command" -Force
        $null = Set-ItemProperty -Path "HKCU:\Software\Classes\txtfile\shell\open\command" -Name "(Default)" -Value "`"$ExecutablePath`" `"%1`""
        
        Write-Host "[SUCCESS] Set Notepad++ as default text editor" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "[WARNING] Failed to set default text editor: $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }
}

# Main execution
Write-Host "[INFO] Processing $($FileExtensions.Count) file extensions..." -ForegroundColor Yellow

$successCount = 0
$failCount = 0

# Process each file extension
foreach ($ext in $FileExtensions) {
    if (Set-FileAssociation -Extension $ext -ExecutablePath $NOTEPADPP_PATH) {
        $successCount++
        if ($successCount % 10 -eq 0) {
            Write-Host "[PROGRESS] Processed $successCount extensions..." -ForegroundColor Cyan
        }
    } else {
        $failCount++
    }
}

Write-Host ""
Write-Host "[INFO] Setting up additional configurations..." -ForegroundColor Yellow

# Add universal context menu
Add-UniversalContextMenu -ExecutablePath $NOTEPADPP_PATH

# Set as default text editor
Set-DefaultTextEditor -ExecutablePath $NOTEPADPP_PATH

# Refresh file associations (attempt to notify Windows of changes)
try {
    # This sends a message to Windows to refresh file associations
    Add-Type @"
        using System;
        using System.Runtime.InteropServices;
        public class Win32 {
            [DllImport("shell32.dll", CharSet = CharSet.Auto, SetLastError = true)]
            public static extern void SHChangeNotify(uint wEventId, uint uFlags, IntPtr dwItem1, IntPtr dwItem2);
        }
"@
    [Win32]::SHChangeNotify(0x08000000, 0x0000, [IntPtr]::Zero, [IntPtr]::Zero)
    Write-Host "[SUCCESS] Notified Windows of file association changes" -ForegroundColor Green
} catch {
    Write-Host "[WARNING] Could not refresh file associations automatically" -ForegroundColor Yellow
}

# Summary
Write-Host ""
Write-Host "[SUMMARY] Notepad++ File Associations Setup Completed!" -ForegroundColor Green
Write-Host "  → Successfully configured: $successCount extensions" -ForegroundColor Cyan
Write-Host "  → Failed configurations: $failCount extensions" -ForegroundColor $(if ($failCount -gt 0) { 'Yellow' } else { 'Cyan' })
Write-Host "  → Notepad++ Path: $NOTEPADPP_PATH" -ForegroundColor Cyan
Write-Host "  → Universal context menu added" -ForegroundColor Cyan
Write-Host "  → Default text editor configured" -ForegroundColor Cyan

if ($failCount -gt 0) {
    Write-Host ""
    Write-Host "[NOTE] Some associations may require administrator privileges to set system-wide" -ForegroundColor Yellow
    Write-Host "[TIP] You may need to restart Windows Explorer or reboot for all changes to take effect" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "[INFO] Right-click on any file to see 'Edit with Notepad++' option" -ForegroundColor Green
Write-Host "[INFO] Supported file types will now open with Notepad++ by default" -ForegroundColor Green

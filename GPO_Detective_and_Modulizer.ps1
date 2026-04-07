# GPO Detective & Modularizer
# This script scans your GPO backup folder and exports a detailed inventory to CSV.

# --- CONFIGURATION ---
$BackupPath = "$HOME\Downloads\Windows Server-2022-Security-Baseline-FINAL\GPOs"
$ExportPath = "$HOME\Downloads\GPO_Inventory.csv"

# --- 1. SCANNING FOLDER ---
Write-Host "Scanning GPO Backups in: $BackupPath..." -ForegroundColor Cyan

# Validate backup path exists
if (-not (Test-Path $BackupPath)) {
    Write-Host "ERROR: Backup path does not exist: $BackupPath" -ForegroundColor Red
    Write-Host "Please update the `$BackupPath variable to point to your GPO backup folder." -ForegroundColor Yellow
    return
}

$GPOList = Get-ChildItem $BackupPath -Directory
$Results = @()

foreach ($Folder in $GPOList) {
    $BackupXmlPath = Join-Path $Folder.FullName "Backup.xml"
    if (Test-Path $BackupXmlPath) {
        [xml]$xml = Get-Content $BackupXmlPath
        
        # Fix XML parsing - use InnerText to handle CDATA sections
        $GPOName = $xml.GroupPolicyBackupScheme.GroupPolicyObject.GroupPolicyCoreSettings.DisplayName.InnerText
        $GPOID   = $xml.GroupPolicyBackupScheme.GroupPolicyObject.GroupPolicyCoreSettings.ID.InnerText
        
        # Determine Path logic (Machine vs User) - check both possible locations
        $HasMachine = (Test-Path (Join-Path $Folder.FullName "DomainSysvol\GPO\Machine")) -or (Test-Path (Join-Path $Folder.FullName "Machine"))
        $HasUser    = (Test-Path (Join-Path $Folder.FullName "DomainSysvol\GPO\User")) -or (Test-Path (Join-Path $Folder.FullName "User"))
        
        $Results += [PSCustomObject]@{
            FriendlyName = $GPOName
            FolderID     = $Folder.Name
            InternalID   = $GPOID
            HasMachine   = $HasMachine
            HasUser      = $HasUser
            Path         = $Folder.FullName
        }
    }
}

# --- 2. EXPORTING INVENTORY ---
# Ensure export directory exists
$ExportDir = Split-Path $ExportPath -Parent
if (-not (Test-Path $ExportDir)) {
    Write-Host "Creating export directory: $ExportDir" -ForegroundColor Yellow
    New-Item -Path $ExportDir -ItemType Directory -Force | Out-Null
}

if ($Results.Count -eq 0) {
    Write-Host "WARNING: No GPO backups found in the specified path." -ForegroundColor Yellow
    return
}

$Results | Export-Csv -Path $ExportPath -NoTypeInformation
Write-Host "SUCCESS: Inventory exported to $ExportPath" -ForegroundColor Green
Write-Host "Please open this CSV in Excel to see all available policies." -ForegroundColor Yellow

# --- 3. ANALYSIS INSTRUCTIONS ---
Write-Host "`nNEXT STEPS:" -ForegroundColor White
Write-Host "1. Review the CSV on your desktop."
Write-Host "2. Identify the rows you want to separate."
Write-Host "3. Tell the AI: 'I want to take FolderID [ID] and split it into [X] files'."
Write-Host "4. To view detailed settings: Get-GPOSettings -FolderID '{GUID}'" -ForegroundColor Cyan

# ================================================================================
# FUNCTION: Get-GPOSettings
# Shows all settings/policies configured in a specific GPO backup
# ================================================================================
function Get-GPOSettings {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FolderID
    )
    
    $GPOPath = Join-Path $BackupPath $FolderID
    
    if (-not (Test-Path $GPOPath)) {
        Write-Host "ERROR: GPO folder not found: $GPOPath" -ForegroundColor Red
        return
    }
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "GPO SETTINGS REPORT" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    # Read GPO Name from Backup.xml
    $BackupXmlPath = Join-Path $GPOPath "Backup.xml"
    if (Test-Path $BackupXmlPath) {
        [xml]$backupXml = Get-Content $BackupXmlPath
        $gpoName = $backupXml.GroupPolicyBackupScheme.GroupPolicyObject.GroupPolicyCoreSettings.DisplayName.InnerText
        Write-Host "GPO Name: $gpoName" -ForegroundColor Yellow
        Write-Host "Folder ID: $FolderID" -ForegroundColor Yellow
    }
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "FILE LOCATIONS:" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "GPO Path: $GPOPath`n" -ForegroundColor White
    
    # Track settings found
    $settingsFound = $false
    
    # --- MACHINE SETTINGS ---
    # Check both locations: DomainSysvol\GPO\Machine and Machine
    $MachinePath = Join-Path $GPOPath "DomainSysvol\GPO\Machine"
    if (-not (Test-Path $MachinePath)) {
        $MachinePath = Join-Path $GPOPath "Machine"
    }
    
    if (Test-Path $MachinePath) {
        Write-Host "`n[COMPUTER CONFIGURATION]" -ForegroundColor Green
        Write-Host "Location: $MachinePath`n" -ForegroundColor Gray
        
        # Registry.pol (Registry-based policies)
        $RegistryPol = Join-Path $MachinePath "Registry.pol"
        if (Test-Path $RegistryPol) {
            Write-Host "  [Registry Policies]" -ForegroundColor Yellow
            Write-Host "  File: $RegistryPol" -ForegroundColor Gray
            
            # Parse Registry.pol using the PolicyFileEditor module approach
            try {
                $regEntries = Parse-PolFile -Path $RegistryPol
                if ($regEntries.Count -gt 0) {
                    foreach ($entry in $regEntries) {
                        Write-Host "    - $($entry.Key)\$($entry.ValueName) = $($entry.Data)" -ForegroundColor White
                    }
                    $settingsFound = $true
                }
            } catch {
                Write-Host "    Registry.pol file exists but parsing requires PolicyFileEditor module" -ForegroundColor Yellow
                Write-Host "    Install with: Install-Module -Name PolicyFileEditor -Scope CurrentUser" -ForegroundColor Gray
                $settingsFound = $true
            }
        }
        
        # Audit policies
        $AuditXml = Join-Path $MachinePath "Microsoft\Windows NT\Audit\audit.csv"
        if (Test-Path $AuditXml) {
            Write-Host "`n  [Audit Policies]" -ForegroundColor Yellow
            Write-Host "  File: $AuditXml" -ForegroundColor Gray
            $auditData = Import-Csv $AuditXml
            foreach ($audit in $auditData) {
                Write-Host "    - $($audit.'Subcategory') : $($audit.'Setting Value')" -ForegroundColor White
            }
            $settingsFound = $true
        }
        
        # Security settings
        $SecEditInf = Join-Path $MachinePath "Microsoft\Windows NT\SecEdit\GptTmpl.inf"
        if (Test-Path $SecEditInf) {
            Write-Host "`n  [Security Settings]" -ForegroundColor Yellow
            Write-Host "  File: $SecEditInf" -ForegroundColor Gray
            $secContent = Get-Content $SecEditInf
            Write-Host "    Sections found:" -ForegroundColor White
            $secContent | Where-Object { $_ -match '^\[.*\]$' } | ForEach-Object {
                Write-Host "    - $_" -ForegroundColor White
            }
            $settingsFound = $true
        }
        
        # Windows Firewall
        $FirewallXml = Join-Path $MachinePath "Microsoft\Windows NT\SecEdit\GptTmpl.inf"
        if (Test-Path $FirewallXml) {
            # Already shown above
        }
    }
    
    # --- USER SETTINGS ---
    # Check both locations: DomainSysvol\GPO\User and User
    $UserPath = Join-Path $GPOPath "DomainSysvol\GPO\User"
    if (-not (Test-Path $UserPath)) {
        $UserPath = Join-Path $GPOPath "User"
    }
    
    if (Test-Path $UserPath) {
        Write-Host "`n[USER CONFIGURATION]" -ForegroundColor Green
        Write-Host "Location: $UserPath`n" -ForegroundColor Gray
        
        $UserRegistryPol = Join-Path $UserPath "Registry.pol"
        if (Test-Path $UserRegistryPol) {
            Write-Host "  [Registry Policies]" -ForegroundColor Yellow
            Write-Host "  File: $UserRegistryPol" -ForegroundColor Gray
            
            try {
                $regEntries = Parse-PolFile -Path $UserRegistryPol
                if ($regEntries.Count -gt 0) {
                    foreach ($entry in $regEntries) {
                        Write-Host "    - $($entry.Key)\$($entry.ValueName) = $($entry.Data)" -ForegroundColor White
                    }
                    $settingsFound = $true
                }
            } catch {
                Write-Host "    Registry.pol file exists but parsing requires PolicyFileEditor module" -ForegroundColor Yellow
                $settingsFound = $true
            }
        }
    }
    
    # --- XML-BASED SETTINGS (DomainSysvol\GPO) ---
    $DomainSysvolPath = Join-Path $GPOPath "DomainSysvol\GPO"
    if (Test-Path $DomainSysvolPath) {
        Write-Host "`n[ADVANCED SETTINGS (XML-based)]" -ForegroundColor Green
        Write-Host "Location: $DomainSysvolPath`n" -ForegroundColor Gray
        
        # Find all XML files
        $xmlFiles = Get-ChildItem $DomainSysvolPath -Recurse -Filter "*.xml"
        foreach ($xmlFile in $xmlFiles) {
            Write-Host "  [Policy File: $($xmlFile.Name)]" -ForegroundColor Yellow
            Write-Host "  Path: $($xmlFile.FullName)" -ForegroundColor Gray
            
            # Try to parse and show settings
            try {
                [xml]$xmlContent = Get-Content $xmlFile.FullName
                $rootElement = $xmlContent.DocumentElement
                if ($rootElement) {
                    Write-Host "    Type: $($rootElement.LocalName)" -ForegroundColor White
                    # Count child elements
                    $childCount = @($rootElement.ChildNodes | Where-Object { $_.NodeType -eq 'Element' }).Count
                    Write-Host "    Contains: $childCount policy setting(s)" -ForegroundColor White
                    $settingsFound = $true
                }
            } catch {
                Write-Host "    XML file present (parsing details requires manual inspection)" -ForegroundColor Gray
            }
            Write-Host ""
        }
    }
    
    if (-not $settingsFound) {
        Write-Host "`nWARNING: No policy settings found in this GPO." -ForegroundColor Yellow
        Write-Host "This might be an empty GPO or the settings are in an unrecognized format." -ForegroundColor Yellow
    }
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "SUMMARY" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "All policy files are located in the directory structure above." -ForegroundColor White
    Write-Host "To manually inspect, navigate to: $GPOPath" -ForegroundColor White
    Write-Host "`nNote: For detailed registry policy parsing, install PolicyFileEditor module:" -ForegroundColor Yellow
    Write-Host "  Install-Module -Name PolicyFileEditor -Scope CurrentUser" -ForegroundColor Gray
    Write-Host ""
}

# ================================================================================
# HELPER FUNCTION: Parse-PolFile (Basic parser for Registry.pol)
# ================================================================================
function Parse-PolFile {
    param([string]$Path)
    
    $results = @()
    
    # Read the binary file
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    
    # Check for PReg header
    if ($bytes.Length -lt 8) { return $results }
    
    $header = [System.Text.Encoding]::ASCII.GetString($bytes[0..3])
    if ($header -ne "PReg") { 
        throw "Invalid Registry.pol file format"
    }
    
    # Parse entries (simplified - real parsing is complex)
    # This is a basic implementation showing the concept
    $index = 8
    while ($index -lt $bytes.Length - 20) {
        try {
            # Try to find registry key patterns
            $nullIndex = $index
            while ($nullIndex -lt $bytes.Length - 1 -and -not ($bytes[$nullIndex] -eq 0 -and $bytes[$nullIndex+1] -eq 0)) {
                $nullIndex += 2
            }
            
            if ($nullIndex -ge $bytes.Length) { break }
            
            # Extract unicode string
            $keyLength = $nullIndex - $index
            if ($keyLength -gt 0 -and $keyLength -lt 2000) {
                $keyName = [System.Text.Encoding]::Unicode.GetString($bytes[$index..$nullIndex])
                $keyName = $keyName.Trim([char]0)
                
                if ($keyName.Length -gt 0) {
                    $results += [PSCustomObject]@{
                        Key = $keyName
                        ValueName = "(parsed)"
                        Data = "(binary data)"
                    }
                }
            }
            
            $index = $nullIndex + 2
            
            # Safety break
            if ($results.Count -gt 100) { break }
            
        } catch {
            break
        }
    }
    
    return $results
}

Write-Host "`nFunction loaded: Get-GPOSettings -FolderID '{GUID}'" -ForegroundColor Green
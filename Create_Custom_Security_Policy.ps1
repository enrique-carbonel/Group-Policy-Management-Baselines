# ================================================================================
# CREATE CUSTOM SECURITY POLICY (INF FILE)
# This script extracts specific policies and creates a .INF file you can apply
# ================================================================================

# --- CONFIGURATION ---
$WorkingDir = "$PSScriptRoot\CustomPolicies"
if (-not (Test-Path $WorkingDir)) {
    New-Item -Path $WorkingDir -ItemType Directory -Force | Out-Null
}

# ================================================================================
# FUNCTION: New-CustomSecurityPolicy
# Create a custom security policy INF file from selected settings
# ================================================================================
function New-CustomSecurityPolicy {
    param(
        [Parameter(Mandatory=$true)]
        [string]$OutputName,
        
        [Parameter(Mandatory=$false)]
        [hashtable]$SystemAccess = @{},
        
        [Parameter(Mandatory=$false)]
        [hashtable]$RegistryValues = @{},
        
        [Parameter(Mandatory=$false)]
        [hashtable]$PrivilegeRights = @{},
        
        [Parameter(Mandatory=$false)]
        [string]$Description = ""
    )
    
    $outputFile = Join-Path $WorkingDir "$OutputName.inf"
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "CREATING CUSTOM SECURITY POLICY" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    if ($Description) {
        Write-Host "Description: $Description" -ForegroundColor Yellow
    }
    
    # Build INF content
    $infContent = @"
[Unicode]
Unicode=yes

[Version]
signature="`$CHICAGO`$"
Revision=1

"@
    
    # Add System Access settings (password policies, account lockout, etc.)
    if ($SystemAccess.Count -gt 0) {
        $infContent += "[System Access]`n"
        Write-Host "`n[System Access Policies]" -ForegroundColor Green
        foreach ($key in $SystemAccess.Keys | Sort-Object) {
            $value = $SystemAccess[$key]
            $infContent += "$key=$value`n"
            Write-Host "  $key = $value" -ForegroundColor White
        }
        $infContent += "`n"
    }
    
    # Add Registry Values
    if ($RegistryValues.Count -gt 0) {
        $infContent += "[Registry Values]`n"
        Write-Host "`n[Registry Values]" -ForegroundColor Green
        foreach ($key in $RegistryValues.Keys | Sort-Object) {
            $value = $RegistryValues[$key]
            $infContent += "$key=$value`n"
            Write-Host "  $key = $value" -ForegroundColor White
        }
        $infContent += "`n"
    }
    
    # Add Privilege Rights
    if ($PrivilegeRights.Count -gt 0) {
        $infContent += "[Privilege Rights]`n"
        Write-Host "`n[Privilege Rights]" -ForegroundColor Green
        foreach ($key in $PrivilegeRights.Keys | Sort-Object) {
            $value = $PrivilegeRights[$key]
            $infContent += "$key=$value`n"
            Write-Host "  $key = $value" -ForegroundColor White
        }
        $infContent += "`n"
    }
    
    # Save to file
    $infContent | Out-File -FilePath $outputFile -Encoding Unicode
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "SUCCESS" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Policy file created: $outputFile`n" -ForegroundColor Yellow
    
    Write-Host "TO APPLY THIS POLICY:" -ForegroundColor White
    Write-Host "`n  OPTION 1: Import into Group Policy (RECOMMENDED for servers)" -ForegroundColor Green
    Write-Host "  1. Open Group Policy Management: gpmc.msc" -ForegroundColor Cyan
    Write-Host "  2. Edit your GPO > Computer Config > Policies > Windows Settings > Security Settings" -ForegroundColor Cyan
    Write-Host "  3. Right-click 'Security Settings' > Import Policy..." -ForegroundColor Cyan
    Write-Host "  4. Browse to: $outputFile" -ForegroundColor Cyan
    Write-Host "  5. Link GPO to your OU and run: gpupdate /force`n" -ForegroundColor Cyan
    
    Write-Host "  OPTION 2: Apply Locally (for testing only)" -ForegroundColor Green
    Write-Host "  secedit /configure /db temp.sdb /cfg '$outputFile' /overwrite`n" -ForegroundColor Cyan
    
    Write-Host "  OPTION 3: Review First" -ForegroundColor Green
    Write-Host "  notepad '$outputFile'`n" -ForegroundColor Cyan
    
    Write-Host "NOTE: This file stays in CustomPolicies\ - it does NOT need to be moved to GPO backup folders!`n" -ForegroundColor Yellow
    
    return $outputFile
}

# ================================================================================
# EXAMPLE USAGE
# ================================================================================

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "CUSTOM SECURITY POLICY CREATOR" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Working Directory: $WorkingDir`n" -ForegroundColor Gray

Write-Host "EXAMPLE - Create a custom password policy with only 3 settings:" -ForegroundColor Yellow
Write-Host @"

New-CustomSecurityPolicy -OutputName 'MyPasswordPolicy' -SystemAccess @{
    MinimumPasswordLength = 14
    PasswordComplexity    = 1
    LockoutBadCount       = 10
} -Description 'My custom password policy'

"@ -ForegroundColor Gray

Write-Host "`nCOMMON SYSTEM ACCESS SETTINGS:" -ForegroundColor White
Write-Host @"
  MinimumPasswordLength      = 14       (characters)
  MaximumPasswordAge         = 60       (days, 0=never expires)
  MinimumPasswordAge         = 1        (days)
  PasswordComplexity         = 1        (1=enabled, 0=disabled)
  PasswordHistorySize        = 24       (passwords remembered)
  LockoutBadCount            = 10       (invalid attempts before lockout)
  LockoutDuration            = 15       (minutes)
  ResetLockoutCount          = 15       (minutes)
  ClearTextPassword          = 0        (1=allow, 0=disallow)
  RequireLogonToChangePassword = 0     (1=require, 0=not required)
  LSAAnonymousNameLookup     = 0        (1=allow, 0=disallow)

"@ -ForegroundColor Gray

Write-Host "For a full list, see: https://learn.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/`n" -ForegroundColor DarkGray

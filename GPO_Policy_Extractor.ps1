# ================================================================================
# GPO POLICY EXTRACTOR & SELECTOR
# Extract individual policies from GPOs and create custom GPOs with only selected policies
# ================================================================================

# --- CONFIGURATION ---
$BackupPath = "$HOME\Downloads\Windows Server-2022-Security-Baseline-FINAL\GPOs"
$PolicyAnalyzerPath = Join-Path $PSScriptRoot "PolicyAnalyzer_40"
$WorkingDir = "$PSScriptRoot\PolicyExtraction"

# Create working directory
if (-not (Test-Path $WorkingDir)) {
    New-Item -Path $WorkingDir -ItemType Directory -Force | Out-Null
}

# ================================================================================
# FUNCTION: Get-GPOPolicies
# Convert a GPO to PolicyRules and display all individual policies
# ================================================================================
function Get-GPOPolicies {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FolderID,
        
        [switch]$ExportToFile
    )
    
    $GPOPath = Join-Path $BackupPath $FolderID
    
    if (-not (Test-Path $GPOPath)) {
        Write-Host "ERROR: GPO folder not found: $GPOPath" -ForegroundColor Red
        return
    }
    
    # Get GPO Name
    $BackupXmlPath = Join-Path $GPOPath "Backup.xml"
    if (Test-Path $BackupXmlPath) {
        [xml]$backupXml = Get-Content $BackupXmlPath
        $gpoName = $backupXml.GroupPolicyBackupScheme.GroupPolicyObject.GroupPolicyCoreSettings.DisplayName.InnerText
    }
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "EXTRACTING POLICIES FROM GPO" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "GPO Name: $gpoName" -ForegroundColor Yellow
    Write-Host "Folder ID: $FolderID`n" -ForegroundColor Yellow
    
    # Convert to PolicyRules
    $policyRulesFile = Join-Path $WorkingDir "$FolderID.PolicyRules"
    $gpo2PolicyExe = Join-Path $PolicyAnalyzerPath "GPO2PolicyRules.exe"
    
    Write-Host "Converting GPO to PolicyRules format..." -ForegroundColor Gray
    & $gpo2PolicyExe $GPOPath $policyRulesFile | Out-Null
    
    if (-not (Test-Path $policyRulesFile)) {
        Write-Host "ERROR: Failed to convert GPO to PolicyRules format" -ForegroundColor Red
        return
    }
    
    # Parse PolicyRules XML
    [xml]$policyXml = Get-Content $policyRulesFile
    $policies = @()
    $index = 1
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "INDIVIDUAL POLICIES" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    foreach ($node in $policyXml.DocumentElement.ChildNodes) {
        $policyType = $node.Name
        $policyDetails = ""
        
        switch ($policyType) {
            "SecurityTemplate" {
                $section = $node.Section
                $lineItem = $node.LineItem
                $policyDetails = "[$section] $lineItem"
            }
            "RegistryPolicy" {
                $keyPath = $node.KeyPath
                $valueName = $node.ValueName
                $value = $node.Value
                $valueType = $node.Type
                $policyDetails = "Registry: $keyPath\$valueName = $value ($valueType)"
            }
            "ComputerConfig" {
                $key = $node.Key
                $valueName = $node.Value
                $regType = $node.RegType
                $regData = $node.RegData
                $policyDetails = "Registry (Computer): $key\$valueName = $regData ($regType)"
            }
            "UserConfig" {
                $key = $node.Key
                $valueName = $node.Value
                $regType = $node.RegType
                $regData = $node.RegData
                $policyDetails = "Registry (User): $key\$valueName = $regData ($regType)"
            }
            "AuditPolicy" {
                $subcategory = $node.SubcategoryName
                $setting = $node.SettingValue
                $settingText = switch ($setting) {
                    "0" { "No Auditing" }
                    "1" { "Success" }
                    "2" { "Failure" }
                    "3" { "Success and Failure" }
                    default { $setting }
                }
                $policyDetails = "Audit: $subcategory = $settingText"
            }
            "UserRightsAssignment" {
                $right = $node.Name
                $accounts = $node.Member -join ", "
                if ([string]::IsNullOrWhiteSpace($accounts)) {
                    $accounts = "(None)"
                }
                $policyDetails = "User Right: $right = $accounts"
            }
            "CSE-Machine" {
                $cseName = $node.Name
                $policyDetails = "[Extension] $cseName"
            }
            "CSE-User" {
                $cseName = $node.Name
                $policyDetails = "[Extension] $cseName"
            }
            default {
                $policyDetails = "$policyType (custom policy)"
            }
        }
        
        $policies += [PSCustomObject]@{
            Index = $index
            Type = $policyType
            Details = $policyDetails
            XMLNode = $node.OuterXml
        }
        
        # Don't display CSE extensions in the main list
        if ($policyType -notlike "CSE-*") {
            Write-Host ("{0,3}. {1}" -f $index, $policyDetails) -ForegroundColor White
        } else {
            Write-Host ("{0,3}. {1}" -f $index, $policyDetails) -ForegroundColor DarkGray
        }
        
        $index++
    }
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "SUMMARY" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Total policies found: $($policies.Count)" -ForegroundColor Yellow
    Write-Host "PolicyRules file: $policyRulesFile`n" -ForegroundColor Gray
    
    # Store in global variable for selection
    $global:CurrentGPOPolicies = $policies
    $global:CurrentGPOName = $gpoName
    $global:CurrentPolicyRulesFile = $policyRulesFile
    
    Write-Host "NEXT STEPS:" -ForegroundColor White
    Write-Host "1. To select specific policies: Select-Policies -Indices 1,2,5,7" -ForegroundColor Cyan
    Write-Host "2. To export all to CSV: Export-PoliciesToCSV -Path 'policies.csv'" -ForegroundColor Cyan
    Write-Host "3. To view a specific policy: Get-PolicyDetails -Index 3" -ForegroundColor Cyan
    
    return $policies
}

# ================================================================================
# FUNCTION: Select-Policies
# Select specific policies by index and create a new PolicyRules file
# ================================================================================
function Select-Policies {
    param(
        [Parameter(Mandatory=$true)]
        [int[]]$Indices,
        
        [Parameter(Mandatory=$false)]
        [string]$OutputName
    )
    
    if ($null -eq $global:CurrentGPOPolicies) {
        Write-Host "ERROR: No policies loaded. Run Get-GPOPolicies first." -ForegroundColor Red
        return
    }
    
    if ([string]::IsNullOrWhiteSpace($OutputName)) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $OutputName = "Selected_Policies_$timestamp"
    }
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "CREATING CUSTOM POLICY SET" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Base GPO: $global:CurrentGPOName" -ForegroundColor Yellow
    Write-Host "Selected Policies:" -ForegroundColor Yellow
    
    $selectedXML = "<PolicyRules>`n"
    
    foreach ($idx in $Indices) {
        $policy = $global:CurrentGPOPolicies | Where-Object { $_.Index -eq $idx }
        if ($policy) {
            Write-Host "  [$idx] $($policy.Details)" -ForegroundColor White
            $selectedXML += "  " + $policy.XMLNode + "`n"
        } else {
            Write-Host "  WARNING: Index $idx not found" -ForegroundColor Yellow
        }
    }
    
    $selectedXML += "</PolicyRules>"
    
    # Save to file
    $outputFile = Join-Path $WorkingDir "$OutputName.PolicyRules"
    $selectedXML | Out-File -FilePath $outputFile -Encoding UTF8
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "SUCCESS" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Custom PolicyRules file created: $outputFile" -ForegroundColor Yellow
    
    Write-Host "`nNEXT STEPS:" -ForegroundColor White
    Write-Host "1. Convert to importable format:" -ForegroundColor Cyan
    Write-Host "   Convert-ToGPOFormat -PolicyRulesFile '$outputFile'" -ForegroundColor Gray
    Write-Host "2. Or merge with other policies:" -ForegroundColor Cyan
    Write-Host "   Merge-PolicyFiles -Files @('file1.PolicyRules', 'file2.PolicyRules')" -ForegroundColor Gray
    
    return $outputFile
}

# ================================================================================
# FUNCTION: Export-PoliciesToCSV
# Export all policies to CSV for easy review in Excel
# ================================================================================
function Export-PoliciesToCSV {
    param(
        [Parameter(Mandatory=$false)]
        [string]$Path = "$WorkingDir\Policies_Export.csv"
    )
    
    if ($null -eq $global:CurrentGPOPolicies) {
        Write-Host "ERROR: No policies loaded. Run Get-GPOPolicies first." -ForegroundColor Red
        return
    }
    
    $global:CurrentGPOPolicies | Select-Object Index, Type, Details | Export-Csv -Path $Path -NoTypeInformation
    Write-Host "Policies exported to: $Path" -ForegroundColor Green
}

# ================================================================================
# FUNCTION: Get-PolicyDetails
# Show detailed information about a specific policy
# ================================================================================
function Get-PolicyDetails {
    param(
        [Parameter(Mandatory=$true)]
        [int]$Index
    )
    
    if ($null -eq $global:CurrentGPOPolicies) {
        Write-Host "ERROR: No policies loaded. Run Get-GPOPolicies first." -ForegroundColor Red
        return
    }
    
    $policy = $global:CurrentGPOPolicies | Where-Object { $_.Index -eq $Index }
    
    if (-not $policy) {
        Write-Host "ERROR: Policy with index $Index not found" -ForegroundColor Red
        return
    }
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "POLICY DETAILS - Index $Index" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Type: $($policy.Type)" -ForegroundColor Yellow
    Write-Host "Details: $($policy.Details)" -ForegroundColor White
    Write-Host "`nXML Structure:" -ForegroundColor Yellow
    Write-Host $policy.XMLNode -ForegroundColor Gray
}

# ================================================================================
# FUNCTION: Convert-ToGPOFormat
# Convert PolicyRules file to importable GPO format
# ================================================================================
function Convert-ToGPOFormat {
    param(
        [Parameter(Mandatory=$true)]
        [string]$PolicyRulesFile,
        
        [Parameter(Mandatory=$false)]
        [string]$OutputName
    )
    
    if (-not (Test-Path $PolicyRulesFile)) {
        Write-Host "ERROR: PolicyRules file not found: $PolicyRulesFile" -ForegroundColor Red
        return
    }
    
    if ([string]::IsNullOrWhiteSpace($OutputName)) {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($PolicyRulesFile)
        $OutputName = $baseName + "_GPO"
    }
    
    $outputPath = Join-Path $WorkingDir $OutputName
    $builderExe = Join-Path $PolicyAnalyzerPath "PolicyRulesFileBuilder.exe"
    
    Write-Host "`nConverting PolicyRules to GPO format..." -ForegroundColor Cyan
    Write-Host "Input: $PolicyRulesFile" -ForegroundColor Gray
    Write-Host "Output: $outputPath" -ForegroundColor Gray
    
    # Capture error output from the conversion tool
    $output = & $builderExe $PolicyRulesFile $outputPath 2>&1
    $exitCode = $LASTEXITCODE
    
    if (Test-Path $outputPath) {
        # Check if output is a directory (GPO structure) or file
        $isDirectory = (Get-Item $outputPath).PSIsContainer
        
        if ($isDirectory) {
            Write-Host "`nSUCCESS: GPO folder structure created in: $outputPath" -ForegroundColor Green
            Write-Host "`nYou can now import this GPO using Group Policy Management Console" -ForegroundColor Yellow
            Write-Host "or copy it to your GPOs backup folder." -ForegroundColor Yellow
        } else {
            # It's a file, check if it has content
            $fileSize = (Get-Item $outputPath).Length
            if ($fileSize -gt 100) {
                Write-Host "`nSUCCESS: GPO file created: $outputPath (Size: $fileSize bytes)" -ForegroundColor Green
            } else {
                Write-Host "`nWARNING: Conversion created output but file is nearly empty ($fileSize bytes)" -ForegroundColor Yellow
                Write-Host "This may indicate an issue with the PolicyRules file format or missing dependencies." -ForegroundColor Yellow
                if ($output) {
                    Write-Host "`nToolOutput: $output" -ForegroundColor Gray
                }
            }
        }
    } else {
        Write-Host "`nERROR: Conversion failed - no output created" -ForegroundColor Red
        Write-Host "Builder exit code: $exitCode" -ForegroundColor Red
        if ($output) {
            Write-Host "`nTool Error Output: $output" -ForegroundColor Red
        }
        Write-Host "`nThis tool may not support CLI conversion on this machine." -ForegroundColor Yellow
        Write-Host "Use Convert-ToInfFormat for SecurityTemplate policies instead." -ForegroundColor Yellow
        Write-Host "`nTroubleshooting tips:" -ForegroundColor Yellow
        Write-Host "1. Verify the PolicyRules file has valid content" -ForegroundColor Yellow
        Write-Host "2. Check that referenced GPO source files exist" -ForegroundColor Yellow
        Write-Host "3. Try running Policy Analyzer manually: $(Join-Path $PolicyAnalyzerPath 'PolicyAnalyzer.exe')" -ForegroundColor Yellow
        Write-Host "4. If this still fails, use Convert-ToInfFormat -PolicyRulesFile '<file.PolicyRules>'" -ForegroundColor Yellow
    }
}

# ================================================================================
# FUNCTION: Merge-PolicyFiles
# Merge multiple PolicyRules files into one
# ================================================================================
function Merge-PolicyFiles {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$Files,
        
        [Parameter(Mandatory=$false)]
        [string]$OutputName = "Merged_Policies"
    )
    
    $mergeScript = Join-Path $PolicyAnalyzerPath "Merge-PolicyRules.ps1"
    $outputFile = Join-Path $WorkingDir "$OutputName.PolicyRules"
    
    Write-Host "`nMerging policy files..." -ForegroundColor Cyan
    foreach ($file in $Files) {
        Write-Host "  - $file" -ForegroundColor Gray
    }
    
    & $mergeScript $Files | Out-File -Encoding utf8 -FilePath $outputFile
    
    Write-Host "`nSUCCESS: Merged file created: $outputFile" -ForegroundColor Green
    return $outputFile
}

# ================================================================================
# FUNCTION: Convert-ToInfFormat
# Convert SecurityTemplate policies from PolicyRules to .inf format
# More reliable for security policies (passwords, account lockout, etc)
# ================================================================================
function Convert-ToInfFormat {
    param(
        [Parameter(Mandatory=$true)]
        [string]$PolicyRulesFile,
        
        [Parameter(Mandatory=$false)]
        [string]$OutputName
    )
    
    if (-not (Test-Path $PolicyRulesFile)) {
        Write-Host "ERROR: PolicyRules file not found: $PolicyRulesFile" -ForegroundColor Red
        return
    }
    
    if ([string]::IsNullOrWhiteSpace($OutputName)) {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($PolicyRulesFile)
        $OutputName = $baseName
    }
    
    $outputFile = Join-Path $WorkingDir "$OutputName.inf"
    
    Write-Host "`nConverting PolicyRules to .INF format..." -ForegroundColor Cyan
    Write-Host "Input: $PolicyRulesFile" -ForegroundColor Gray
    Write-Host "Output: $outputFile" -ForegroundColor Gray
    
    try {
        [xml]$policyXml = Get-Content $PolicyRulesFile
        
        # Build INF file content
        $infContent = @()
        $infContent += "[Version]"
        $infContent += "signature=`"`$CHICAGO`$"
        $infContent += "Revision=1"
        $infContent += ""
        
        $systemAccessItems = @()
        $otherSections = @{}
        
        # Extract security template items
        foreach ($node in $policyXml.PolicyRules.ChildNodes) {
            if ($node.Name -eq 'SecurityTemplate') {
                $section = $node.Section
                $lineItem = $node.LineItem
                
                if ($section -eq 'System Access') {
                    $systemAccessItems += $lineItem
                } else {
                    if (-not $otherSections.ContainsKey($section)) {
                        $otherSections[$section] = @()
                    }
                    $otherSections[$section] += $lineItem
                }
            }
        }
        
        # Add System Access section
        if ($systemAccessItems.Count -gt 0) {
            $infContent += "[System Access]"
            $infContent += $systemAccessItems
            $infContent += ""
        }
        
        # Add other sections
        foreach ($section in $otherSections.Keys) {
            $infContent += "[$section]"
            $infContent += $otherSections[$section]
            $infContent += ""
        }
        
        # Write to file
        $infContent | Out-File -Encoding ASCII -FilePath $outputFile -Force
        
        Write-Host "`nSUCCESS: INF file created: $outputFile" -ForegroundColor Green
        Write-Host "File size: $((Get-Item $outputFile).Length) bytes" -ForegroundColor Gray
        Write-Host "`nYou can import this file using:" -ForegroundColor Yellow
        Write-Host "  secedit /configure /db temp.sdb /cfg '$outputFile' /overwrite" -ForegroundColor Gray
        Write-Host "`nOr via Group Policy Management Console:" -ForegroundColor Yellow
        Write-Host "  Right-click 'Security Settings' > 'Import Policy...' > Select this .inf file" -ForegroundColor Gray
        
        return $outputFile
    }
    catch {
        Write-Host "`nERROR: Failed to convert PolicyRules to INF format" -ForegroundColor Red
        Write-Host "Details: $_" -ForegroundColor Red
        return $null
    }
}

# ================================================================================
# STARTUP MESSAGE
# ================================================================================
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "GPO POLICY EXTRACTOR & SELECTOR" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Working Directory: $WorkingDir`n" -ForegroundColor Gray

Write-Host "AVAILABLE COMMANDS:" -ForegroundColor White
Write-Host "1. Get-GPOPolicies -FolderID '{GUID}'" -ForegroundColor Cyan
Write-Host "   Extract and view all policies from a GPO`n" -ForegroundColor Gray

Write-Host "2. Select-Policies -Indices 1,3,5,7 -OutputName 'MyCustomPolicies'" -ForegroundColor Cyan
Write-Host "   Select specific policies by index number`n" -ForegroundColor Gray

Write-Host "3. Export-PoliciesToCSV -Path 'policies.csv'" -ForegroundColor Cyan
Write-Host "   Export policies to CSV for Excel review`n" -ForegroundColor Gray

Write-Host "4. Convert-ToInfFormat -PolicyRulesFile 'file.PolicyRules'" -ForegroundColor Cyan
Write-Host "   Convert SecurityTemplate policies to .INF format (RECOMMENDED)`n" -ForegroundColor Gray

Write-Host "5. Convert-ToGPOFormat -PolicyRulesFile 'file.PolicyRules'" -ForegroundColor Cyan
Write-Host "   Convert PolicyRules to full GPO format`n" -ForegroundColor Gray

Write-Host "6. Merge-PolicyFiles -Files @('file1.PolicyRules', 'file2.PolicyRules')" -ForegroundColor Cyan
Write-Host "   Combine multiple policy files into one`n" -ForegroundColor Gray

Write-Host "========================================`n" -ForegroundColor Green

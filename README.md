# 📘 GPO Policy Analysis & Extraction Toolkit

## 🌟 What Is This Toolkit?

This toolkit helps you **understand and manage Windows security policies** stored in Group Policy Objects (GPOs). Think of it as a **Swiss Army knife for security policies** - it lets you see exactly what security settings are in a GPO, pick only the ones you want, and create your own custom policy files.

---

## 🤔 What Are Group Policy Objects (GPOs)?

### Simple Explanation
A **Group Policy Object (GPO)** is like a **rulebook for Windows computers**. Just like a school has rules (no running in halls, raise hand to speak, etc.), Windows computers can have rules too:

- **Password Rules**: "Passwords must be at least 14 characters long"
- **Security Rules**: "Don't save passwords in Remote Desktop"
- **Firewall Rules**: "Block incoming connections unless specifically allowed"
- **Audit Rules**: "Log every time someone tries to log in"

### The Problem This Toolkit Solves

Imagine you have a rulebook with **200 rules**, but you only want to apply **10 specific rules** to your computer. Reading through all 200 rules manually would be tedious! This toolkit helps you:

1. **📋 SEE** - View all 200 rules in a readable list
2. **✂️ EXTRACT** - Pick only the 10 rules you want
3. **📦 CREATE** - Package those 10 rules into a new file you can apply

---

## 📁 What's In Your Workspace?

### **Windows Server-2022-Security-Baseline-FINAL\GPOs\** (Original Data)
🔒 **DO NOT DELETE** - This is your **master rulebook collection**

This folder contains **8 different GPO "rulebooks"** from Microsoft's Security Baseline:

```
📂 GPOs\
  ├─ {0A531EAC...} - Internet Explorer 11 - Computer
  ├─ {20FAD6FB...} - Windows Server 2022 - Member Server (200+ rules!)
  ├─ {64059F15...} - Credential Guard
  ├─ {8104AFEB...} - Domain Controller Virtualization
  ├─ {966B53AB...} - Defender Antivirus
  ├─ {AAC7C960...} - Domain Security (password policies)
  ├─ {BEA08B79...} - Internet Explorer 11 - User
  └─ {E2B8214C...} - Domain Controller
```

Each folder contains files like:
- **Backup.xml** - Metadata (GPO name, ID)
- **registry.pol** - Registry settings (binary file, hard to read)
- **GptTmpl.inf** - Security settings (readable text file)
- **audit.csv** - Audit policies (what to log)

### **Your PowerShell Scripts** (The Tools)

#### 1. **GPO_Detective_and_Modulizer.ps1** 📊
**What it does**: Creates a **quick inventory** of all your GPOs

**Think of it as**: A **table of contents** for your rulebooks

**What you get**: A CSV file showing:
- GPO Name (friendly name like "Member Server")
- Folder ID (the GUID/unique identifier)
- Whether it has Computer or User settings
- Full path to the GPO files

**How to use**:
```powershell
# Just run the script
. 'C:\Users\enriq\Downloads\Baselines Powershell\GPO_Detective_and_Modulizer.ps1'

# Output: GPO_Inventory.csv on your Desktop in your local machine (ex: C:\users\user\Desktop)
```

**Real-world scenario**: You have 8 GPOs and you forgot what they're called. Run this script to get a quick list.

---

#### 2. **GPO_Policy_Extractor.ps1** 🔍
**What it does**: **Extracts and displays EVERY individual policy** from a GPO

**Think of it as**: A **magnifying glass** that shows you each rule inside the rulebook

**What you get**:
- A numbered list of ALL policies (e.g., 1-200)
- Clear descriptions of each policy
- Ability to select specific policies by number
- Export to CSV for review in Excel

**How to use**:
```powershell
# Step 1: Load the script
. 'C:\Users\enriq\Downloads\Baselines Powershell\GPO_Policy_Extractor.ps1'

# Step 2: Extract policies from a GPO
Get-GPOPolicies -FolderID '{20FAD6FB-7C6D-496E-801C-0434769847FF}'

# You'll see a list like:
#   1. Registry (Computer): NoDriveTypeAutoRun = 255
#   2. Registry (Computer): NoAutorun = 1
#   3. Registry (Computer): DisableAutomaticRestartSignOn = 1
#   ... (continues for 200+ policies)

# Step 3: Select only the policies you want (example: policies 1, 5, and 10)
Select-Policies -Indices 1,5,10 -OutputName 'MyCustomPolicies'

# Step 4: Export all policies to Excel for easier review
Export-PoliciesToCSV -Path 'C:\Users\enriq\Desktop\AllPolicies.csv'
Convert-ToInfFormat -PolicyRulesFile 'PolicyExtraction\MySecurityPolicies.PolicyRules'
```

**Real-world scenario**: You want to see all 200+ policies in the Member Server GPO, then pick only 5 specific ones to apply to your computer.

**Key Functions**:

| Function | What It Does | Example |
|----------|--------------|---------|
| `Get-GPOPolicies` | Shows all policies in a GPO | `Get-GPOPolicies -FolderID '{GUID}'` |
| `Select-Policies` | Picks specific policies by number | `Select-Policies -Indices 1,3,5,7` |
| `Export-PoliciesToCSV` | Exports to Excel | `Export-PoliciesToCSV -Path 'myfile.csv'` |
| `Convert-ToInfFormat` | ✅ **RECOMMENDED** - Converts security policies to .INF | `Convert-ToInfFormat -PolicyRulesFile 'file.PolicyRules'` |
| `Convert-ToGPOFormat` | Converts PolicyRules to GPO format (experimental; CLI may fail) | `Convert-ToGPOFormat -PolicyRulesFile 'file.PolicyRules'` |
| `Merge-PolicyFiles` | Combines multiple policy files | `Merge-PolicyFiles -Files @('file1.PolicyRules', 'file2.PolicyRules')` |

---

#### 3. **Create_Custom_Security_Policy.ps1** ✏️
**What it does**: Creates **custom .INF files** with only the security settings you choose

**Think of it as**: A **policy builder** that lets you create your own rulebook from scratch

**What you get**: A `.inf` file that you can apply to your computer or import into a GPO

**Best for**: Password policies, account lockout, privilege assignments (NOT registry settings)

**How to use**:
```powershell
# Load the script
. 'C:\Users\enriq\Downloads\Baselines Powershell\Create_Custom_Security_Policy.ps1'

# Example 1: Create a custom password policy
New-CustomSecurityPolicy -OutputName 'StrictPasswords' -SystemAccess @{
    MinimumPasswordLength = 16
    PasswordComplexity    = 1    # 1 = enabled, 0 = disabled
    MaximumPasswordAge    = 90   # days
    PasswordHistorySize   = 24   # remember last 24 passwords
} -Description 'Strict password requirements for HR department'

# Example 2: Account lockout policy
New-CustomSecurityPolicy -OutputName 'LockoutPolicy' -SystemAccess @{
    LockoutBadCount    = 5    # Lock after 5 failed attempts
    LockoutDuration    = 30   # Stay locked for 30 minutes
    ResetLockoutCount  = 30   # Reset counter after 30 minutes
} -Description 'Aggressive account lockout'

# Output: Creates a .inf file in CustomPolicies\ folder
```

**📦 Where Does the .INF File Go?**

Your `.inf` file is automatically saved in:
```
C:\Users\enriq\Downloads\Baselines Powershell\CustomPolicies\YourPolicyName.inf
```

**It does NOT need to be moved** to the GPO backup folders (`Windows Server-2022-Security-Baseline-FINAL\GPOs\`). Those folders contain original Microsoft baseline GPO backups and should remain unchanged.

**To import your .inf file into Group Policy**: See **Scenario 4** below for complete step-by-step instructions!

**Common Settings You Can Use**:

| Setting | What It Controls | Example Values |
|---------|------------------|----------------|
| `MinimumPasswordLength` | Shortest password allowed | `14` = at least 14 characters |
| `PasswordComplexity` | Require uppercase, lowercase, numbers, symbols | `1` = required, `0` = not required |
| `MaximumPasswordAge` | How often password must change | `60` = change every 60 days, `0` = never expires |
| `MinimumPasswordAge` | How soon can change password again | `1` = must wait 1 day between changes |
| `PasswordHistorySize` | How many old passwords to remember | `24` = can't reuse last 24 passwords |
| `LockoutBadCount` | Failed login attempts before lockout | `10` = lock after 10 wrong passwords |
| `LockoutDuration` | How long account stays locked | `15` = unlock after 15 minutes, `-1` = admin must unlock |
| `ResetLockoutCount` | Time before attempt counter resets | `15` = reset counter after 15 minutes |
| `ClearTextPassword` | Allow storing passwords as plain text | `0` = no (secure), `1` = yes (INSECURE!) |

**Real-world scenario**: You need a password policy that requires 16-character passwords with complexity, but you don't want all the other 190 policies from the Member Server GPO.

---

### **PolicyAnalyzer_40\** (Microsoft's Official Tool)
🔧 **Third-party toolkit** from Microsoft Security Compliance Toolkit

This folder contains Microsoft's official tools for converting and analyzing GPOs:

| File | What It Does |
|------|--------------|
| **GPO2PolicyRules.exe** | Converts GPO backups to readable `.PolicyRules` XML format |
| **PolicyRulesFileBuilder.exe** | Converts `.PolicyRules` back to GPO format |
| **Split-PolicyRules.ps1** | Splits a PolicyRules file by GPO name |
| **Merge-PolicyRules.ps1** | Combines multiple PolicyRules files |
| **PolicyAnalyzer.exe** | GUI tool to compare two GPOs and see differences |

**Note**: The `GPO_Policy_Extractor.ps1` script uses these tools behind the scenes!

---

### **Temporary Working Folders** (Auto-Generated)

#### **PolicyExtraction\** (Temporary)
✅ **Safe to delete** - Will regenerate automatically

Contains:
- **{GUID}.PolicyRules** - Extracted policies from GPOs
- **CustomPolicyName.PolicyRules** - Your custom policy selections

**When it's created**: Automatically when you run `Get-GPOPolicies`

**What's inside**:
```
PolicyExtraction\
  ├─ {20FAD6FB...}.PolicyRules  - Extracted Member Server policies
  ├─ {AAC7C960...}.PolicyRules  - Extracted Domain Security policies
  └─ MyCustomSelection.PolicyRules - Your selected policies
```

#### **CustomPolicies\** (Temporary)
✅ **Safe to delete** - Will regenerate automatically

Contains:
- **PolicyName.inf** - Custom security policy files you created

**When it's created**: Automatically when you run `New-CustomSecurityPolicy`

**What's inside**:
```
CustomPolicies\
  ├─ MyPasswordPolicy.inf
  ├─ LockoutPolicy.inf
  └─ StrictPasswords.inf
```

---

## 🚀 Common Workflows

### **Scenario 1: "I Want to See What's in a GPO"**

**Goal**: View all the rules inside the "Member Server" GPO

```powershell
# Step 1: Load the extractor tool
. 'C:\Users\enriq\Downloads\Baselines Powershell\GPO_Policy_Extractor.ps1'

# Step 2: Extract and view all policies
Get-GPOPolicies -FolderID '{20FAD6FB-7C6D-496E-801C-0434769847FF}'

# You'll see a numbered list of all 200+ policies
```

**What you'll see**:
```
1. Registry (Computer): Software\Microsoft\Windows\...\NoDriveTypeAutoRun = 255
2. Registry (Computer): Software\Microsoft\Windows\...\NoAutorun = 1
3. Registry (Computer): Software\Microsoft\Windows\...\DisableAutomaticRestartSignOn = 1
...
200. [Extension] Security
```

---

### **Scenario 2: "I Only Want 5 Policies Out of 200"**

**Goal**: Extract policies 2, 15, 23, 45, and 100 from Member Server GPO

```powershell
# Step 1: Load and extract
. 'C:\Users\enriq\Downloads\Baselines Powershell\GPO_Policy_Extractor.ps1'
Get-GPOPolicies -FolderID '{20FAD6FB-7C6D-496E-801C-0434769847FF}'

# Step 2: Select only the policies you want by their numbers
Select-Policies -Indices 2,15,23,45,100 -OutputName 'MyFivePolicies'

# Step 3: Convert to .INF format (RECOMMENDED for security policies)
Convert-ToInfFormat -PolicyRulesFile 'PolicyExtraction\MyFivePolicies.PolicyRules' -OutputName 'MyFivePolicies'

# Output: Creates PolicyExtraction\MyFivePolicies.inf
# This file contains ONLY those 5 policies in importable format!
```

**What happens**:
1. Script reads all 200 policies
2. Extracts only policies #2, #15, #23, #45, and #100
3. Converts to .INF format (better for security policies)
4. You can now import this file or share it

**Note on Conversion Formats**:
- **Use `Convert-ToInfFormat`** (✅ RECOMMENDED) for security policies like:
  - Password policies (minimum length, complexity, age)
  - Account lockout policies
  - Kerberos policies
  - Privilege restrictions
  
- **Use `Convert-ToGPOFormat`** for complex registry-based policies or when you need the full GPO folder structure.
  - Note: `Convert-ToGPOFormat` is experimental and may fail depending on `PolicyRulesFileBuilder.exe` support in your environment.
  - If it fails, use `Convert-ToInfFormat` instead for SecurityTemplate-style policy output.

---

### **Scenario 3: "I Want to Create a Password Policy"**

**Goal**: Create a policy with strict password requirements

```powershell
# Load the policy creator
. 'C:\Users\enriq\Downloads\Baselines Powershell\Create_Custom_Security_Policy.ps1'

# Create your custom policy
New-CustomSecurityPolicy -OutputName 'StrictPasswords' -SystemAccess @{
    MinimumPasswordLength = 16       # Passwords must be 16+ characters
    PasswordComplexity    = 1        # Must have uppercase, lowercase, numbers, symbols
    MaximumPasswordAge    = 90       # Must change password every 90 days
    MinimumPasswordAge    = 1        # Can't change password more than once per day
    PasswordHistorySize   = 24       # Can't reuse last 24 passwords
    LockoutBadCount       = 5        # Lock after 5 wrong attempts
    LockoutDuration       = 30       # Stay locked for 30 minutes
} -Description 'Strict password policy for Finance department'

# Output: CustomPolicies\StrictPasswords.inf
```

**To apply this policy locally**:
```powershell
secedit /configure /db temp.sdb /cfg 'C:\Users\enriq\Downloads\Baselines Powershell\CustomPolicies\StrictPasswords.inf' /overwrite
```

---

### **Scenario 4: "I Want to Import My Custom Policy into Group Policy Management"**

**Goal**: Import the `.inf` file you created into a Group Policy Object on your server

#### **📍 Where Are Your .INF Files Located?**

When you create a custom policy with `Create_Custom_Security_Policy.ps1`, the `.inf` file is automatically saved in:

```
C:\Users\enriq\Downloads\Baselines Powershell\CustomPolicies\YourPolicyName.inf
```

**Important**: Your `.inf` file does **NOT** need to be inside the GPO backup folders. You can import `.inf` files from **any location** on your computer or network.

#### **Method 1: Import via Group Policy Management Console (GUI)** ✅ **RECOMMENDED**

**Step-by-step instructions**:

1. **Open Group Policy Management**
   ```powershell
   # Launch GPMC
   gpmc.msc
   ```

2. **Create or Select a GPO**
   - **Option A - Create New GPO**:
     - Right-click on **"Group Policy Objects"** → **"New"**
     - Name it (e.g., "Custom Security Policy - HR Department")
     - Click **OK**
   
   - **Option B - Use Existing GPO**:
     - Navigate to **"Group Policy Objects"** folder
     - Find the GPO you want to modify

3. **Edit the GPO**
   - Right-click your GPO → **"Edit"**
   - Group Policy Management Editor opens

4. **Navigate to Security Settings**
   - Expand: **Computer Configuration** → **Policies** → **Windows Settings** → **Security Settings**

5. **Import Your .INF File**
   - Right-click on **"Security Settings"** → **"Import Policy..."**
   - Browse to your `.inf` file location:
     ```
     C:\Users\enriq\Downloads\Baselines Powershell\CustomPolicies\StrictPasswords.inf
     ```
   - Select the file → Click **"Open"**
   - The import happens immediately (no confirmation dialog)

6. **Verify the Import**
   - Expand **Security Settings** and check sub-folders:
     - **Account Policies** → **Password Policy** (for password settings)
     - **Account Policies** → **Account Lockout Policy** (for lockout settings)
     - **Local Policies** → **User Rights Assignment** (for privileges)
   - You should see your imported values

7. **Close the Editor**

8. **Link the GPO to an Organizational Unit (OU)**
   - In Group Policy Management Console
   - Navigate to your domain → Find your desired OU (e.g., "Computers" or "HR Department")
   - Right-click the OU → **"Link an Existing GPO..."**
   - Select your GPO → **OK**

9. **Force Group Policy Update on Target Computers**
   ```powershell
   # On each target computer, run:
   gpupdate /force
   
   # Or remotely trigger update:
   Invoke-GPUpdate -Computer "TargetComputerName" -Force
   ```

#### **Method 2: Apply Locally for Testing** ⚡ **FOR TESTING ONLY**

Before deploying to your domain, test the policy on a single computer:

```powershell
# Apply the .inf file to your local computer
secedit /configure /db temp.sdb /cfg "C:\Users\enriq\Downloads\Baselines Powershell\CustomPolicies\StrictPasswords.inf" /overwrite

# Verify it applied
secedit /export /cfg "C:\Users\enriq\Desktop\CurrentPolicy.inf"
notepad "C:\Users\enriq\Desktop\CurrentPolicy.inf"
```

**Warning**: This only applies to the local computer and will be overridden by domain GPOs when the computer syncs with the domain controller.

#### **Method 3: Import via LGPO.exe** (Advanced)

Microsoft's Local Group Policy Object tool can import .inf files:

```powershell
# Download LGPO.exe from Microsoft Security Compliance Toolkit
# Then run:
LGPO.exe /s "CustomPolicies\StrictPasswords.inf"
```

#### **📋 Verification Checklist**

After importing, verify the policy took effect:

- [ ] Open Group Policy Management Editor → Check policy values
- [ ] Run `gpresult /h C:\report.html` on target computer
- [ ] Open report.html → Find your GPO → Verify settings applied
- [ ] Test the actual behavior (try creating a short password - should fail)
- [ ] Check Event Viewer for policy application events

#### **🚨 Common Issues**

| Problem | Solution |
|---------|----------|
| "Import Policy" option is greyed out | Run console as Administrator |
| Settings don't appear after import | Your .inf file may be empty or incorrectly formatted |
| GPO doesn't apply to computers | Check GPO is linked to correct OU and has proper permissions |
| Local settings override GPO | Domain GPOs override local policies - ensure GPO has higher precedence |
| Changes don't take effect | Run `gpupdate /force` and wait 5-10 minutes |

---

### **Scenario 5: "I Want to Export Everything to Excel"**

**Goal**: Get all policies in a spreadsheet for easy review

```powershell
# Step 1: Extract policies
. 'C:\Users\enriq\Downloads\Baselines Powershell\GPO_Policy_Extractor.ps1'
Get-GPOPolicies -FolderID '{20FAD6FB-7C6D-496E-801C-0434769847FF}'

# Step 2: Export to CSV (opens in Excel)
Export-PoliciesToCSV -Path 'C:\Users\enriq\Desktop\AllMemberServerPolicies.csv'

# Open the CSV in Excel, filter, sort, and review at your leisure
```

---

### **Scenario 6: "I Want to Combine Policies from Multiple GPOs"**

**Goal**: Take 5 policies from Member Server + 3 policies from Domain Security

```powershell
. 'C:\Users\enriq\Downloads\Baselines Powershell\GPO_Policy_Extractor.ps1'

# Extract from first GPO
Get-GPOPolicies -FolderID '{20FAD6FB-7C6D-496E-801C-0434769847FF}'
Select-Policies -Indices 1,2,3,4,5 -OutputName 'MemberServer_Selected'

# Extract from second GPO
Get-GPOPolicies -FolderID '{AAC7C960-51D3-4BEE-89BD-7FB10361AA16}'
Select-Policies -Indices 1,2,3 -OutputName 'DomainSecurity_Selected'

# Merge them together
Merge-PolicyFiles -Files @(
    'PolicyExtraction\MemberServer_Selected.PolicyRules',
    'PolicyExtraction\DomainSecurity_Selected.PolicyRules'
) -OutputName 'Combined_Policies'

# Output: PolicyExtraction\Combined_Policies.PolicyRules
```

---

## 📊 Understanding Policy Types

When you extract policies, you'll see different types:

### **1. Registry Policies** (Most Common)
These change Windows registry settings.

**Example**:
```
Registry (Computer): Software\Policies\Microsoft\Windows\WinRM\Client\AllowBasic = 0
```

**Translation**: 
- **Location**: Computer registry key for WinRM (Windows Remote Management)
- **Setting**: AllowBasic (basic authentication)
- **Value**: 0 (disabled - don't allow basic authentication)
- **Security Impact**: Prevents insecure authentication method

### **2. Security Template / System Access**
Password policies, account lockout, Kerberos settings.

**Example**:
```
[System Access] MinimumPasswordLength=14
```

**Translation**: Passwords must be at least 14 characters long

### **3. Audit Policies**
What security events to log.

**Example**:
```
Audit: Audit Logon = Success and Failure
```

**Translation**: Log every successful AND failed login attempt

### **4. User Rights / Privilege Assignments**
Who can do what on the system.

**Example**:
```
User Right: SeDebugPrivilege = *S-1-5-32-544
```

**Translation**: Only Administrators (S-1-5-32-544) can debug programs

---

## 🔐 Security Best Practices

### **Before Applying Policies:**

1. ✅ **Test in a non-production environment first**
   - Don't apply directly to critical servers
   - Use a test VM or isolated system

2. ✅ **Understand what each policy does**
   - Read the policy descriptions
   - Research unfamiliar settings
   - Microsoft docs: https://learn.microsoft.com/en-us/windows/security/

3. ✅ **Create backups**
   - Export current policies: `secedit /export /cfg current_policy.inf`
   - Take system snapshots

4. ✅ **Apply incrementally**
   - Don't apply 200 policies at once
   - Apply in small groups (10-20 at a time)
   - Test after each group

### **After Applying Policies:**

1. ✅ **Verify settings took effect**
   - Check Group Policy results: `gpresult /h report.html`
   - Check registry keys manually
   - Test the actual behavior

2. ✅ **Monitor for issues**
   - Check Event Viewer for errors
   - Test critical applications
   - Verify users can still do their jobs

3. ✅ **Document what you applied**
   - Keep notes on which policies you selected
   - Save your `.PolicyRules` and `.inf` files
   - Document any issues encountered

---

## 🆘 Troubleshooting

### **Problem: "I ran the script but nothing happened"**

**Solution**: You need to "dot-source" the script to load its functions:
```powershell
# Wrong (runs but functions disappear after):
.\GPO_Policy_Extractor.ps1

# Correct (loads functions into your session):
. .\GPO_Policy_Extractor.ps1
# ^ Notice the dot and space before the path
```

---

### **Problem: "Get-GPOPolicies : The term is not recognized"**

**Solution**: Load the script first:
```powershell
. 'C:\Users\enriq\Downloads\Baselines Powershell\GPO_Policy_Extractor.ps1'
```

---

### **Problem: "No policies found in the specified path"**

**Causes**:
1. Wrong GUID/FolderID
2. GPO folder doesn't exist
3. GPO is empty

**Solution**:
```powershell
# First, check what GPOs exist:
. 'C:\Users\enriq\Downloads\Baselines Powershell\GPO_Detective_and_Modulizer.ps1'

# Open the CSV and find the correct FolderID
```

---

### **Problem: "Access Denied when applying policy"**

**Solution**: Run PowerShell as Administrator:
1. Right-click PowerShell icon
2. Select "Run as Administrator"
3. Navigate to your scripts folder
4. Try again

---

### **Problem: "Policy applied but settings didn't change"**

**Causes**:
1. Group Policy from domain may override local policy
2. Policy wasn't actually applied
3. Need to restart or run `gpupdate /force`

**Solutions**:
```powershell
# Force Group Policy update
gpupdate /force

# Check what policies are applied
gpresult /h C:\Users\enriq\Desktop\gpresult.html

# Verify specific settings in registry
Get-ItemProperty -Path 'HKLM:\Software\Policies\Microsoft\Windows\Whatever'
```

---

## 📚 Additional Resources

### **Microsoft Documentation**
- [Security Policy Settings Reference](https://learn.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/)
- [Group Policy Overview](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-r2-and-2012/hh831791(v=ws.11))
- [Security Compliance Toolkit](https://www.microsoft.com/en-us/download/details.aspx?id=55319)

### **Tools Used**
- **Secedit**: Built-in Windows tool for applying security policies
- **GPO2PolicyRules**: Microsoft's tool for converting GPOs
- **PolicyFileEditor**: PowerShell module for reading Registry.pol files
  ```powershell
  Install-Module -Name PolicyFileEditor -Scope CurrentUser
  ```

### **File Formats**

| Extension | What It Is | Can Edit With |
|-----------|------------|---------------|
| `.xml` | GPO metadata and configuration | Any text editor, XML editor |
| `.inf` | Security policy in readable text format | Notepad, VS Code |
| `.pol` | Binary registry policy file | PolicyFileEditor module, LGPO.exe |
| `.PolicyRules` | Microsoft's XML format for policies | Text editor, XML editor |
| `.csv` | Comma-separated values (audit policies) | Excel, Notepad |

---

## 🎓 Learning Path

### **Beginner**
1. Run `GPO_Detective_and_Modulizer.ps1` to see what GPOs you have
2. Use `Get-GPOPolicies` to extract and view policies from one GPO
3. Export to CSV and review in Excel
4. Try creating a simple password policy with `New-CustomSecurityPolicy`

### **Intermediate**
1. Select specific policies using `Select-Policies`
2. Apply a custom policy to a test system
3. Combine policies from multiple GPOs
4. Compare policies before/after using `gpresult`

### **Advanced**
1. Parse Registry.pol files manually using PolicyFileEditor module
2. Create complex custom policies with registry values and privilege rights
3. Script bulk policy extraction for multiple GPOs
4. Integrate with configuration management tools (Ansible, PowerShell DSC)

---

## ⚠️ Important Warnings

### **🚨 DO NOT:**
- ❌ Apply untested policies to production servers
- ❌ Delete the original GPO backup folders
- ❌ Apply policies you don't understand
- ❌ Disable security features without good reason
- ❌ Mix up Computer Configuration with User Configuration
- ❌ Apply domain controller policies to member servers (or vice versa)

### **✅ DO:**
- ✅ Test all policies in a lab environment first
- ✅ Keep backups of current policies before making changes
- ✅ Document all changes you make
- ✅ Research unfamiliar settings before applying
- ✅ Apply policies slowly and monitor for issues
- ✅ Keep the temporary folders if you want to preserve custom selections

---

## 🏁 Quick Start Checklist

- [ ] **Step 1**: Run inventory script to see all GPOs
  ```powershell
  . 'GPO_Detective_and_Modulizer.ps1'
  ```

- [ ] **Step 2**: Open the CSV on your desktop, pick a GPO to investigate

- [ ] **Step 3**: Extract policies from that GPO
  ```powershell
  . 'GPO_Policy_Extractor.ps1'
  Get-GPOPolicies -FolderID '{GUID-FROM-CSV}'
  ```

- [ ] **Step 4**: Export to CSV for easier review
  ```powershell
  Export-PoliciesToCSV -Path 'Desktop\MyPolicies.csv'
  ```

- [ ] **Step 5**: Review policies in Excel, identify ones you want

- [ ] **Step 6**: Select specific policies
  ```powershell
  Select-Policies -Indices 1,5,10,15 -OutputName 'MySelection'
  ```

- [ ] **Step 7**: Test in a non-production environment!

---

## 💡 Pro Tips

1. **Use Tab Completion**: Type `Get-GPO` and press Tab - PowerShell will auto-complete function names

2. **Get Help**: Use `Get-Help` on any function:
   ```powershell
   Get-Help Get-GPOPolicies -Detailed
   ```

3. **Pipeline Magic**: Chain commands together:
   ```powershell
   Get-GPOPolicies -FolderID '{GUID}' | 
     Where-Object { $_.Type -eq 'ComputerConfig' } |
     Select-Object Index, Details
   ```

4. **Save Your Work**: Keep your custom `.PolicyRules` and `.inf` files in a safe location, not just the temporary folders

5. **Version Control**: Use Git or another VCS to track changes to your custom policy files

6. **Comment Your Code**: If you modify the scripts, add comments explaining what you changed and why

---

## 📞 Need More Help?

This toolkit is designed to be self-contained and educational. If you need assistance:

1. **Re-read this README** - Most answers are here!
2. **Check Microsoft documentation** - Links provided above
3. **Review PowerShell help**: `Get-Help <function-name> -Detailed`
4. **Test in a safe environment** - Always test before applying to production

---

## 📄 License & Credits

- **Microsoft Security Compliance Toolkit**: © Microsoft Corporation
  - PolicyAnalyzer_40 tools and documentation
  - Licensed under Microsoft Software License Terms
  
- **Custom Scripts** (GPO_Detective_and_Modulizer.ps1, GPO_Policy_Extractor.ps1, Create_Custom_Security_Policy.ps1):
  - Created as educational tools for GPO analysis
  - Use at your own risk
  - No warranty provided

---

## 📝 Version History

**Version 1.0** (February 2026)
- Initial toolkit creation
- GPO inventory script
- Policy extraction and selection
- Custom security policy creator
- Comprehensive documentation

---

**Remember**: These tools give you power over your system's security. With great power comes great responsibility. Always test, always backup, always understand what you're changing!

Happy policy hunting! 🔍🔐

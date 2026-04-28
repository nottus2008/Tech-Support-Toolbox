# ==============================================================
#           Tech Troubleshooting Toolbox
#           Version 2.5 - Sanitized for Open Source
# ==============================================================

# --- 1. Load the required Windows GUI assemblies ---
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- 2. Create the Main Window (Form) ---
$mainForm = New-Object System.Windows.Forms.Form
$mainForm.Text = "Tech Troubleshooting Toolbox"
$mainForm.Size = New-Object System.Drawing.Size(420, 660)
$mainForm.StartPosition = "CenterScreen"
$mainForm.BackColor = "White"
$mainForm.FormBorderStyle = "FixedSingle"
$mainForm.MaximizeBox = $false

# ==========================================
#          GLOBAL CONFIGURATION
# ==========================================
$userLabel = New-Object System.Windows.Forms.Label
$userLabel.Location = New-Object System.Drawing.Point(120, 15)
$userLabel.Size = New-Object System.Drawing.Size(180, 15)
$userLabel.Text = "Target Username (Required):"
$userLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 8.25, [System.Drawing.FontStyle]::Bold)
$mainForm.Controls.Add($userLabel)

$userTextBox = New-Object System.Windows.Forms.TextBox
$userTextBox.Location = New-Object System.Drawing.Point(120, 30)
$userTextBox.Size = New-Object System.Drawing.Size(180, 20)

# Detect the logged-in user safely
$wmiUser = Get-WmiObject -Class Win32_ComputerSystem | Select-Object -ExpandProperty UserName
if ($wmiUser) { $userTextBox.Text = $wmiUser.Split('\')[-1] } else { $userTextBox.Text = $env:USERNAME }
$mainForm.Controls.Add($userTextBox)

# Logging Checkbox
$logCheckBox = New-Object System.Windows.Forms.CheckBox
$logCheckBox.Location = New-Object System.Drawing.Point(120, 55)
$logCheckBox.Size = New-Object System.Drawing.Size(180, 20)
$logCheckBox.Text = "Enable Debug Logging"
$mainForm.Controls.Add($logCheckBox)

# --- Helper Functions ---
$debugLogPath = "$env:TEMP\Toolbox_Log.txt"

# Safely determine where the script is running from to place the Audit Log
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $PSCommandPath }
if (-not $scriptDir) { $scriptDir = $env:TEMP } # Failsafe
$auditLogPath = "$scriptDir\Toolbox_Audit.log"

function Write-ToolLog {
    param([string]$Message)
    if ($logCheckBox.Checked) {
        $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "[$stamp] $Message" | Out-File -FilePath $debugLogPath -Append
    }
}

function Write-SimpleLog {
    param([string]$ActionName, [string]$TargetName)
    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $tech = $env:USERNAME
    "[$stamp] Tech: $tech | Target: $TargetName | Action: $ActionName" | Out-File -FilePath $auditLogPath -Append -ErrorAction SilentlyContinue
}

function Get-UserSID ($Username) {
    try {
        $objUser = New-Object System.Security.Principal.NTAccount($Username)
        return $objUser.Translate([System.Security.Principal.SecurityIdentifier]).Value
    } catch { return $null }
}

# ==========================================
#               PROFILE FIXES
# ==========================================
$sysLabel = New-Object System.Windows.Forms.Label
$sysLabel.Location = New-Object System.Drawing.Point(60, 85)
$sysLabel.Size = New-Object System.Drawing.Size(300, 20)
$sysLabel.Text = "-------------------- Profile Fixes --------------------"
$sysLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$mainForm.Controls.Add($sysLabel)

# --- Row 1: RDP & Printer Fix ---
$rdpButton = New-Object System.Windows.Forms.Button
$rdpButton.Location = New-Object System.Drawing.Point(30, 110)
$rdpButton.Size = New-Object System.Drawing.Size(170, 40)
$rdpButton.Text = "RDP Registry Debloat"
$rdpButton.BackColor = "LightGray"
$rdpButton.Add_Click({
    $targetUser = $userTextBox.Text.Trim()
    $sid = Get-UserSID $targetUser
    if (-not $sid) { [System.Windows.Forms.MessageBox]::Show("Invalid Username.", "Error", 0, 16); return }

    $warn1 = "Clean RDP Telemetry for $targetUser?`n`nWARNING: This process can take 20-30 minutes to complete depending on the size of the bloat."
    if ([System.Windows.Forms.MessageBox]::Show($warn1, "Confirm Task", 4, 48) -eq 'Yes') {
        
        $warn2 = "Are you absolutely sure?`n`nThe Toolbox GUI will appear 'frozen' or 'Not Responding' while this runs. A black command window will open to show progress. DO NOT close it until finished."
        if ([System.Windows.Forms.MessageBox]::Show($warn2, "Final Warning: 30 Minute Lockout", 4, 48) -eq 'Yes') {
            
            Write-SimpleLog "RDP Registry Debloat Started" $targetUser
            Write-ToolLog "Started RDP Registry Debloat for user: $targetUser (SID: $sid)"
            $rdpButton.Enabled = $false
            
            $cmdArgs = "/c echo Deleting RDP Telemetry for $targetUser... & echo THIS MAY TAKE 20-30 MINUTES. DO NOT CLOSE THIS WINDOW. & echo. & reg delete `"HKU\$sid\Software\Microsoft\Terminal Server Client\Telemetry`" /f & echo. & echo Deletion Complete! & timeout /t 5"
            Start-Process "cmd.exe" -ArgumentList $cmdArgs -Wait
            
            Write-ToolLog "Finished RDP Registry Debloat."
            Write-SimpleLog "RDP Registry Debloat Completed" $targetUser
            $rdpButton.Enabled = $true
            [System.Windows.Forms.MessageBox]::Show("RDP Telemetry Cleared!", "Success", 0, 64)
        }
    }
})
$mainForm.Controls.Add($rdpButton)

$printerButton = New-Object System.Windows.Forms.Button
$printerButton.Location = New-Object System.Drawing.Point(210, 110)
$printerButton.Size = New-Object System.Drawing.Size(170, 40)
$printerButton.Text = "Fix Chrome/PaperCut"
$printerButton.BackColor = "LightGray"
$printerButton.Add_Click({
    $targetUser = $userTextBox.Text.Trim()
    $sid = Get-UserSID $targetUser
    if (-not $sid) { [System.Windows.Forms.MessageBox]::Show("Invalid Username.", "Error", 0, 16); return }

    if ([System.Windows.Forms.MessageBox]::Show("Force-close Chrome and reset spooler for $targetUser?", "Warning", 4, 48) -eq 'Yes') {
        Write-SimpleLog "Chrome/PaperCut Fix" $targetUser
        Write-ToolLog "Started Printer Surgical Strike for user: $targetUser"
        $printerButton.Enabled = $false
        Stop-Process -Name "chrome" -Force -ErrorAction SilentlyContinue; Start-Sleep 2
        
        $Pref = "C:\Users\$targetUser\AppData\Local\Google\Chrome\User Data\Default\Preferences"
        if (Test-Path $Pref) { try { $p = Get-Content $Pref -Raw | ConvertFrom-Json; $p.printing = @{}; $p | ConvertTo-Json -Depth 100 | Set-Content $Pref; Write-ToolLog "Cleared Chrome Print Prefs." } catch { Write-ToolLog "Failed to clear Chrome prefs." } }
        
        @("HKU\$sid\Printers\Connections", "HKU\$sid\Printers\Settings", "HKU\$sid\Software\Microsoft\Windows NT\CurrentVersion\PrinterPorts", "HKU\$sid\Software\Microsoft\Windows NT\CurrentVersion\Devices") | ForEach-Object { if (Test-Path $_) { Remove-Item "$_\*" -Recurse -Force -EA 0 } }
        
        $PC = "C:\Users\$targetUser\AppData\Local\PaperCut MF\client\cache"; if (Test-Path $PC) { Remove-Item "$PC\*" -Recurse -Force -EA 0; Write-ToolLog "Cleared PaperCut cache." }
        
        Start-Process "powershell" "-Command Restart-Service Spooler -Force" -Verb RunAs -Wait
        Write-ToolLog "Restarted Spooler. Printer fix complete."
        $printerButton.Enabled = $true
        [System.Windows.Forms.MessageBox]::Show("Printer fix complete!", "Success", 0, 64)
    }
})
$mainForm.Controls.Add($printerButton)

# --- Row 2: Chrome Bookmark Restore ---
$bookmarkBtn = New-Object System.Windows.Forms.Button
$bookmarkBtn.Location = New-Object System.Drawing.Point(120, 160)
$bookmarkBtn.Size = New-Object System.Drawing.Size(180, 40)
$bookmarkBtn.Text = "Restore Chrome Bookmarks"
$bookmarkBtn.BackColor = "LightGray"
$bookmarkBtn.Add_Click({
    $targetUser = $userTextBox.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($targetUser)) { return }
    
    if ([System.Windows.Forms.MessageBox]::Show("Force-close Chrome and restore Bookmarks.bak for $targetUser?", "Confirm", 4, 32) -eq 'Yes') {
        Write-SimpleLog "Restore Chrome Bookmarks" $targetUser
        Write-ToolLog "Starting Chrome Bookmark Restore for $targetUser"
        $bookmarkBtn.Enabled = $false
        Stop-Process -Name "chrome" -Force -ErrorAction SilentlyContinue; Start-Sleep 2
        
        $chromePath = "C:\Users\$targetUser\AppData\Local\Google\Chrome\User Data"
        if (Test-Path $chromePath) {
            $bakFiles = Get-ChildItem -Path $chromePath -Filter "Bookmarks.bak" -Recurse -ErrorAction SilentlyContinue
            if ($bakFiles.Count -gt 0) {
                foreach ($bak in $bakFiles) {
                    $dir = $bak.DirectoryName
                    $liveBmk = Join-Path $dir "Bookmarks"
                    if (Test-Path $liveBmk) { Rename-Item -Path $liveBmk -NewName "Bookmarks.broken" -Force -ErrorAction SilentlyContinue }
                    Copy-Item -Path $bak.FullName -Destination $liveBmk -Force -ErrorAction SilentlyContinue
                    Write-ToolLog "Restored backup in $dir"
                }
                [System.Windows.Forms.MessageBox]::Show("Restored Bookmarks in $($bakFiles.Count) profile(s)!", "Success", 0, 64)
            } else { [System.Windows.Forms.MessageBox]::Show("No Bookmarks.bak files found.", "Not Found", 0, 48) }
        } else { [System.Windows.Forms.MessageBox]::Show("Chrome User Data folder not found.", "Error", 0, 16) }
        $bookmarkBtn.Enabled = $true
    }
})
$mainForm.Controls.Add($bookmarkBtn)

# ==========================================
#             MACHINE FIXES
# ==========================================
$machLabel = New-Object System.Windows.Forms.Label
$machLabel.Location = New-Object System.Drawing.Point(60, 215)
$machLabel.Size = New-Object System.Drawing.Size(300, 20)
$machLabel.Text = "------------------- Machine Fixes -------------------"
$machLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$mainForm.Controls.Add($machLabel)

# --- Row 1: Stability Repair & Temp ACL ---
$stabilityButton = New-Object System.Windows.Forms.Button
$stabilityButton.Location = New-Object System.Drawing.Point(30, 240)
$stabilityButton.Size = New-Object System.Drawing.Size(170, 40)
$stabilityButton.Text = "Stability Repair (Reboot)"
$stabilityButton.BackColor = "LightGray"
$stabilityButton.Add_Click({
    if ([System.Windows.Forms.MessageBox]::Show("Runs SFC, DISM, and rebuilds WMI.`n`nREBOOT IS REQUIRED after finishing. Proceed?", "Warning", 4, 48) -eq 'Yes') {
        Write-SimpleLog "Stability Repair (SFC/DISM/WMI)" "SYSTEM"
        Write-ToolLog "Launching Windows Stability Repair."
        $tempScript = "$env:TEMP\WinRepair.ps1"
        $scriptContent = @(
            'Write-Host "Running SFC /scannow..." -ForegroundColor Cyan'; 'sfc.exe /scannow'
            'Write-Host "`nRunning DISM RestoreHealth..." -ForegroundColor Cyan'; 'dism.exe /Online /Cleanup-Image /RestoreHealth'
            'Write-Host "`nAttempting WMI Rebuild..." -ForegroundColor Cyan'; 'Stop-Service winmgmt -Force -ErrorAction SilentlyContinue'
            'if (Test-Path "$env:windir\System32\wbem\Repository") { Rename-Item "$env:windir\System32\wbem\Repository" "Repository.bak" -Force -ErrorAction SilentlyContinue }'
            'Start-Service winmgmt'; 'Write-Host "Repair Complete. REBOOT NOW." -ForegroundColor Green'; 'Read-Host "Press Enter to close..."'
        ) -join "`r`n"
        Set-Content -Path $tempScript -Value $scriptContent
        Start-Process "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$tempScript`"" -Verb RunAs
    }
})
$mainForm.Controls.Add($stabilityButton)

$aclButton = New-Object System.Windows.Forms.Button
$aclButton.Location = New-Object System.Drawing.Point(210, 240)
$aclButton.Size = New-Object System.Drawing.Size(170, 40)
$aclButton.Text = "Fix Temp ACL (15m)"
$aclButton.BackColor = "LightGray"
$aclButton.Add_Click({
    try {
        Write-SimpleLog "Temp ACL Modification" "SYSTEM"
        Write-ToolLog "Applying 15-minute Temp ACL Fix."
        $acl = Get-Acl -Path "C:\Windows\Temp"
        $ace = New-Object System.Security.AccessControl.FileSystemAccessRule('Authenticated Users', 'Modify', 'ContainerInherit, ObjectInherit', 'None', 'Allow')
        $acl.AddAccessRule($ace); Set-Acl -Path "C:\Windows\Temp" -AclObject $acl

        $revertScript = "$env:TEMP\RevertTempACL.ps1"
        $scriptContent = @(
            'Start-Sleep -Seconds 900'
            'try {'
            '    $acl = Get-Acl -Path "C:\Windows\Temp"'
            '    $ace = New-Object System.Security.AccessControl.FileSystemAccessRule("Authenticated Users", "Modify", "ContainerInherit, ObjectInherit", "None", "Allow")'
            '    $acl.RemoveAccessRule($ace)'
            '    Set-Acl -Path "C:\Windows\Temp" -AclObject $acl'
            '} catch {}'
            'Remove-Item $PSCommandPath -Force -EA 0'
        ) -join "`r`n"
        
        Set-Content -Path $revertScript -Value $scriptContent
        Start-Process "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$revertScript`""
        [System.Windows.Forms.MessageBox]::Show("Temp ACL set to Modify. Will auto-revert in 15 mins.", "Success", 0, 64)
    } catch { [System.Windows.Forms.MessageBox]::Show("Failed to set ACL. Run as Admin.", "Error", 0, 16) }
})
$mainForm.Controls.Add($aclButton)

# --- Row 2: Network Reset & GPUpdate ---
$netResetBtn = New-Object System.Windows.Forms.Button
$netResetBtn.Location = New-Object System.Drawing.Point(30, 290)
$netResetBtn.Size = New-Object System.Drawing.Size(170, 40)
$netResetBtn.Text = "Network / DNS Reset"
$netResetBtn.BackColor = "LightGray"
$netResetBtn.Add_Click({
    Write-SimpleLog "Network/DNS Reset" "SYSTEM"
    Write-ToolLog "Running Network/DNS Reset."
    Start-Process "cmd.exe" -ArgumentList "/c echo Flushing DNS and Resetting Network... & ipconfig /release & ipconfig /renew & ipconfig /flushdns & netsh winsock reset & echo. & echo NETWORK RESET COMPLETE. & pause" -Wait
})
$mainForm.Controls.Add($netResetBtn)

$gpUpdateBtn = New-Object System.Windows.Forms.Button
$gpUpdateBtn.Location = New-Object System.Drawing.Point(210, 290)
$gpUpdateBtn.Size = New-Object System.Drawing.Size(170, 40)
$gpUpdateBtn.Text = "Force GPUpdate"
$gpUpdateBtn.BackColor = "LightGray"
$gpUpdateBtn.Add_Click({
    if ([System.Windows.Forms.MessageBox]::Show("Connected to the Office Network or VPN?", "Network Check", 4, 32) -eq 'Yes') {
        Write-SimpleLog "Force GPUpdate" "SYSTEM"
        Write-ToolLog "Running gpupdate /force."
        Start-Process "cmd.exe" -ArgumentList "/c echo Running GPUpdate Force... & gpupdate /force & pause" -Wait
    }
})
$mainForm.Controls.Add($gpUpdateBtn)

# --- Row 3: Clear Temp Files ---
$clearTempBtn = New-Object System.Windows.Forms.Button
$clearTempBtn.Location = New-Object System.Drawing.Point(120, 340)
$clearTempBtn.Size = New-Object System.Drawing.Size(180, 40)
$clearTempBtn.Text = "Clear System & User Temp"
$clearTempBtn.BackColor = "LightGray"
$clearTempBtn.Add_Click({
    $targetUser = $userTextBox.Text.Trim()
    Write-SimpleLog "Clear System & User Temp" $targetUser
    Write-ToolLog "Clearing Temp Files."
    $clearTempBtn.Enabled = $false
    Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($targetUser) -eq $false -and (Test-Path "C:\Users\$targetUser\AppData\Local\Temp")) {
        Remove-Item -Path "C:\Users\$targetUser\AppData\Local\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
    }
    $clearTempBtn.Enabled = $true
    Write-ToolLog "Temp Files Cleared."
    [System.Windows.Forms.MessageBox]::Show("Temporary files cleared successfully!", "Success", 0, 64)
})
$mainForm.Controls.Add($clearTempBtn)

# ==========================================
#      DATA BACKUP & RESTORE UTILITY
# ==========================================
$migLabel = New-Object System.Windows.Forms.Label
$migLabel.Location = New-Object System.Drawing.Point(60, 395)
$migLabel.Size = New-Object System.Drawing.Size(300, 20)
$migLabel.Text = "-------------- User Migration Utility --------------"
$migLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$mainForm.Controls.Add($migLabel)

$targetFolders = @("Desktop", "Documents", "Downloads", "Favorites", "Pictures", "Videos")

# --- Row 1: NETWORK BACKUP & RESTORE ---
$netBackupBtn = New-Object System.Windows.Forms.Button
$netBackupBtn.Location = New-Object System.Drawing.Point(30, 420)
$netBackupBtn.Size = New-Object System.Drawing.Size(170, 40)
$netBackupBtn.Text = "BACKUP to Network"
$netBackupBtn.BackColor = "LightBlue"
$netBackupBtn.Add_Click({
    $targetUser = $userTextBox.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($targetUser)) { return }
    $destBase = "\\YOUR_SERVER\HomeDirs$\$targetUser" # <--- CONFIGURE SERVER HERE
    
    if ([System.Windows.Forms.MessageBox]::Show("Backup '$targetUser' to NETWORK?", "Confirm", 4, 32) -eq 'Yes') {
        Write-SimpleLog "Network Backup Started" $targetUser
        Write-ToolLog "Starting Network Backup for $targetUser to $destBase"
        $netBackupBtn.Enabled = $false
        if (-not (Test-Path "\\YOUR_SERVER\HomeDirs$")) {
            Write-ToolLog "Prompting for IT Credentials."
            try {
                $creds = Get-Credential -Message "Enter Domain credentials for \\YOUR_SERVER (Ask user to enter their password if needed)" -ErrorAction Stop
                $user = $creds.GetNetworkCredential().UserName; $pass = $creds.GetNetworkCredential().Password; $domain = $creds.GetNetworkCredential().Domain
                cmd.exe /c "net use \\YOUR_SERVER\IPC$ $pass /user:$domain\$user" | Out-Null
            } catch { Write-ToolLog "Auth cancelled."; $netBackupBtn.Enabled = $true; return }
        }
        foreach ($f in $targetFolders) {
            $src = "C:\Users\$targetUser\$f"; $dst = "$destBase\$f"
            if (Test-Path $src) { 
                $roboArgs = "`"$src`" `"$dst`" /E /XO /Z /R:3 /W:5 /NP"
                if ($logCheckBox.Checked) { $roboArgs += " /TEE /LOG+:`"$logPath`"" }
                Start-Process "robocopy.exe" -ArgumentList $roboArgs -Wait 
            }
        }
        cmd.exe /c "net use \\YOUR_SERVER\IPC$ /delete 2>nul" | Out-Null
        Write-ToolLog "Network Backup Complete."
        Write-SimpleLog "Network Backup Completed" $targetUser
        $netBackupBtn.Enabled = $true
        [System.Windows.Forms.MessageBox]::Show("Network Backup complete!", "Success", 0, 64)
    }
})
$mainForm.Controls.Add($netBackupBtn)

$netRestoreBtn = New-Object System.Windows.Forms.Button
$netRestoreBtn.Location = New-Object System.Drawing.Point(210, 420)
$netRestoreBtn.Size = New-Object System.Drawing.Size(170, 40)
$netRestoreBtn.Text = "RESTORE from Net"
$netRestoreBtn.BackColor = "LightGreen"
$netRestoreBtn.Add_Click({
    $targetUser = $userTextBox.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($targetUser)) { return }
    $srcBase = "\\YOUR_SERVER\HomeDirs$\$targetUser" # <--- CONFIGURE SERVER HERE
    
    if ([System.Windows.Forms.MessageBox]::Show("Restore '$targetUser' from NETWORK?", "Confirm", 4, 32) -eq 'Yes') {
        Write-SimpleLog "Network Restore Started" $targetUser
        Write-ToolLog "Starting Network Restore for $targetUser from $srcBase"
        $netRestoreBtn.Enabled = $false
        if (-not (Test-Path "\\YOUR_SERVER\HomeDirs$")) {
            try {
                $creds = Get-Credential -Message "Enter Domain credentials for \\YOUR_SERVER (Ask user to enter their password if needed)" -ErrorAction Stop
                $user = $creds.GetNetworkCredential().UserName; $pass = $creds.GetNetworkCredential().Password; $domain = $creds.GetNetworkCredential().Domain
                cmd.exe /c "net use \\YOUR_SERVER\IPC$ $pass /user:$domain\$user" | Out-Null
            } catch { Write-ToolLog "Auth cancelled."; $netRestoreBtn.Enabled = $true; return }
        }
        foreach ($f in $targetFolders) {
            $src = "$srcBase\$f"; $dst = "C:\Users\$targetUser\$f"
            if (Test-Path $src) { 
                $roboArgs = "`"$src`" `"$dst`" /E /XO /Z /R:3 /W:5 /NP"
                if ($logCheckBox.Checked) { $roboArgs += " /TEE /LOG+:`"$logPath`"" }
                Start-Process "robocopy.exe" -ArgumentList $roboArgs -Wait 
            }
        }
        cmd.exe /c "net use \\YOUR_SERVER\IPC$ /delete 2>nul" | Out-Null
        Write-ToolLog "Network Restore Complete."
        Write-SimpleLog "Network Restore Completed" $targetUser
        $netRestoreBtn.Enabled = $true
        [System.Windows.Forms.MessageBox]::Show("Network Restore complete!", "Success", 0, 64)
    }
})
$mainForm.Controls.Add($netRestoreBtn)

# --- Row 2: LOCAL BACKUP & RESTORE ---
$locBackupBtn = New-Object System.Windows.Forms.Button
$locBackupBtn.Location = New-Object System.Drawing.Point(30, 470)
$locBackupBtn.Size = New-Object System.Drawing.Size(170, 40)
$locBackupBtn.Text = "BACKUP to Local (C:\)"
$locBackupBtn.BackColor = "LightSkyBlue"
$locBackupBtn.Add_Click({
    $targetUser = $userTextBox.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($targetUser)) { return }
    $destBase = "C:\IT_Backups\$targetUser"
    
    if ([System.Windows.Forms.MessageBox]::Show("Backup '$targetUser' to LOCAL DRIVE?", "Confirm", 4, 32) -eq 'Yes') {
        Write-SimpleLog "Local Backup Started" $targetUser
        Write-ToolLog "Starting Local Backup for $targetUser to $destBase"
        $locBackupBtn.Enabled = $false
        foreach ($f in $targetFolders) {
            $src = "C:\Users\$targetUser\$f"; $dst = "$destBase\$f"
            if (Test-Path $src) { 
                $roboArgs = "`"$src`" `"$dst`" /E /XO /Z /R:3 /W:5 /NP"
                if ($logCheckBox.Checked) { $roboArgs += " /TEE /LOG+:`"$logPath`"" }
                Start-Process "robocopy.exe" -ArgumentList $roboArgs -Wait 
            }
        }
        Write-ToolLog "Local Backup Complete."
        Write-SimpleLog "Local Backup Completed" $targetUser
        $locBackupBtn.Enabled = $true
        [System.Windows.Forms.MessageBox]::Show("Local Backup complete!", "Success", 0, 64)
    }
})
$mainForm.Controls.Add($locBackupBtn)

$locRestoreBtn = New-Object System.Windows.Forms.Button
$locRestoreBtn.Location = New-Object System.Drawing.Point(210, 470)
$locRestoreBtn.Size = New-Object System.Drawing.Size(170, 40)
$locRestoreBtn.Text = "RESTORE from Local"
$locRestoreBtn.BackColor = "PaleGreen"
$locRestoreBtn.Add_Click({
    $targetUser = $userTextBox.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($targetUser)) { return }
    $srcBase = "C:\IT_Backups\$targetUser"
    
    if ([System.Windows.Forms.MessageBox]::Show("Restore '$targetUser' from LOCAL DRIVE?", "Confirm", 4, 32) -eq 'Yes') {
        Write-SimpleLog "Local Restore Started" $targetUser
        Write-ToolLog "Starting Local Restore for $targetUser from $srcBase"
        $locRestoreBtn.Enabled = $false
        foreach ($f in $targetFolders) {
            $src = "$srcBase\$f"; $dst = "C:\Users\$targetUser\$f"
            if (Test-Path $src) { 
                $roboArgs = "`"$src`" `"$dst`" /E /XO /Z /R:3 /W:5 /NP"
                if ($logCheckBox.Checked) { $roboArgs += " /TEE /LOG+:`"$logPath`"" }
                Start-Process "robocopy.exe" -ArgumentList $roboArgs -Wait 
            }
        }
        Write-ToolLog "Local Restore Complete."
        Write-SimpleLog "Local Restore Completed" $targetUser
        $locRestoreBtn.Enabled = $true
        [System.Windows.Forms.MessageBox]::Show("Local Restore complete!", "Success", 0, 64)
    }
})
$mainForm.Controls.Add($locRestoreBtn)

# ==========================================
#               RESOURCES
# ==========================================
$resLabel = New-Object System.Windows.Forms.Label
$resLabel.Location = New-Object System.Drawing.Point(60, 525)
$resLabel.Size = New-Object System.Drawing.Size(300, 20)
$resLabel.Text = "---------------------- Resources ----------------------"
$resLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$mainForm.Controls.Add($resLabel)

# --- Button 7: KB Links (HTML Version) ---
$kbButton = New-Object System.Windows.Forms.Button
$kbButton.Location = New-Object System.Drawing.Point(30, 555)
$kbButton.Size = New-Object System.Drawing.Size(170, 40)
$kbButton.Text = "Open KB Links"
$kbButton.BackColor = "Plum"
$kbButton.Add_Click({
    Write-SimpleLog "Opened KB Links (HTML)" $env:USERNAME
    Write-ToolLog "Generating and launching HTML KB Portal."
    
    $htmlPath = "$env:TEMP\Toolbox_KBs.html"
    
    # HTML Content with embedded CSS for a clean, modern look
    $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>Tech Support Knowledge Base</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f4f4f9; color: #333; margin: 40px; }
        .container { background-color: #fff; padding: 30px; border-radius: 8px; box-shadow: 0 4px 8px rgba(0,0,0,0.1); max-width: 600px; margin: auto; }
        h2 { color: #0056b3; border-bottom: 2px solid #0056b3; padding-bottom: 10px; margin-top: 0; }
        ul { list-style-type: none; padding: 0; }
        li { margin: 20px 0; padding-bottom: 15px; border-bottom: 1px solid #eee; }
        li:last-child { border-bottom: none; }
        a { text-decoration: none; color: #0078d7; font-weight: bold; font-size: 18px; }
        a:hover { color: #004578; text-decoration: underline; }
        .desc { font-size: 14px; color: #666; margin-top: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <h2>Tech Support Knowledge Base</h2>
        <ul>
            <li>
                <a href="https://github.com" target="_blank">1. IT Wiki / Documentation</a>
                <div class="desc">Standard operating procedures, policies, and general network documentation.</div>
            </li>
            <li>
                <a href="https://github.com" target="_blank">2. Helpdesk Runbooks</a>
                <div class="desc">Step-by-step troubleshooting guides for common Tier 1/2 tickets.</div>
            </li>
        </ul>
    </div>
</body>
</html>
"@

    Set-Content -Path $htmlPath -Value $htmlContent
    Start-Process $htmlPath
})
$mainForm.Controls.Add($kbButton)

# --- Button 8: Help / Instructions (Scrollable) ---
$helpButton = New-Object System.Windows.Forms.Button
$helpButton.Location = New-Object System.Drawing.Point(210, 555)
$helpButton.Size = New-Object System.Drawing.Size(170, 40)
$helpButton.Text = "Help / Instructions"
$helpButton.BackColor = "PaleGoldenrod"
$helpButton.Add_Click({
    Write-SimpleLog "Opened Help Menu" $env:USERNAME

    $helpForm = New-Object System.Windows.Forms.Form
    $helpForm.Text = "Toolbox Documentation"
    $helpForm.Size = New-Object System.Drawing.Size(500, 450)
    $helpForm.StartPosition = "CenterScreen"
    $helpForm.FormBorderStyle = "FixedDialog"
    $helpForm.MaximizeBox = $false
    $helpForm.MinimizeBox = $false

    $helpTextBox = New-Object System.Windows.Forms.TextBox
    $helpTextBox.Multiline = $true
    $helpTextBox.ScrollBars = "Vertical"
    $helpTextBox.ReadOnly = $true
    $helpTextBox.BackColor = "White"
    $helpTextBox.Font = New-Object System.Drawing.Font("Consolas", 10)
    $helpTextBox.Dock = "Fill" 

    $helpTextBox.Text = @"
================================================
          TECH TROUBLESHOOTING TOOLBOX
================================================

1. TARGET USERNAME: 
Verify the correct username before running any profile fixes. The tool defaults to the currently logged-in user.

2. PROFILE FIXES: 
Safe to run without rebooting. These target the specific user's registry hive or AppData.

3. MACHINE FIXES: 
Reboots are explicitly REQUIRED for the Stability Repair (SFC/DISM). GPUpdate requires an active connection to the Domain Controller.

4. MIGRATION UTILITY: 
- Network: Automates Robocopy to network shares. Prompts for credentials to bypass standard UAC token drops.
- Local: Stages data to C:\IT_Backups for off-network repairs.

5. LOGGING: 
- Audit Log: Always runs in the background. Tracks user actions.
- Debug Log: Check the box to save a highly detailed text log to your Temp folder.

6. FURTHER DOCUMENTATION:
Click the 'Open KB Links' button to view further guides and standard operating procedures.
"@

    $helpForm.Controls.Add($helpTextBox)
    [void]$helpForm.ShowDialog()
})
$mainForm.Controls.Add($helpButton)

# ==========================================
#               DISPLAY WINDOW
# ==========================================
[void]$mainForm.ShowDialog()
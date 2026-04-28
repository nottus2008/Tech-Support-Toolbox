# Tech Troubleshooting Toolbox

A lightweight, heavily audited PowerShell GUI designed to accelerate Tier 1 and Tier 2 Helpdesk operations. It standardizes common endpoint troubleshooting processes, mitigates manual data entry errors, and provides a robust mechanism for local and network user data migration.

## 🚀 The Problem & The Solution
Helpdesk technicians frequently spend extended periods executing repetitive CLI tasks (e.g., DNS resets, SFC scans, profile registry debloating, and Robocopy data migrations). Furthermore, running tools as a Local Administrator often strips the technician of their Kerberos domain token, complicating network data backups for corrupted profiles. 

This Toolbox resolves these bottlenecks by providing:
* **Standardized Execution:** One-click fixes for complex issues (Chrome Profile rebuilding, Temp ACL modification, WMI repository repairs).
* **UAC Token Bypass:** Intelligent credential prompting that allows Local Admins to map network shares and execute Robocopy data migrations without manually binding IPC$.
* **Full Auditability:** Background logging that tracks which technician executed what fix against which target user.

## 🛠️ Features Breakdown

### Profile Fixes (Targeted Repairs)
* **RDP Registry Debloat:** Clears massive telemetry cache buildup (`DiagConnectionCache`) in the user's specific registry hive. (Includes UI lock-out warnings and a visible CLI window).
* **Fix Chrome/PaperCut:** Force-closes Chrome, resets corrupted `Preferences` JSON files (preserving bookmarks), purges the PaperCut cache, and forcefully restarts the Print Spooler.
* **Restore Chrome Bookmarks:** Resolves missing bookmarks post-tenant migration by automatically reverting to the `Bookmarks.bak` file.

### Machine Fixes (System Health)
* **Stability Repair:** Sequentially runs `sfc /scannow`, `dism /RestoreHealth`, and rebuilds the WMI repository in a visible window. 
* **Fix Temp ACL (15m):** Grants a temporary IT administrative override (Modify rights) to `C:\Windows\Temp` to resolve installer hangs. Automatically revokes the permission via a background job after 15 minutes.
* **Network / DNS Reset:** Performs a complete IPv4 flush (`release`, `renew`, `flushdns`, `winsock reset`).

### Data Migration Utility
A highly resilient Robocopy wrapper designed to back up user profiles prior to destruction/rebuilding. Uses safe flags (`/XO`, `/R:3`, `/W:5`).
* **Network Backup/Restore:** Automatically tests line-of-sight to network shares. If access is denied (due to Local Admin constraints), it prompts for domain credentials and temporarily maps the drive for the transfer.
* **Local Backup/Restore:** Stages data safely at `C:\IT_Backups` outside of the `C:\Users` directory, preventing infinite loop errors during profile deletion.

## 📋 Prerequisites and Configuration
1. **Execution Policy:** Must be run with Local Administrator privileges on the target Windows endpoint.
2. **Server Configuration:** You must configure the script variables to match your environment. 
   * Edit `Toolbox.ps1` and find the `$netBackupBtn` and `$netRestoreBtn` blocks.
   * Change `\\YOUR_SERVER\HomeDirs$` to point to your organization's file share.

## 🏃 Usage
Because standard Windows Execution Policies restrict unsigned scripts, launch the Toolbox using a bypass:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Toolbox.ps1

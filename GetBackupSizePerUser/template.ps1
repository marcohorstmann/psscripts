<# 
   .SYNOPSIS
   Short description what this script is used for
   .DESCRIPTION
   Explain in detail what this script dp
   .PARAMETER LogFile
   You can set your own path for log file from this script. Default filename is "C:\ProgramData\dfsrecovery.log"

   .Example
   How to run this script with an example
   .\Involve-NASInstantDFSRecovery.ps1 -DfsRoot "\\homelab\dfs" -ScanDepth 3 -VBRJobName "DFS NAS Test" -Owner "HOMELAB\Administrator"

   .Notes 
   Version:        1.0
   Author:         Marco Horstmann (marco.horstmann@veeam.com)
   Creation Date:  13 November 2020
   Purpose/Change: Initial Release
   
   .LINK https://github.com/marcohorstmann/psscripts
   .LINK https://horstmann.in
 #>
### Customizable Parameter
#Log configuration
$Log="C:\ProgramData\


# Email configuration
$sendEmail = $true
#ORG $emailHost = "smtp.yourserver.com"
$emailHost = "192.168.30.10"
$emailPort = 25
$emailEnableSSL = $false
$emailUser = ""
$emailPass = ""
$emailFrom = "veeam@homelab.horstmann.in"
#ORG $emailTo = "you@youremail.com"
$emailTo = "admin@homelab.horstmann.in"
# Send HTML report as attachment (else HTML report is body)
#$emailAttach = $false
# Email Subject 
#$emailSubject = $rptTitle
# Append Report Mode to Email Subject E.g. My Veeam Report (Last 24 Hours)
#$modeSubject = $true
# Append VBR Server name to Email Subject
#$vbrSubject = $true
# Append Date and Time to Email Subject
###############################################################################$dtSubject = $false

#
# GLOBAL MODULE IMPORT
#

#Remove Modules for Debug
Remove-Module mho-common -ErrorAction Ignore
Remove-Module mho-veeam -ErrorAction Ignore
Remove-Module mho-netapp -ErrorAction Ignore
Remove-Module mho-microsoft -ErrorAction Ignore
Remove-Module mho-vmware -ErrorAction Ignore

# Switch Powershell current path to script path
Split-Path -Parent $PSCommandPath | Set-Location

#Import Logging Module
Import-Module ..\include\mho-common\mho-common.psm1 -ErrorAction stop
#Import-Module ..\include\mho-veeam\mho-veeam.psm1 -ErrorAction stop
#Import-Module ..\include\mho-netapp\mho-netapp.psm1 -ErrorAction stop
#Import-Module ..\include\mho-microsoft\mho-microsoft.psm1 -ErrorAction stop
#Import-Module ..\include\mho-vmware\mho-vmware.psm1 -ErrorAction stop

#
# GOBAL MODULE IMPORT END
#

#
# SCRIPT FUNCTIONS START
#
# Add here all functions which are used in this script.
# If function can be reused think about to add it to the imported modules
# to make this functions reusable across multiple scripts.
#



#
# SCRIPT FUNCTIONS END
#

#
# MAIN CODE START
#   


# Create a new Log
Start-MHOLog

# Load Veeam Backup Module
#Import-MHOVeeamBackupModule
# Load NetApp Ontap Module
#Import-MHONetAppOntapModule
#Load/Install AD Management Module
#Import-MHOADManagementModule
#Load/Install DfS Management Module
#Import-MHODfsManagementModule
# Laden des VMware Moduls
#Import-MHOVMwareModule



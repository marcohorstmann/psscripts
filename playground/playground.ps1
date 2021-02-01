<# 
   .SYNOPSIS
   Short description what this script is used for
   .DESCRIPTION
   Explain in detail what this script dp
   .PARAMETER LogFile
   You can set your own path for log file from this script. Default filename is "C:\ProgramData\dfsrecovery.log"

   .EXAMPPLE
   How to run this script with an example
   .\Involve-NASInstantDFSRecovery.ps1 -DfsRoot "\\homelab\dfs" -ScanDepth 3 -VBRJobName "DFS NAS Test" -Owner "HOMELAB\Administrator"

   .Notes 
   Version:        1.0
   Author:         Marco Horstmann (marco.horstmann@veeam.com)
   Creation Date:  13 November 
   Purpose/Change: Initial Release
   
   .LINK
   Online Version: https://github.com/marcohorstmann/psscripts
   .LINK
   Online Version: https://horstmann.in
 #> 
[CmdletBinding(DefaultParameterSetName="__AllParameterSets")]
Param(

<#
   [Parameter(Mandatory=$True)]
   [string]$VBRJobName,
#>
   [Parameter(Mandatory=$False)]
   [string]$Log=$("C:\log\" + $MyInvocation.MyCommand.Name + ".log")
)

#
# GLOBAL MODULE IMPORT
#

#Remove Modules for Debug (can be removed in production code)
Remove-Module mho-logging -ErrorAction Ignore
Remove-Module mho-veeam -ErrorAction Ignore
Remove-Module mho-netapp -ErrorAction Ignore
Remove-Module mho-microsoft -ErrorAction Ignore

# Switch Powershell current path to script path
Split-Path -Parent $PSCommandPath | Set-Location

#Import Logging Module
Import-Module ..\include\mho-logging\mho-logging.psm1 -ErrorAction stop
Import-Module ..\include\mho-veeam\mho-veeam.psm1 -ErrorAction stop
Import-Module ..\include\mho-netapp\mho-netapp.psm1 -ErrorAction stop
Import-Module ..\include\mho-microsoft\mho-microsoft.psm1 -ErrorAction stop

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
Import-MHOVeeamBackupModule
# Load NetApp Ontap Module
Import-MHONetAppOntapModule
#Load/Install AD Management Module
Import-MHOADManagementModule
#Load/Install DfS Management Module
Import-MHODfsManagementModule

#$testdfs = Get-MHODfsFolder -path "\\homelab\dfs" -currentdepth 1 -maxdepth 2
#Get-MHOShareFromReparsePoint -reparsepoints $testdfs

$date = (Get-Date).AddMonths(-1)
#$date = (Get-Date).AddMinutes(-15)
#Get-MHOVBRAgentPolicyBackupsSize
Get-MHOVBRAgentPolicyBackupsSize -Name "L" -SinceDate $date

#Write-MHOLog -Info "test" -Status Error

Get-MHOVeeamProxyIp
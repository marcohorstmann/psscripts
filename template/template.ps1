<# 
   .SYNOPSIS
   Short description what this script is used for
   .DESCRIPTION
   Explain in detail what this script do. This block can be of cause multiline as well.
   .PARAMETER LogFile
   You can set your own path for log file from this script. Default filename is "C:\ProgramData\template.log"

   .Example
   How to run this script with an example
   .\template.ps1 -parameter1 "\\homelab\dfs"

   .Notes 
   Version:        1.0
   Author:         Marco Horstmann (marco.horstmann@veeam.com)
   Creation Date:  15 October 2021
   Purpose/Change: Initial Release
   
   .LINK https://github.com/marcohorstmann/psscripts
   .LINK https://horstmann.in
 #> 
[CmdletBinding(DefaultParameterSetName="__AllParameterSets")]
Param(
<# This is a sample parameter you can use to pass commandline parameters to this script
   [Parameter(Mandatory=$True)]
   [string]$VBRJobName,
#>
   [Parameter(Mandatory=$False)]
   [string]$global:Log=$("C:\log\" + $MyInvocation.MyCommand.Name + ".log")
)

#
# GLOBAL MODULE IMPORT
#

#Remove Modules for Debug (I sometimes need it for Debugging changed modules. Normally this will not be used)
#Remove-Module mho-logging -ErrorAction Ignore
#Remove-Module mho-common -ErrorAction Ignore
#Remove-Module mho-veeam -ErrorAction Ignore
#Remove-Module mho-netapp -ErrorAction Ignore
#Remove-Module mho-microsoft -ErrorAction Ignore
#Remove-Module mho-vmware -ErrorAction Ignore

# Change current Powershell path to script location
Split-Path -Parent $PSCommandPath | Set-Location

#Import Logging Module
Import-Module ..\include\mho-common\mho-common.psm1 -ErrorAction stop
Import-Module ..\include\mho-veeam\mho-veeam.psm1 -ErrorAction stop
Import-Module ..\include\mho-netapp\mho-netapp.psm1 -ErrorAction stop
Import-Module ..\include\mho-microsoft\mho-microsoft.psm1 -ErrorAction stop
Import-Module ..\include\mho-vmware\mho-vmware.psm1 -ErrorAction stop

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
# Laden des VMware Moduls
Import-MHOVMwareModule



<#
$dfsfolder = Get-MHODfsFolder -path "\\homelab\dfs" -currentdepth 0 -maxdepth 2
$dfsfolder
$reparsepointDetails = Get-MHOReparsePointDetails -reparsepoints $dfsfolder
$reparsepointDetails
#>
<#
$volume = Get-MHONetAppVolumeInfo -Session $NetAppSession -Volume "unixfiles"
$volume
#>

<#
Add-MHONetAppSnapshot -Session $NetAppNfsSession -Volume "unixfiles" -Snapshot "VeeamNASBackup"
Rename-MHONetAppSnapshot -Session $NetAppNfsSession -Volume "unixfiles" -Snapshot "VeeamNASBackup" -NewSnapshot "VeeamNASBackupTest"
Remove-MHONetAppSnapshot -Session $NetAppNfsSession -Volume "unixfiles" -Snapshot "VeeamNASBackupTest"
#>

<#
$NetAppCifsSession = Connect-MHONetAppSVM -SVM "lab-nacifs01" -CredentialFile "C:\scripts\credential.xml"
$shares = Get-MHONetAppSVMShares -Session $NetAppCifsSession
#>

<#
$sharesNetView = Get-MHOSmbShares -Server lab-dc01 -Exclude "C$","ADMIN$","SYSVOL","NETLOGON"
$sharesNetView


#>

<#

$iptoint = Get-MHOIP-toINT64 -ip 192.168.1.1

Get-MHOINT64-toIP $iptoint

#>

#$creds = Get-VBRCredentials -Name "root" | ? { $_.Description -match "root" }

Write-MHOLog -Info "This is the text which will be logged to the log file" -Status Error
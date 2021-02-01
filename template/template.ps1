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

#Remove Modules for Debug
Remove-Module mho-logging -ErrorAction Ignore
Remove-Module mho-common -ErrorAction Ignore
Remove-Module mho-veeam -ErrorAction Ignore
Remove-Module mho-netapp -ErrorAction Ignore
Remove-Module mho-microsoft -ErrorAction Ignore
Remove-Module mho-vmware -ErrorAction Ignore

# Switch Powershell current path to script path
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
$NetAppNfsSession = Connect-MHONetAppSVM -SVM "lab-nanfs01" -CredentialFile "C:\scripts\credential.xml"
$proxylist = Get-MHOVeeamProxyIp
Add-MHOIpListToNetAppExportPolicy -Session $NetAppNfsSession -ExportPolicy "default" -IpList $proxylist
#>

<#
if(!( Find-MHOADCredentials -Username "HOMELAB\xAdministrator" )) {
        # What should happen if username can not be validated
        exit 99
    }
#>

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



$vmwarecreds = Get-CredentialsFromFile -File "C:\scripts\vmware-admin.xml"

$vcSession = Connect-VIServer -Server lab-vc01 -Credential $vmwarecreds

$vm = Get-VM -Name "lab-dc01"

#Open-VMConsoleWindow -VM $vm -Server $vcSession -UrlOnly

$vmid = $vm.ExtensionData.MoRef.Value
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $False }
#Invoke-WebRequest -Uri "https://lab-vc01/screen?id=$vmid" -Credential $vmwarecreds -OutFile "C:\scripts\$vmid-$(Get-Date -f yyyyMMdd-hhmm).png" -DisableKeepAlive -Verbose
Invoke-WebRequest -Uri "https://lab-vc01/screen?id=$vmid" -Credential $vmwarecreds -OutFile "C:\scripts\$vmid-$(Get-Date -f yyyyMMdd-hhmm).png" -Method Get
#Invoke-RestMethod -Uri "https://lab-vc01/screen?id=$vmid" -Credential $vmwarecreds -OutFile C:\scripts\$vmid-$(Get-Date -f yyyyMMdd-hhmm).png

#https://lab-vc01/screen?id=vm-1038
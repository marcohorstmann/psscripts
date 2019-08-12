<# 
   .SYNOPSIS
   Creating Snapshot and transfer it to NetApp SnapVault destination for use with Veeam NAS Backup
   .DESCRIPTION
   This script creates a Snapshot on the source volume, transfer this snapshot to the destination volume and cleans the not longer used snapshots up. This script is primary used for 
   .PARAMETER SourceCluster
   With this parameter you specify the source NetApp cluster
   .PARAMETER SourceSVM
   With this parameter you specify the source NetApp SVM or Vserver
   .PARAMETER SourceVolume
   With this parameter you secify the source volume from SourceSVM
   .PARAMETER SourceClusterCredentials
   This parameter is a filename of a saved credentials file for source cluster
   .PARAMETER DestinationCluster
   With this parameter you specify the destination NetApp cluster
   .PARAMETER DestinationSVM
   With this parameter you specify the destination NetApp SVM or Vserver
   .PARAMETER DestinationVolume
   With this parameter you secify the destination volume from DestinationSVM
   .PARAMETER DestinationClusterCredentials
   This parameter is a filename of a saved credentials file for destination cluster. If this parameter is not set it uses the same credentials as the SourceClusterCredentials
   .PARAMETER SnapshotName
   With this parameter you can change the default snapshotname "VeeamNASBackup" to your own name
   .PARAMETER LogPath
   You can set your own path for log files from this script. Default path is the same VBR uses by default "C:\ProgramData\Veeam\Backup"
   .PARAMETER RetainLastDestinationSnapshots
   If you want to keep the last X snapshots which was transfered to snapvault destination 

   .INPUTS
   None. You cannot pipe objects to this script

   .Example 
   You can add this file and parameter to a Veeam NAS Backup Job
   Invoke-NASBackupSnapVaultUpdate.ps1 -SourceCluster 192.168.1.220 -SourceSVM "lab-netapp94-svm1" -SourceVolume "vol_cifs" -SourceClusterCredentials "C:\scripts\saved_credentials_SYSTEM.xml" -DestinationCluster 192.168.1.220 -DestinationSVM "lab-netapp94-svm1" -DestinationVolume "vol_cifs_vault" -DestinationClusterCredentials "C:\scripts\saved_credentials_SYSTEM.xml"

   .Notes 
   Version:        1.0
   Author:         Marco Horstmann (marco.horstmann@veeam.com)
   Creation Date:  <Date>
   Purpose/Change: Initial script development
   
   .LINK https://github.com/marcohorstmann/psscripts/tree/master/NASBackup
   .LINK https://horstmann.in
 #> 
Param(
   [Parameter(Mandatory=$True)]
   [string]$SourceCluster,

   [Parameter(Mandatory=$True)]
   [string]$SourceSVM,
   
   [Parameter(Mandatory=$True)]
   [string]$SourceVolume,
   
   [Parameter(Mandatory=$True)]
   [string]$SourceClusterCredentials,   

   [Parameter(Mandatory=$True)]
   [string]$DestinationCluster,
 
   [Parameter(Mandatory=$True)]
   [string]$DestinationSVM,
 
   [Parameter(Mandatory=$True)]
   [string]$DestinationVolume,

   [Parameter(Mandatory=$false)]
   [string]$DestinationClusterCredentials=$SourceClusterCredentials,   

   [Parameter(Mandatory=$False)]
   [string]$SnapshotName="VeeamNASBackup",

   [Parameter(Mandatory=$False)]
   [string]$LogPath="C:\ProgramData\Veeam\Backup",

   [Parameter(Mandatory=$False)]
   [int]$RetainLastDestinationSnapshots=2
)


#### start of log handling code
#### This section is used to write logs for the operation
$logdate = get-date -format "yyyy-MM-dd-HH-mm"
$logfile = ("NASScriptSnapLog_" + $logdate + ".log")
$logfilename = $Logpath + "\" + $logfile

function Write-Log([string]$logtext, [int]$level=0)
{
	$logdate = get-date -format "yyyy-MM-dd HH:mm:ss"
	if($level -eq 0)
	{
		$logtext = "[INFO] " + $logtext
		$text = "["+$logdate+"] - " + $logtext
		Write-Host $text
	}
	if($level -eq 1)
	{
		$logtext = "[WARNING] " + $logtext
		$text = "["+$logdate+"] - " + $logtext
		Write-Host $text -ForegroundColor Yellow
	}
	if($level -eq 2)
	{
		$logtext = "[ERROR] " + $logtext
		$text = "["+$logdate+"] - " + $logtext
		Write-Host $text -ForegroundColor Red
	}
	$text >> $logfilename
}

# Cleanup log folder (delete old logs exept the newest 10 logs)
$logpathandprefix = $Logpath + "\NASScriptSnapLog_*"
Get-Item -Path $logpathandprefix | Sort-Object -Descending CreationTime |  Select-Object -Skip 10 | Remove-Item

#### End of log handling code

# Import NetApp Powershell Plugins
Write-Log "Trying to load NetApp Powershell module"
try {
   Import-Module DataONTAP
   Write-Log "Loaded NetApp Powershell module sucessfully"
} catch  {
   Write-Log "$_" 2
   Write-Log "Loading NetApp Powershell module failed" 2
}

#Connecting to source cluster (TODO: Maybe a SVM Only connect works with later Ontap Versions?)
try {
   #Load saved credentials for source cluster
   Write-Log "Loading credentials for source cluster from file $SourceClusterCredentials"
   $srcCredential = Import-CliXml -Path $SourceClusterCredentials -ErrorAction Stop
} catch {
   # Error handling if loading credentials failed  
      Write-Log "$_" 2
      Write-Log "Failed to load credentials from file for source cluster $SourceClusterCredentails" 2
      Write-Log "Maybe credentials wasn't saved with account Veeam Service is running" 2
      Write-Log "see Documentation of this script for instructions" 2
      exit 1
}
Write-Log "Trying to connect to source cluster $SourceCluster"
try {  
   Connect-NcController -name $SourceCluster -Credential $srcCredential -HTTPS -ErrorAction Stop
   Write-Log "Connection established to $SourceCluster"
   } catch {
      # Error handling if connection fails  
      Write-Log "$_" 2
      exit 1
}

if($SourceCluster -eq $DestinationCluster ) {
   #Connecting to destination cluster
    try {
      #Load saved credentials for destination cluster
      Write-Log "Loading credentials for source cluster from file $DestinationClusterCredentials"
      $dstCredential = Import-CliXml -Path $DestinationClusterCredentials -ErrorAction Stop
   } catch {
      # Error handling if loading credentials failed  
         Write-Log "$_" 2
         Write-Log "Failed to load credentials from file for destination cluster $DestinationClusterCredentials" 2
         Write-Log "Maybe credentials wasn't saved with account Veeam Service is running" 2
         Write-Log "see Documentation of this script for instructions" 2
         exit 1
   }
   Write-Log "Trying to connect to destination cluster $DestinationCluster"
   try {  
      Connect-NcController -name $DestinationCluster -Credential $dstCredential -HTTPS -ErrorAction Stop
      Write-Log "Connection established to $DestinationCluster"
      } catch {
         # Error handling if connection fails  
         Write-Log "$_" 2
         exit
   }
}

#Generate Snapshotname for the previous snapshot on source system
$OldSnapshotName = $SnapshotName + "OLD"
# If an Snapshot with the name from $OldSnapshotName varible exists delete it
if(get-NcSnapshot -Vserver $SourceSVM -Volume $SourceVolume -Snapshot $OldSnapshotName -Verbose) {
    Write-Log "Previous Snapshot exists and will be removed..."
    try {
    Remove-NcSnapshot -VserverContext $SourceSVM -Volume $SourceVolume -Snapshot $OldSnapshotName -Verbose -Confirm:$false -ErrorAction Stop
    Write-Log "Previous Snapshot was removed"
    } catch {
      # Error handling if snapshot cannot be removed
      Write-Log "$_" 2
      Write-Log "Previous Snapshot could be removed" 2
      exit 1
      }
} 

# Now rename existing transfer snapshot to a new name
if(get-NcSnapshot -Vserver $SourceSVM -Volume $SourceVolume -Snapshot $SnapshotName -Verbose) {
    Write-Log "Actual Snapshot exists and will be renamed..."
    try {
    get-NcSnapshot -Vserver $SourceSVM -Volume $SourceVolume -Snapshot $SnapshotName | Rename-NcSnapshot -NewName $OldSnapshotName
    Write-Log "Snapshot was renamed"
    } catch {
      # Error handling if snapshot cannot be removed
      Write-Log "$_" 2
      Write-Log "Snapshot could be renamed" 2
      exit 1
      }
} 


# Create new snapshot on the source system
Write-Log "Snapshot will be created..."
try {
   New-NcSnapshot -VserverContext $SourceSVM -Volume $SourceVolume -Snapshot $SnapshotName -Verbose
   Write-Log "Snapshot was created"
} catch {
   Write-Log "$_" 2
   Write-Log "Snapshot could not be created" 2
   exit 1
}

Write-Log "Before Snapvault transfer"

#transfer snapshot to the destination system
try {
  Invoke-NcSnapmirrorUpdate -DestinationVserver $DestinationSVM -DestinationVolume $DestinationVolume -SourceSnapshot $SnapshotName
  Write-Log "Waiting for SV Transfer to finish..."
  Start-Sleep 20
  # Check every 30 seconds if snapvault relationship is in idle state
  while (get-ncsnapmirror -DestinationVserver $DestinationSVM -DestinationVolume $DestinationVolume | ? { $_.Status -ine "idle" } ) {
    Write-Log "Waiting for SV Transfer to finish..."
    Start-Sleep -seconds 30
  }
  Write-Log "SV Transfer Finished"
} catch {
  Write-Log "$_" 2
  Write-Log "Transfering Snapshot to destination system failed" 2
  exit 1
}

$SnapshotNameWithDate = $SnapshotName + "_*"
#cleanup Snapshots on Destination
Write-Log "Starting with cleaning up destination snapshots"
try {
  # Get the snapshots from destination and delete all snapshots created by this script and maybe retain X snapshots depending on parameter RetainLastDestinationSnapshots
  get-NcSnapshot -Vserver $DestinationSVM -Volume $DestinationVolume -Snapshot $SnapshotNameWithDate | Sort-Object -Property Created -Descending | Select-Object -Skip $RetainLastDestinationSnapshots | Remove-NcSnapshot -Confirm:$false
  Write-Log "Old Snapshots was cleaned up"
} catch {
  Write-Log "$_" 2
  Write-Log "Snapshots couldn't be cleaned up at destination volume" 2
}


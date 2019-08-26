﻿<# 
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
   .PARAMETER SecondaryCluster
   With this parameter you specify the destination NetApp cluster
   .PARAMETER SecondarySVM
   With this parameter you specify the destination NetApp SVM or Vserver
   .PARAMETER SecondaryShare
   With this parameter you secify the destination volume from DestinationSVM
   .PARAMETER SecondaryClusterCredentials
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
[CmdletBinding(DefaultParameterSetName="__AllParameterSets")]
Param(

   [Parameter(Mandatory=$True)]
   [string]$SourceCluster,

   [Parameter(Mandatory=$True)]
   [string]$SourceSVM,
   
   [Parameter(Mandatory=$True)]
   [string]$SourceShare,
   
   [Parameter(Mandatory=$True)]
   [string]$SourceClusterCredentials,   

   [Parameter(Mandatory=$False)]
   [string]$SnapshotName="VeeamNASBackup",

   [Parameter(Mandatory=$False)]
   [string]$LogFile="C:\programdata\NASBackup.log",

   [Parameter(Mandatory=$False)]
   [int]$RetainLastDestinationSnapshots=2,

   [Parameter(Mandatory=$False)]
   [switch]$UseSecondaryDestination
)

DynamicParam {
  if ($UseSecondaryDestination)
  {
    #create paramater dictenory
    $paramDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

    #create general settings for all attributes
    $attributes = New-Object System.Management.Automation.ParameterAttribute
    $attributes.ParameterSetName = "__AllParameterSets"
    $attributes.Mandatory = $true
    $attributeCollection = New-Object -Type System.Collections.ObjectModel.Collection[System.Attribute]
    $attributeCollection.Add($attributes)

    #Creating the diffentent dynamic parameters
    $SecondaryClusterAttribute = New-Object System.Management.Automation.ParameterAttribute
    $SecondaryClusterAttribute.Mandatory = $true
    $SecondaryClusterAttribute.HelpMessage = "This is the secondary system in a mirror and/or vault relationship"
    $SecondaryClusterParam = New-Object System.Management.Automation.RuntimeDefinedParameter('SecondaryCluster', [String], $attributeCollection)

    $SecondarySVMAttribute = New-Object System.Management.Automation.ParameterAttribute
    $SecondarySVMAttribute.Mandatory = $true
    $SecondarySVMAttribute.HelpMessage = "This is the secondary SVM in a mirror and/or vault relationship"
    $SecondarySVMParam = New-Object System.Management.Automation.RuntimeDefinedParameter('SecondarySVM', [String], $attributeCollection)

    $SecondaryShareAttribute = New-Object System.Management.Automation.ParameterAttribute
    $SecondaryShareAttribute.Mandatory = $true
    $SecondarySVMAttribute.HelpMessage = "This is the secondary share in a mirror and/or vault relationship"
    $SecondaryShareParam = New-Object System.Management.Automation.RuntimeDefinedParameter('SecondaryShare', [String], $attributeCollection)
    
    $SecondaryCredentialsAttribute = New-Object System.Management.Automation.ParameterAttribute
    $SecondaryCredentialsAttribute.Mandatory = $false
    $SecondaryCredentialsAttribute.HelpMessage = "This is the secondary share in a mirror and/or vault relationship"
    $SecondaryCredentialsParam = New-Object System.Management.Automation.RuntimeDefinedParameter('SecondaryCredentials', [String], $attributeCollection)
    $SecondaryCredentialsParam.Value = $SourceClusterCredentials

    #Add here all parameters 
    $paramDictionary.Add('SecondaryCluster', $SecondaryClusterParam)
    $paramDictionary.Add('SecondarySVM', $SecondarySVMParam)
    $paramDictionary.Add('SecondaryShare', $SecondaryShareParam)
    $paramDictionary.Add('SecondaryCredentials', $SecondaryCredentialsParam)
    #add here additional parameters
  }

  return $paramDictionary
}

PROCESS {

  function Write-Log($Info, $Status)
  {
    switch($Status)
    {
        Info    {Write-Host $Info -ForegroundColor Green  ; $Info | Out-File -FilePath $LogFile -Append}
        Status  {Write-Host $Info -ForegroundColor Yellow ; $Info | Out-File -FilePath $LogFile -Append}
        Warning {Write-Host $Info -ForegroundColor Yellow ; $Info | Out-File -FilePath $LogFile -Append}
        Error   {Write-Host $Info -ForegroundColor Red -BackgroundColor White; $Info | Out-File -FilePath $LogFile -Append}
        default {Write-Host $Info -ForegroundColor white $Info | Out-File -FilePath $LogFile -Append}
    }
  } #end function 

  function Load-NetAppModule
  {
    Write-Log -Info "Trying to load NetApp Powershell module" -Status Info
    try {
        Import-Module DataONTAP
        Write-Log -Info "Loaded NetApp Powershell module sucessfully" -Status Info
    } catch  {
        Write-Log -Info "$_" -Status Error
        Write-Log -Info "Loading NetApp Powershell module failed" -Status Error
        exit 99
    }
  }


  function Connect-NetAppSystem($clusterName, $svmName, $clusterCredential)
  {
    # Import NetApp Powershell Plugins
    Write-Log -Info "Trying to connect to SVM $svmName on cluster $clusterName " -Status Info
    try {
        $Credential = Import-CliXml -Path $clusterCredential -ErrorAction Stop  
        #Connect-NcController -name $System -Vserver $svmName -Credential $Credential -HTTPS -ErrorAction Stop
        Connect-NcController -name $clusterName -Vserver $svmName -Credential $Credential -HTTPS -ErrorAction Stop
        Write-Log -Info "Connection established to $svmName on cluster $clusterName" -Status Info
    } catch {
        # Error handling if connection fails  
        Write-Log -Info "$_" -Status Error
        exit 1
    }
  }

  function Get-NetAppVolumeFromShare($SVM, $Share)
  {
    $share = get-nccifsshare -VserverContext $SVM -name $Share
    return $share.Volume
  }

  function Remove-NetAppSnapshot($SnapshotName, $SVM, $Volume)
  {
    # If an Snapshot with the name exists delete it
    if(get-NcSnapshot -Vserver $SVM -Volume $Volume -Snapshot $SnapshotName -Verbose) {
      Write-Log -Info "Previous Snapshot exists and will be removed..." -Status Info
      try {
        Remove-NcSnapshot -VserverContext $SVM -Volume $Volume -Snapshot $SnapshotName -Verbose -Confirm:$false -ErrorAction Stop
        Write-Log -Info "Previous Snapshot was removed" -Status Info
      } catch {
        # Error handling if snapshot cannot be removed
        Write-Log -Info "$_" -Status Error
        Write-Log -Info "Previous Snapshot could be removed" -Status Error
        exit 1
      }
    }
  }

  function Create-NetAppSnapshot($SnapshotName, $SVM, $Volume)
  {
    # Create new snapshot on the source system
    Write-Log -Info "Snapshot will be created..." -Status Info
    try {
      New-NcSnapshot -VserverContext $SVM -Volume $Volume -Snapshot $SnapshotName -Verbose
      Write-Log -Info "Snapshot was created" -Status Info
    } catch {
      Write-Log -Info "$_" -Status Error
      Write-Log -Info "Snapshot could not be created" -Status Error
      exit 1
    }
  }

  function Rename-NetAppSnapshot($SnapshotName, $NewSnapshotName, $SVM, $Volume)
  {
    if(get-NcSnapshot -Vserver $SVM -Volume $Volume -Snapshot $SnapshotName -Verbose) {
      Write-Log -Info "Actual Snapshot exists and will be renamed..." -Status Info
      try {
      get-NcSnapshot -Vserver $SVM -Volume $Volume -Snapshot $SnapshotName | Rename-NcSnapshot -NewName $NewSnapshotName
      Write-Log -Info "Snapshot was renamed" -Status Info
      } catch {
        # Error handling if snapshot cannot be removed
        Write-Log -Info "$_" -Status Error
        Write-Log -Info "Snapshot could not be renamed" -Status Error
        exit 1
      }
    } 
  }

  function Start-NetAppSync($SecondarySVM, $SecondaryVolume, $SourceSnapshotName)
  {
    #transfer snapshot to the destination system
      try {
        Invoke-NcSnapmirrorUpdate -DestinationVserver $SecondarySVM -DestinationVolume $SecondaryVolume -SourceSnapshot $SourceSnapshotName
        Write-Log -Info "Waiting for SV Transfer to finish..." -Status Info
        Start-Sleep 20
        # Check every 30 seconds if snapvault relationship is in idle state
        while (get-ncsnapmirror -DestinationVserver $SecondarySVM -DestinationVolume $SecondaryVolume | ? { $_.Status -ine "idle" } ) {
          Write-Log -Info "Waiting for SV Transfer to finish..." -Status Info
          Start-Sleep -seconds 30
        }
        Write-Log -Info "SV Transfer Finished" -Status Info
      } catch {
        Write-Log -Info "$_" -Status Error
        Write-Log -Info "Transfering Snapshot to destination system failed" -Status Error
        exit 1
      }
  }

  function CleanUp-SecondaryDestination($SecondarySVM, $SecondaryVolume, $SourceSnapshotName)
  {
    $SnapshotNameWithDate = $SnapshotName + "_*"
    Write-Log -Info "Starting with cleaning up destination snapshots" -Status Info
    try {
      # Get the snapshots from destination and delete all snapshots created by this script and maybe retain X snapshots depending on parameter RetainLastDestinationSnapshots
      get-NcSnapshot -Vserver $SecondarySVM -Volume $SecondaryVolume -Snapshot $SnapshotNameWithDate | Sort-Object -Property Created -Descending | Select-Object -Skip $RetainLastDestinationSnapshots | Remove-NcSnapshot -Confirm:$false
      Write-Log -Info "Old Snapshots was cleaned up" -Status Info
    } catch {
      Write-Log -Info "$_" -Status Error
      Write-Log -Info "Snapshots couldn't be cleaned up at destination volume" -Status Error
    }
  }

  ####
  ####
  ####  .\Invoke-NASBackup.ps1 -SourceCluster 192.168.1.220 -SourceSVM "lab-netapp94-svm1" -SourceShare "vol_cifs" -SourceClusterCredentials "C:\scripts\saved_credentials_Administrator.xml" -UseSecondaryDestination -SecondaryCluster 192.168.1.220 -SecondarySVM "lab-netapp94-svm1" -SecondaryShare "vol_cifs_vault" -SecondaryCredentials "C:\scripts\saved_credentials_Administrator.xml"
  ####
  ####
  ##### MainScript

  #Add dynamic paramters to use it in normal code
  foreach($key in $PSBoundParameters.keys)
    {
        Set-Variable -Name $key -Value $PSBoundParameters."$key" -Scope 0
    }

  Load-NetAppModule
  #Connect to the NetApp system
  Connect-NetAppSystem -clusterName $SourceCluster -svmName $SourceSVM -clusterCredential $SourceClusterCredentials
  # IF we use Secondary Storage System we need to connect to this controller (exept its the same system as source)
  if($UseSecondaryDestination -and ($SourceCluster -ne $SecondaryCluster))
  {
    Connect-NetAppSystem -clusterName $SecondaryCluster -svmName $SecondarySVM -clusterCredential $SecondaryCredentials
  }
  if($UseSecondaryDestination)
  {

  }
  #Get the name of the volume from share (ToDo: Check if Junction paths are used)
  $SourceVolume = Get-NetAppVolumeFromShare -SVM $SourceSVM -Share $SourceShare

  if($UseSecondaryDestination)
  {
    #If using Snapvault or SnapMirror we cannot just delete the snapshot. We need to rename
    #it otherwise we get problems with the script
    $OldSnapshotName = $SnapshotName + "OLD"
    $SecondaryVolume = Get-NetAppVolumeFromShare -SVM $SecondarySVM -Share $SecondaryShare
    Remove-NetAppSnapshot -SnapshotName $OldSnapshotName -SVM $SourceSVM -Volume $SourceVolume
    # Rename exisiting Snapshot to $OldSnapshotName
    Rename-NetAppSnapshot -SnapshotName $SnapshotName -NewSnapshotName $OldSnapshotName -SVM $SourceSVM -Volume $SourceVolume
    Create-NetAppSnapshot -SnapshotName $SnapshotName -SVM $SourceSVM -Volume $SourceVolume
    Start-NetAppSync -SecondarySVM $SecondarySVM -SecondaryVolume $SecondaryVolume -SourceSnapshotName $SnapshotName
    Cleanup-SecondaryDestination -SecondarySVM $SecondarySVM -SecondaryVolume $SecondaryVolume -SourceSnapshotName $SnapshotName
    ###
  } else {
    #Just rotate the local snapshot when no secondary destination is enabled
    Remove-NetAppSnapshot -SnapshotName $SnapshotName -SVM $SourceSVM -Volume $SourceVolume
    Create-NetAppSnapshot -SnapshotName $SnapshotName -SVM $SourceSVM -Volume $SourceVolume
  }
} # END Process
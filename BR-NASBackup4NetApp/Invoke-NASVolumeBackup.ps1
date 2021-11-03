<# 
   .SYNOPSIS
   Create NetApp Snapshot and optional Transfer to secondary destination for NAS Backup 
   .DESCRIPTION
   This script create an snapshot on the given primary volume(s). After creating this snapshot
   this snapshot will optional transfered to a secondary destination.
   .PARAMETER PrimaryCluster
   With this parameter you specify the source NetApp cluster, where the volume is located.
   .PARAMETER PrimarySVM
   With this parameter you specify the source NetApp SVM, where the volume is located.
   .PARAMETER PrimaryVolume
   With this parameter you specify the source volume(s) from primary SVM. You can add
   here more than one volume with "vol1","vol2","etc" but this only works if you are not
   use a secondary destination.
   .PARAMETER PrimaryClusterCredentials
   This parameter is a filename of a saved credentials file for source cluster.
   .PARAMETER SecondaryCluster
   With this parameter you specify the destination NetApp cluster, where the destination volume is located.
   .PARAMETER SecondarySVM
   With this parameter you specify the secondary NetApp SVM, where the destination volume is located.
   .PARAMETER SecondaryVolume
   With this parameter you specify the secondary volume from secondary SVM.
   .PARAMETER SecondaryClusterCredentials
   This parameter is a filename of a saved credentials file for secondary cluster.
   .PARAMETER SnapshotName
   With this parameter you can change the default snapshotname "VeeamNASBackup" to your own snapshotname.
   .PARAMETER LogFile
   You can set your own path for log file from this script. Default filename is "C:\ProgramData\NASBackup.log"
   .PARAMETER RetainLastDestinationSnapshots
   If you want to keep the last X snapshots which was transfered to snapvault destination. Default: 2
   .PARAMETER UseSecondaryDestination
   With UseSecondaryDestinatination the script will require details to a secondary system. Without this Parameter you can just backup from primary share.

   .INPUTS
   None. You cannot pipe any objects to this script.

   .Example
   If you want to use this script with only one NetApp system you can use this parameters.
   You can add this file and parameter to a Veeam NAS Backup Job
   .\Invoke-NASBackup.ps1 -PrimarySVM lab-nacifs01 -PrimaryVolume "data" -PrimaryClusterCredentials "C:\scripts\psscripts\BR-NASBackup4NetApp\credentials.xml"

   .Example
   if you are only running this script against a primary NetApp system you can specify multiple volumes.
   You can add this file and parameter to a Veeam NAS Backup Job
   .\Invoke-NASBackup.ps1 -PrimarySVM "lab-nacifs01" -PrimaryVolume "volume1","volume2","volume3" -PrimaryClusterCredentials "C:\scripts\psscripts\BR-NASBackup4NetApp\credentials.xml"

   .Example
   If you want to use a secondary destination as source for NAS Backup you can use this parameter set.
   You can add this file and parameter to a Veeam NAS Backup Job
   .\Invoke-NASVolumeBackup.ps1 -PrimarySVM "lab-nacifs01" -PrimaryVolume "data" -PrimaryCredentials "C:\scripts\psscripts\BR-NASBackup4NetApp\credential_admin.xml" -UseSecondaryDestination -SecondarySVM "lab-nacifs02" -SecondaryVolume "data_mirror" -SecondaryCredentials "C:\scripts\psscripts\BR-NASBackup4NetApp\credential_admin.xml" 

   .Notes 
   Version:        4.0
   Author:         Marco Horstmann (marco.horstmann@veeam.com)
   Creation Date:  30 July 2020
   Purpose/Change: Forked script to allow adding volume name instead of share name
                   Also improved logging
   
   .LINK https://github.com/veeamhub/powershell
   .LINK https://horstmann.in
 #> 
[CmdletBinding(DefaultParameterSetName="__AllParameterSets")]
Param(
   [Parameter(Mandatory=$True)]
   [string]$PrimarySVM,
   
   [Parameter(Mandatory=$True)]
   [string[]]$PrimaryVolume,
   
   [Parameter(Mandatory=$True)]
   [string]$PrimaryCredentials,   

   [Parameter(Mandatory=$False)]
   [string]$SnapshotName="VeeamNASBackup",

   [Parameter(Mandatory=$False)]
#   [string]$global:Log=$("C:\log\" + $MyInvocation.MyCommand.Name + ".log"),
   [string]$global:Log=$("C:\log\nasbackup.log"),

    [Parameter(Mandatory=$False)]
    [switch]$global:LogToVBR=$True,

   [Parameter(Mandatory=$False)]
   [int]$RetainLastDestinationSnapshots=2,

   [Parameter(Mandatory=$False)]
   [switch]$UseSecondaryDestination
)

DynamicParam {
  # If Parameter -UseSecondaryDestination was set, the script needs additional parameters to work.
  # With this codesection I was able to create dynamic parameters.
  if ($UseSecondaryDestination)
  { 
    #create paramater dictenory
    $paramDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

    #create general settings for all attributes which will be assigend to the parameters
    $attributes = New-Object System.Management.Automation.ParameterAttribute
    $attributes.ParameterSetName = "__AllParameterSets"
    $attributes.Mandatory = $true
    $attributeCollection = New-Object -Type System.Collections.ObjectModel.Collection[System.Attribute]
    $attributeCollection.Add($attributes)
    <#
    #Creating the diffentent dynamic parameters
    $SecondaryClusterAttribute = New-Object System.Management.Automation.ParameterAttribute
    $SecondaryClusterAttribute.Mandatory = $true
    $SecondaryClusterAttribute.HelpMessage = "This is the secondary system in a mirror and/or vault relationship"
    $SecondaryClusterParam = New-Object System.Management.Automation.RuntimeDefinedParameter('SecondaryCluster', [String], $attributeCollection)
    #>
    $SecondarySVMAttribute = New-Object System.Management.Automation.ParameterAttribute
    $SecondarySVMAttribute.Mandatory = $true
    $SecondarySVMAttribute.HelpMessage = "This is the secondary SVM in a mirror and/or vault relationship"
    $SecondarySVMParam = New-Object System.Management.Automation.RuntimeDefinedParameter('SecondarySVM', [String], $attributeCollection)

    $SecondaryVolumeAttribute = New-Object System.Management.Automation.ParameterAttribute
    $SecondaryVolumeAttribute.Mandatory = $true
    $SecondaryVolumeAttribute.HelpMessage = "This is the secondary volume in a mirror and/or vault relationship"
    $SecondaryVolumeParam = New-Object System.Management.Automation.RuntimeDefinedParameter('SecondaryVolume', [String], $attributeCollection)
    
    $SecondaryCredentialsAttribute = New-Object System.Management.Automation.ParameterAttribute
    $SecondaryCredentialsAttribute.Mandatory = $false
    $SecondaryCredentialsAttribute.HelpMessage = "This is the secondary share in a mirror and/or vault relationship"
    $SecondaryCredentialsParam = New-Object System.Management.Automation.RuntimeDefinedParameter('SecondaryCredentials', [String], $attributeCollection)
    $SecondaryCredentialsParam.Value = $PrimaryCredentials

    #Add here all parameters to the dictionary to make them available for use in script
    #$paramDictionary.Add('SecondaryCluster', $SecondaryClusterParam)
    $paramDictionary.Add('SecondarySVM', $SecondarySVMParam)
    $paramDictionary.Add('SecondaryVolume', $SecondaryVolumeParam)
    $paramDictionary.Add('SecondaryCredentials', $SecondaryCredentialsParam)
    #add here additional parameters if later needed
  }

  return $paramDictionary
}

PROCESS {
    #Remove Modules for Debug (can be removed in production code)
    Remove-Module mho-common -ErrorAction Ignore
    Remove-Module mho-veeam -ErrorAction Ignore
    Remove-Module mho-netapp -ErrorAction Ignore
    #Remove-Module mho-microsoft -ErrorAction Ignore

    # Switch Powershell current path to script path
    Split-Path -Parent $PSCommandPath | Set-Location
    #Import Logging Module
    Import-Module ..\include\mho-common\mho-common.psm1 -ErrorAction stop
    Import-Module ..\include\mho-veeam\mho-veeam.psm1 -ErrorAction stop
    Import-Module ..\include\mho-netapp\mho-netapp.psm1 -ErrorAction stop
    #Import-Module ..\include\mho-microsoft\mho-microsoft.psm1 -ErrorAction stop

    Start-MHOLog
    #Add dynamic paramters to use it in normal code
    foreach($key in $PSBoundParameters.keys)
    {
        Set-Variable -Name $key -Value $PSBoundParameters."$key" -Scope 0
    }



    #
    # Main Code starts
    #
    
    if($LogToVBR) {
        $global:BackupSession = Get-MHOVbrJobSessionFromPID
        Write-MHOLog -Info "Obtaining VBR job session details..." -Status Info
        #$logentry = Add-MHOVbrJobSessionLogEvent -BackupSession $BackupSession -Status Success -Text "Marco Test Success"
    }
    

    # Additional checks for unsupported configuration
    if($PrimaryVolume.Count -gt 1) {
        Write-MHOLog -Info "More than one primary volume was added. This is not supported with secondary destination" -Status Error
        $logentry = Add-MHOVbrJobSessionLogEvent -BackupSession $BackupSession -Status Error -Text "More than one primary volume was added. This is not supported with secondary destination"
        exit
    }

    # Load the NetApp Modules
    Import-MHONetAppOntapModule

    $PrimarySVMSession = Connect-MHONetAppSVM -SVM $PrimarySVM -CredentialFile $PrimaryCredentials
    
    # IF we use Secondary Storage System we need to connect to this controller (exept its the same system as source)
    if($UseSecondaryDestination)
    {
        $SecondarySVMSession = Connect-MHONetAppSVM -SVM $SecondarySVM -CredentialFile $SecondaryCredentials
    }

    
    #Get the volume properties
    ForEach($SingleVolume in $PrimaryVolume) {
        $PrimaryVolumeObject = Get-MHONetAppVolumeInfo -Session $PrimarySVMSession -Volume $SingleVolume
        if($LogToVBR) { $logentry = Add-MHOVbrJobSessionLogEvent -BackupSession $BackupSession -Status Success -Text "Getting properties of primary volume $($PrimaryVolumeObject.name)" }
        # This codeblock is only needed if we transfer to a secondary system. 
        if($UseSecondaryDestination)
        {
            #If using Snapvault or SnapMirror we cannot just delete the snapshot. We need to rename
            #it otherwise we get problems with the script
            $OldSnapshotName = $SnapshotName + "OLD"
            $SecondaryVolumeObject = Get-MHONetAppVolumeInfo -Session $SecondarySVMSession -SVM $SecondarySVM -Volume $SecondaryVolume
            if($LogToVBR) { $logentry = Add-MHOVbrJobSessionLogEvent -BackupSession $BackupSession -Status Success -Text "Getting properties of secondary volume $($SecondaryVolumeObject.name)" }
            Remove-MHONetAppSnapshot -Session $PrimarySVMSession -Volume $PrimaryVolumeObject -Snapshot $OldSnapshotName
            # Rename exisiting Snapshot to $OldSnapshotName
            Rename-MHONetAppSnapshot -Session $PrimarySVMSession -Volume $PrimaryVolumeObject -Snapshot $SnapshotName -NewSnapshot $OldSnapshotName
            Add-MHONetAppSnapshot -Session $PrimarySVMSession -Volume $PrimaryVolumeObject -Snapshot $SnapshotName
            Invoke-MHONetAppSync -Session $SecondarySVMSession -SecondarySVM $SecondarySVM -SecondaryVolume $SecondaryVolumeObject -SnapshotName $SnapshotNameObject
            ########END EDITED
            Invoke-MHONetAppSecondaryDestinationCleanUp -Session $SecondarySVMSession -SecondaryVolume $SecondaryVolumeObject -SnapshotName $SnapshotName
            # If we dont use seconady systems we only take care of processing on the primary system.
        } else {
            #Just rotate the local snapshot when no secondary destination is enabled
            Remove-MHONetAppSnapshot -SnapshotName $SnapshotName -Session $PrimarySVMSession -Volume $PrimaryVolumeObject
            Create-MHONetAppSnapshot -SnapshotName $SnapshotName -Session $PrimarySVMSession -Volume $PrimaryVolumeObject
        }
    }

    Write-MHOLog -Status Info -Info "Script execution finished"
} # END Process

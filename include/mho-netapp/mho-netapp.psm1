# This function will load the NetApp Powershell Module.
function Import-MHONetAppOntapModule {
<#
    .SYNOPSIS
        This function is used to load the NetApp DataOntap Modules
    .DESCRIPTION
        This function tries to load the NetApp DataOntap cmdlets. If this fails
        it will stop the script execution.
    .INPUTS
        None

    .OUTPUTS
        None

    .EXAMPLE
        Import-MHONetAppOntapModule

    .NOTES 
        Version:        2.0
        Author:         Marco Horstmann (marco.horstmann@veeam.com)
        Creation Date:  25 Januar 2021
        Purpose/Change: Initial Release
    .LINK
        Online Version: https://github.com/marcohorstmann/psscripts
#>
    Write-MHOLog -Status Info -Info "Checking if NetApp Ontap Modules are installed ..."
    if(Get-Command -Module *DataOntap*) {
        import-module DataOntap -ErrorAction Stop
        Write-MHOLog -Status Info -Info "NetApp Ontap Modules are loaded ... DONE"
        if($LogToVBR) { $logentry = Add-MHOVbrJobSessionLogEvent -BackupSession $BackupSession -Status Success -Text "NetApp DataONTAP modules are loaded" }
    } else {
        Write-MHOLog -Status Info -Info "NetApp Ontap Modules are not installed... INSTALLING..."
        try {
            Install-Module -Name DataOntap -Force -Confirm:$False
            import-module DataOntap -ErrorAction Stop
            Write-MHOLog -Info "NetApp Ontap Modules was installed... DONE" -Status Info
            if($LogToVBR) { $logentry = Add-MHOVbrJobSessionLogEvent -BackupSession $BackupSession -Status Success -Text "NetApp DataONTAP modules are installed" }
        } catch  {
            Write-MHOLog -Info "$_" -Status Error
            Write-MHOLog -Info "Installing NetApp Ontap Modules... FAILED" -Status Error
            if($LogToVBR) { $logentry = Add-MHOVbrJobSessionLogEvent -BackupSession $BackupSession -Status Error -Text "NetApp DataONTAP modules failed to install" }
            exit
        }
    }
} # end function


# This function is used to connect to a specfix NetApp SVM
function Connect-MHONetAppSVM($SVM, $CredentialFile) {
    Write-MHOLog -Info "Trying to connect to SVM $SVM" -Status Info
    try {
        # Read Credentials from credentials file
        $Credential = Import-CliXml -Path $CredentialFile -ErrorAction Stop
        # Save the session into a variable to return this into the main script 
        $session = Connect-NcController -name $SVM -Credential $Credential -HTTPS -ErrorAction Stop
        Write-MHOLog -Info "Connection established to $SVM ..." -Status Info
        if($LogToVBR) { $logentry = Add-MHOVbrJobSessionLogEvent -BackupSession $BackupSession -Status Success -Text "Connection established to $SVM" }
        return $session
    } catch {
        # Error handling if connection fails  
        Write-MHOLog -Info "$_" -Status Error
        Write-MHOLog -Info "Connection failed to $SVM" -Status Error
        if($LogToVBR) { $logentry = Add-MHOVbrJobSessionLogEvent -BackupSession $BackupSession -Status Error -Text "Connection failed to $SVM - Common issue is that you have not enabled managemwent access on SVM lif" }
        Write-MHOLog -Info "Common issue is that you have not enabled managemwent access on SVM lif"
        exit
    }
}

# Getting NetAppVolume Infos
function Get-MHONetAppVolumeInfo($Session, $Volume) {
    try {
        $volumeObject = Get-NcVol -Controller $Session -name $Volume
        if (!$volumeObject) {
            Write-MHOLog -Info "Volume $Volume was not found" -Status Error
            if($LogToVBR) { $logentry = Add-MHOVbrJobSessionLogEvent -BackupSession $BackupSession -Status Error -Text "Volume $Volume was not found" }
            exit
        }
        Write-MHOLog -Info "Volume $Volume was found" -Status Info
        #if($LogToVBR) { $logentry = Add-MHOVbrJobSessionLogEvent -BackupSession $BackupSession -Status Success -Text "Getting properties of volume $Volume" }
        return $volumeObject
    } catch {
        Write-MHOLog -Info "$_" -Status Error
        Write-MHOLog -Info "Volume $Volume couldn't be located" -Status Error
        if($LogToVBR) { $logentry = Add-MHOVbrJobSessionLogEvent -BackupSession $BackupSession -Status Error -Text "Volume $Volume was not found" }
        exit 40
    }
} # end function

# Function to get all shares of a SVM
function Get-MHONetAppSVMShares($Session) {
    try {
        $sharesObject = get-nccifsshare -Controller $Session | Where-Object {$_.Path.Length -gt "1"}
        if (!$sharesObject) {
            Write-MHOLog -Info "SVM $Session has no shares" -Status Error
            exit 40
        }
        Write-MHOLog -Info "Shares was found on $SVM" -Status Info
        return $sharesObject
    } catch {
        Write-MHOLog -Info "$_" -Status Error
        exit 40
    }
} # end function



# This function creates a snapshot on source system
function Add-MHONetAppSnapshot($Session, $Volume, $Snapshot) {
    Write-MHOLog -Info "Snapshot $Snapshot on $Volume will be created..." -Status Info
    try {
        New-NcSnapshot -Controller $Session -Volume $Volume -Snapshot $Snapshot -Verbose
        Write-MHOLog -Info "Snapshot was created" -Status Info
        if($LogToVBR) { $logentry = Add-MHOVbrJobSessionLogEvent -BackupSession $BackupSession -Status Success -Text "Creating snapshot `"$Snapshot`" on volume `"$Volume`"" }
    } catch {
        Write-MHOLog -Info "$_" -Status Error
        Write-MHOLog -Info "Snapshot could not be created" -Status Error
        if($LogToVBR) { $logentry = Add-MHOVbrJobSessionLogEvent -BackupSession $BackupSession -Status Error -Text "Creating snapshot `"$Snapshot`" on volume `"$Volume`" failed" }
        exit
    }
} # end function

# This function is used to rename snapshots on secondary system e.g. Snapvault volume.
function Rename-MHONetAppSnapshot($Session, $Volume, $Snapshot, $NewSnapshot) {
    if(get-NcSnapshot -Controller $Session -Volume $Volume -Snapshot $Snapshot -Verbose) {
        Write-MHOLog -Info "Snapshot $Snapshot on $Volume exists and will be renamed..." -Status Info
        try {
            get-NcSnapshot -Controller $Session -Volume $Volume -Snapshot $Snapshot | Rename-NcSnapshot -NewName $NewSnapshot -Verbose
            Write-MHOLog -Info "Snapshot $Snapshot was renamed to $NewSnapshot on volume $Volume" -Status Info
            if($LogToVBR) { $logentry = Add-MHOVbrJobSessionLogEvent -BackupSession $BackupSession -Status Success -Text "Rename existing snapshot `"$Snapshot`" on volume `"$Volume`"" }
        } catch {
            # Error handling if snapshot cannot be removed
            Write-MHOLog -Info "$_" -Status Error
            Write-MHOLog -Info "Snapshot could not be renamed" -Status Error
            if($LogToVBR) { $logentry = Add-MHOVbrJobSessionLogEvent -BackupSession $BackupSession -Status Error -Text "Rename snapshot `"$Snapshot`" on volume `"$Volume`" failed" }
            exit 10
        }
    } 
} # end function

# This function deletes a snapshot 
function Remove-MHONetAppSnapshot($Session, $Volume, $Snapshot) {
    # If an Snapshot with the name exists delete it
    if(get-NcSnapshot -Controller $Session -Volume $Volume -Snapshot $Snapshot -Verbose) {
        Write-MHOLog -Info "Snapshot $Snapshot on volume $Volume exists and will be removed..." -Status Info
        try {
            Remove-NcSnapshot -Controller $Session -Volume $Volume -Snapshot $Snapshot -Verbose -Confirm:$false -ErrorAction Stop
            Write-MHOLog -Info "Snapshot $Snapshot on volume $Volume was removed" -Status Info
            if($LogToVBR) { $logentry = Add-MHOVbrJobSessionLogEvent -BackupSession $BackupSession -Status Success -Text "Deleted snapshot `"$Snapshot`" on volume `"$Volume`"" }
        } catch {
            # Error handling if snapshot cannot be removed
            Write-MHOLog -Info "$_" -Status Error
            Write-MHOLog -Info "Snapshot $Snapshot on volume $Volume could not be removed" -Status Error
            if($LogToVBR) { $logentry = Add-MHOVbrJobSessionLogEvent -BackupSession $BackupSession -Status Error -Text "Deleting snapshot `"$Snapshot`" on volume `"$Volume`" failed" }
            exit
        }
    } else {
        Write-MHOLog -Info "Snapshot named $Snapshot wasn't found" -Status Error
        if($LogToVBR) { $logentry = Add-MHOVbrJobSessionLogEvent -BackupSession $BackupSession -Status Error -Text "Could not find snapshot `"$Snapshot`" on volume `"$Volume`"" }
    }
} # end function

#All list of IP addresses to NetApp Export Policy
function Add-MHOIpListToNetAppExportPolicy ($Session, $ExportPolicy, $IpList) {
    $exportpolicies = Get-NcExportPolicy -Name $ExportPolicy
    if($exportpolicies -eq $null) {
        Write-MHOLog -Info "Export Policy not found SVM" -Status Error
        exit
    }
    $clientaddr = @()
    forEach ($exportpolicy IN $exportpolicies ) {
        ForEach ($ip IN $IpList) {
            $clientaddr += $ip + "/32"
        }
        $exportpolicy | New-NcExportRule -Controller $Session -Index 1 -Protocol "nfs" -ClientMatch $($clientaddr -join ",") -ReadOnlySecurityFlavor any -ReadWriteSecurityFlavor any -SuperUserSecurityFlavor any
        Write-MHOLog -Info "New Export Rule was created." -Status Info
    }
} # end function

# This function transfer snapshot to the destination system and waits until transfer is completed
function Invoke-MHONetAppSync($Session, $SecondarySVM, $SecondaryVolume, $SnapshotName)
{
    #transfer snapshot to the destination system
    try {
        Write-MHOLog -Info "SecondarySVM: $SecondarySVM" -Status Info
        Write-MHOLog -Info "SecondaryVolume: $SecondaryVolume" -Status Info
        Write-MHOLog -Info "Snapshot: $SnapshotName" -Status Info
        Invoke-NcSnapmirrorUpdate -Controller $Session -DestinationVserver $SecondarySVM -DestinationVolume $SecondaryVolume -SourceSnapshot $SnapshotName -Verbose
        if($LogToVBR) { $logentry = Add-MHOVbrJobSessionLogEvent -BackupSession $BackupSession -Status Running -Text "Updating SnapMirror Destination `"$SecondarySVM`:$($SecondaryVolume.name)`"" }
        Write-MHOLog -Info "Waiting for Data Transfer to finish..." -Status Info
        Start-Sleep 10
        # Check every 10 seconds if snapvault relationship is in idle state
        while (get-ncsnapmirror -Controller $Session -DestinationVserver $SecondarySVM -DestinationVolume $SecondaryVolume | ? { $_.Status -ine "idle" } ) {
          Write-MHOLog -Info "Waiting for Data Transfer to finish..." -Status Info
          Start-Sleep -seconds 10
        }
        Write-MHOLog -Info "SV Transfer Finished" -Status Info
        if($LogToVBR) { $logentry = Add-MHOVbrJobSessionLogEvent -BackupSession $BackupSession -Status UpdateSuccess -Text "SnapMirror Destination `"$SecondarySVM`:$($SecondaryVolume.name)`" was updated" -LogNumber $logentry }
        
      } catch {
        Write-MHOLog -Info "$_" -Status Error
        Write-MHOLog -Info "Transfering Snapshot to destination system failed" -Status Error
        if($LogToVBR) { $logentry = Add-MHOVbrJobSessionLogEvent -BackupSession $BackupSession -Status UpdateFailed -Text "SnapMirror Destination `"$SecondarySVM`:$($SecondaryVolume.name)`" failed to update" -LogNumber $logentry }
        exit 11
      }
} # end function

  # This function gets the snapshots from destination and delete all snapshots created by this script and maybe retain X snapshots
  # depending on parameter RetainLastDestinationSnapshots
  function Invoke-MHONetAppSecondaryDestinationCleanUp($Session, $SecondaryVolume, $SnapshotName)
  {
    $SnapshotNameWithDate = $SnapshotName + "_*"
    Write-MHOLog -Info "Starting with cleaning up destination snapshots" -Status Info
    #Checking if it is a vault or mirror
    $MirrorRelationship = Get-NcSnapmirror -Controller $Controller -DestinationVserver $SecondarySVM -DestinationVolume $SecondaryVolume
    if($MirrorRelationship.PolicyType -eq "vault")
    {
      try {
        Write-MHOLog -Info "This is a snapvault relationship. Cleanup needed" -Status Info
        get-NcSnapshot -Controller $Session -Volume $SecondaryVolume -Snapshot $SnapshotNameWithDate | Sort-Object -Property Created -Descending | Select-Object -Skip $RetainLastDestinationSnapshots | Remove-NcSnapshot -Confirm:$false -ErrorAction Stop
        Write-MHOLog -Info "Old Snapshots was cleaned up" -Status Info
        if($LogToVBR) { $logentry = Add-MHOVbrJobSessionLogEvent -BackupSession $BackupSession -Status Success -Text "Removing old snapshots from secondary volume" }

      } catch {
        Write-MHOLog -Info "$_" -Status Error
        Write-MHOLog -Info "Snapshots couldn't be cleaned up at destination volume" -Status Error
      }
    }
    elseif($MirrorRelationship.PolicyType -eq "async_mirror")
    {
      Write-MHOLog -Info "This is a snapmirror relationship. Cleanup not needed" -Status Info
    }
    elseif($MirrorRelationship.PolicyType -eq "mirror_vault")
    {
      Write-MHOLog -Info "This is a mirror and vault relationship. No idea how it works so I do nothing." -Status Warning
    }
   
  }

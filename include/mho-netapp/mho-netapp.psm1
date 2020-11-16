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
   Creation Date:  20 August 2020
   Purpose/Change: Initial Release
   
   .LINK https://github.com/marcohorstmann/powershell
   .LINK https://horstmann.in
 #> 

# This function will load the NetApp Powershell Module.
function Import-MHONetAppOntapModule {
    Write-MHOLog -Status Info -Info "Trying to load NetApp Ontap Powershell Modul ..."
    try {
        Import-Module DataONTAP -ErrorAction Stop
        Write-MHOLog -Info "Trying to load NetApp Ontap Powershell Modul ... SUCCESSFUL" -Status Info
    } catch  {
        Write-MHOLog -Info "$_" -Status Error
        Write-MHOLog -Info "Loading NetApp Powershell module failed" -Status Error
        exit 99
        }
} # end function

# This function is used to connect to a specfix NetApp SVM
function Connect-MHONetAppSVM($SVM, $CredentialFile) {
    Write-MHOLog -Info "Trying to connect to SVM $SVM" -Status Info
    try {
        # Read Credentials from credentials file
        $Credential = Import-CliXml -Path $CredentialFile -ErrorAction Stop
        # Save the session into a variable to return this into the main script 
        $Session = Connect-NcController -name $SVM -Credential $Credential -HTTPS -ErrorAction Stop
        Write-MHOLog -Info "Connection established to $SVM ..." -Status Info
        return $controllersession
    } catch {
        # Error handling if connection fails  
        Write-MHOLog -Info "$_" -Status Error
        Write-MHOLog -Info "Connection to $SVM failed" -Status Error
        exit
    }
}

# Getting NetAppVolume Infos
function Get-MHONetAppVolumeInfo($Session, $Volume) {
    try {
        $volumeObject = Get-NcVol -Controller $Session -name $Volume
        if (!$volumeObject) {
            Write-MHOLog -Info "Volume $Volume was not found" -Status Error
            exit
        }
        Write-MHOLog -Info "Volume $Volume was found" -Status Info
        return $volumeObject
    } catch {
        # Error handling if snapshot cannot be removed
        Write-MHOLog -Info "$_" -Status Error
        Write-MHOLog -Info "Volume $Volume couldn't be located" -Status Error
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
    } catch {
        Write-MHOLog -Info "$_" -Status Error
        Write-MHOLog -Info "Snapshot could not be created" -Status Error
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
        } catch {
            # Error handling if snapshot cannot be removed
            Write-MHOLog -Info "$_" -Status Error
            Write-MHOLog -Info "Snapshot could not be renamed" -Status Error
            exit 1
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
        } catch {
            # Error handling if snapshot cannot be removed
            Write-MHOLog -Info "$_" -Status Error
            Write-MHOLog -Info "Snapshot $Snapshot on volume $Volume could not be removed" -Status Error
            exit
        }
    } else {
        Write-MHOLog -Info "Snapshot named $Snapshot wasn't found" -Status Error
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
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
[CmdletBinding(DefaultParameterSetName="__AllParameterSets")]
Param(
   <#
   [Parameter(Mandatory=$True)]
   [string]$DfsRoot,
   
   [Parameter(Mandatory=$True)]
   [string]$VBRJobName,

   [Parameter(Mandatory=$True)]
   [string]$Owner,

   [Parameter(Mandatory=$True)]
   [int]$ScanDepth, #>
   
   [Parameter(Mandatory=$False)]
   [string]$LogFile="C:\ProgramData\logfile.log"
)
    
    #GLOBAL FUNCTIONS START (section maybe will replaced by newer version)

    # Return a Timestring  timestamp for log
    function Get-TimeStamp
    {    
        return "[{0:dd.MM.yyyy} {0:HH:mm:ss}]" -f (Get-Date)
    } # end function

    # This function is used to log status to console and also the given logfilename.
    # Usage: Write-Log -Status [Info, Status, Warning, Error] -Info "This is the text which will be logged
    function Write-Log($Info, $Status)
    {
        $Info = "$(Get-TimeStamp) $Info" # maybe can this be replaced?
        switch($Status)
        {
            NewLog {Write-Host $Info -ForegroundColor Green  ; $Info | Out-File -FilePath $LogFile}
            Info    {Write-Host $Info -ForegroundColor Green  ; $Info | Out-File -FilePath $LogFile -Append}
            Warning {Write-Host $Info -ForegroundColor Yellow ; $Info | Out-File -FilePath $LogFile -Append}
            Error   {Write-Host $Info -ForegroundColor Red -BackgroundColor White; $Info | Out-File -FilePath $LogFile -Append}
            default {Write-Host $Info -ForegroundColor white $Info | Out-File -FilePath $LogFile -Append}
        }
    } #end function 


    # Function to load Veeam Backup Powershell module
    function Load-VeeamBackupModule {    
        Write-Log -Status Info -Info "Loading Veeam Backup Powershell Module (V11+) ..."
        try {
            import-module Veeam.Backup.PowerShell -ErrorAction Stop
            Write-Log -Info "Loading Veeam Backup Powershell Module (V11+) ... SUCCESSFUL" -Status Info
        } catch  {
            Write-Log -Info "$_" -Status Warning
            Write-Log -Info "Loading Veeam Backup Powershell Module (V11+) ... FAILED" -Status Warning
            Write-Log -Info "This can happen if you are using an Veeam Backup & Replication earlier than V11." -Status Warning
            Write-Log -Info "You can savely ignore this warning." -Status Warning
            try {
                Write-Log -Info "Loading Veeam Backup Powershell Snapin (V10) ..." -Status Info
                Add-PSSnapin VeeamPSSnapin -ErrorAction Stop
                Write-Log -Info "Loading Veeam Backup Powershell Snapin (V10) ... SUCCESSFUL" -Status Info
            } catch  {
                Write-Log -Info "$_" -Status Error
                Write-Log -Info "Loading Veeam Backup Powershell Snapin (V10) ... FAILED" -Status Error
                Write-Log -Info "Was not able to load Veeam Backup Powershell Snapin (V10) or Module (V11)" -Status Error
                exit 99
            }
        }
    } #end function

    # NETAPP Modules

    # This function will load the NetApp Powershell Module.
    function Load-NetAppOntapModule {
        Write-Log -Status Info -Info "Trying to load NetApp Ontap Powershell Modul ..."
        try {
            Import-Module DataONTAP
            Write-Log -Info "Trying to load NetApp Ontap Powershell Modul ... SUCCESSFUL" -Status Info
        } catch  {
            Write-Log -Info "$_" -Status Error
            Write-Log -Info "Loading NetApp Powershell module failed" -Status Error
            exit 99
        }
    } # end function

    # This function is used to connect to a specfix NetApp SVM
    function Connect-NetAppSVM($SVM, $CredentialFile)
    {
        Write-Log -Info "Trying to connect to SVM $SVM" -Status Info
        try {
            # Read Credentials from credentials file
            $Credential = Import-CliXml -Path $CredentialFile -ErrorAction Stop
            # Save the session into a variable to return this into the main script 
            $Session = Connect-NcController -name $SVM -Credential $Credential -HTTPS -ErrorAction Stop
            Write-Log -Info "Connection established to $SVM ..." -Status Info
        } catch {
            # Error handling if connection fails  
            Write-Log -Info "$_" -Status Error
            Write-Log -Info "Connection to $SVM failed" -Status Error
            exit
        }
        return $controllersession
    }

    # Getting NetAppVolume Infos
    function Get-NetAppVolumeInfo($Session, $Volume)
    {
        try {
            $volumeObject = Get-NcVol -Controller $Session -name $Volume
            if (!$volumeObject) {
                Write-Log -Info "Volume $Volume was not found" -Status Error
                exit
            }
            Write-Log -Info "Volume $Volume was found" -Status Info
            return $volumeObject
        } catch {
            # Error handling if snapshot cannot be removed
            Write-Log -Info "$_" -Status Error
            Write-Log -Info "Volume $Volume couldn't be located" -Status Error
            exit 40
        }
    }

    # Function to get all shares of a SVM
    function Get-NetAppSVMShares($Session) {
        try {
            $sharesObject = get-nccifsshare -Controller $Session | Where-Object {$_.Path.Length -gt "1"}
            if (!$sharesObject) {
                Write-Log -Info "SVM $Session has no shares" -Status Error
                exit 40
            }
            Write-Log -Info "Shares was found on $SVM" -Status Info
            return $sharesObject
        } catch {
            Write-Log -Info "$_" -Status Error
            exit 40
        }
    }



    # This function creates a snapshot on source system
    function Create-NetAppSnapshot($Session, $Volume, $Snapshot) {
        Write-Log -Info "Snapshot $Snapshot on $Volume will be created..." -Status Info
        try {
            New-NcSnapshot -Controller $Session -Volume $Volume -Snapshot $Snapshot -Verbose
            Write-Log -Info "Snapshot was created" -Status Info
        } catch {
            Write-Log -Info "$_" -Status Error
            Write-Log -Info "Snapshot could not be created" -Status Error
            exit
        }
    }

    # This function is used to rename snapshots on secondary system e.g. Snapvault volume.
    function Rename-NetAppSnapshot($Session, $Volume, $Snapshot, $NewSnapshot) {
        if(get-NcSnapshot -Controller $Session -Volume $Volume -Snapshot $Snapshot -Verbose) {
            Write-Log -Info "Snapshot $Snapshot on $Volume exists and will be renamed..." -Status Info
            try {
                get-NcSnapshot -Controller $Session -Volume $Volume -Snapshot $Snapshot | Rename-NcSnapshot -NewName $NewSnapshot -Verbose
                Write-Log -Info "Snapshot $Snapshot was renamed to $NewSnapshot on volume $Volume" -Status Info
            } catch {
                # Error handling if snapshot cannot be removed
                Write-Log -Info "$_" -Status Error
                Write-Log -Info "Snapshot could not be renamed" -Status Error
                exit 1
            }
        } 
    }

    # This function deletes a snapshot 
    function Remove-NetAppSnapshot($Session, $Volume, $Snapshot) {
        # If an Snapshot with the name exists delete it
        if(get-NcSnapshot -Controller $Session -Volume $Volume -Snapshot $Snapshot -Verbose) {
            Write-Log -Info "Snapshot $Snapshot on volume $Volume exists and will be removed..." -Status Info
            try {
                Remove-NcSnapshot -Controller $Session -Volume $Volume -Snapshot $Snapshot -Verbose -Confirm:$false -ErrorAction Stop
                Write-Log -Info "Snapshot $Snapshot on volume $Volume was removed" -Status Info
            } catch {
                # Error handling if snapshot cannot be removed
                Write-Log -Info "$_" -Status Error
                Write-Log -Info "Snapshot $Snapshot on volume $Volume could not be removed" -Status Error
                exit
            }
        } else {
            Write-Log -Info "Snapshot named $Snapshot wasn't found" -Status Error
        }
    }

    # Check if DFS Management Module is installed 
    function Install-DfsManagementModule {
        Write-Log -Status Info -Info "Checking if DFS Management Tools are installed ..."
        if(get-windowsFeature -Name "RSAT-DFS-Mgmt-Con" | Where-Object -Property "InstallState" -EQ "Installed") {
            Write-Log -Status Info -Info "DFS Management Tools are already installed ..."
        } else {
            Write-Log -Status Status -Info "DFS Management Tools are not installed ... INSTALLING"
            try {
                Install-WindowsFeature -Name "RSAT-DFS-Mgmt-Con" -Confirm:$false
                Write-Log -Info "DFS Management Tools was installed... SUCCESSFUL" -Status Info
            } catch  {
                Write-Log -Info "$_" -Status Error
                Write-Log -Info "DFS Management Tools installation... FAILED" -Status Error
                exit 99
            }
        }
    }

    # Check if AD Management Tools are installed
    function Install-AdManagementModule {
        Write-Log -Status Info -Info "Checking if Active Directory Powershell modules are installed ..."
        if(get-windowsFeature -Name "RSAT-AD-PowerShell" | Where-Object -Property "InstallState" -EQ "Installed") {
            Write-Log -Status Info -Info "Active Directory Powershell modules are already installed... SKIPPED"
        } else {
            Write-Log -Status Info -Info "Active Directory Powershell modules are not installed... INSTALLING..."
            try {
                Install-WindowsFeature -Name "RSAT-AD-PowerShell" –IncludeAllSubFeature -Confirm:$false
                Write-Log -Info "Active Directory Powershell modules was installed... DONE" -Status Info
            } catch  {
                Write-Log -Info "$_" -Status Error
                Write-Log -Info "Active Directory Powershell modules installation... FAILED" -Status Error
                exit 99
            }
        }
    }


    # Function to validate, if a user exists
    function Validate-ADCredentials ($Username) {
        Write-Log -Info "Validating User $Username ..." -Status Info
        $UsernameDetails = $Username.Split('\\').Split("@")
        
        # Put the right stuff into the variable by determing which notation was used:
        # DOMAIN\user or user@domain.int
        if($Username -like "*\*")
        {
            $ADDomain = $UsernameDetails[0].ToString()
            $ADUser = $UsernameDetails[1].ToString()
        } elseif($Owner -like "*@*") {
            $ADDomain = $UsernameDetails[1].ToString()
            $ADUser = $UsernameDetails[0].ToString()
        } else {
            Write-Log -Info "$_" -Status Error
            Write-Log -Info "Validating User $Username ... FAILED" -Status Error
            return $False
        } # end function
        <#  function usage example
            if(!( Validate-ADCredentials -Username "HOMELAB\Administrator" )) {
                # What should happen if username can not be validated
                exit 99
            } #>

        # Check if domain name is valid
        try {
            $Null = Get-ADDomain -Identity $ADDomain
            Write-Log -Info "Validating Domain ... SUCCESSFUL" -Status Info
            if((Get-ADUser -Filter {sAMAccountName -eq $ADUser}) -eq $Null)
                {
                Write-Log -Info "Validating Username ... FAILED" -Status Error
                return $False
            } else {
                Write-Log -Info "Validating Username ... SUCCESSFUL" -Status Info
                return $true
            }
        } catch {
            Write-Log -Info "$_" -Status Error
            Write-Log -Info "Validating Domain ... FAILED" -Status Error
            return $False
        }
    }

    # Get all shares of a give system via Net view
    function Get-SharesViaNetView {
        Param(
            [Parameter(Mandatory=$True)]
            [string]$Server,

            [Parameter(Mandatory=$False)]
            [string[]]$Exclude
        )
        Write-Log -Status Info -Info "Trying to get list of shares for $Server ..."
        try {
            [System.Collections.ArrayList]$allshares = net view \\$($Server) /all | select -Skip 7 | ?{$_ -match 'disk*'} | %{$_ -match '^(.+?)\s+Disk*'|out-null;$matches[1]}
            # Check if the $allshares is empty
            if(!$allshares) {
                Write-Log -Info "Failed to get shares" -Status Error
                exit 99
            }
            Write-Log -Info "File shares ... FOUND" -Status Info
            ForEach($excludedElement in $Exclude) {
                $allshares.Remove($excludedElement)
            }
        } catch  {
            Write-Log -Info "$_" -Status Error
            Write-Log -Info "Failed to load file shares" -Status Error
            exit 99
        }
        <#
            # Maybe include optional exclude function
            # For each detected shares check if it is excluded
            [string[]]$ExcludeShares=@("c$","ADMIN$","SYSVOL","NETLOGON"),
            ForEach($share in $allshares) {    
                $isexcluded = $false
                $ExcludeShares = $ExcludeShares
                ForEach ($ExcludeShare in $ExcludeShares) {
                if ($share -ilike $ExcludeShare) {
                    $isexcluded = $true
                }
            }
        #>


        return $allshares
    } #end function


    # NETAPP AND VEEAM Modules

    #Module to create a export policy for Veeam File Proxies
    function Add-VeeamProxyToNetAppExportPolicy ($Session, $SVM, $ExportPolicy) {
        $exportpolicies = Get-NcExportPolicy -Vserver $SVM -Name $ExportPolicy
        $nasproxies = get-vbrnasproxyserver
        $clientaddr = @()
        forEach ($exportpolicy IN $exportpolicies ) {
            ForEach ($nasproxy IN $nasproxies) {
                $ip = Resolve-DnsName -Name $($nasproxy.Server.Name) -Type A
                Write-Host "NAS Proxy: $($nasproxy.Server.Name) with IPv4: $($ip.IPAddress)"
                $clientaddr += $ip.IPAddress + "/32"
            }
            $exportpolicy | New-NcExportRule -Controller $Session -Index 1 -Protocol "nfs" -ClientMatch $($clientaddr -join ",") -ReadOnlySecurityFlavor any -ReadWriteSecurityFlavor any -SuperUserSecurityFlavor any
        }
    } # end function


    # GOBAL FUNCTIONS END (section maybe will replaced by newer version)

    # SCRIPT FUNCTIONS START

    # SCRIPT FUNCTIONS END

    # VALIDATE VARIABLES START 

    <#
    # Validate parameters: VBRJobName
    Write-Log -Status Info -Info "Validating VBR Job Name ..."
    $nasBackupJob = Get-VBRNASBackupJob -name $VBRJobName
    if($nasBackupJob -eq $null) {
        Write-Log -Info "Validating VBR Job Name ... FAILED" -Status Error
        exit 99
    } else { 
        Write-Log -Info "Validating VBR Job Name ... SUCCESSS" -Status Info
    }#>

    # VALIDATE VARIABLES END

    # MAIN CODE START
    
    # Clear the log file
    Write-Log -Status NewLog -Info "Starting new log file"

    Load-VeeamBackupModule
    Load-NetAppOntapModule
    Install-AdManagementModule
    Install-DfsManagementModule
    if(!( Validate-ADCredentials -Username "HOMELAB\Administrator" )) {
        # What should happen if username can not be validated
        exit 99
    }
    $NetAppNfsSession = Connect-NetAppSVM -SVM "lab-nanfs01" -CredentialFile "C:\scripts\credential.xml"
    #$volume = Get-NetAppVolumeInfo -Session $NetAppSession -Volume "unixfiles"

    Create-NetAppSnapshot -Session $NetAppNfsSession -Volume "unixfiles" -Snapshot "VeeamNASBackup"
    Rename-NetAppSnapshot  -Session $NetAppNfsSession -Volume "unixfiles" -Snapshot "VeeamNASBackup" -NewSnapshot "VeeamNASBackupTest"
    Remove-NetAppSnapshot -Session $NetAppNfsSession -Volume "unixfiles" -Snapshot "VeeamNASBackupTest"
    
    $NetAppCifsSession = Connect-NetAppSVM -SVM "lab-nacifs01" -CredentialFile "C:\scripts\credential.xml"
    #$shares = Get-NetAppSVMShares -Session $NetAppCifsSession
    $sharesNetView = Get-SharesViaNetView -Server lab-dc01 # -Exclude "C$","ADMIN$","SYSVOL","NETLOGON"
    $sharesNetView
    # MAIN CODE END
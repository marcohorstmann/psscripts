function Import-MHOVeeamBackupModule {
<#
    .SYNOPSIS
        This function is used to load the Veeam Backup & Replication Modules
    .DESCRIPTION
        This function tries to load the Veeam Powershell Cmdlets. If this fails
        it will stop the script execution.
    .INPUTS
        None

    .OUTPUTS
        None

    .EXAMPLE
        Import-MHOVeeamBackupModule

    .NOTES 
        Version:        2.0
        Author:         Marco Horstmann (marco.horstmann@veeam.com)
        Creation Date:  25 Januar 2021
        Purpose/Change: Initial Release
    .LINK
        Online Version: https://github.com/marcohorstmann/psscripts
#>
    Write-MHOLog -Status Info -Info "Loading Veeam Backup Powershell Module (V11+) ..."
        try {
            import-module Veeam.Backup.PowerShell -ErrorAction Stop -DisableNameChecking
            Write-MHOLog -Info "Loading Veeam Backup Powershell Module (V11+) ... SUCCESSFUL" -Status Info
        } catch  {
            Write-MHOLog -Info "$_" -Status Warning
            Write-MHOLog -Info "Loading Veeam Backup Powershell Module (V11+) ... FAILED" -Status Warning
            Write-MHOLog -Info "This can happen if you are using an Veeam Backup & Replication earlier than V11." -Status Warning
            Write-MHOLog -Info "You can savely ignore this warning." -Status Warning
            try {
                Write-MHOLog -Info "Loading Veeam Backup Powershell Snapin (V10) ..." -Status Info
                Add-PSSnapin VeeamPSSnapin -ErrorAction Stop
                Write-MHOLog -Info "Loading Veeam Backup Powershell Snapin (V10) ... SUCCESSFUL" -Status Info
            } catch  {
                Write-MHOLog -Info "$_" -Status Error
                Write-MHOLog -Info "Loading Veeam Backup Powershell Snapin (V10) ... FAILED" -Status Error
                Write-MHOLog -Info "Was not able to load Veeam Backup Powershell Snapin (V10) or Module (V11)" -Status Error
                exit
            }
    }
} #end function


function Get-MHOVeeamProxyIp ($Session) {
<#
    .SYNOPSIS
        This function get an IP address list for all Veeam File Proxies
    .INPUTS
        None

    .OUTPUTS
        An string array with ip addresses

    .EXAMPLE
        $proxyIpList = Get-MHOVeeamProxyIp

    .NOTES 
        Version:        2.0
        Author:         Marco Horstmann (marco.horstmann@veeam.com)
        Creation Date:  25 Januar 2021
        Purpose/Change: Initial Release
    .LINK
        Online Version: https://github.com/marcohorstmann/psscripts
#>
    # Get all registered file proxies in VBR
    $nasProxies = get-vbrnasproxyserver
    # Check if a file proxy server is registered
    if($nasProxies.count -gt 0) {
        # Create an empty array for the ip addresses
        $nasProxiesByIp = @()
        # For every file proxy which is in the database to:
        ForEach ($nasProxy IN $nasProxies) {
            # If the name of the object includes a letter it is properbly a DNS name
            if($nasProxy.Server.Name -match “[a-z]”) {
                # Resolve the name to an ip address
                $ip = Resolve-DnsName -Name $($nasProxy.Server.Name) -Type A
                Write-MHOLog -Status Info -Info "Discoverd NAS Proxy: $($nasproxy.Server.Name) with IPv4: $($ip.IPAddress)"
                $nasProxiesByIp += $ip.IPAddress
            } else {
                Write-MHOLog -Status Info -Info "Discoverd NAS Proxy: $($nasproxy.Server.Name) without DNS hostname"
                $nasProxiesByIp += $nasproxy.Server.Name
            }
        }
        # Return an array of ip adresses
        return $nasProxiesByIp
    } else {
        Write-MHOLog -Status Error -Info "No File Proxy servers discovered"
        return $null
    }
} # end function Get-MHOVeeamProxyIp


function Get-MHOVBRAgentPolicyBackupsSize {
    <#
    .SYNOPSIS
        This function gets the backup file sizes of given Agent Policy
    .DESCRIPTION
        If you need to know how much backup space every Agent Policy needs,
        you can request this information

    .INPUTS
        None

    .OUTPUTS
        None

    .EXAMPLE
        $result = Get-MHOVBRAgentPolicyBackupsSize
        
        Get all Agent Polices and all backup file sizes that exists

    .EXAMPLE
        $date = (Get-Date).AddMonths(-1)
        $result = Get-MHOVBRAgentPolicyBackupsSize -Name "L" -SinceDate $date
        
        Get all Agent Policies starting with L* and size of all backup files
        created in the last month

    .NOTES 
        Version:        2.0
        Author:         Marco Horstmann (marco.horstmann@veeam.com)
        Creation Date:  25 Januar 2021
        Purpose/Change: Initial Release
    .LINK
        Online Version: https://github.com/marcohorstmann/psscripts
    #>
    ### IDEAS: Extend this to show it on per Agent base
    param(
    # Filter the agent policies by name, e.g. L* for all policies starting with L
    [Parameter(Mandatory=$False)]
    [string]$Name="*",

    # Filter the found backup files for an specific age, e.g. an month
    [Parameter(Mandatory=$False)]
    [DateTime]$SinceDate
    )
    
    $agentBackupsResult = @()
    $agentBackups = Get-VBRBackup -Name $Name | Where-Object { (($_.JobType -match "EpAgentPolicy")) }

    foreach($agentBackup in $agentBackups) {
        if($SinceDate -eq $null) {
            $files = $agentBackup.GetAllChildrenStorages()
            #Write-Host "DEBUG: ist leer"
        } else {
            $files = $agentBackup.GetAllChildrenStorages() | ?{($_.CreationTime -ge $SinceDate) }
            #Write-Host "DEBUG: ist gesetzt"
        }
        $backupSize = 0

        foreach($file in $files) {
            $backupSize += [math]::Round([long]$file.Stats.BackupSize/1GB, 2)
        }

        $Backupsize = [PSCustomObject] @{
            Name = $agentBackup.JobName
            "Backup Size (GB)" = $backupSize
        }
        $agentBackupsResult += $backupSize
    }
    return $agentBackupsResult
} # end function

function Get-MHOVbrJobNameFromPID {
    $parentPid = (Get-WmiObject Win32_Process -Filter "processid='$pid'").parentprocessid.ToString()
    $parentCmd = (Get-WmiObject Win32_Process -Filter "processid='$parentPid'").CommandLine
    $cmdArgs = $parentCmd.Replace('" "','","').Replace('"','').Split(',')
    $jobName = (Get-VBRJob | ? {$cmdArgs[4] -eq $_.Id.ToString()}).Name
    return $jobName
}

function Get-MHOVbrJobSessionFromPID {
    $parentPid = (Get-WmiObject Win32_Process -Filter "processid='$pid'").parentprocessid.ToString()
    $parentCmd = (Get-WmiObject Win32_Process -Filter "processid='$parentPid'").CommandLine
    $cmdArgs = $parentCmd.Replace('" "','","').Replace('"','').Split(',')
    
    $jobSession = (Get-VBRJob | ? {$cmdArgs[4] -eq $_.Id.ToString()}).FindLastSession()

    return $jobSession
}


function Add-MHOVbrJobSessionLogEvent {
    param(
    [Parameter(Mandatory=$True)]
    [string]$Text,
    
    [Parameter(Mandatory=$False)]
    $LogNumber,
    
    [Parameter(Mandatory=$True)]
    $BackupSession,

    [ValidateSet("Running",”Success”,"Warning”,”Error”,"UpdateSuccess", "UpdateFailed", "UpdateWarning")]
    [Parameter(Mandatory=$True)]
    [string]$Status
    )

    switch($Status)
    {
        Running        { $logevent = $BackupSession.Logger.AddLog($Text) }
        Success        { $logevent = $BackupSession.Logger.AddSuccess($Text) }
        Warning        { $logevent = $BackupSession.Logger.AddWarning($Text) }
        Error          { $logevent = $BackupSession.Logger.AddErr($Text) }
        UpdateSuccess  { $logevent = $BackupSession.Logger.UpdateLog($LogNumber, "ESucceeded", $Text, "") }
        UpdateFailed   { $logevent = $BackupSession.Logger.UpdateLog($LogNumber, "EFailed", $Text, "") }
        UpdateWarning  { $logevent = $BackupSession.Logger.UpdateLog($LogNumber, "EWarning", $Text, "") }
        default { }
    }

    # Add new "Play" Log entry which starts to run with a counter
    #$logevent = $backupSession.Logger.AddLog("Test Log")
    # Add new Error Log Entry
    #$logevent = $backupsessions.Logger.AddErr("Test Job Error")
    # Add new Success Log Entry
    #$logevent = $BackupSession.Logger.AddSuccess($Text)
    #Add new Warning Log Entry
    #$logevent = $backupsessions.Logger.AddWarning("Test Job Warning")
    #Delete a Log Event based on the Log entry no
    #$backupsessions.Logger.RemoveRecord($logevent)

    # Change Log entry to 
    #$backupsessions.Logger.UpdateLog($logevent, "ESucceeded", "Abgeschlossen", "Beschreibung")
    #$backupsessions.Logger.UpdateLog($logevent, "EFailed", "Fehlgeschlagen", "Beschreibung")
    return $logevent
}
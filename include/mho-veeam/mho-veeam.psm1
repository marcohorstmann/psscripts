<# 
   .SYNOPSIS
   Loading Veeam Modules with error handling
   .DESCRIPTION
   Loading Veeam Modules needs to be done with error handling because
   e.g. the loding of Modules was changed between V10 and V11.

   .Example
   Load the Veeam Backup Powershell Module or the Snapins

   Import-MHOVeeamBackupModule


   .Notes 
   Version:        1.0
   Author:         Marco Horstmann (marco.horstmann@veeam.com)
   Creation Date:  12 November 2020
   Purpose/Change: Initial Release
   
   .LINK https://github.com/marcohorstmann/psscripts
   .LINK https://horstmann.in
 #> 

# Function to load Veeam Backup Powershell module
function Import-MHOVeeamBackupModule {    
    Write-MHOLog -Status Info -Info "Loading Veeam Backup Powershell Module (V11+) ..."
        try {
            import-module Veeam.Backup.PowerShell -ErrorAction Stop
            Write-MHOLog -Info "Loading Veeam Backup Powershell Module (V11+) ... SUCCESSFUL" -Status Info
            return $true
        } catch  {
            Write-MHOLog -Info "$_" -Status Warning
            Write-MHOLog -Info "Loading Veeam Backup Powershell Module (V11+) ... FAILED" -Status Warning
            Write-MHOLog -Info "This can happen if you are using an Veeam Backup & Replication earlier than V11." -Status Warning
            Write-MHOLog -Info "You can savely ignore this warning." -Status Warning
            try {
                Write-MHOLog -Info "Loading Veeam Backup Powershell Snapin (V10) ..." -Status Info
                Add-PSSnapin VeeamPSSnapin -ErrorAction Stop
                Write-MHOLog -Info "Loading Veeam Backup Powershell Snapin (V10) ... SUCCESSFUL" -Status Info
                return $true
            } catch  {
                Write-MHOLog -Info "$_" -Status Error
                Write-MHOLog -Info "Loading Veeam Backup Powershell Snapin (V10) ... FAILED" -Status Error
                Write-MHOLog -Info "Was not able to load Veeam Backup Powershell Snapin (V10) or Module (V11)" -Status Error
                return $false
            }
    }
} #end function



#Module to create a export policy for Veeam File Proxies
function Get-MHOVeeamProxyIp ($Session) {
    $nasProxies = get-vbrnasproxyserver
    $nasProxiesByIp = @()
    ForEach ($nasProxy IN $nasProxies) {
        if($nasProxy.Server.Name -match “[a-z]”) {
            $ip = Resolve-DnsName -Name $($nasProxy.Server.Name) -Type A
            Write-MHOLog -Status Info -Info "Discoverd NAS Proxy: $($nasproxy.Server.Name) with IPv4: $($ip.IPAddress)"
                $nasProxiesByIp += $ip.IPAddress
        } else {
            Write-MHOLog -Status Info -Info "Discoverd NAS Proxy: $($nasproxy.Server.Name) without DNS hostname"
            $nasProxiesByIp += $nasproxy.Server.Name
        }
    }
    return $nasProxiesByIp
} # end function


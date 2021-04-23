function Import-MHODfsManagementModule {
<#
    .SYNOPSIS
        This function checks or loads the DFS Management Components
    .DESCRIPTION
        This function is used to load the DFS modules. Because they are
        not installed by default this function will install the modules.
    .INPUTS
        None

    .OUTPUTS
        None

    .EXAMPLE
        Import-MHODfsManagementModule
    
    .NOTES 
        Version:        2.0
        Author:         Marco Horstmann (marco.horstmann@veeam.com)
        Creation Date:  25 Januar 2021
        Purpose/Change: Initial Release
    .LINK
        Online Version: https://github.com/marcohorstmann/psscripts
#>

    Write-MHOLog -Status Info -Info "Checking if DFS Management Tools are installed ..."
    if(get-windowsFeature -Name "RSAT-DFS-Mgmt-Con" | Where-Object -Property "InstallState" -EQ "Installed") {
        Write-MHOLog -Status Info -Info "DFS Management Tools are already installed ..."
    } else {
        Write-MHOLog -Status Info -Info "DFS Management Tools are not installed ... INSTALLING"
        try {
            Install-WindowsFeature -Name "RSAT-DFS-Mgmt-Con" -Confirm:$false
            Write-MHOLog -Info "DFS Management Tools was installed... SUCCESSFUL" -Status Info
        } catch  {
            Write-MHOLog -Info "$_" -Status Error
            Write-MHOLog -Info "DFS Management Tools installation... FAILED" -Status Error
            exit
        }
    }
} # end function


function Import-MHOADManagementModule {
<#
    .SYNOPSIS
        This function checks or loads the AD Management Tools
    .DESCRIPTION
        This function is used to load the AD Management Tools. Because they are
        not installed by default this function will install the AD Management Tools.
    .INPUTS
        None

    .OUTPUTS
        None

    .EXAMPLE
        Import-MHODfsManagementModule
    
    .NOTES 
        Version:        2.0
        Author:         Marco Horstmann (marco.horstmann@veeam.com)
        Creation Date:  25 Januar 2021
        Purpose/Change: Initial Release
    .LINK
        Online Version: https://github.com/marcohorstmann/psscripts
#>
    Write-MHOLog -Status Info -Info "Checking if Active Directory Powershell modules are installed ..."
    if(get-windowsFeature -Name "RSAT-AD-PowerShell" | Where-Object -Property "InstallState" -EQ "Installed") {
        Write-MHOLog -Status Info -Info "Active Directory Powershell modules are already installed... SKIPPED"
    } else {
        Write-MHOLog -Status Info -Info "Active Directory Powershell modules are not installed... INSTALLING..."
        try {
            Install-WindowsFeature -Name "RSAT-AD-PowerShell" –IncludeAllSubFeature -Confirm:$false
            Write-MHOLog -Info "Active Directory Powershell modules was installed... DONE" -Status Info
        } catch  {
            Write-MHOLog -Info "$_" -Status Error
            Write-MHOLog -Info "Active Directory Powershell modules installation... FAILED" -Status Error
            exit 99
        }
    }
} # end function


function Find-MHOADCredentials {
<#
    .SYNOPSIS
        This function validates if an Active Directory user exists
    .DESCRIPTION
        This function is used to check if an user exists in active directory.
    .INPUTS
        None

    .OUTPUTS
        returns true or false

    .EXAMPLE
        if(!( Find-MHOADCredentials -Username "HOMELAB\Administrator" )) {
            # What should happen if username can not be validated
            exit 99
        }
    
    .NOTES 
        Version:        2.0
        Author:         Marco Horstmann (marco.horstmann@veeam.com)
        Creation Date:  25 Januar 2021
        Purpose/Change: Initial Release
    .LINK
        Online Version: https://github.com/marcohorstmann/psscripts
#>
    param(
        [Parameter(Mandatory=$True)]
        [string]$Username
    )
    Write-MHOLog -Info "Validating User $Username ..." -Status Info
    $UsernameDetails = $Username.Split('\\').Split("@")    
    # Put the right stuff into the variable by determing which notation was used:
    # DOMAIN\user or user@domain.int
    if($Username -like "*\*") {
        $ADDomain = $UsernameDetails[0].ToString()
        $ADUser = $UsernameDetails[1].ToString()
    } elseif($Owner -like "*@*") {
        $ADDomain = $UsernameDetails[1].ToString()
        $ADUser = $UsernameDetails[0].ToString()
    } else {
        Write-MHOLog -Info "$_" -Status Error
        Write-MHOLog -Info "Validating User $Username ... FAILED" -Status Error
        return $False
    } 
    # Check if domain name is valid
    try {
        $Null = Get-ADDomain -Identity $ADDomain
        Write-MHOLog -Info "Validating Domain ... SUCCESSFUL" -Status Info
        if((Get-ADUser -Filter {sAMAccountName -eq $ADUser}) -eq $Null)
        {
            Write-MHOLog -Info "Validating Username ... FAILED" -Status Error
            return $False
        } else {
            Write-MHOLog -Info "Validating Username ... SUCCESSFUL" -Status Info
            return $true
        }
    } catch {
        Write-MHOLog -Info "$_" -Status Error
        Write-MHOLog -Info "Validating Domain ... FAILED" -Status Error
        return $False
    }
} # end function


function Get-MHOSmbShares {
<#
    .SYNOPSIS
        Get all shares of a give system via Net view
    .DESCRIPTION
        Get all shares of a give system via Net view
    .INPUTS
        None

    .OUTPUTS
        return string array of shares

    .EXAMPLE
        Get-MHOSmbShares -Server lab-dc01
    .EXAMPLE
        Get-MHOSmbShares -Server lab-dc01 -Exclude "C$","ADMIN$","SYSVOL","NETLOGON"
        Get all shares of this server and exclude several shares

    .NOTES 
        Version:        2.0
        Author:         Marco Horstmann (marco.horstmann@veeam.com)
        Creation Date:  25 Januar 2021
        Purpose/Change: Initial Release
    .LINK
        Online Version: https://github.com/marcohorstmann/psscripts
#>
    Param(
        [Parameter(Mandatory=$True)]
        [string]$Server,

        [Parameter(Mandatory=$False)]
        [string[]]$Exclude
    )
    Write-MHOLog -Status Info -Info "Trying to get list of shares for $Server ..."
    try {
        [System.Collections.ArrayList]$allshares = net view \\$($Server) /all | select -Skip 7 | ?{$_ -match 'disk*'} | %{$_ -match '^(.+?)\s+Disk*'|out-null;$matches[1]}
        # Check if the $allshares is empty
        if(!$allshares) {
            Write-MHOLog -Info "Failed to get shares" -Status Error
            exit
        }
        Write-MHOLog -Info "File shares ... FOUND" -Status Info
        ForEach($excludedElement in $Exclude) {
            $allshares.Remove($excludedElement)
        }
    } catch  {
        Write-MHOLog -Info "$_" -Status Error
        Write-MHOLog -Info "Failed to load file shares" -Status Error
            exit
    }
    return $allshares
} #end function


function Get-MHODfsFolder {
<#
    .SYNOPSIS
        This function will scan a folder for subfolders and if it finds a reparse point it returns the reparsepoints as object array.
    .DESCRIPTION
        This function will scan a folder for subfolders and if it finds a reparse point it returns the reparsepoints as object array.
    .INPUTS
        None

    .OUTPUTS
        return string array of folder path

    .EXAMPLE
        PS G:\psscripts\playground> Get-MHODfsFolder -path "\\homelab\dfs" -currentdepth 0 -maxdepth 2
            \\homelab\dfs\Field\marketing
            \\homelab\dfs\Field\sales
            \\homelab\dfs\Orga\IT
    
    .NOTES 
        Version:        2.0
        Author:         Marco Horstmann (marco.horstmann@veeam.com)
        Creation Date:  25 Januar 2021
        Purpose/Change: Initial Release
    .LINK
        Online Version: https://github.com/marcohorstmann/psscripts
#>
    param(
    # This parameter is the dfs path to scan in UNC format e.g. \\domain\dfsroot
    [Parameter(Mandatory=$True)]
    [string]$path,

    # This parameter is used to tell the script at which level the script currently is searching for reparse points
    [Parameter(Mandatory=$True)]
    [int]$currentdepth,
    
    # This parameter is used to tel the script at which level it should stop to search for reparse points
    [Parameter(Mandatory=$True)]
    [int]$maxdepth
    )
    #Increment the currentdepth parameter to end nesting of this fuction within itself.
    $currentdepth++
    #create a folderarray which is used locally for each call of this function (works even in function call in a function call)
    $folderarray = @()
    #Gets all folders of the given path  and for each object it checks its attributes for reparse points. If one folder is also a reparse point it will added to the folderarray
    Get-ChildItem -Path $path -Directory | ForEach-Object {
        if($_.Attributes -like "*ReparsePoint*") {
            $folderarray += $_.FullName
            Write-MHOLog "Found Reparse Point $_ ... ADD TO REPARSE POINT LIST" -Status Info
        }
        # e.g. If the currentdepth 2 is less or equal to maxdepth e.g. 3 it will make a nested function call for the current folder
        if($currentdepth -le $maxdepth) {
            # Because a reparse Point below Reparse Point in DFS is not possible. If folder is a reparse point
            # we do not need to dive deeper because we will not found anymore in this folder.
            if(!($_.Attributes -like "*ReparsePoint*")) {
                $folderarray += Get-MHODfsFolder -path $_.FullName -currentdepth $currentdepth -maxdepth $maxdepth
            }
        }
    }
    return $folderarray
} #end function

#region Function Get-MHOReparsePointDetails
function Get-MHOReparsePointDetails {
<#
    .SYNOPSIS
        This function will get the details of every reparse point provided e.g. from Get-MHODfsFolder and return all ReparsePointDetails
    .DESCRIPTION
        This function will get the details of every reparse point provided e.g. from Get-MHODfsFolder and return all ReparsePointDetails
    .INPUTS
        None

    .OUTPUTS
        return array of dfs targets

    .EXAMPLE
        $dfsfolder = Get-MHODfsFolder -path "\\homelab\dfs" -currentdepth 0 -maxdepth 2
        $reparsepointDetails = Get-MHOReparsePointDetails -reparsepoints $dfsfolder
    
    .NOTES 
        Version:        2.1
        Author:         Marco Horstmann (marco.horstmann@veeam.com)
        Creation Date:  3 February 2021
        Purpose/Change: Get pipeline stuff working.
    .LINK
        Online Version: https://github.com/marcohorstmann/psscripts
#>
    [CmdletBinding()]
    param(
        # This parameter is an array with UNC paths to check
        [Parameter(Mandatory=$True, ValueFromPipeline = $true)]
        [String[]]$reparsepoints
    )
    # Needs to be done in this way otherwise pipelines wouldn't work.
    BEGIN {
        #Create the share
        $sharearray = @()
    }
    PROCESS {
        #For every Reparse Point return the details
        Foreach ($reparsepoint IN $reparsepoints) {
            $sharearray  += Get-DfsnFolderTarget $reparsepoint
        }
    }
    END {
        #Return all reparse point details
        return $sharearray
    }
}
#endregion Get-MHOReparsePointDetails
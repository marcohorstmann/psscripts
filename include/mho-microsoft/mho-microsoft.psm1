
# Check if DFS Management Module is installed 
function Import-MHODfsManagementModule {
    Write-MHOLog -Status Info -Info "Checking if DFS Management Tools are installed ..."
    if(get-windowsFeature -Name "RSAT-DFS-Mgmt-Con" | Where-Object -Property "InstallState" -EQ "Installed") {
        Write-MHOLog -Status Info -Info "DFS Management Tools are already installed ..."
    } else {
        Write-MHOLog -Status Status -Info "DFS Management Tools are not installed ... INSTALLING"
        try {
            Install-WindowsFeature -Name "RSAT-DFS-Mgmt-Con" -Confirm:$false
            Write-MHOLog -Info "DFS Management Tools was installed... SUCCESSFUL" -Status Info
        } catch  {
            Write-MHOLog -Info "$_" -Status Error
            Write-MHOLog -Info "DFS Management Tools installation... FAILED" -Status Error
            exit 99
        }
    }
} # end function

# Check if AD Management Tools are installed
function Import-MHOADManagementModule {
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


# Function to validate, if a user exists
function Find-MHOADCredentials ($Username) {
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
    <#  function usage example
        if(!( Validate-ADCredentials -Username "HOMELAB\Administrator" )) {
        # What should happen if username can not be validated
        exit 99
        } #>



# Get all shares of a give system via Net view
function Get-MHOSmbShares {
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
            exit 99
        }
        Write-MHOLog -Info "File shares ... FOUND" -Status Info
        ForEach($excludedElement in $Exclude) {
            $allshares.Remove($excludedElement)
        }
    } catch  {
        Write-MHOLog -Info "$_" -Status Error
        Write-MHOLog -Info "Failed to load file shares" -Status Error
            exit 99
    }
    return $allshares
} #end function

function Import-MHOVMwareModule {
<#
    .SYNOPSIS
        This function is used to load/install VMware PowerCLI
    .NOTES 
        Version:        2.0
        Author:         Marco Horstmann (marco.horstmann@veeam.com)
        Creation Date:  25 Januar 2021
        Purpose/Change: Initial Release
    .LINK
        Online Version: https://github.com/marcohorstmann/psscripts
#>
    Write-MHOLog -Status Info -Info "Checking if VMware Modules are installed ..."
    if(Get-Command -Module *VMWare*) {
        Write-MHOLog -Status Info -Info "VMware Modules are already installed... SKIPPED"
        import-module VMware.PowerCLI -ErrorAction Stop
    } else {
        Write-MHOLog -Status Info -Info "VMware Modules are not installed... INSTALLING..."
        try {
            Install-Module -Name VMware.PowerCLI -Force -Confirm:$False
            Set-PowerCLIConfiguration -Scope AllUsers -ParticipateInCeip $false -InvalidCertificateAction Ignore
            Write-MHOLog -Info "VMware Modules was installed... DONE" -Status Info
        } catch  {
            Write-MHOLog -Info "$_" -Status Error
            Write-MHOLog -Info "Installing VMware Modules... FAILED" -Status Error
            exit
        }
    }
} # end function


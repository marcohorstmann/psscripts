# This module will not load if no variable $Log exists
if(!(Get-Variable -Name Log -ErrorAction SilentlyContinue)) {
    Write-Error -Message "Please create variable called Log. Otherwise this module will not load." -ErrorAction Stop
    Get-Variable -Name Log -ErrorAction Stop
}

function Get-MHOTimeStamp {
<#
    .SYNOPSIS
        This function is used by other function to get the current timestamp
        as a string for using it e.g. in Write-MHOLog
    .INPUTS
        None

    .OUTPUTS
        Returns a timestamp as a string in format: [DD.MM.YYYY HH:MM:ss]

    .EXAMPLE
        $timestamp = Get-MHOTimeStamp
    
    .NOTES 
        Version:        2.0
        Author:         Marco Horstmann (marco.horstmann@veeam.com)
        Creation Date:  25 Januar 2021
        Purpose/Change: Initial Release
    .LINK
        Online Version: https://github.com/marcohorstmann/psscripts
#>
    return "[{0:dd.MM.yyyy} {0:HH:mm:ss}]" -f (Get-Date)
} # end function Get-MHOTimeStamp

function Write-MHOLog {
<#
    .SYNOPSIS
        This function is used by the scripts to log entries into a logfile.
    .DESCRIPTION
        This function is used to write log entries into a log file which is
        provided by a $Log variable in the calling script.
    .INPUTS
        None

    .OUTPUTS
        None

    .EXAMPLE
        Write-MHOLog -Info "Text which should be logged" -Status Info

    .EXAMPLE
        Write-MHOLog -Info "Starting a new log file" -Status NewLog
        This function will always append to a logfile exept if you use the NewLog as status which recreates the log file.
    
    .NOTES 
        Version:        2.0
        Author:         Marco Horstmann (marco.horstmann@veeam.com)
        Creation Date:  25 Januar 2021
        Purpose/Change: Initial Release
    .LINK
        Online Version: https://github.com/marcohorstmann/psscripts
#>
    param(
    # This parameter is the message that needs to be logged
    [Parameter(Mandatory=$True)]
    [string]$Info,

    # This parameter is the servity level of this log entry. Depending
    # on the servity the commands will be recolored, e.g. red when error accoured
    [ValidateSet(“NewLog”,”Info”,"Warning”,”Error”)]
    [Parameter(Mandatory=$True)]
    [string]$Status
    )
    $Info = "$(Get-MHOTimeStamp) $Info"
    switch($Status)
    {
        NewLog  {Write-Host $Info -ForegroundColor Green  ; $Info | Out-File -FilePath $Log}
        Info    {Write-Host $Info -ForegroundColor Green  ; $Info | Out-File -FilePath $Log -Append}
        Warning {Write-Host $Info -ForegroundColor Yellow ; $Info | Out-File -FilePath $Log -Append}
        Error   {Write-Host $Info -ForegroundColor Red -BackgroundColor White; $Info | Out-File -FilePath $Log -Append}
        default {Write-Host $Info -ForegroundColor White ;  $Info | Out-File -FilePath $Log -Append}
    }
} #end function Write-MHOLog 

function Start-MHOLog {
<#
    .SYNOPSIS
        This function is used by the scripts to recreate a log file.
    .NOTES 
        Version:        2.0
        Author:         Marco Horstmann (marco.horstmann@veeam.com)
        Creation Date:  25 Januar 2021
        Purpose/Change: Initial Release
    .LINK
        Online Version: https://github.com/marcohorstmann/psscripts
#>

    Write-MHOLog -Info "Starting new log file" -Status NewLog
} #end function Start-MHOLog 

function Get-MHOIP-toINT64 () {
<#
    .SYNOPSIS
        This function is used to convert an IP to an INT64 value
    .NOTES 
        Version:        2.0
        Author:         Marco Horstmann (marco.horstmann@veeam.com)
        Creation Date:  25 Januar 2021
        Purpose/Change: Initial Release
    .LINK
        Online Version: https://github.com/marcohorstmann/psscripts
#>
  param ($ip) 
 
  $octets = $ip.split(".") 
  return [int64]([int64]$octets[0]*16777216 +[int64]$octets[1]*65536 +[int64]$octets[2]*256 +[int64]$octets[3]) 
} 
 
function Get-MHOINT64-toIP {
<#
    .SYNOPSIS
        This function is used to convert an INT64 value to an IP address
    .NOTES 
        Version:        2.0
        Author:         Marco Horstmann (marco.horstmann@veeam.com)
        Creation Date:  25 Januar 2021
        Purpose/Change: Initial Release
    .LINK
        Online Version: https://github.com/marcohorstmann/psscripts
#>
  param ([int64]$int) 

  return (([math]::truncate($int/16777216)).tostring()+"."+([math]::truncate(($int%16777216)/65536)).tostring()+"."+([math]::truncate(($int%65536)/256)).tostring()+"."+([math]::truncate($int%256)).tostring() )
}

function Import-MHOAWSModule {
<#
    .SYNOPSIS
        This function is used to load/install AWS module
    .NOTES 
        Version:        2.0
        Author:         Marco Horstmann (marco.horstmann@veeam.com)
        Creation Date:  25 Januar 2021
        Purpose/Change: Initial Release
    .LINK
        Online Version: https://github.com/marcohorstmann/psscripts
#>
    Write-MHOLog -Status Info -Info "Checking if AWS Modules are installed ..."
    if(get-module -Name "AWSPowerShell.NetCore") {
        Write-MHOLog -Status Info -Info "AWS Modules are already installed... SKIPPED"
    } else {
        Write-MHOLog -Status Info -Info "AWS Modules are not installed... INSTALLING..."
        try {
            Install-Module -Name AWSPowerShell.NetCore -Force -Confirm:$False
            Write-MHOLog -Info "AWS Modules was installed... DONE" -Status Info
        } catch  {
            Write-MHOLog -Info "$_" -Status Error
            Write-MHOLog -Info "Installing AWS Modules... FAILED" -Status Error
            exit 12
        }
    }
} # end function


function Get-CredentialsFromFile {
<#
    .SYNOPSIS
        This function is used to load saved credentials from XML file.
    .DESCRIPTION
        None
    .INPUTS
        None

    .OUTPUTS
        None

    .EXAMPLE
        Get-CredentialsFromFile -File "C:\script\vmware-admin.xml"
    
    .NOTES 
        Version:        2.0
        Author:         Marco Horstmann (marco.horstmann@veeam.com)
        Creation Date:  25 Januar 2021
        Purpose/Change: Initial Release
    .LINK
        Online Version: https://github.com/marcohorstmann/psscripts
#>
    param(
    # This parameter is the filename of the credentials file
    [Parameter(Mandatory=$True)]
    [string]$File
    )
    if($Credential = Import-CliXml $File -ErrorAction Ignore) {
        Write-MHOLog -Status Info -Info "Loading credentials file $File ... SUCSESSFUL"
    } else {
        Write-MHOLog -Status Error -Info "Loading credentials file $File ... FAILED"
        exit 13
    }
    return $Credential
}

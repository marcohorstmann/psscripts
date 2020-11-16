<# 
   .SYNOPSIS
   Advanced Logging
   .DESCRIPTION
   This module is used for advanced logging. It uses the $Log variable of
   the source script 

   .EXAMPLE

   

   .Notes 
   Version:        1.0
   Author:         Marco Horstmann (marco.horstmann@veeam.com)
   Creation Date:  12 December 2020
   Purpose/Change: Initial Release
   
   .LINK https://github.com/marcohorstmann/psscripts
   .LINK https://horstmann.in
 #>
# Return a Timestring  timestamp for log
function Get-MHOTimeStamp {    
        return "[{0:dd.MM.yyyy} {0:HH:mm:ss}]" -f (Get-Date)
} # end function

# This function is used to log status to console and also the given logfilename.
# Usage: Write-Log -Status [Info, Status, Warning, Error] -Info "This is the text which will be logged" -Log "C:\test\Logfilename"
function Write-MHOLog($Info, $Status)
{
    $Info = "$(Get-MHOTimeStamp) $Info" # maybe can this be replaced?
    switch($Status)
    {
        NewLog  {Write-Host $Info -ForegroundColor Green  ; $Info | Out-File -FilePath $Log}
        Info    {Write-Host $Info -ForegroundColor Green  ; $Info | Out-File -FilePath $Log -Append}
        Warning {Write-Host $Info -ForegroundColor Yellow ; $Info | Out-File -FilePath $Log -Append}
        Error   {Write-Host $Info -ForegroundColor Red -BackgroundColor White; $Info | Out-File -FilePath $Log -Append}
        default {Write-Host $Info -ForegroundColor White ;  $Info | Out-File -FilePath $Log -Append}
    }
} #end function 

# This function just calls Write-Log but was added for better code Readablility
function Start-MHOLog {
    Write-MHOLog -Status NewLog -Info "Starting new log file"
}


if(!(Get-Variable -Name Log -ErrorAction SilentlyContinue)) {
    Write-Error -Message "Please create variable called Log. Otherwise this module will not load." -ErrorAction Stop
    Get-Variable -Name Log -ErrorAction Stop
}


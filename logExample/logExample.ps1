<# 
   .SYNOPSIS
   This is a sample script how to log data from pre- and post-Job scripts to the
   backup job itself. This allows a better monitoring of script messages.
   .DESCRIPTION
   This is a sample script how to log data from pre- and post-Job scripts to the
   backup job itself. This allows a better monitoring of script messages.
   
   .Notes 
   Version:        1.1
   Author:         Marco Horstmann (marco.horstmann@veeam.com)
   Creation Date:  15 October 2021
   Purpose/Change: Initial Release
   
   .LINK
   Online Version: https://github.com/marcohorstmann/psscripts
   .LINK
   Online Version: https://horstmann.in
 #>
[CmdletBinding(DefaultParameterSetName="__AllParameterSets")]
Param(

<#
   [Parameter(Mandatory=$True)]
   [string]$VBRJobName,
#>
   [Parameter(Mandatory=$False)]
   [string]$global:Log=$("C:\log\" + $MyInvocation.MyCommand.Name + ".log")
)

#
# GLOBAL MODULE IMPORT
#

#Remove Modules for Debug (can be removed in production code)
Remove-Module mho-common -ErrorAction Ignore
Remove-Module mho-veeam -ErrorAction Ignore
#Remove-Module mho-netapp -ErrorAction Ignore
#Remove-Module mho-microsoft -ErrorAction Ignore

# Switch Powershell current path to script path
Split-Path -Parent $PSCommandPath | Set-Location
#Import Logging Module
Import-Module ..\include\mho-common\mho-common.psm1 -ErrorAction stop
Import-Module ..\include\mho-veeam\mho-veeam.psm1 -ErrorAction stop
#Import-Module ..\include\mho-netapp\mho-netapp.psm1 -ErrorAction stop
#Import-Module ..\include\mho-microsoft\mho-microsoft.psm1 -ErrorAction stop

#
# GOBAL MODULE IMPORT END
#

#
# MAIN CODE START
#
# Create a new Log
Start-MHOLog

# This command gets the current BackupSession Info from running powershell to
# allow automatic detection of current job.
$BackupSession = Get-MHOVbrJobSessionFromPID

# This are some examples for running code

# Creating a normal green success message. You can pass any text with -Test parameter
$logentry = Add-MHOVbrJobSessionLogEvent -BackupSession $BackupSession -Status Success -Text "Marco Test Success"

# Creating a warning message. You can pass any text with -Test parameter. When a warnung will be logged the VBR job
# it will automatically set the complete job to warnung.
$logentry = Add-MHOVbrJobSessionLogEvent -BackupSession $BackupSession -Status Warning -Text "Marco Test Warning"

# Creating a error message. You can pass any text with -Test parameter. When an error will be logged the VBR job
# it will automatically set the complete job to error.
$logentry = Add-MHOVbrJobSessionLogEvent -BackupSession $BackupSession -Status Error -Text "Marco Test Error"

# This example can be used to record a longer operation like a big script block and want the user to see in which state we are

# First we need to start the "running" entry with this command. You now see the "play" button like event in VBR. If you maybe
# have more than one of this running you need own variables for them because we need the variable later to finish this
$logentrySuccess = Add-MHOVbrJobSessionLogEvent -BackupSession $BackupSession -Status Running -Text "Marco Test Running"
$logentryWarning = Add-MHOVbrJobSessionLogEvent -BackupSession $BackupSession -Status Running -Text "Marco Test Running"
$logentryFailed = Add-MHOVbrJobSessionLogEvent -BackupSession $BackupSession -Status Running -Text "Marco Test Running"

# For demo 
Start-Sleep -Seconds 10
$logentrySuccess = Add-MHOVbrJobSessionLogEvent -BackupSession $BackupSession -Status UpdateSuccess -Text "Marco Test Finshed Success" -LogNumber $logentrySuccess
Start-Sleep -Seconds 10
$logentryFailed = Add-MHOVbrJobSessionLogEvent -BackupSession $BackupSession -Status UpdateFailed -Text "Marco Test Finshed Failed" -LogNumber $logentryFailed
Start-Sleep -Seconds 10
$logentryWarning = Add-MHOVbrJobSessionLogEvent -BackupSession $BackupSession -Status UpdateWarning -Text "Marco Test Finshed" -LogNumber $logentryWarning

#If you only want to write something to the log file you can use the command Write-MHOLog

$debug = Write-MHOLog -Info "This is my debug message" -Status Info
#>

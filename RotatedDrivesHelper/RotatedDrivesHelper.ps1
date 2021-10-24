<# 
   .SYNOPSIS
   Writes the disk label to the backup job session
   .DESCRIPTION
   This is a sample script how to log the label of a volume to the VBR
   job statistics. This script was created to have an option for Veeam
   users which are using rotated drives (e.g. RDX, USB-drive, ...) to
   create an offline copy of their data. This script will help you to
   easier find the required disk for a restore.
   
   .Notes 
   Version:        1.0
   Author:         Marco Horstmann (marco.horstmann@veeam.com)
   Creation Date:  25 October 2021
   Purpose/Change: Initial Release
   
   .LINK
   Online Version: https://github.com/marcohorstmann/psscripts
   .LINK
   Online Version: https://horstmann.in
 #>
[CmdletBinding(DefaultParameterSetName="__AllParameterSets")]
Param(

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

# This commands gets the current JobInfos BackupSession Info from running powershell to
# allow automatic detection of current job.
#This commands will get the job name, job details and current job session
$BackupJobName = Get-MHOVbrJobNameFromPID
$BackupJob = Get-VBRJob -Name $BackupJobName
$BackupSession = Get-MHOVbrJobSessionFromPID
<# Used for debugging script when not run as a post job script
#  $BackupJob = Get-VBRJob -Name "Rotated Drives Test"
#  $BackupSession = (Get-VBRJob -Name "Rotated Drives Test").FindLastSession()
#>

# This gets the backup folder e.g. "Q:\Backup" from job details and writes it to
# an array. The first entry of this array is the drive letter which is used as
# BackupVolume
$BackupTarget = $BackupJob.TargetDir.ToString().Split(":\")
$BackupVolume = get-volume -DriveLetter $BackupTarget[0]

try {
    #If FileSystemLabel has more than 0 characters report the volume label, otherwise it writes a warning to the log.
    if($BackupVolume.FileSystemLabel.Length -gt 0) {
        $logentry = Add-MHOVbrJobSessionLogEvent -BackupSession $BackupSession -Status Success -Text "Used disk with label `"$($BackupVolume.FileSystemLabel)`" for this job session."
    } else {
        $logentry = Add-MHOVbrJobSessionLogEvent -BackupSession $BackupSession -Status Warning -Text "Used disk without label for this job session. Please set label to easier locate your backups."
    }
}
catch {
    Write-MHOLog -Info "$_" -Status Error
}


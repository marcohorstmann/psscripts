<# 
   .SYNOPSIS
   This scripts looks for the most current file of all backup objects in a job
   .DESCRIPTION
   This scripts looks for the most current file of all backup objects in a job and only adds the
   last written file of every backup object into the include mask of the job
   .PARAMETER LogFile
   You can set your own path for log file from this script. Default filename is "C:\ProgramData\Involve-NASBackupOnlyOneFile.log"

   .Example
   How to run this script with an example
   .\Involve-NASBackupOnlyOneFile.ps1 -Job "File Backup Job"

   .Notes 
   Version:        1.0
   Author:         Marco Horstmann (marco.horstmann@veeam.com)
   Creation Date:  23 April 2021
   Purpose/Change: Initial Release
   
   .LINK https://github.com/marcohorstmann/psscripts
   .LINK https://horstmann.in
 #> 
[CmdletBinding(DefaultParameterSetName="__AllParameterSets")]
Param(
   [Parameter(Mandatory=$True)]
   [string]$Job,

   [Parameter(Mandatory=$False)]
   [string]$Log=$("C:\log\" + $MyInvocation.MyCommand.Name + ".log")
   
)

#
# GLOBAL MODULE IMPORT
#

# Switch Powershell current path to script path
Split-Path -Parent $PSCommandPath | Set-Location

#Import Logging Module
Import-Module ..\include\mho-common\mho-common.psm1 -ErrorAction stop
#Import Veeam Module
Import-Module ..\include\mho-veeam\mho-veeam.psm1 -ErrorAction stop
#
# GOBAL MODULE IMPORT END
#

#
# MAIN CODE START
#   

# Create a new Log
Start-MHOLog

# Load Veeam Backup Module
Import-MHOVeeamBackupModule

# Validate parameters: VBRJobName
Write-MHOLog -Status Info -Info "Checking VBR Job Name"
$nasBackupJob = Get-VBRNASBackupJob -name $Job
if($nasBackupJob -eq $null) {
    Write-MHOLog -Info "VBR Job Name ... NOT FOUND" -Status Error
    exit
} else { 
    Write-MHOLog -Info "VBR Job Name ... FOUND" -Status Info
}

# Create empty array for results of the next loop
$UpdatedNasBackupObjects = @()

# Loop for every Object in the backup job
ForEach($backupObject in $nasBackupJob.BackupObject) {
    
    # Get the last written file of the current path
    $MostCurrentFile = Get-ChildItem $backupObject.Path | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    # Set the inclusionMask for the current path
    $UpdatedNasBackupObjects += Set-VBRNASBackupJobObject -JobObject $backupObject -InclusionMask "$($MostCurrentFile.Name)"
}

# Update the File Backup Job
$jobUpdateResult = Set-VBRNASBackupJob -Job $nasBackupJob -BackupObject $UpdatedNasBackupObjects


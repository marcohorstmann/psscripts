<# 
   .SYNOPSIS
   Short description what this script is used for
   .DESCRIPTION
   Explain in detail what this script do. This block can be of cause multiline as well.
   .PARAMETER LogFile
   You can set your own path for log file from this script. Default filename is "C:\ProgramData\template.log"

   .Example
   How to run this script with an example
   .\template.ps1 -parameter1 "\\homelab\dfs"

   .Notes 
   Version:        1.0
   Author:         Marco Horstmann (marco.horstmann@veeam.com)
   Creation Date:  15 October 2021
   Purpose/Change: Initial Release
   
   .LINK https://github.com/marcohorstmann/psscripts
   .LINK https://horstmann.in
 #> 
[CmdletBinding(DefaultParameterSetName="__AllParameterSets")]
Param(
<# This is a sample parameter you can use to pass commandline parameters to this script
   [Parameter(Mandatory=$True)]
   [string]$VBRJobName,
#>
   [Parameter(Mandatory=$False)]
   [string]$global:Log=$("C:\log\" + $MyInvocation.MyCommand.Name + ".log")
)

#
# GLOBAL MODULE IMPORT
#

#Remove Modules for Debug (I sometimes need it for Debugging changed modules. Normally this will not be used)
#Remove-Module mho-logging -ErrorAction Ignore
#Remove-Module mho-common -ErrorAction Ignore
#Remove-Module mho-veeam -ErrorAction Ignore
#Remove-Module mho-netapp -ErrorAction Ignore
#Remove-Module mho-microsoft -ErrorAction Ignore
#Remove-Module mho-vmware -ErrorAction Ignore

# Change current Powershell path to script location
Split-Path -Parent $PSCommandPath | Set-Location

#Import Logging Module
Import-Module ..\include\mho-common\mho-common.psm1 -ErrorAction stop
Import-Module ..\include\mho-veeam\mho-veeam.psm1 -ErrorAction stop
#Import-Module ..\include\mho-netapp\mho-netapp.psm1 -ErrorAction stop
#Import-Module ..\include\mho-microsoft\mho-microsoft.psm1 -ErrorAction stop
#Import-Module ..\include\mho-vmware\mho-vmware.psm1 -ErrorAction stop

#
# GOBAL MODULE IMPORT END
#

#
# SCRIPT FUNCTIONS START
#
# Add here all functions which are used in this script.
# If function can be reused think about to add it to the imported modules
# to make this functions reusable across multiple scripts.
#
function Get-MHOVbrJobDetails($job) {
    
    
    return $jobDetails
}

#
# SCRIPT FUNCTIONS END
#

#
# MAIN CODE START
#   


# Create a new Log
Start-MHOLog

# Load Veeam Backup Module
Import-MHOVeeamBackupModule

#Get first all jobs to reduce number of requests to the VBR server
$jobs = Get-VBRJob | ?{$_.JobType -eq "Backup"}

<#
# Get all Repositories Normal and Scale-Out
#$repositories = Get-VBRBackupRepository
#$repositories += Get-VBRBackupRepository -ScaleOut
#>

#ToDo: Errorhandling if both are empty
$referenceJob = $jobs | Sort-Object -Property Name | Out-GridView -OutputMode Single -Title "Please select reference job"

$compareJobs = $jobs | ?{$_.Id -ne $referenceJob.Id} | Sort-Object -Property Name  | Out-GridView -OutputMode Multi -Title "Please select jobs which should be compared to the reference Job"

#Referenz-Info
Write-MHOLog -Info "`n-------------------------------------------------------------------------" -Status Info
Write-MHOLog -Info "Processing reference job: '$($referenceJob.Name)'" <#[$jobs_counter of $jobs_number]"#> -Status Info
Write-MHOLog -Info "-------------------------------------------------------------------------`n" -Status Info

$referenceJobProxy = [Veeam.Backup.Core.COijProxy]::GetOijProxiesByJob($referenceJob.Id)
Write-MHOLog -Status Info -Info "This reference job using Log Shipping Server(s) $($referenceJobProxy.Proxy.Name)"

ForEach ($job in $compareJobs) {
    Write-MHOLog -Info "`n-------------------------------------------------------------------------" -Status Info
    Write-MHOLog -Info "Processing job: '$($job.Name)'" <#[$jobs_counter of $jobs_number]"#> -Status Info
    Write-MHOLog -Info "-------------------------------------------------------------------------`n" -Status Info
    #Compare-Object -IncludeEqual $referenceJob $job
    # Compare-Object $a $b -Property ProcessName, Id, CPU
    <# Check High Priority
    if($referenceJob.IsHighPriority() -ne $job.IsHighPriority()) {
        Write-MHOLog -Info "High Priority Setting differs from Reference. This job is set to $($job.IsHighPriority())" -Status Warning
    } else {
        Write-MHOLog -Info "High Priority Setting is the same as Reference." -Status Info
    }
    #>

    <# Was will ich in einer Tabelle sehen?

    High Priority

    Which backup repo is used: $job.GetBackupTargetRepository().name

    $job.BackupStorageOptions.RetentionType # Cycles or Days
    $job.BackupStorageOptions.RetainCycles  #Number of Cycles
    $job.BackupStorageOptions.RetainDays # Number of days of RetaintionType is Days
    $job.BackupStorageOptions

    # EnableDeletedVmDataRetention : False # ggf. deleted vms synthe
    # CompressionLevel             : 5
    #EnableDeduplication          : True
    #StgBlockSize                 : KbBlockSize1024 # Welche Blocksize wird verwendet
    # ??????? EnableIntegrityChecks        : True
    # UseSpecificStorageEncryption : False # ??? verschlüsselung
    # StorageEncryptionEnabled     : False # ??? verschlüsselung

    $job.Options.GfsPolicy

    $job.Options.GfsPolicy.Weekly

IsEnabled KeepBackupsForNumberOfWeeks DesiredTime BeginTimeLocal     
--------- --------------------------- ----------- --------------     
    False                           1      Sunday 01.01.0001 00:00:00



     $job.Options.GfsPolicy.Monthly

IsEnabled KeepBackupsForNumberOfMonths DesiredTime BeginTimeLocal     
--------- ---------------------------- ----------- --------------     
    False                            1       First 01.01.0001 00:00:00



     $job.Options.GfsPolicy.Yearly

IsEnabled KeepBackupsForNumberOfYears DesiredTime BeginTimeLocal     
--------- --------------------------- ----------- --------------     
    False                           1     January 01.01.0001 00:00:00


    #>

    #$job.Info
    
    #$repositories | where {$_.id -eq $job.Info.TargetRepositoryId} | select name

    #Log Shippping
    $jobProxy = [Veeam.Backup.Core.COijProxy]::GetOijProxiesByJob($job.Id)
    if($jobProxy.Proxy.Name -eq $null) {
        Write-MHOLog -Status Info -Info "This backup job doesn't has Log Shipping configured"
    } elseif($referenceJobProxy.Proxy.Name -eq $jobProxy.Proxy.Name) {
        Write-MHOLog -Status Warning -Info "This backup job using other Log Shipping Server(s) then Reference: $($jobProxy.Proxy.Name)"
    } else {
        Write-MHOLog -Status Info -Info "This backup job using Log Shipping Server(s) $($jobProxy.Proxy.Name)"
    }

    #Hier die Backup Job Objects
    [Array]$jobBackupObjects = Get-VBRJobObject $job
    ForEach ($jobBackupObject in $jobBackupObjects) {
        #Get Information for every Job Object
        $BackupObjectsVssOptions = Get-VBRJobObjectVssOptions -ObjectInJob $jobBackupObject
    }

<#

$job.BackupStorageOptions
CheckRetention               : True
RetentionType                : Days
RetainCycles                 : 7
RetainDaysToKeep             : 7
KeepFirstFullBackup          : False
RetainDays                   : 14
EnableDeletedVmDataRetention : False
CompressionLevel             : 6
EnableDeduplication          : True
StgBlockSize                 : KbBlockSize1024
EnableIntegrityChecks        : True
EnableFullBackup             : False
BackupIsAttached             : False
UseSpecificStorageEncryption : False
StorageEncryptionEnabled     : False

$job.BackupTargetOptions
Algorithm                        : Increment
FullBackupScheduleKind           : Daily
FullBackupDays                   : {Saturday}
FullBackupMonthlyScheduleOptions : Veeam.Backup.Model.CDomFullBackupMonthlyScheduleOptions
TransformFullToSyntethic         : True
TransformIncrementsToSyntethic   : False
TransformToSyntethicDays         : {Saturday}

$job.JobScriptCommand
PostCommand           : Veeam.Backup.Model.CCustomCommand
PreCommand            : Veeam.Backup.Model.CCustomCommand
Periodicity           : Cycles
PostScriptEnabled     : False
PostScriptCommandLine : 
PreScriptEnabled      : False
PreScriptCommandLine  : 
Frequency             : 1
Days                  : {Saturday}

Options                     : Veeam.Backup.Common.CDomContainer
GfsPolicy                   : Veeam.Backup.GFS.Model.DOM.CDomGfsPolicy
HvReplicaTargetOptions      : Veeam.Backup.Model.CDomHvReplicaTargetOptions
ReIPRulesOptions            : 
BackupStorageOptions        : Veeam.Backup.Model.CDomBackupStorageOptions
BackupTargetOptions         : Veeam.Backup.Model.CDomBackupTargetOptions
VmbSourceOptions            : Veeam.Backup.Model.CDomVmbSourceOptions
HvSourceOptions             : Veeam.Backup.Model.CDomHvSourceOptions
JobOptions                  : Veeam.Backup.Model.CDomJobOptions
ViNetworkMappingOptions     : Veeam.Backup.Model.CDomViNetworkMappingOptions
HvNetworkMappingOptions     : Veeam.Backup.Model.CDomHvNetworkMappingOptions
NotificationOptions         : Veeam.Backup.Model.CDomNotificationOptions
JobScriptCommand            : Veeam.Backup.Model.CDomJobScriptCommand
VcdReplicaTargetOptions     : Veeam.Backup.Model.CDomVcdReplicaOptions
ViReplicaTargetOptions      : Veeam.Backup.Model.CDomViReplicaTargetOptions
CloudReplicaTargetOptions   : Veeam.Backup.Model.CDomCloudReplicaTargetOptions
ViSourceOptions             : Veeam.Backup.Model.CDomViSourceOptions
GenerationPolicy            : Veeam.Backup.Model.CDomGenerationPolicy
SanIntegrationOptions       : Veeam.Backup.Model.CDomSanIntegrationOptions
ReplicaSourceOptions        : Veeam.Backup.Model.CDomReplicaSourceOptions
SqlLogBackupOptions         : Veeam.Backup.Model.CDomSqlLogBackupOptions
FailoverPlanOptions         : Veeam.Backup.Model.CDomFailoverPlanOptions
ViCloudReplicaTargetOptions : Veeam.Backup.Model.CDomViCloudReplicaTargetOptions
EpPolicyOptions             : Veeam.Backup.Model.CDomEpPolicyOptions
NasBackupRetentionPolicy    : Veeam.Backup.Model.CDomNasBackupRetentionPolicy
NasBackupOptions            : Veeam.Backup.Model.CDomNasBackupOptions
RpoOptions                  : Veeam.Backup.Model.CDomRpoOptions
VmbJobOptions               : 
IsBackupCopyGfsEnabled      : False


$job.ScheduleOptions
OptionsScheduleAfterJob               : Veeam.Backup.Model.CScheduleAfterJobOptions
StartDateTimeLocal                    : 01.04.2022 22:00:00
EndDateTimeSpecified                  : False
EndDateTimeLocal                      : 03.04.2022 11:49:08
RepeatSpecified                       : False
RepeatNumber                          : 1
RepeatTimeUnit                        : hour(s)
RepeatTimeUnitMs                      : 3600000
RetryTimes                            : 3
RetryTimeout                          : 10
RetrySpecified                        : True
WaitForBackupCompletion               : True
BackupCompetitionWaitingPeriodMin     : 180
BackupCompetitionWaitingUnit          : Hours
OptionsDaily                          : Enabled: True, DayNumberInMonth: Everyday, Days: Sunday, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday
OptionsMonthly                        : Enabled: False, Time: 01.04.2022 22:00:00, Day Number In Month: Fourth, Day Of Week: Saturday, Months: January, February, March, April, May, 
                                        June, July, August, September, October, November, December
OptionsPeriodically                   : Enabled: False, Period: 1 hour(s), ScheduleString: <scheduler><Sunday>0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0</Sunday><Monday>0,0,0,0,0,0
                                        ,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0</Monday><Tuesday>0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0</Tuesday><Wednesday>0,0,0,0,0,0,0,0,0,0,0,0
                                        ,0,0,0,0,0,0,0,0,0,0,0,0</Wednesday><Thursday>0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0</Thursday><Friday>0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                                        ,0,0,0,0,0,0,0</Friday><Saturday>0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0</Saturday></scheduler>, HourlyOffset: 0
OptionsContinuous                     : Enabled: False, ScheduleString: <scheduler><Sunday>0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0</Sunday><Monday>0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                                        0,0,0,0,0,0,0,0,0</Monday><Tuesday>0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0</Tuesday><Wednesday>0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                                        0,0,0</Wednesday><Thursday>0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0</Thursday><Friday>0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0</Fri
                                        day><Saturday>0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0</Saturday></scheduler>
OptionsBackupWindow                   : Veeam.Backup.Model.CBackupWindowOptions
NextRun                               : 
LatestRunLocal                        : 01.04.2022 11:49:08
LatestRecheckLocal                    : 01.01.0001 00:00:00
BackupAtStartup                       : False
BackupAtLogoff                        : False
BackupAtLock                          : False
BackupAtStorageAttach                 : False
LimitBackupsFrequency                 : False
MaxBackupsFrequency                   : 2
FrequencyTimeUnit                     : Hour
EjectRemovableStorageOnBackupComplete : False
ResumeMissedBackup                    : False
IsServerMode                          : False
IsFakeSchedule                        : False
IsContinious                          : False
IsCdp                                 : False
CdpPeriodicallyRpo                    : 
MarkPolicyWarningOnRpoExceeded        : 
MarkPolicyFailedOnRpoExceeded         : 
CdpPeriodicallyShortTerm              : 
CdpPeriodicallyLongTerm               : 
CdpRetentionDays                      : 0
CdpRetentionMinutes                   : 0


$job.ViSourceOptions
EncryptLanTraffic               : False
FailoverToNetworkMode           : False
VCBMode                         : san
VDDKMode                        : san;nbd
UseChangeTracking               : True
EnableChangeTracking            : True
ResetChangeTrackingOnActiveFull : True
VMToolsQuiesce                  : False
VmAttributeName                 : Notes
BackupTemplates                 : True
ExcludeSwapFile                 : True
DirtyBlocksNullingEnabled       : True
BackupTemplatesOnce             : True
SetResultsToVmNotes             : False
VmNotesAppend                   : True


#>

    #Get all added VBRJobObjects in this job, especially the object specfic settings like SQL settings


   
    #jobDetails
    <# Test von Forum
	$jobOptions = New-Object PSObject
	$jobOptions | Add-Member -MemberType NoteProperty -Name "Name" -value $job.name
	$jobOptions | Add-Member -MemberType NoteProperty -Name "Enabled" -value $job.isscheduleenabled
	$jobOptions | Add-Member -MemberType NoteProperty -Name "Backup Mode" -value $job.backuptargetoptions.algorithm
	$repo = (Get-VBRBackupRepository | ?{$_.HostId -eq $job.TargetHostId -and $_.Path -eq $job.TargetDir}).name
	$jobOptions | Add-Member -MemberType NoteProperty -Name "Repository" -value $repo
	$proxies = $null
	foreach ($prox in ($job | get-vbrjobproxy)) {
		$pName = $prox.Name
		$proxies = $proxies + $pName
	}
	$jobOptions | Add-Member -MemberType NoteProperty -Name "Proxy" -value $proxies
	$jobOptions | Add-Member -MemberType NoteProperty -Name "Auto Proxy" -Value $job.sourceproxyautodetect
	$jobOptions | Add-Member -MemberType NoteProperty -Name "Next Run" -Value $job.scheduleoptions.nextrun
	$jobOptions | Add-Member -MemberType NoteProperty -Name "Restore Points" -Value $job.backupstorageoptions.retaincycles
	$jobOptions | Add-Member -MemberType NoteProperty -Name "Deduplication" -Value $job.backupstorageoptions.enablededuplication
	$comp = $job.backupstorageoptions.compressionlevel
	If ($comp -eq 0) {$comp = "None"}
	If ($comp -eq 4) {$comp = "Dedupe Friendly"}
	If ($comp -eq 5) {$comp = "Optimal"}
	If ($comp -eq 6) {$comp = "High"}
	If ($comp -eq 9) {$comp = "Extreme"}
	$jobOptions | Add-Member -MemberType NoteProperty -Name "Compression" -Value $comp
	$opti = $job.backupstorageoptions.stgblocksize
	If ($opti -eq "KbBlockSize8192") {$opti = "Local Target(16TB+ Files)"}
	If ($opti -eq "KbBlockSize1024") {$opti = "Local Target"}
	If ($opti -eq "KbBlockSize512") {$opti = "LAN Target"}
	If ($opti -eq "KbBlockSize256") {$opti = "WAN Target"}
	$jobOptions | Add-Member -MemberType NoteProperty -Name "Optimized" -Value $opti
	$jobOptions | Add-Member -MemberType NoteProperty -Name "Integrity Checks" -Value $job.backupstorageoptions.enableintegritychecks
	$jobOptions | Add-Member -MemberType NoteProperty -Name "Exclude Swap" -Value $job.visourceoptions.excludeswapfile
	$jobOptions | Add-Member -MemberType NoteProperty -Name "Remove Deleted VMs" -Value $job.backupstorageoptions.enabledeletedvmdataretention
	$jobOptions | Add-Member -MemberType NoteProperty -Name "Retain Deleted VMs" -Value $job.backupstorageoptions.retaindays
	$jobOptions | Add-Member -MemberType NoteProperty -Name "CBT Enabled" -Value $job.visourceoptions.usechangetracking
	$jobOptions | Add-Member -MemberType NoteProperty -Name "Auto Enable CBT" -Value $job.visourceoptions.enablechangetracking
	$jobOptions | Add-Member -MemberType NoteProperty -Name "Set VM Note" -Value $job.visourceoptions.setresultstovmnotes
	$jobOptions | Add-Member -MemberType NoteProperty -Name "VM Attribute Name" -Value $job.visourceoptions.vmattributename
	$jobOptions | Add-Member -MemberType NoteProperty -Name "VMTools Quiesce" -Value $job.visourceoptions.vmtoolsquiesce
	$jobOptions | Add-Member -MemberType NoteProperty -Name "VSS Enabled" -Value $job.vssoptions.enabled
	$igfs = $job.vssoptions.guestfsindexingtype
	If ($igfs -eq "None") {$igfs = "Disabled"}
	ElseIf ($igfs -eq "EveryFolders") {$igfs = "Enabled"}
	$jobOptions | Add-Member -MemberType NoteProperty -Name "Index Guest FS" -Value $igfs
	$jobOptions | Add-Member -MemberType NoteProperty -Name "VSS Username" -Value $($job | get-vbrjobvssoptions).credentials.username
	$jobOptions | Add-Member -MemberType NoteProperty -Name "Description" -Value $job.Description
	$allDetails += $jobOptions
}

#--------------------------------------------------------------------
# Outputs

# Display results summary
$allDetails | select Name, Enabled | Sort Name | ft -AutoSize

If (!$path -or !$path.EndsWith(".csv")) {
	Write-Host "`n`nUsing Default Path"
	$path = $scriptDir + "\" + $scriptName + "_" + (Get-Date -uformat %m-%d-%Y_%I-%M-%S) + ".csv"
	$path
} Else {
	Write-Host "`n`nUsing Supplied Path"
	$path
}

# Export results
$allDetails | Sort Name | Export-Csv $path -NoTypeInformation -Force

# Open csv
If ($autoLaunch) {
	Invoke-Item $path
}

$finishtime = Get-Date -uformat "%m-%d-%Y %I:%M:%S"
Write-Host "`n`n"
Write-Host "********************************************************************************"
Write-Host "$scriptName`t`t`t`tFinish Time:`t$finishtime"
Write-Host "********************************************************************************"

# Prompt to exit script - This leaves PS window open when run via right-click
Write-Host "`n`n"
Write-Host "Press any key to continue ..." -foregroundcolor Gray
$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    #>


#THIS IS THE END
}
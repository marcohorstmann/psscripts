<# 
   .SYNOPSIS
   Short description what this script is used for
   .DESCRIPTION
   Explain in detail what this script dp
   .PARAMETER LogFile
   You can set your own path for log file from this script. Default filename is "C:\ProgramData\dfsrecovery.log"

   .Example
   How to run this script with an example
   .\Involve-NASInstantDFSRecovery.ps1 -DfsRoot "\\homelab\dfs" -ScanDepth 3 -VBRJobName "DFS NAS Test" -Owner "HOMELAB\Administrator"

   .Notes 
   Version:        1.0
   Author:         Marco Horstmann (marco.horstmann@veeam.com)
   Creation Date:  13 November 2020
   Purpose/Change: Initial Release
   
   .LINK https://github.com/marcohorstmann/psscripts
   .LINK https://horstmann.in
 #>
### Customizable Parameter
#Log configuration
$Log="C:\ProgramData\GetBackupSizePerUser.log"

#Which path should be scanned
$Path = "S:\"

# Report Title
$rptTitle = "Backup Size by User"
# HTML Report Width (Percent)
$rptWidth = 97

# Email configuration
#ORG $emailHost = "smtp.yourserver.com"
$emailHost = "192.168.30.10"
$emailPort = 25
$emailEnableSSL = $false
$emailUser = ""
$emailPass = ""
$emailFrom = "veeam@homelab.horstmann.in"
#ORG $emailTo = "you@youremail.com"
$emailTo = "admin@homelab.horstmann.in"
# Email Subject 
#$emailSubject = $rptTitle
# Append Report Mode to Email Subject E.g. My Veeam Report (Last 24 Hours)
#$modeSubject = $true
# Append VBR Server name to Email Subject
#$vbrSubject = $true
# Append Date and Time to Email Subject
###############################################################################$dtSubject = $false

#
# GLOBAL MODULE IMPORT
#

#Remove Modules for Debug
Remove-Module mho-common -ErrorAction Ignore
Remove-Module mho-veeam -ErrorAction Ignore
Remove-Module mho-netapp -ErrorAction Ignore
Remove-Module mho-microsoft -ErrorAction Ignore
Remove-Module mho-vmware -ErrorAction Ignore

# Switch Powershell current path to script path
Split-Path -Parent $PSCommandPath | Set-Location

#Import Logging Module
#Import-Module ..\include\mho-common\mho-common.psm1 -ErrorAction stop
#Import-Module ..\include\mho-veeam\mho-veeam.psm1 -ErrorAction stop
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



#
# SCRIPT FUNCTIONS END
#

#
# MAIN CODE START
#   


# Create a new Log
#Start-MHOLog

# Load Veeam Backup Module
#Import-MHOVeeamBackupModule
# Load NetApp Ontap Module
#Import-MHONetAppOntapModule
#Load/Install AD Management Module
#Import-MHOADManagementModule
#Load/Install DfS Management Module
#Import-MHODfsManagementModule
# Laden des VMware Moduls
#Import-MHOVMwareModule

#Array to store the folder informations
$outputList = @()

#All folders from AD users having _ in the path so this is used filtering other stuff in the repo
$userFolders = Get-ChildItem $Path | Where-Object { $_.Name -like "*_*" }

Foreach ($userFolder IN $userFolders) {
    $userFolderSize = Get-Childitem $userFolder.FullName -Recurse |  Measure-Object -property length -sum
    $userFolderSize = $userFolderSize.sum / 1GB
    # Build an output object
    $outputLine = New-Object PSObject -Property @{
        Username = $userFolder.Name.Replace("_","\")
        Foldersize = $userFolderSize
    }
    $outputList += $outputLine
}

#$outputList | Select-Object -Property Username,Foldersize

# Building the mail report

# HTML Stuff
$headerObj = @"
<html>
    <head>
        <title>$rptTitle</title>
            <style>  
              table {font-family: Tahoma;width: $($rptWidth)%;font-size: 12px;border-collapse:collapse;}
              <!-- table tr:nth-child(odd) td {background: #e2e2e2;} -->
              </style>
    </head>
    <body>
        <center>
            <table>
                <tr>
                    <td style="width: 50%;height: 14px;border: none;font-size: 10px;vertical-align: bottom;text-align: left;padding: 2px 0px 0px 5px;"></td>
                    <td style="width: 50%;height: 14px;border: none;font-size: 12px;vertical-align: bottom;text-align: right;padding: 2px 5px 0px 0px;">Report generated on $(Get-Date -format g)</td>
                </tr>
                <tr>
                    <td style="width: 50%;height: 24px;border: none;font-size: 24px;vertical-align: bottom;text-align: left;padding: 0px 0px 0px 15px;">$rptTitle</td>
                    <td style="width: 50%;height: 24px;border: none;font-size: 12px;vertical-align: bottom;text-align: right;padding: 0px 5px 2px 0px;"></td>
                </tr>
            </table>
"@


# $htmlOutput = $headerObj + $bodyTop + $bodySummaryProtect + $bodySummaryBK + $bodySummaryRp + $bodySummaryBc + $bodySummaryTp + $bodySummaryEp + $bodySummarySb
$htmlOutput = $headerObj

<#
$bodyJobSizeBk = Get-BackupSize -backups $backupsBk | Sort JobName | Select @{Name="Job Name"; Expression = {$_.JobName}},
      @{Name="VM Count"; Expression = {$_.VMCount}},
      @{Name="Repository"; Expression = {$_.Repo}},
      @{Name="Data Size (GB)"; Expression = {$_.DataSize}},
      @{Name="Backup Size (GB)"; Expression = {$_.BackupSize}} | ConvertTo-HTML -Fragment
    $bodyJobSizeBk = $subHead01 + "Backup Job Size" + $subHead02 + $bodyJobSizeBk
#>

$htmlOutput += @"
<table>
                <tr>
                    <td style="height: 35px;color: #626365;font-size: 16px;padding: 5px 0 0 15px;border-top: 5px solid white;border-bottom: none;align: left;">
"@

<#
$htmlOutput += $outputList | Select @{Username="Username"; Expression = {$_.Username}},
                                       @{Name="Folder Size (GB)"; Expression = {$_.Foldersize}} | ConvertTo-HTML -Fragment
                                       #>
$htmlOutput += $outputList | ConvertTo-Html -Fragment 


$htmlOutput += @"
</td>
                </tr>
             </table>
"@


# Send Report via Email
# Create new SMTP connection to mail server
$smtp = New-Object System.Net.Mail.SmtpClient($emailHost, $emailPort)
# Authenticate against mail server
$smtp.Credentials = New-Object System.Net.NetworkCredential($emailUser, $emailPass)
# If SSL is used SSL will be enabled
$smtp.EnableSsl = $emailEnableSSL
# Create an new email object
$msg = New-Object System.Net.Mail.MailMessage($emailFrom, $emailTo)
$msg.Subject = $emailSubject
# Make htmlOutput to body   ##ToDo Check if I can skip this step
$body = $htmlOutput
$msg.Body = $body
#define that this mail is an HTML formated mail
$msg.isBodyhtml = $true      
# Send email
$smtp.send($msg)

#>
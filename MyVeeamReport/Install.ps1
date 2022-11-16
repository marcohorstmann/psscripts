#requires -Version 5.0
<#

    .DESCRIPTION
    Script to install MyVeeamReport

    .NOTES
    Author: Bernhard Roth
    Last Updated: 15 November 2022
    Version: 1.0

#>

# Customize to your requirements...
$Script = "C:\Temp\MyVeeamReport.ps1"
$Config = "C:\Temp\MyVeeamReport_config.ps1"
$Schedule = "C:\Temp\Schedule.ps1"


$URL_Script = "https://github.com/broth-itk/psscripts/raw/master/MyVeeamReport/MyVeeamReport.ps1"
$URL_Config = "https://github.com/broth-itk/psscripts/raw/master/MyVeeamReport/MyVeeamReport_config.ps1"
$URL_Schedule = "https://github.com/broth-itk/psscripts/raw/master/MyVeeamReport/Schedule.ps1"


# download latest version of script
Write-Information "Downloading latest version of script..."
try {
    Invoke-WebRequest -outfile $Script -uri $URL_Script
    Write-Information "The file [$Script] has been created."
} catch {
    throw $_.Exception.Message
}


# if the config file does not exist, create it.
if (-not(Test-Path -Path $Config -PathType Leaf)) {
    Write-Information "Downloading latest version of configuration file..."
    try {
        Invoke-WebRequest -outfile $Config -uri $URL_Config
        Write-Information "The file [$Config] has been created."
    } catch {
        throw $_.Exception.Message
    }
 }


# download schedule script
Write-Information "Downloading latest version of schedule script..."
try {
    Invoke-WebRequest -outfile $Schedule -uri $URL_Schedule
    Write-Information "Executing script..."
    Invoke-Expression -Command $Schedule
    Remove-Item $Schedule
    Write-Information "Scheduler set"
} catch {
    throw $_.Exception.Message
}

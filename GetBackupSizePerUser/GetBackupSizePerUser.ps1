<# 
   .SYNOPSIS
   Creates based on a folder for all subfolders with "_" in name a foldersize report

   .Notes 
   Version:        1.0
   Author:         Marco Horstmann (marco.horstmann@veeam.com)
   Creation Date:  01 Feb 2021
   Purpose/Change: Initial Release
   
   .LINK https://github.com/marcohorstmann/psscripts
   .LINK https://horstmann.in
 #>
### Customizable Parameter

#Which path should be scanned
$Path = "S:\"

# Report Title
$rptTitle = "Backup Size by User"
# HTML Report Width (Percent)
$rptWidth = 60

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

#
# MAIN CODE START
#

#Array to store the folder informations
$outputList = @()

#All folders from AD users having "_" in the path so this is used filtering other stuff in the repo like "Recyle Bin"
$userFolders = Get-ChildItem $Path | Where-Object { $_.Name -like "*_*" }

#Now get details for all folders
Foreach ($userFolder IN $userFolders) {
    # Get Folder content recursivly and sum up their sizes
    $userFolderSize = Get-Childitem $userFolder.FullName -Recurse |  Measure-Object -property length -sum
    # Nobody counts in bytes so we convert it to Gigabytes
    $userFolderSize = $userFolderSize.sum / 1GB
    # Build an output object
    $outputLine = New-Object PSObject -Property @{
        # Replace _ with \ to get the real username
        Username = $userFolder.Name.Replace("_","\")
        Foldersize = $userFolderSize
    }
    $outputList += $outputLine
}

# Building the mail report
# HTML Stuff (formating etc)

$htmlOutput = @"
<html>
    <head>
        <title>$rptTitle</title>
            <style>  
              table {font-family: Tahoma;width: $($rptWidth)%;font-size: 12px;border-collapse:collapse;}
              <!-- table tr:nth-child(odd) td {background: #e2e2e2;} -->
              th {text-align: left; }
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
                    <!-- <td style="width: 50%;height: 24px;border: none;font-size: 12px;vertical-align: bottom;text-align: right;padding: 0px 5px 2px 0px;"></td> -->
                </tr>
            </table>
            <table>
                <tr>
                    <td style="height: 35px;color: #626365;font-size: 16px;padding: 5px 0 0 15px;border-top: 5px solid white;border-bottom: none;align: left;">
"@

# Add Results to the html file and format it a little bit.
$htmlOutput += $outputList | Sort Foldersize -Descending | Select @{Name="Username"; Expression = {$_.Username}},
                                    @{Name="Folder Size (GB)"; Expression = {[math]::Round($_.Foldersize,2)}} | ConvertTo-HTML -Fragment

# Close HTML table
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
$msg.Subject = $rptTitle
# Make htmlOutput to body   ##ToDo Check if I can skip this step
$body = $htmlOutput
$msg.Body = $body
#define that this mail is an HTML formated mail
$msg.isBodyhtml = $true      
# Send email
$smtp.send($msg)

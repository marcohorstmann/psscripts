$BackupReport = @()
$agentBackup = Get-VBRBackup | Where-Object { (($_.JobType -match "EpAgentPolicy")) }

foreach($backup in $agentBackup) {

    $files = $backup.GetAllChildrenStorages() | ?{($_.CreationTime -ge (Get-Date).AddMonths(-1)) }
    #$files = $backup.GetChildrenAllStorages() | ?{($_.CreationTime -ge (Get-Date).AddMinutes(-15)) }

    $backupSize = 0

    foreach($file in $files) {
        $backupSize += [math]::Round([long]$file.Stats.BackupSize/1GB, 2)
    }

    $Backupsize = [PSCustomObject] @{
        Name = $backup.JobName
        "Backup Size (GB)" = $backupSize
    }

    $BackupReport += $Backupsize
}
$BackupReport | Format-Table * -AutoSize
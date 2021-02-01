$agentBackup = Get-VBRBackup -Name "Linux Agent Policy - lab-linux"
$files = $agentBackup.GetAllStorages() | ?{($_.CreationTime -ge (Get-Date).AddMonths(-1)) }
#$files = $agentBackup.GetAllStorages() | ?{($_.CreationTime -ge (Get-Date).AddMinutes(-15)) }
$backupSize = 0
Foreach($file IN $files) {
    $backupSize += [math]::Round([long]$file.Stats.BackupSize/1GB, 2)
}
Write-Host "Es wurden $backupSize GB gesichert"


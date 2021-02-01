Get-command -Module Veeam*



$job = Get-VBRJob -name "Linux Backup Job" <#| Start-VBRJob #>



$jobOptions = Get-VBRJobOptions -Job $job



$jobOptions.BackupTargetOptions.TransformToSyntethicDays = "Sunday"
#True = Disabled , False = scheduled
$jobOptions.JobOptions.RunManually = $true



Set-VBRJobOptions -Job $job -Options $jobOptions




$jobs = Get-VBRJob | Where-Object { $_.TypeToString -match "VMware Backup" }
Foreach ($currentJob IN $jobs) {
    $currentJobOptions = Get-VBRJobOptions -Job $currentJob
    $currentJobOptions.JobOptions.RunManually = $false
    Set-VBRJobOptions -Job $currentJob -Options $currentJobOptions
}


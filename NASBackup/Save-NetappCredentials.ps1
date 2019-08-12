#Script to store securely the password

$credential = Get-Credential

$credential | Export-CliXml -Path "C:\scripts\saved_credentials_Administrator.xml"

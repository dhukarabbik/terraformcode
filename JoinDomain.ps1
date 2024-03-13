param (
    [string]$DomainName,
    [string]$UserName,
    [string]$Password
)

# Import Active Directory module
Import-Module ActiveDirectory

# Join the domain
Add-Computer -DomainName $DomainName -Credential (New-Object System.Management.Automation.PSCredential($UserName, (ConvertTo-SecureString $Password -AsPlainText -Force)))

# Restart the computer after successful domain join
Restart-Computer
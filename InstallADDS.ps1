# Import Active Directory module
Import-Module ActiveDirectory

# Set variables
$DomainName = "mydomain.com" # Replace with your desired domain name
$SafeModeAdminPassword = "P@$$w0rd1234!" # Replace with a strong password

# Install AD DS role
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

# Promote server to a domain controller
Install-ADDSForest `
    -DomainName $DomainName `
    -SafeModeAdminPassword (ConvertTo-SecureString $SafeModeAdminPassword -AsPlainText -Force) `
    -ForestMode "Win2012R2" `
    -DomainMode "Win2012R2"

# Restart the server after successful installation
Restart-Computer
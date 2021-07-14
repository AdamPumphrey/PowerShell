<#

Assign-CalendarPermission.ps1 V1.00
Adam Pumphrey
Adapted from https://www.tachytelic.net/2014/06/grant-single-user-permissions-access-users-calenders-office-365/ 

Last Updated 7/12/2021

This script connects to Exchange Online and adds a mailbox permission to allow a user to view another user's
calendar availability.

Changelog

Adam Pumphrey V1.00
- Initial script + comments
  - script connects to Exchange Online and adds a mailbox permission for a user to another user's mailbox
  - requires Exchange Admin credentials

#>

[CmdletBinding()]
Param()

function Get-UserCredential {
    try {
        # $null removes garbage output
        $Credential = Get-Credential -Credential $null
        return $Credential
    } catch [System.Management.Automation.ParameterBindingException] {
        Read-Host "`nExiting program..."
        Exit
    }
}

# install exchange online module if not present
if (Get-Module -ListAvailable -Name ExchangeOnlineManagement) {
    Write-Verbose "ExchangeOnlineManagement already installed"
}
else {
    Write-Verbose "ExchangeOnlineManagement not already installed - install module"
    Install-Module -Name ExchangeOnlineManagement
}

# exchange admin credentials required
# username should be an email address eg) username_of_exch_admin@user.ca
$Credential = Get-UserCredential

$validated = $false

do {
    try {
        # connect to exchange online
        Connect-ExchangeOnline -Credential $Credential -ShowProgress $true -ShowBanner:$false
        $validated = $true
    } catch [System.AggregateException] {
        Write-Error "`nInvalid credentials - try again"
        $Credential = Get-UserCredential
    }
} until ($validated)

$userToAdd = "<user_to_grant_permissions_to@user.ca>"

# CHANGE THIS FOR EACH USER
# Example: $newUser = "apumphrey"
$newUser = "<target_user>"

$newUserIdentity = $newUser + ":\calendar"
Write-Verbose $newUserIdentity
# permission to grant
$access = "AvailabilityOnly"
Write-Verbose $access

# check for existing permissions (should be none)
$ExistingPermission = Get-EXOMailboxFolderPermission -Identity $newUserIdentity -User $userToAdd -ErrorAction SilentlyContinue

# if existing permissions - remove permissions
if ($ExistingPermission) {
    Remove-MailboxFolderPermission -Identity $newUserIdentity -User $userToAdd -Confirm:$false
}

# assign permissions
if ($newUser -ne $userToAdd) {
    Add-MailboxFolderPermission $newUserIdentity -User $userToAdd -AccessRights $access
}

Disconnect-ExchangeOnline

Read-Host "Press enter to exit"
<#

Remove-DeletedGroup V1.00
Adam Pumphrey

This script purges a previously deleted Microsoft 365 group from the "deleted groups" holding
area. Instead of the group being removed after 30 days (default), purging the group removes
it after 24 hours. Basically the equivalent of clearing an item from the recycle bin.

This script can only be ran after deleting a group from the Exchange Admin Center web portal.
(the group won't show up in the "deleted groups" otherwise)

Last updated: 7/16/2021

Changelog

Adam Pumphrey V1.00
- initial script

#>

[CmdletBinding()]
Param()

function Get-GroupName {
    <#
    function Get-GroupName
    This function lists the currently deleted groups, and then receives user input for 
    the group name or quits the script
    :return: $groupName (string)
    #>

    # list currently deleted groups
    Write-Host "`nDeleted groups:"
    Get-AzureADMSDeletedGroup | Select -ExpandProperty DisplayName | % { Write-Host $_ }
    #Write-Host $delGroups
    $groupName = Read-Host "`nEnter the name (or part of the name) of the deleted group, or q to quit"
    # q to quit script
    if ($groupName -match '^q$') {
        Read-Host "`nPress enter to exit"
        Disconnect-AzureAD
        exit
    }
    else {
        return $groupName
    }
}

# main script

# install Azure AD module if not present
if (Get-Module -ListAvailable -Name AzureAD) {
    Write-Verbose "AzureAD already installed"
}
else {
    Write-Verbose "AzureAD not already installed - install module"
    Install-Module -Name AzureAD
}

try {
    # connect to Azure AD
    # credentials should be an email address and password
    Connect-AzureAD | Out-Null
    $connected = $true
}
catch [Microsoft.Open.Azure.AD.CommonLibrary.AadAuthenticationFailedException] {
    Write-Error "`nAuthentication failed (may have been cancelled)" -Category AuthenticationError
    $connected = $false
}

if ($connected) {
    # while running
    $running = $true
    do {
        # name of deleted group you want to purge 
        # supports partial names eg. Adam Test Group or Adam, as long as there are no other groups with Adam in their name
        $groupName = Get-GroupName
    
        # while the group is not found
        $found = $false
        do {
            # get the ID of the group
            $id = Get-AzureADMSDeletedGroup -SearchString $groupName | % { $_.id }
            # if the group cannot be found
            if ($null -eq $id) {
                Write-Error "`nGroup not found" -Category InvalidArgument
                # restart
                $groupName = Get-GroupName
            }
            else {
                # ID exists, group is found
                $found = $true
            }
        } until ($found)
        Write-Verbose "group name has been found, name is $groupName"
    
        # purge the specified group
        Write-Host "`nDeleting group..."
        Remove-AzureADMSDeletedDirectoryObject -Id $id
        Write-Verbose "$groupName has been deleted"
    
        # list deleted groups again
        Write-Host "`nDeleted groups:"
        Get-AzureADMSDeletedGroup | Select -ExpandProperty DisplayName | % { Write-Host $_ }

        # while not validated
        $validated = $false
        do {
            # user confirmation that the group was purged
            $confirm = Read-Host "`nConfirm the group has been removed (y/n)"
            if ($confirm -match '^y$') {
                # stop script
                $running = $false
                $validated = $true
            }
            elseif ($confirm -match '^n$') {
                $validated = $true
                # try again
                Write-Host "`nRestarting..."   
            }
            else {
                Write-Error "`nInvalid input" -Category InvalidArgument
            }
        } until ($validated)
    } until (!$running)
}

Read-Host "`nPress enter to exit"
Disconnect-AzureAD
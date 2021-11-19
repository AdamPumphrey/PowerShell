<#

Adam-ADUser.psm1 V1.01

Last updated: 6/22/2021

Changelog

Adam Pumphrey V0.50
- moved functions from CreateADUser.ps1 into Adam-ADUser.psm1 module
- added some ignores for PSScriptAnalyzer's Credential warning
- changed CopyUser's default parameter implementation
- changed Confirm-User formatting
- general bug fixes

Adam Pumphrey V1.00
- moved functions from EditADUser.ps1 into Adam-ADUser.psm1 module
- fully operational

Adam Pumphrey V1.01
- removed Credential requirement since program is being run as admin
- fixed bug with editing username (actually using Confirm-Username now)
- removed home drive functionality

#>

function Get-Name {
    <#
    function Get-Name
    This function takes in and validates user input for a new user's name.
    Input validation checks for blank name (eg. pressing enter) and whitespace name (eg. space)
    :param: $NameStatus: string, used to change the input string (eg. first, last)
    :return: $nameItem (string)
    #>

    param (
        $NameStatus
    )
    

    $validated = $false
    do {
        Write-Host
        $nameItem = Read-Host "Enter the user's $NameStatus name (or q to cancel)"

        # check if name is blank or if name is just whitespace
        if ($nameItem.Length -eq 0 -or $nameItem -match "^\s+$") {
            Write-Error "`nError: User must have a $NameStatus name`n"
        }
        elseif ($nameItem -eq "q") {
            return "q"
        }
        else {
            # name is not empty and name is not just whitespace = name contains a character = valid
            $validated = $true
        }

    } until ($validated)

    return $nameItem
}

function Copy-User {
    <#
    function Copy-User
    This function takes in user input to create a new local AD user account.
    Uses a template AD account and user input to fill required properties.
    Adds newly created user to the same AD groups as the template AD account.
    Input validation and error checking/handling throughout.
    :return: $returnValue (String)
    #>

    param (
        $Domain
    )

    $validated = $false
    do {

        try {

            $existingUser = Read-Host "`nEnter user to copy from (or q to cancel)"
            if ($existingUser.Length -eq 0 -or $existingUser -match "^\s+$") {
                Write-Error "`nError: Template username cannot be blank`n" -Category InvalidArgument
            }
            elseif ($existingUser -eq "q") {
                Read-Host "`nExiting program"
                Exit
            }
            else {
                # get template AD user account as specified by user input
                # commented line contains homedrive properties
                # $userCopy = Get-ADUser $existingUser -Properties city, company, department, description, distinguishedname, fax, homedrive, homepage, manager, memberof, objectcategory, objectclass, office, passwordexpired, passwordneverexpires, passwordnotrequired, postalcode, state, streetaddress, title -ErrorAction Stop
                $userCopy = Get-ADUser $existingUser -Properties city, company, department, description, distinguishedname, fax, homepage, manager, memberof, objectcategory, objectclass, office, passwordexpired, passwordneverexpires, passwordnotrequired, postalcode, state, streetaddress, title -ErrorAction Stop
                $validated = $true
            }

            # template user does not exist 
        }
        catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
            Write-Error "`nError: User does not exist in local AD`n" -Category ObjectNotFound

            # incorrect credential information entered
        }
        catch [System.Security.Authentication.AuthenticationException] {
            Write-Error "`nError: Invalid login information`n" -Category AuthenticationError

            # if 'cancel' is pressed in credential window
        }
        catch [System.Management.Automation.ParameterBindingException] {
            Read-Host "`nExiting program"
            Exit
        }

    } until ($validated)

    # copy DistinguishedName for manipulation
    $userDistinguishedName = $userCopy.DistinguishedName

    # get and format user's first, last, and username
    $givenName = Get-Name -NameStatus "first"
    if ($givenName -eq "q") {
        Read-Host "`nExiting program"
        Exit
    }
    $surname = Get-Name -NameStatus "last"
    if ($surname -eq "q") {
        Read-Host "`nExiting program"
        Exit
    }
    $name = "$givenName $surname"
    $samAccountName = ($givenName.Substring(0, 1) + $surname).ToLower()

    $validated = $false
    do {

        try {
            # check if user-to-be-created already exists
            $newUserTest = Get-ADUser $samAccountName -ErrorAction SilentlyContinue

            # if the user does already exist
            if ($null -ne $newUserTest) {
                $samAccountName = Read-Host "`nUsername already exists. Enter a new username (or q to cancel)"
                if ($samAccountName -eq "q") {
                    Read-Host "`nExiting program"
                    Exit
                }
            }

            # if the user doesn't already exist
        }
        catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
            $validated = $true
        }
    
    } until ($validated)

    # keep phones blank - usually assigned later
    $officePhone = ""
    $mobilePhone = ""

    # create unique userPrincipleName (UPN), same as email
    #$userPrincipleName = $samAccountName + "@<domain>"
    $userPrincipleName = $samAccountName + $Domain
    $emailAddress = $userPrincipleName

    # get the OU path, garbageCatch simply catches useless data
    $garbageCatch, $path = $userDistinguishedName -split ',', 2
    # assign home directory to new user
    # $homeDirectory = "<home_path>" + $samAccountName
    # $homeDrive = 'Z:'

    $validated = $false
    do {

        # read in as secure string, decrypt to plaintext for string comparisons/regex matching
        $accountPassword1 = Read-Host "`nEnter password (or q to cancel)" -AsSecureString #user input
        
        # allocates memory for a binary string pointer, copies SecureString to unmanaged binary string
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($accountPassword1)
        # copies unmanaged binary string to managed string
        $accountPassword1 = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
        # frees binary string pointer allocated previously
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

        if ($accountPassword1 -eq "q") {
            Read-Host "`nExiting program"
            Exit
        }

        $accountPassword2 = Read-Host "Confirm password (or q to cancel)" -AsSecureString #user input - confirming password
        
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($accountPassword2)
        $accountPassword2 = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        # https://stackoverflow.com/questions/40503240/is-it-possible-to-hide-the-user-input-from-read-host-in-powershell

        if ($accountPassword2 -eq "q") { 
            Read-Host "`nExiting program"
            Exit
        }

        # if the passwords entered match each other (case-sensitive)
        if ($accountPassword1 -ceq $accountPassword2) {

            # password must be a minimum of 15 characters
            if ($accountPassword1.Length -ge 15) {

                # password must have uppercase and lowercase
                if ($accountPassword1 -cmatch "[A-Z]" -and $accountPassword1 -cmatch "[a-z]") {

                    # check if number in password
                    if ($accountPassword1 -match "\d+") {

                        # check for special character at any point in string
                        $regex = [regex]"[~!@#\$%\^&\*_\-\+=`\|\\\(\){}\[\]:;""'<>,\.\?\/]+"
                        if ($accountPassword1 -match $regex) {

                            # convert back to secure string
                            $accountPassword = ConvertTo-SecureString $accountPassword1 -AsPlainText -Force
                            $validated = $true
                            Remove-Variable accountPassword1
                            Remove-Variable accountPassword2

                        }
                        else {
                            Write-Error "`nError: Password must contain a special character`n" -Category InvalidArgument
                        }

                    }
                    else {
                        Write-Error "`nError: Password must contain a number`n" -Category InvalidArgument
                    }

                }
                else {
                    Write-Error "`nError: Password must contain Capital and lowercase characters`n" -Category InvalidArgument
                }

            }
            else {
                Write-Error "`nError: Password is too short. Minimum length is 15 characters`n" -Category InvalidArgument
            }

        }
        else {
            Write-Error "`nError: Passwords do not match`n" -Category AuthenticationError
        }

    } until ($validated)

    try {

        # create new user with info provided and copied from existing user
        # commented line contains homedrive properties
        # New-ADUser -GivenName $givenName -Surname $surname -Name $name -DisplayName $name -SamAccountName $samAccountName -HomeDirectory $homeDirectory -HomeDrive $homeDrive -AccountPassword $accountPassword -OfficePhone $officePhone -MobilePhone $mobilePhone -UserPrincipalName $userPrincipleName -EmailAddress $emailAddress -Path $path -Instance $userCopy -ErrorAction Stop
        New-ADUser -GivenName $givenName -Surname $surname -Name $name -DisplayName $name -SamAccountName $samAccountName -AccountPassword $accountPassword -OfficePhone $officePhone -MobilePhone $mobilePhone -UserPrincipalName $userPrincipleName -EmailAddress $emailAddress -Path $path -Instance $userCopy -ErrorAction Stop
        Write-Host "`nThe user $samAccountName has been created`n"

        # if the user already exists in the same OU as the template user
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityAlreadyExistsException] {
        Write-Error "`nError: User account already exists`n" -Category InvalidOperation

        # if the user already exists in a different OU as the template user
    }
    catch [Microsoft.ActiveDirectory.Management.ADException] {
        Write-Error "`nError: User account already exists in another OU`n" -Category InvalidOperation
    }

    # assign new user to the same groups as the template user
    Get-ADUser $existingUser -Properties memberof | Select-Object -ExpandProperty memberof | Add-ADGroupMember -Members $samAccountName
    # https://mikefrobbins.com/2014/01/30/add-an-active-directory-user-to-the-same-groups-as-another-user-with-powershell/

    $returnValue = $samAccountName
    return $returnValue
}

function Confirm-User {
    <#
    function Confirm-User
    This function grabs and displays the properties of the new AD user.
    User is asked to confirm that the information is correct.
    :param: $NewUsername: string, the username of the newly created user
    #>
    param (
        $NewUsername,
        $Domain
    )

    $confirmed = $false
    do {
        # get the new user's relevant properties
        # commented line contains homedrive properties
        # $newUser = Get-ADUser $NewUsername -Properties city, company, department, description, emailaddress, fax, givenname, homedirectory, homedrive, homepage, ipphone, manager, memberof, mobilephone, name, office, officephone, postalcode, samaccountname, state, streetaddress, surname, title
        $newUser = Get-ADUser $NewUsername -Properties city, company, department, description, emailaddress, fax, givenname, homepage, ipphone, manager, memberof, mobilephone, name, office, officephone, postalcode, samaccountname, state, streetaddress, surname, title

        $firstName = $newUser.GivenName
        $lastName = $newUser.Surname
        $username = $newUser.samAccountName
        $email = $newUser.EmailAddress
        $department = $newUser.Department
        $company = $newUser.Company
        $office = $newUser.Office
        $address = $newUser.StreetAddress
        $city = $newUser.City
        $province = $newUser.State
        $postalCode = $newUser.PostalCode
        $officePhone = $newUser.OfficePhone
        $mobilePhone = $newUser.MobilePhone
        $ipPhone = $newUser.ipPhone
        $fax = $newUser.Fax
        $description = $newUser.Description
        # $homeDirectory = $newUser.HomeDirectory
        # $homeDrive = $newUser.HomeDrive
        $title = $newUser.Title
        $homePage = $newUser.HomePage

        $manager = Get-Manager -Manager $newUser.Manager

        # 5 second pause to wait for groups to be assigned in AD
        Write-Host "`nGetting user information..."
        Start-Sleep -Seconds 5
        # grab groups assigned to the user
        # https://www.powershellbros.com/powershell-one-liner-get-ad-user-groups/
        $groups = (Get-ADUser -Identity $NewUsername -Properties memberof).memberof | Get-ADGroup | Select-Object Name | Sort-Object Name
        $groupString = ""
        $count = 0
        # format groups output
        foreach ($group in $groups) {
            if ($count -lt 1) {
                $groupName = $group.Name + "`n"
            }
            else {
                $groupName = "`t`t`t`t`t " + $group.Name + "`n"
            }

            $groupString += $groupName
            $count++
        }

        "`n"
        $formattedOutput = @"
                Please Verify the following information:
                ----------------------------------------------------------------
                First Name             = $firstName
                Last Name              = $lastName
                Username               = $username
                Email                  = $email
                Department             = $department
                Company                = $company
                Office                 = $office
                Address                = $address
                City                   = $city
                Province               = $province
                Postal Code            = $postalCode
                Office Phone           = $officePhone
                Mobile Phone           = $mobilePhone
                IP Phone               = $ipPhone
                Fax                    = $fax
                Description            = $description
                Title                  = $title
                Home Page              = $homePage
                Manager                = $manager
                Groups                 = $groupString
"@
        $formattedOutput
        "`n"
        Write-Host "Note: To edit Groups please go into AD and edit manually"
        $confirmChoice = Read-Host "Confirm user information? (Enter n to edit) (y/n)"
        # if user entered y or n
        if ($confirmChoice -eq "y" -or $confirmChoice -eq "n") {
            
            if ($confirmChoice -eq "n") {
                # start editor
                $editedUsername = Edit-User -Domain $Domain -Username $NewUsername -User $newUser -ReturnValue $true

                $editedUsername = $editedUsername[1]

                if ($editedUsername) {
                    $NewUsername = $editedUsername
                }
            }

            else {
                $confirmed = $true
            }
        }

        else {
            Write-Host
            Write-Error "`nInvalid selection`n" -Category InvalidArgument
        }

    } until ($confirmed)

}

function Show-Menu {
    <#
    function Show-Menu
    This function displays the program's menu
    #>
    Write-Host "`nPlease select a property to modify`n"
    Write-Host "1. First name"
    Write-Host "2. Last name"
    Write-Host "3. Username"
    Write-Host "4. Department"
    Write-Host "5. Office"
    Write-Host "6. Address"
    Write-Host "7. Postal Code"
    Write-Host "8. Phone (Office/IP/Mobile)"
    Write-Host "9. Fax"
    Write-Host "A. Description"
    Write-Host "B. Title"
    Write-Host "C. Home Page"
    Write-Host "D. Manager"
    Write-Host "E. Exit`n"
}

function Add-NewFullName {
    <#
    function Add-NewFullName
    This function sets the Name and DisplayName values in the hash table
    :param: $UserFirstName: string, the first name of the user
    :param: $UserLastName: string, the last name of the user
    :param: $HashTable: hash table, the hash table
    :return: $HashTable (Hash Table)
    #>
    param(
        $UserFirstname,
        $UserLastName,
        $HashTable
    )
    # set Name and DisplayName in hash table
    $HashTable["Name"] = "$UserFirstName $UserLastName"
    $HashTable["DisplayName"] = "$UserFirstName $UserLastName"
    return $HashTable

}

function Confirm-ValidInput {
    <#
    function Confirm-ValidInput
    This function reads in user input and verifies that its not blank or q to quit
    :return: $UserInput (String) or "q" (String)
    #>
    $validated = $false

    do {
        $UserInput = Read-Host "Enter new value (or q to cancel)"
        # check if input is blank or if input is just whitespace

        if ($UserInput.Length -eq 0 -or $UserInput -match "^\s+$") {
            Write-Error "`nError: Item entered cannot be blank`n" -Category InvalidArgument
        }

        elseif ($UserInput -eq "q") {
            return "q"
        }

        else {
            # item is not empty and item is not just whitespace = item contains a character = valid
            $validated = $true
        }

    } until ($validated)

    return $UserInput
    
}

function Confirm-NewValue {
    <#
    function Confirm -NewValue
    This function takes in user input related to confirming a previously entered value
    :param: $Value: string, the previously entered value for confirmation
    :return: $false (bool) or "q" (String) or "true" (String)
    #>
    param(
        $Value
    )

    $valid = $false

    do {
        Write-Host "`nNew value is" $value
        $confirm = Read-Host "Confirm new value (y/n or q to cancel)"
        # if input is y or n or q

        if ($confirm -eq "y" -or $confirm -eq "n" -or $confirm -eq "q") {
            $valid = $true

            if ($confirm -eq "y") {
                return "true"
            }

            elseif ($confirm -eq "q") {
                return "q"
            }

            else {
                return $false
            }
        }

        else {
            Write-Host
            Write-Error "`nInvalid selection`n" -Category InvalidArgument
        }

    } until ($valid)
}

function Invoke-NewValue {
    <#
    function Invoke-NewValue
    This function displays the current property's value and takes in a new value for said property
    :param: $CurrentValue: string, the value of the current property
    :param: $PropertyName: string, the current property
    :param: $Name: bool, flag to signal the property is a name (optional)
    :return: $false (bool) or $newValue (string)
    #>
    param(
        $CurrentValue,
        $PropertyName,
        [Parameter(Mandatory = $false)]
        $Name = $false
    )
    $validated = $false

    do {
        Write-Host "User's current $PropertyName is:" $CurrentValue

        if ($Name) {
            # enter new name value
            $newValue = Get-Name -NameStatus $Name
        }

        else {
            # enter new value
            $newValue = Confirm-ValidInput
        }

        if ($newValue -eq "q") {
            return $false
        }
        # check if value entered is what user intended
        $validated = Confirm-NewValue -Value $newValue

        if ($validated -eq "true") {
            $validated = $true
        }

        elseif ($validated -eq "q") {
            return $false
        }

    } until ($validated)

    return $newValue
}

function Invoke-NewManager {
    <#
    function Invoke-NewManager
    This function displays the current manager and takes in a new manager
    :param: $ManagerName: string, the name of the current manager
    :return: $newManager: (ADUser object)
    #>
    param(
        $ManagerName
    )

    $validated = $false
    do {

        try {
            $valid = $false

            do {
                Write-Host "`nCurrent manager is:" $ManagerName
                # get new manager's username
                $newManagerUsername = Read-Host "`nEnter username of new manager (or q to cancel)"

                if ($newManagerUsername -eq "q") {
                    return $false
                }
                $valid = Confirm-NewValue -Value $newManagerUsername

                if ($valid -eq "true") {
                    $valid = $true
                }

                elseif ($newManagerCheck -eq "q") {
                    return $false
                }

            } until ($valid)
            
            # test if new manager exists in AD
            $newManager = Get-ADUser $newManagerUsername
            $validated = $true

        }
        catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
            Write-Error "`nError: User does not exist in local AD`n" -Category ObjectNotFound
        }

    } until ($validated)

    return $newManager
}

function Confirm-Username {
    <#
    function Confirm-Username
    This function checks to see if an entered username is already in use
    :param: $Username: string, the username to be checked (optional)
    :return: $Username (string)
    #>
    param(
        [Parameter(Mandatory = $false)]
        $Username = $false
    )

    $validated = $false
    do {

        try {

            $valid = $false
            do {
                if (!$Username) {
                    # take in new username
                    $Username = Confirm-ValidInput
                    $valid = Confirm-NewValue -Value $Username
                }
                else {
                    $valid = $true
                }
            } until ($valid)
            

            # check if username already being used
            $newUserTest = Get-ADUser $Username -ErrorAction SilentlyContinue

            # if username taken
            if ($null -ne $newUserTest) {
                Write-Host "`nUsername name already exists. Enter a new username`n"
                $valid = $false
                do {
                    # take in new username
                    $Username = Confirm-ValidInput
                    if ($Username -eq "q"){
                        return $false
                    }
                    $valid = Confirm-NewValue -Value $Username
                    if ($valid -eq "q"){
                        return $false
                    }
                } until ($valid)
            }

            # if username is free
        }
        catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
            $validated = $true
        }
    
    } until ($validated)

    return $Username
}

function Get-Manager {
    <#
    function Get-Manager
    This function extracts a manager's first and last name from an AD User object
    :param: $Manager: ADUser Object, the manager
    :return: $result (string), the manager's first and last names
    #>
    param(
        $Manager
    )
    if ($null -eq $Manager) {
        return $null
    }
    # output the Manager property as a string
    $managerString = $Manager | Out-String
    # get the start position of manager's name (always starts with CN=)
    $startPos = $managerString.IndexOf('=') + 1
    # get the end position of manager's name (always a , at the end)
    $endPos = $managerString.IndexOf(',') - $startPos
    # grab the name substring from the Manager property
    $result = $managerString.Substring($startPos, $endPos)

    return $result
}

function Edit-Username {
    <#
    function Edit-Username
    This function modifies the samAccountName and its dependents for the user after a name change.
    :param: $changedData: hash table, the hash table containing changed data
    :param: $firstName: string, the first name of the user
    :param: $lastName: string, the last name of the user
    :return: $changedData (hash table), updated with the new data
    #>
    param(
        $changedData,
        $firstName,
        $lastName,
        $Domain
    )
    $newSamAccountName = ($firstName[0] + $lastName).ToLower()
    $changedData["samAccountName"] = $newSamAccountName
    #$newUserPrincipalName = $newSamAccountName + "@<domain>"
    $newUserPrincipalName = $newSamAccountName + $Domain
    $newEmailAddress = $newUserPrincipalName
    # $newHomeDirectory = "<home_path>" + $newSamAccountName
    $changedData["UserPrincipalName"] = $newUserPrincipalName
    $changedData["EmailAddress"] = $newEmailAddress
    # $changedData["HomeDirectory"] = $newHomeDirectory

    return $changedData
}

function Set-Properties {
    <#
    function Set-Properties
    This function creates a hash table for parameters and values and splats it to the Set-ADUser cmdlet
    :param: $Username: string, the username of the user that is being edited
    :param: $ChangedData: hash table, the hash table containing changed data
    :param: $Key: string, the key value of the data pair
    #>
    param(
        $Username,
        $ChangedData,
        $Key
    )
    $paramTable = @{
        Identity   = $Username
        $Key       = $ChangedData[$key]
    }

    Set-ADUser @paramTable
}

function Edit-User {
    <#
    function Edit-User
    This function allows for editing of ADUser properties

    Properties excluded from explicit editing:
    - Full name (updates automatically if changes are made to first/last name)
    - email, userprincipalname, homedirectory, homedrive - all samAccountName dependant
    - Company
    - City
    - Province (technically State)
    - Groups (MemberOf) - easier to just go into AD and remove/add groups that way

    Note:
    - samAccountName updates upon First/Last Name change

    :param: $Username: string, the username of the user to be edited (optional)
    :return: $User: ADUser Object, the user to be edited (optional)
    #>
    param (
        $Domain,
        [Parameter(Mandatory = $false)]
        $Username = $false,
        [Parameter(Mandatory = $false)]
        $User = $false,
        [Parameter(Mandatory = $false)]
        $ReturnValue = $false
    )

    $validated = $false
    do {

        try {

            if (!$Username) {
                $checked = $false

                do {
                    Write-Host
                    # take in username
                    $Username = Read-Host "Enter user to edit"

                    if ($Username.Length -eq 0 -or $Username -match "^\s+$") {
                        Write-Error "`nError: Item entered cannot be blank`n" -Category InvalidArgument
                    }

                    else {
                        $checked = $true
                    }

                } until ($checked)
            }

            if (!$User) {
                # get user to edit
                # commented line contains homedrive properties
                # $User = Get-ADUser $Username  -Properties city, company, department, description, distinguishedname, emailaddress, fax, givenname, homedirectory, homedrive, homepage, ipphone, manager, memberof, mobilephone, name, office, officephone, postalcode, samaccountname, state, streetaddress,surname, title
                $User = Get-ADUser $Username  -Properties city, company, department, description, distinguishedname, emailaddress, fax, givenname, homepage, ipphone, manager, memberof, mobilephone, name, office, officephone, postalcode, samaccountname, state, streetaddress,surname, title
                
            }
            # once all parameters are filled and checked they are valid
            $validated = $true
            
            # user does not exist 
        }
        catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
            Write-Error "`nError: User does not exist in local AD`n" -Category ObjectNotFound
            # reset username to false for user to re-enter username
            $Username = $false
            $User = $false

            # incorrect credential information entered
        }
        catch [System.Security.Authentication.AuthenticationException] {
            Write-Error "`nError: Invalid login information`n" -Category AuthenticationError

            # if 'cancel' is pressed in credential window
        }
        catch [System.Management.Automation.ParameterBindingException] {
            Write-Host "`nExiting editor..."
            Exit
        }

    } until ($validated)

    $changedData = @{}

    $runStatus = $true
    # while running
    do {

        $validated = $false
        do {
            Show-Menu
            # take in user choice
            $userChoice = Read-Host "Enter your selection"
            # selection matching regex
            $regex = [regex]"^[a-e]$|^[A-E]$|^[1-9]$"

            if ($userChoice -cmatch $regex) {
                $validated = $true
                # change user input to lowercase if capital was entered

                if ($userChoice -cmatch "^[A-E]$") {
                    $userChoice.ToLower()
                }
            }

            else {
                Write-Error "`nError: Invalid selection`n" -Category InvalidArgument
            }

        } until ($validated)

        switch ($userChoice) {

            # first name
            '1' {
                # get new first name
                if ($changedData["GivenName"]) {
                    $newFirstName = Invoke-NewValue -CurrentValue $changedData["GivenName"] -PropertyName "first name" -Name "first"
                } 

                else {
                    $newFirstName = Invoke-NewValue -CurrentValue $User.GivenName -PropertyName "first name" -Name "first"
                }

                if ($newFirstName) {
                    $changedData["GivenName"] = $newFirstName
                    # update full name
                    $changedData = Add-NewFullName -UserFirstname $newFirstName -UserLastName $User.Surname -HashTable $changedData
                    # update username for new name
                    #$names = $changedData["Name"].Split(' ')
                    #$changedData = Edit-Username -changedData $changedData -firstName $names[0] -lastName $names[1] -Domain $Domain
                }

                else {
                    Write-Host "Cancelling..."
                }
            }

            # last name
            '2' {
                # get new last name
                if ($changedData["Surname"]) {
                    $newLastName = Invoke-NewValue -CurrentValue $changedData["Surname"] -PropertyName "last name" -Name "last"
                }

                else {
                    $newLastName = Invoke-NewValue -CurrentValue $User.Surname -PropertyName "last name" -Name "last"
                }

                if ($newLastName) {
                    $changedData["Surname"] = $newLastName
                    # update full name
                    $changedData = Add-NewFullName -UserFirstname $User.GivenName -UserLastName $newLastName -HashTable $changedData
                    # update username for new name
                    #$names = $changedData["Name"].Split(' ')
                    #$changedData = Edit-Username -changedData $changedData -firstName $names[0] -lastName $names[1] -Domain $Domain
                }

                else {
                    Write-Host "Cancelling..."
                }     
            }

            # username
            '3' {
                # this does not check to see if first/last name matches!
                # this will allow you to create a username that does not match the user's name
                # get new username
                if ($changedData["samAccountName"]) {
                    $newSamAccountName = Invoke-NewValue -CurrentValue $changedData["samAccountName"] -PropertyName "username"
                }

                else {
                    $newSamAccountName = Invoke-NewValue -CurrentValue $User.samAccountName -PropertyName "username"
                }

                if ($newSamAccountName) {
                    $newSamAccountName = Confirm-Username -Username $newSamAccountName
                    $changedData["samAccountName"] = $newSamAccountName
                    # update dependents to match new username
                    #$newUserPrincipalName = $newSamAccountName + "@<domain>"
                    $newUserPrincipalName = $newSamAccountName + $Domain
                    $newEmailAddress = $newUserPrincipalName
                    # $newHomeDirectory = "<home_path>" + $newSamAccountName
                    $changedData["UserPrincipalName"] = $newUserPrincipalName
                    $changedData["EmailAddress"] = $newEmailAddress
                    # $changedData["HomeDirectory"] = $newHomeDirectory
                }

                else {
                    Write-Host "Cancelling..."
                }
            }

            # department
            '4' {
                # get new department
                if ($changedData["Department"]) {
                    $newDepartment = Invoke-NewValue -CurrentValue $changedData["Department"] -PropertyName "department"
                }

                else {
                    $newDepartment = Invoke-NewValue -CurrentValue $User.Department -PropertyName "department"
                }

                if ($newDepartment) {
                    $changedData["Department"] = $newDepartment
                }

                else {
                    Write-Host "Cancelling..."
                }
            }

            # office
            '5' {
                # get new office
                if ($changedData["Office"]) {
                    $newOffice = Invoke-NewValue -CurrentValue $changedData["Office"] -PropertyName "office location"
                }

                else {
                    $newOffice = Invoke-NewValue -CurrentValue $User.Office -PropertyName "office location"
                }

                if ($newOffice) {
                    $changedData["Office"] = $newOffice
                }

                else {
                    Write-Host "Cancelling..."
                }
            }

            # address
            '6' {
                # get new address
                if ($changedData["StreetAddress"]) {
                    $newAddress = Invoke-NewValue -CurrentValue $changedData["StreetAddress"] -PropertyName "street address"
                }

                else {
                    $newAddress = Invoke-NewValue -CurrentValue $User.StreetAddress -PropertyName "street address"
                }

                if ($newAddress) {
                    $changedData["StreetAddress"] = $newAddress
                }

                else {
                    Write-Host "Cancelling..."
                }
            }

            # postal code
            '7' {
                # get new postal code
                if ($changedData["PostalCode"]) {
                    $newPostalCode = Invoke-NewValue -CurrentValue $changedData["PostalCode"] -PropertyName "postal code"
                }

                else {
                    $newPostalCode = Invoke-NewValue -CurrentValue $User.PostalCode -PropertyName "postal code"
                }

                if ($newPostalCode) {
                    $changedData["PostalCode"] = $newPostalCode
                }

                else {
                    Write-Host "Cancelling..."
                }
            }

            # phone
            '8' {
                $validated = $false
                # pick which phone property to edit
                do {
                    Write-Host "1. Office Phone"
                    Write-Host "2. Mobile Phone"
                    Write-Host "3. IP Phone`n"
                    $selection = Read-Host "Enter your selection"
                    # selection matching regex
                    $regex = [regex]"^[1-3]$"

                    if ($selection -match $regex) {
                        $validated = $true
                    }

                    else {
                        Write-Error "`nError: Invalid selection`n" -Category InvalidArgument
                    }

                } until ($validated)

                if ($selection -eq 1) {
                    # get new office phone
                    if ($changedData["OfficePhone"]) {
                        $newPhone = Invoke-NewValue -CurrentValue $changedData["OfficePhone"] -PropertyName "office phone number"
                    }

                    else {
                        $newPhone = Invoke-NewValue -CurrentValue $User.OfficePhone -PropertyName "office phone number"
                    }

                    if ($newPhone) {
                        $changedData["OfficePhone"] = $newPhone
                    }

                    else {
                        Write-Host "Cancelling..."
                    }
                }

                # get new mobile phone
                elseif ($selection -eq 2) {

                    if ($changedData["MobilePhone"]) {
                        $newPhone = Invoke-NewValue -CurrentValue $changedData["MobilePhone"] -PropertyName "mobile phone number"
                    }

                    else {
                        $newPhone = Invoke-NewValue -CurrentValue $User.MobilePhone -PropertyName "mobile phone number"
                    }

                    if ($newPhone) {
                        $changedData["MobilePhone"] = $newPhone
                    }

                    else {
                        Write-Host "Cancelling..."
                    }
                }

                # get new IP phone
                else {

                    if ($changedData["ipPhone"]) {
                        $newPhone = Invoke-NewValue -CurrentValue $changedData["ipPhone"] -PropertyName "ip phone extension"
                    }

                    else {
                        $newPhone = Invoke-NewValue -CurrentValue $User.ipPhone -PropertyName "ip phone extension"
                    }

                    if ($newPhone) {
                        $changedData["ipPhone"] = $newPhone
                    }

                    else {
                        Write-Host "Cancelling..."
                    }
                }
            }

            # fax
            '9' {
                # get new fax
                if ($changedData["Fax"]) {
                    $newFax = Invoke-NewValue -CurrentValue $changedData["Fax"] -PropertyName "fax number"
                }

                else {
                    $newFax = Invoke-NewValue -CurrentValue $User.Fax -PropertyName "fax number"
                }

                if ($newFax) {
                    $changedData["Fax"] = $newFax
                }

                else {
                    Write-Host "Cancelling..."
                }
            }

            # description
            { $_ -eq "a" } {
                # get new description
                if ($changedData["Description"]) {
                    $newDescription = Invoke-NewValue -CurrentValue $changedData["Description"] -PropertyName "description"
                }

                else {
                    $newDescription = Invoke-NewValue -CurrentValue $User.Description -PropertyName "description"
                }

                if ($newDescription) {
                    $changedData["Description"] = $newDescription
                }

                else {
                    Write-Host "Cancelling..."
                }
            }

            # title
            { $_ -eq "b" } {
                # get new title
                if ($changedData["Title"]) {
                    $newTitle = Invoke-NewValue -CurrentValue $changedData["Title"] -PropertyName "title"
                }

                else {
                    $newTitle = Invoke-NewValue -CurrentValue $User.Title -PropertyName "title"
                }

                if ($newTitle) {
                    $changedData["Title"] = $newTitle
                }

                else {
                    Write-Host "Cancelling..."
                }
            }

            # home page
            { $_ -eq "c" } {
                # get new home page
                if ($changedData["HomePage"]) {
                    $newHomePage = Invoke-NewValue -CurrentValue $changedData["HomePage"] -PropertyName "home page"
                }

                else {
                    $newHomePage = Invoke-NewValue -CurrentValue $User.HomePage -PropertyName "home page"   
                }

                if ($newHomePage) {
                    $changedData["HomePage"] = $newHomePage
                }

                else {
                    Write-Host "Cancelling..."
                }
            }

            # manager
            { $_ -eq "d" } {
                # get new manager
                if ($changedData["Manager"]) {
                    $managerName = Get-Manager -Manager $changedData["Manager"]
                }
                
                else {
                    $managerName = Get-Manager -Manager $User.Manager
                }

                $newManager = Invoke-NewManager -ManagerName $managerName
                if ($newManager) {
                    $changedData["Manager"] = $newManager
                }
                
                else {
                    Write-Host "Cancelling..."
                }
            }

            # exit
            { $_ -eq "e" } {
                # exit editing
                $runStatus = $false
            }

            default {
                Write-Host
                Write-Error "`nUnexpected input: $_ Adjust regex accordingly`n" -Category InvalidArgument
            }
        }
        # until not running
    } until (!$runStatus)

    Write-Host "`nChanged values:"
    # for each property that was changed
    foreach ( $key in $changedData.Keys ) {

        # if the property is the full name
        if ($key -eq "Name") {
            Rename-ADObject -Identity $User.DistinguishedName -NewName $changedData["Name"] 
        }

        # if the property is the manager
        elseif ($key -eq "Manager") {
            $displayData = Get-Manager -Manager $changedData["Manager"]
            Set-Properties -Username $Username -ChangedData $changedData -Key $key 
        }

        # if the property is the username
        elseif ($key -eq "samAccountName") {
            Set-Properties -Username $Username -ChangedData $changedData -Key $key 
            $Username = $changedData["samAccountName"]
        }

        # if the property is the ip phone
        elseif ($key -eq "ipPhone") {
            Set-ADUser -Identity $Username -Replace @{ ipPhone = $changedData[$key] }
        }

        else {
            # set property for user with new value
            Set-Properties -Username $Username -ChangedData $changedData -Key $key

        }

        # display property and new value
        if ($key -ne "Manager") {
            $displayData = $changedData[$key]
        }
        Write-Host $key":" $displayData
    }
    Read-Host "`nPress enter to exit editor"
    if ($ReturnValue) {
        if ($changedData["samAccountName"]) {
            $ReturnValue = $changedData["samAccountName"]
        }
        else {
            $ReturnValue = $false
        }
        return $ReturnValue
    }
}
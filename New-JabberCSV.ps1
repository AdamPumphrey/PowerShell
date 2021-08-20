<#

New-JabberCSV V1.00
Adam Pumphrey

This script reads in two .csv files - each formatted to be used for Jabber - and fills in formatted user
data from AD to their corresponding cells in the .csv files

Requires Admin credentials

CSV Specifications:
- .csv files are expected to be correctly formatted for Jabber - see jabber_iphone.csv and jabber_android.csv for reference
- the number of rows in the .csv files should = the number of users in AD + 1
  - to find this number follow the steps below:
    1. open a PowerShell console as Admin
    2. run the following commands:
        a. $count = 0
        b. $adusers = Get-ADUser -Filter *
        c. foreach ($user in $adusers) {$count++}
        d. $count
    3. add 1 to the number displayed after $count
    eg. if $count gives me 400 after those steps, I need 401 rows in my csv, since row 1 is the header and the next 
        400 rows will be for the AD users
- the starting .csv files must be named jabber_iphone.csv and jabber_android.csv
    
Last updated: 8/11/2021

Changelog:

Adam Pumphrey V1.00
- initial script

#>

function Get-UserCredential {
    <#
    function Get-UserCredential
    This function takes in a credential entered by the user
    :return: $Credential (PSCredential object)
    #>
    try {
        # $null removes garbage output
        $Credential = Get-Credential -Credential $null
        return $Credential
    }
    catch [System.Management.Automation.ParameterBindingException] {
        Read-Host "`nExiting program..."
        Exit
    }
}

# initialize specific cells as constants
Set-Variable A -Option ReadOnly -Value "Device Name"
Set-Variable B -Option ReadOnly -Value "Description"
Set-Variable AL -Option ReadOnly -Value "User ID 1"
Set-Variable AN -Option ReadOnly -Value "Owner User ID"
Set-Variable EI -Option ReadOnly -Value "Directory Number 1"
Set-Variable FR -Option ReadOnly -Value "External Phone Number Mask 1"
Set-Variable GB -Option ReadOnly -Value "Line Description 1"
Set-Variable GC -Option ReadOnly -Value "Alerting Name 1"
Set-Variable GD -Option ReadOnly -Value "ASCII Alerting Name 1"
Set-Variable GJ -Option ReadOnly -Value "Display 1"
Set-Variable GK -Option ReadOnly -Value "ASCII Display 1"

$date = Get-Date -Format "MM/dd/yyyy HH:mm"
$date = $date.Replace(" ", "_").Replace(":", "").Replace("/", "_")

# get filenames for iPhone csvs
$iPhoneFilename = "jabber_iphone.csv"
# create jabber_iphone_new filename
$newiPhoneFilename = "<save_path>" + $iPhoneFilename.Split(".")[0] + "_new" + $date + ".csv"

# get filenames for Android csvs
$androidFilename = "jabber_android.csv"
# create jabber_android_new filename
$newAndroidFilename = "<save_path>" + $androidFilename.Split(".")[0] + "_new" + $date + ".csv"

# admin credentials
$Credential = Get-UserCredential

# get list of all AD users and their specific properties
$adUsers = Get-ADUser -Credential $Credential -Filter * -Properties samAccountName, Name, ipPhone, OfficePhone

# import the two csvs to be filled in
$iPhonecsv = @(Import-Csv $iPhoneFilename)
$androidcsv = @(Import-Csv $androidFilename)

# we start at the first row of data
$index = 0

# and we move through each row of data until the end of the csv/ad user list.
# csv's length matches the number of AD users we have
while ($index -lt $iPhonecsv.Length) {
    # assign values to the corresponding cells for each row of data
    $iPhonecsv[$index].$A = "<iPhone>" + $adUsers[$index].samAccountName.ToUpper()
    $androidcsv[$index].$A = "<android>" + $adUsers[$index].samAccountName.ToUpper()

    $iPhonecsv[$index].$B = $adUsers[$index].Name + " Jabber for iPhone"
    $androidcsv[$index].$B = $adUsers[$index].Name + " Jabber for Android"

    $iPhonecsv[$index].$AL = $adUsers[$index].samAccountName
    $androidcsv[$index].$AL = $adUsers[$index].samAccountName

    $iPhonecsv[$index].$AN = $adUsers[$index].samAccountName
    $androidcsv[$index].$AN = $adUsers[$index].samAccountName

    $iPhonecsv[$index].$EI = $adUsers[$index].ipPhone
    $androidcsv[$index].$EI = $adUsers[$index].ipPhone

    # strip the leading 1 if the user has a phone number assigned
    if ($null -ne $adUsers[$index].OfficePhone) {
        $iPhonecsv[$index].$FR = $adUsers[$index].OfficePhone.Substring(1)
        $androidcsv[$index].$FR = $adUsers[$index].OfficePhone.Substring(1)
    } else {
        $iPhonecsv[$index].$FR = $adUsers[$index].OfficePhone
        $androidcsv[$index].$FR = $adUsers[$index].OfficePhone
    }
    
    $iPhonecsv[$index].$GB = $adUsers[$index].Name
    $androidcsv[$index].$GB = $adUsers[$index].Name

    $iPhonecsv[$index].$GC = $adUsers[$index].Name
    $androidcsv[$index].$GC = $adUsers[$index].Name

    $iPhonecsv[$index].$GD = $adUsers[$index].Name
    $androidcsv[$index].$GD = $adUsers[$index].Name

    $iPhonecsv[$index].$GJ = $adUsers[$index].Name
    $androidcsv[$index].$GJ = $adUsers[$index].Name

    $iPhonecsv[$index].$GK = $adUsers[$index].Name
    $androidcsv[$index].$GK = $adUsers[$index].Name

    # move to next row of data
    $index++
}

# export results to new csv files
$iPhonecsv | Export-Csv -Path $newiPhoneFilename -Append -NoTypeInformation
$androidcsv | Export-Csv -Path $newAndroidFilename -Append -NoTypeInformation

Read-Host "Press enter to exit"
<#

Get-PreMigrationReport V1.02
Adam Pumphrey

Last Updated 7/12/2021

Changelog

Adam Pumphrey V1.00
- initial script
  - this script creates a .csv report of all files in the specified user's Z: drive (home directory)
    - accessed via location on the server hosting the data (mapped to the Z: drive for the user via AD)
  - the report displays the file name, size, type, and the date it was last edited

Adam Pumphrey V1.01
- added loop for multiple reports
- added skip for $RECYCLE.BIN items

Adam Pumphrey V1.02
- Fixed $RECYCLE.BIN regex
  - previously was evaluating as ".BIN", where "." acts as a wildcard character
  - changed to evaluate as ".RECYCLE.BIN", which should catch $RECYCLE.BIN items

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
    } catch [System.Management.Automation.ParameterBindingException] {
        Read-Host "`nExiting program..."
        Exit
    }
}

function Get-Name {
    param (
        $NameStatus
    )
    <#
    function Get-Name
    This function takes in and validates user input for a username
    Input validation checks for blank (eg. enter) and whitespace input
    :return: $nameItem (string)
    #>

    $validated = $false
    do{
        Write-Host
        $nameItem = Read-Host "Enter username"

        # check if name is blank or if name is just whitespace
        if ($nameItem.Length -eq 0 -or $nameItem -match "^\s+$") {
            Write-Host
            Write-Host "Error: Username is blank" -ForegroundColor Red
        }

        else {
            # name is not empty and name is not just whitespace = name contains a character = valid
            $validated = $true
        }

    } until ($validated)

    return $nameItem
}

$Credential = Get-UserCredential

# start remote powershell session on server
$session = New-PSSession -ComputerName "<server>" -Credential $Credential -ErrorAction SilentlyContinue

# if connection successful
if (Get-PSSession) {
    $runStatus = $true
    do {
        $path = "<homedirectory_path>"
        $user = Get-Name
        # create homedirectory path eg.) D:\Homedirectories\AdamPumphrey
        $userPath = $path + $user

        # test $userPath to see if user's homedirectory is on the server
        $pathTest = Invoke-Command -Session $session -ScriptBlock { Test-Path -Path $Using:userPath }
        # if test successful
        if ($pathTest) {
            Write-Host "`nGathering files...`n"
            # list all files in user's home directory
            $items = Invoke-Command -Session $session -ScriptBlock { Get-ChildItem -Path $Using:userPath -Recurse -Force }

            # format report filename
            $date = Get-Date -Format "MM/dd/yyyy HH:mm"
            $date = $date.Replace(" ", "_")
            $date = $date.Replace(":", "")
            $date = $date.Replace("/", "_")
            # eg) AdamPumphrey_01_01_21_1400 = Adam Pumphrey on Jan 1, 2021 at 2:00pm
            $newFile = $user + "_" + $date + ".csv"
            # report filename
            $newPath = "<output_path>" + $newFile

            # regex to ignore items with $RECYCLE.BIN in the path
            $recycleRegex = "`.RECYCLE.BIN"

            # for each file in user's home directory
            foreach ($i in $items) {
                # skip items with $RECYCLE.BIN in path
                if ($i.PSPath -notmatch $recycleRegex) {
                    # last time file was written to
                    $fileAge = $i.LastWriteTime

                    # file size in MB (2 decimal place rounding)
                    $fileSize = $i.Length/1MB
                    $fileSize = [math]::Round($fileSize,2)

                    # remove root from filepath (eg. D:\Homedirectories\AdamPumphrey\test becomes test since D:\Homedirectories\AdamPumphrey is constant for all items)
                    $rawItemName = $i.FullName.Split("\")
                    $itemName = ''
                    for ($count = 3; $count -lt $rawItemName.Length; $count++) {
                        $itemName += $rawItemName[$count]
                        if ($count -ne $rawItemName.Length-1) {
                            $itemName += "\"
                        }
                    }

                    # check if item is a directory
                    $tempPath = $i.FullName
                    $result = Invoke-Command -Session $session -ScriptBlock { (Get-Item -Path $Using:tempPath -Force) -is [System.IO.DirectoryInfo] }
                    if ($result) {
                        $extension = 'folder'
                    }
                    else {
                        $extIndex = $itemName.LastIndexOf('.')
                        # $extindex <= 0 shouldn't ever happen, but if it does the extension will be blank
                        if ($extIndex -le 0) {
                            $extension = ''
                        } 
                        else {
                            $extension = $itemName.Substring($extIndex)
                        }
                    }

                    # create new object for csv appending
                    $wrapper = New-Object psobject -Property @{ Filename = $itemName; Extension = $extension; 'Size (MB)' = $fileSize; Age = $fileAge }
                    # append data for this file to the report
                    $wrapper | Select Filename, Extension, 'Size (MB)', Age | Export-Csv $newPath -Append -NoTypeInformation
                }
            }
            Write-Host "Report complete!`n"

            $restart = Read-Host "Restart for another user? (y/n)"
            if ($restart -ne "y") {
                $runStatus = $false
            }
        }
        else {
            Write-Error "User path does not exist"
        }
    } until (!$runStatus)
    $session | Remove-PSSession
}
else {
    Write-Error "Could not establish PSSession"
}

Read-Host "Press enter to exit"
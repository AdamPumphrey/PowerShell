<#

Get-BulkPreMigrationReport V1.03
Adam Pumphrey 

Last Updated 8/4/2021

Changelog

Adam Pumphrey V1.02
- adapted script from Get-PreMigrationReport.ps1

Adam Pumphrey V1.03
- added in functionality to skip users that have already been reported on
- added check to confirm that homedrive reported is the assigned homedrive in AD
- chained .Replace functions

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

if (Get-Module -ListAvailable -Name ActiveDirectory) {
}
else {
    Install-Module -Name ActiveDirectory
}


$Credential = Get-UserCredential

# create list of users that have already had a report generated
$userList = @()

# for debugging purposes
#if (Get-PSSession) {
#    Get-PSSession | % { Remove-PSSession $_.id }
#}
$runCount = 0
do {
    # start remote powershell session on servers
    if ($runCount -lt 1) {
        $session = New-PSSession -ComputerName "<server1>" -Credential $Credential -ErrorAction SilentlyContinue
    }
    else {
        $session = New-PSSession -ComputerName "<server2>" -Credential $Credential -ErrorAction SilentlyContinue
    }

    # if connection successful
    if (Get-PSSession) {
        # server1 path
        if ($runCount -lt 1) {
            $path = "<path1>"
        # server2 path
        }
        else {
            $path = "<path2>"
        }

        $csv = Import-Csv "users.csv"
        
        foreach ($user in $csv.Folder) {
            # skip users that have already had a report generated
            # they should only have a drive on one of the servers, not both
            # though it is possible to have a drive on both, we check for that later
            if ($user -notin $userList) {
                $userPath = $path + $user
                # test $userPath to see if user's homedirectory is on the server
                $pathTest = Invoke-Command -Session $session -ScriptBlock { Test-Path -Path $Using:userPath }
                # if test successful
                if ($pathTest) {
                    Write-Host "`nGathering files...`n"
                    # retrive all files in user's home directory
                    $items = Invoke-Command -Session $session -ScriptBlock { Get-ChildItem -Path $Using:userPath -Recurse -Force }

                    # format report filename
                    $date = Get-Date -Format "MM/dd/yyyy HH:mm"
                    $date = $date.Replace(" ", "_").Replace(":", "").Replace("/", "_")
                    $newFile = $user + "_" + $date + ".csv"
                    # report filename
                    $newPath = "<output_path>" + $newFile

                    $recycleRegex = "`.RECYCLE.BIN"
                    $dcount = 0
                    # for each file in user's home directory
                    foreach ($i in $items) {
                        # skip items with $RECYCLE.BIN in path
                        if ($i.PSPath -notmatch $recycleRegex) {
                            $dcount += 1
                            Write-Host "count is" $dcount
                            # last time file was written to
                            $fileAge = $i.LastWriteTime

                            # file size in MB (2 decimal place rounding)
                            $fileSize = $i.Length / 1MB
                            $fileSize = [math]::Round($fileSize, 2)

                            # remove root from filepath (eg. D:\Homedirectories\AdamP\test becomes test since D:\Homedirectories\AdamP is constant for all items)
                            $rawItemName = $i.FullName.Split("\")
                            $itemName = ''
                            for ($count = 3; $count -lt $rawItemName.Length; $count++) {
                                $itemName += $rawItemName[$count]
                                if ($count -ne $rawItemName.Length - 1) {
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
                    # check to see if report pulled matches assigned homedirectory in AD
                    # this accounts for if a user has a drive in server1 and server2
                    # this happened one time, the user had their homedrive as server2 in AD, but had a drive in server1 as well
                    # the assigned drive is the correct drive, so if we find the assigned drive first, then no need to check
                    # for the existence of the other drive
                    $homedir = (Get-ADUser $user -Credential $Credential -Properties HomeDirectory).HomeDirectory
                    $homedir = $homedir.substring(2,13).ToUpper();
                    if ($runCount -lt 1 -and $homedir -eq "<server1>") {
                        # add user to user list
                        $userList += $user
                    }
                    Write-Host "Report complete!`n"
                }
            }
        }
                
        $session | Remove-PSSession
    }
    else {
        Write-Error "Could not establish PSSession"
    }
    $runCount++
} while ($runCount -lt 2)

Read-Host "Press enter to exit"
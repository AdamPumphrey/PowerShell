<#

Get-NetworkDriveReport V1.00
Adam Pumphrey

This script reads in a .csv file containing a list of network drives and their respective servers, connects to the servers,
and gathers the following information for each network drive: number of folders, number of files, overall size (GB).

The credentials provided must be admin credentials.

Last updated: 8/4/2021

Changelog

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

function Stop-PSSessions {
    <#
    function Stop-PSSessions
    This function clears all existing PSSessions
    #>
    if (Get-PSSession) {
        Get-PSSession | % { Remove-PSSession $_.id }
    }
}

$Credential = Get-UserCredential

$serverName = ""

$csv = Import-Csv "drives.csv"

$data = @()

# format date
# eg. 07_29_2021_1400 = July 29, 2021 at 2:00pm
$date = Get-Date -Format "MM/dd/yyyy HH:mm"
$date = $date.Replace(" ", "_").Replace(":", "").Replace("/", "_")
# report filename
$newFile = "networkdrives_" + $date + ".csv"
# save path
$reportPath = "<savepath>" + $newFile

# for each network drive in the .csv file
foreach ($line in $csv) {
    $startDate = Get-Date
    # if not already connected to the server
    if ($serverName -ne $line.Server) {
        $serverName = $line.Server
        # clear existing PSSsessions
        Stop-PSSessions
        # connect to server via PSSession
        $session = New-PSSession -ComputerName $serverName -Credential $Credential -ErrorAction SilentlyContinue
    }
    $fileCount = 0
    $folderCount = 0
    # gets around file path length restrictions
    $location = "\\?\" + $line.Location
    # get all child items from network drive
    # not recursing on very top level since we recurse into folders later
    # very top level will be eg. D:\Name, splitting on \ gives us two items
    # next level down (recursing level) will be D:\Name\Name2, giving us != 2 items after split on \
    if ($line.Location.Split("\").Length -eq 2) {
        $dirItems = Invoke-Command -Session $session -ScriptBlock { Get-ChildItem $Using:line.Location -Force }
    } else {
        $dirItems = Invoke-Command -Session $session -ScriptBlock { Get-ChildItem $Using:location -Recurse -Force }
    }
    # for each item in the network drive
    foreach ($i in $dirItems) {
        # if the item is a folder
        if (Invoke-Command -Session $session -ScriptBlock { (Get-Item -Path $Using:i.FullName -Force) -is [System.IO.DirectoryInfo] }) {
            # increase folder count
            $folderCount++
        }
        # if the item is not a folder
        else {
            # increase file count
            $fileCount++
        }
    }

    # create object to be written to report file 
    $data += New-Object psobject -Property @{
        # network drive name
        NetworkDrive = $line.Location.Substring(3)
        FolderCount = $folderCount
        FileCount = $fileCount
        # total size of network drive in GB
        'DriveSize (GB)' = ($dirItems | Measure-Object -Property Length -Sum).Sum / 1GB
    }
    $endDate = Get-Date
    Write-Host "`n$serverName" $line.Location
    New-TimeSpan -Start $startDate -End $endDate
}

# write data to report file
$data | Select NetworkDrive, FolderCount, FileCount, 'DriveSize (GB)' | Export-Csv $reportPath -Append -NoTypeInformation

# clear leftover PSSsession
Stop-PSSessions

Write-Host "Report complete!"

Read-Host "`nPress enter to exit"
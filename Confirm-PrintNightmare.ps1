<#

Confirm-PrintNightmare V1.02
Adam Pumphrey

Last updated: 7/30/2021

This script checks to see if the local machine's Print Spooler service is running.
If the service is running, the script checks to see if the machine has the proper 
Microsoft update installed, and has the correct values set for specific registry keys, if they exist

Changelog

Adam Pumphrey V1.00
- initial script

Adam Pumphrey V1.01
- more descriptive output
- changed NoWarningNoElevationOnUpdate to UpdatePromptSettings
- Added check for Print Spooler service status
- removed useless try-catch block

Adam Pumphrey V1.02
- added date check for security updates since they are cumulative
  - a later update will overwrite the actual PrintNightmare patch
  - the later update includes the PrintNightmare patch
  - therefore, checking to see if a later security update was installed is sufficient
- changed "Patch not applied" message

#>

function IsVulnerable {
    <#
    function IsVulnerable
    This function is called if a system is vulnerable to PrintNightmare (as of July 8, 2021, 12:00pm).
    This function will tell the user that the system is vulnerable, and exit the program after.
    #>
    param (
        [Parameter(Mandatory = $false)]
        $Option = 0,
        [Parameter(Mandatory = $false)]
        $Name = ''
    )
    Write-Host "System is vulnerable" -ForegroundColor Red
    if ($Option -eq 1) {
        Write-Host "System has not been patched" -ForegroundColor Red
    }
    elseif ($Option -eq 2) {
        Write-Host "Registry key" $Name "not set" -ForegroundColor Red
    }
    Read-Host "`nPress enter to exit"
    exit
}

function CheckMatch {
    <#
    function CheckMatch
    This function checks the value of $Match that is passed in.
    If $Match is true, the system is not vulnerable.
    :param: $Match: bool, boolean value referencing if the system is vulnerable
    #>
    param (
        $Match
    )
    # if $match is false
    if (!$match) {
        # system is vulnerable
        IsVulnerable -Option 1
    }
}

function CheckRegKey {
    <#
    function CheckRegKey
    This function checks to see if a specific registry key exists.
    If the registry key exists, it checks the value of the key.
    If the value of the key is not the expected value, the system is vulnerable.
    :param: $Path: string, the path to the registry key's folder
    :param: $Name: string, the name of the registry key
    :param: $Reverse: bool, flag to signal the value to check for is 1 instead of 0 (optional)
    :return: nothing, just present to break from the function
    #>
    param (
        $Path,
        $Name,
        [Parameter(Mandatory = $false)]
        $Reverse = $false
    )
    $fullPath = $Path + '\' + $Name 
    # check if registry key exists
    if ((Get-ItemProperty $Path -ErrorAction SilentlyContinue).$Name -eq $true) {
        $regKeyExists = $true
    } else {
        $regKeyExists = $false
    }
    
    # if registry key exists
    if ($regKeyExists) {
        $regKeyValue = Get-ItemPropertyValue -Path $Path -Name $Name
    }
    else {
        # registry keys not existing = default values = safe
        return
    }
    
    # if checking for registry key value of 1
    if ($Reverse) {
        if ($regKeyValue -ne 1) {
            # system is vulnerable
            IsVulnerable -Option 2 -Name $fullPath
        }
    } else {
        # check for registry key value of 0
        if ($regKeyValue -ne 0) {
            # system is vulnerable
            IsVulnerable -Option 2 -Name $fullPath
        }
    }
    
}

# main program

$spoolerStatus = Get-Service Spooler | % { $_.Status }

if ($spoolerStatus -eq "Running") {
    $windowsUpdates = Get-HotFix
    <#
    reverse array of windows updates since printnightmare fix was recent, therefore it is 
    likely to be near the end (now the beginning), and thus more likely to be found quickly.
    less searching is more efficient, we increase the odds of finding it quickly to reduce runtime.
    #>
    [array]::Reverse($windowsUpdates)

    # match all possible printnightmare updates
    $regex = "^KB500494[5-8]$|^KB500495[0-13-68-9]$|^KB5004960$"

    # release date of the patch (July 6)
    $releaseDate = Get-Date 2021/7/6
    $secDate = Get-Date 1999/12/31

    # check to see if any of the installed updates match any printnightmare updates
    $match = $false
    foreach ($update in $windowsUpdates) {
        if ($update.HotFixID -cmatch $regex) {
            $match = $true
            break
        # if the update is not a match and is a Security Update
        } elseif ($update.Description -eq "Security Update") {
            # get update install date
            if ($update.InstalledOn -ge $secDate) {
                $secDate = $update.InstalledOn
            }
        }
    }

    if (!$match) {
        # check if security updates have been installed since the patch release date
        # since updates are cumulative, later updates include the patch
        if ($secDate -ge $releaseDate) {
            # the logic here is that if a security update was installed past the release date of the patch,
            # that security update will include the patch since updates are cumulative
            $match = $true
        }
    }

    CheckMatch($match)

    # check if correct registry keys exist
    # if the registry keys exist, check if they have the correct value
    # https://www.jonathanmedd.net/2014/02/testing-for-the-presence-of-a-registry-key-and-value.html
    $path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint'

    $name = 'NoWarningNoElevationOnInstall'
    CheckRegKey -Path $path -Name $name
    #$name = 'NoWarningNoElevationOnUpdate'
    $name = 'UpdatePromptSettings'
    CheckRegKey -Path $path -Name $name
    $name = 'RestrictDriverInstallationToAdministrators'
    CheckRegKey -Path $path -Name $name -Reverse $true

    Write-Host "This system is protected from PrintNightmare" -ForegroundColor Green
    Read-Host "`nPress enter to exit"

} elseif ($spoolerStatus -eq "Stopped") {
    $spoolerStartup = Get-Service Spooler | % { $_.StartType }

    Write-Host "This system is protected from PrintNightmare" -ForegroundColor Green
    if ($spoolerStartup -ne "Disabled") {
        Write-Host "Print Spooler Service is stopped but not disabled" -ForegroundColor Yellow
    }
    
    Read-Host "`nPress enter to exit"

} else {
    Write-Host "This system is protected from PrintNightmare" -ForegroundColor Green
    Write-Host "Spooler service is paused" -ForegroundColor Yellow
    Read-Host "`nPress enter to exit"
}

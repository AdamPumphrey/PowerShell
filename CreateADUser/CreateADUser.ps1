<#

CreateADUser.ps1 V1.00

Last updated: 6/24/2021

Changelog

Adam Pumphrey V0.10
- initial script
  - script creates a new AD user using information from template user and hard-coded variables
  - new AD user is created in same OU as template user
  - new AD user is assigned the same groups as the template user

Adam Pumphrey V0.20
- added user input and input validation
- created Get-Name function for user input first and last names

Adam Pumphrey V0.30
- added error-checking and exception-handling
- general improvements
- added Copy-User function for main program restarting

Adam Pumphrey V0.40
- added Confirm-User function
  - check user's properties after creation
- added return values for Copy-User
- added whitespace name check in Get-Name

Adam Pumphrey V0.42
- added comments, spacing
- fixed Copy-User not asking for new credentials after incorrect credentials entered

Adam Pumphrey V0.50
- moved functions into Adam-ADUser.psm1 module

Adam Pumphrey V1.00
- self-elevates to run as admin
  - no need for $credential
- auto-installs module from network drive

#>

# main program

# self-elevates to run as admin
# https://stackoverflow.com/a/57035712
try {
    if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Start-Process PowerShell -Verb RunAs "-NoProfile -ExecutionPolicy Bypass -Command `"cd '$pwd'; & '$PSCommandPath';`"";
        exit;
    }
} catch [System.InvalidOperationException] {
    Exit
}

# install module - if module already installed, it will still replace module files
# keeps module up to date each run
$destPath = "C:\Program Files\WindowsPowerShell\Modules\Adam-ADUser"
$moduleDestPath = "C:\Program Files\WindowsPowerShell\Modules\Adam-ADUser\Adam-ADUser.psm1"
$manifestDestPath = "C:\Program Files\WindowsPowerShell\Modules\Adam-ADUser\Adam-ADUser.psd1"
$moduleSourcePath = "<module_path>"
$manifestSourcePath = "<manifest_path>"

# create module directory if it doesn't already exist
if (!(Test-Path $destPath)) {
    New-Item -ItemType Directory -Path $destPath
}

$moduleFound = $false
# remove current module file
if (Test-Path $moduleDestPath) {
    $moduleFound = $true
    Remove-Item $moduleDestPath -Force
}

# remove current manifest file
if (Test-Path $manifestDestPath) {
    Remove-Item $manifestDestPath -Force
}

# install latest module and manifest files from network location
Copy-Item -Path $manifestSourcePath -Destination $destPath -Force
if ($moduleFound) {
    Copy-Item -Path $moduleSourcePath -Destination $destPath -Force
}

Import-Module -Name "Adam-ADUser" -Force

$runStatus = $true
# while the program is running
while ($runStatus) {
    # create new user from existing user
    $newUsername = Copy-User

	# confirm the user's properties
	Confirm-User -NewUsername $newUsername

    $valid = $false
    do {
        # user choice to restart the program
        $restart_choice = Read-Host "`nCreate another user? (y/n)"

        # if user entered y or n
        if ($restart_choice -eq "y" -or $restart_choice -eq "n") {

            # stop the program
            if ($restart_choice -eq "n"){
                $runStatus = $false
            }
            $valid = $true
        }

        else {
            Write-Error "`nInvalid selection`n" -Category InvalidArgument
        }

    } until ($valid)

}

Read-Host "`nPress enter to exit program"

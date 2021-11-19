<#

EditADUser.ps1 V1.01

Last updated: 6/22/2021

Changelog

Adam Pumphrey V0.10
- initial script

Adam Pumphrey V0.20
- added first name, last name, username changing
- decided that this will be incorporated into Adam-ADUser.psm1 module eventually

Adam Pumphrey V0.30
- added department, office, address, postal code, phone, fax, description, title, home page, manager changing
- moved items from switch into functions

Adam Pumphrey V0.40
- added confirmation and cancellation functionality
- more robust in general, multiple functions added
- added listing of changed values

Adam Pumphrey V1.00
- now sets properties for AD user
- samAccountName and its dependents update upon first/last name changes
- utility functions
- fully functional
- added comments

Adam Pumphrey V1.01
- moved functions into Adam-ADUser.psm1 module
- self-elevates to run as admin
  - no need for $credential
- auto-installs module from network drive

#>

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

$domain = "@<domain>"

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

Edit-User -Domain $domain
<#

Clear-ExternalDrive V1.00
Adam Pumphrey

This script's purpose is to automate the process of mass-wiping hard drives. The process is to connect a USB external hard drive to the host machine
while the script is running. The script will detect when the external drive is connected and will wipe the associated drive, allowing for rapid and efficient
mass-cleaning of hard drives. The script MUST be ran as Admin.

Be aware that the script was created specifically for the above use case. Mileage may vary otherwise.

EXTREME CAUTION if your host machine already has more than one drive installed
- need to edit the Clear-Disk command, change -Number 1 to -Number x, where x = (number of drives installed)
  - eg. I have two drives installed (drive 0 and drive 1), need to change to Clear-Disk -Number 2 (2 = the third (new) drive)
  - can verify the number to change to by running Get-Disk in a PowerShell console, Get-Disk will list all installed drives and their numbers

Heavily based off of: https://superuser.com/a/845411 

Last updated: 7/21/2021

Changelog

Adam Pumphrey V1.00
- initial script

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

# register the volumeChange event
Register-WmiEvent -Class win32_VolumeChangeEvent -SourceIdentifier volumeChange -ErrorAction SilentlyContinue

Write-Host (Get-Date -Format s) " Beginning script..."

# do forever
do {
    # wait for an event
    $newEvent = Wait-Event -SourceIdentifier volumeChange
    # after an event occurs, get the type of event
    $eventType = $newEvent.SourceEventArgs.NewEvent.EventType
    $eventTypeName = switch ($eventType) {
        1 {"Configuration changed"}
        2 {"Device arrival"}
        3 {"Device Removal"}
        4 {"docking"}
    }

    Write-Host (Get-Date -Format s) " Event detected = " $eventTypeName
    # if the event type is "Device arrival", i.e. USB device connected
    if ($eventType -eq 2) {
        try {
            <# 
            wipe the drive
              - this assumes that the host machine only has one drive installed (disk 0)
            #>
            Clear-Disk -Number 1 -Confirm:$false -RemoveData -RemoveOEM 
            Write-Host (Get-Date -Format s) " Disk cleaned!`n"

        } catch {
            Write-Error "Unexpected error"
        }
    }

    # remove the event after the disk can been cleared
    Remove-Event -SourceIdentifier volumeChange

} while (1 -eq 1) # do forever

# unregister the event
# honestly not sure why this was here in the example as it will never execute
Unregister-Event -SourceIdentifier volumeChange
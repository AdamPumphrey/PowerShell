# PowerShell
Collection of PowerShell scripts I created from May 2021 to Sept 2021
    
# Assign-CalendarPermission.ps1:
`Assign-CalendarPermission` assigns calendar permissions for one user to another user.
    
The use case for this script was a HR applicant tracking program that needed to be able to view every user's calendar availability. The HR system was an Azure AD-only user, which was assigned `AvailabilityOnly` permissions for every user. This script was used during the account creation process for new users, as the HR system would need permissions for each new user's calendar as well. Hence, it only handles one user at a time, though this could be very easily modified to support multiple users at a time.
    
1. The script installs the `ExchangeOnlineManagement` module (if not already installed)
2. Next, it requests credentials (must be an Exchange Admin) and connects to ExchangeOnline
3. Hard-coded are the values for the user that receives permissions (in the use case this would never change), and the value for the user that is giving permissions (hard coded since its only for one user, and the client was indifferent when I asked if they were fine with this process. For each new user, the value of `$newUser` needs to be changed)
4. The script then checks to see if any permissions were previously granted for the chosen user
    1. If so, the existing permissions are removed
6. Finally, the permission specified by `$access` is assigned to the receiving user, and the connection to ExchangeOnline is terminated
    
Usage: `.\Assign-CalendarPermission.ps1` (must change `$newUser` for each different granting user)

# Clear-ExternalDrive.ps1:
`Clear-ExternalDrive` wipes connected hard drives (excluding the C: drive / drive 0) each time a new drive (via USB external drive) is plugged in and detected.

The use case for this script was simply the need to wipe a large amount of hard drives. Instead of plugging in a USB external drive and manually wiping the drives, this script expedites the process by automatically wiping the drive once the USB external drive is connected. Instead of me spending days wiping drives, I had all of the drives wiped in an afternoon.

This script will run continuously until the PowerShell window/process is manually closed.

This script assumes that the host machine only has one drive installed prior to running. If the host machine has more than 1 drive installed (that you don't want to wipe), the `Clear-Disk` command needs to be edited (`-Number` is set to 1 for the script (wipes drive 1), change accordingly).

1. The script self-elevates to Admin PowerShell session (credentials required)
2. The `volumeChange` event is registered and the script waits for the event to trigger
3. When the event triggers (i.e. a USB external drive is connected) drive 1 (the new drive) is wiped. Timestamps are created and displayed for the connection time and the time it finishes wiping the drive
4. Repeats step 2-3 until manually closed

No input needed from the user. Leave the external drive enclosure plugged in, and simply swap in/out hard drives. Power off drive enclosure when swapping of course.

Usage: `.\Clear-ExternalDrive.ps1`

# Confirm-PrintNightmare.ps1:
`Confirm-PrintNightmare` checks to see if the local machine is vulnerable to the PrintNightmare exploit ([CVE-2021-34527](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2021-34527)) as of July 9, 2021, 12:00am.
    
1. The script first checks if the local machine's Print Spooler service is running. 
    1. If the service is running, the script checks to see if the machine has the proper Microsoft update installed (or a security update was installed after the patch release date - see my commit [here](https://github.com/AdamPumphrey/PowerShell/commit/15f114d8224e3288e7d426bdf9a484fcb679bf1c) for an explanation why).
        1. If so, the script checks to see if the correct values are set for specific registry keys, if they exist.

If the Print Spooler is not running, the system is safe. If the proper Microsoft update is not installed, the system is vulnerable. If the update is installed, but the specific registry keys (`NoWarningNoElevationOnInstall`, `UpdatePromptSettings`, `RestrictDriverInstallationToAdministrators`) exist and are not set to the correct values, the system is vulnerable.

Usage: `.\Confirm-PrintNightmare.ps1`

# Get-MailboxReport.ps1:
`Get-MailboxReport` generates a report for each mailbox in ExchangeOnline. The report for each mailbox consists of the display name (eg. Adam Pumphrey), email address, date and time of the last logon, number of items in the mailbox, the amount of space those items take up, the number of deleted items in the mailbox, and the amount of space the deleted items take up.

The use case for this is simply that a report for every mailbox in the system was requested, with the above fields included.

This script requires Exchange Admin credentials.

1. The script installs the `ExchangeOnlineManagement` module (if not already installed)
2. The script prompts for credentials (must be Exchange Admin)
3. The script connects to ExchangeOnline and all ExchangeOnline mailboxes are pulled
4. The report filename is formatted
5. Data is gathered and formatted for each mailbox, and appended to an array of data objects
6. After each mailbox has been examined, the report is saved to the location specified by `$reportPath`
7. The script disconnects from ExchangeOnline

The resulting report is saved in the following format: `mailboxreport_month_day_year_time.csv`

Usage: `.\Get-MailboxReport.ps1`

# Get-NetworkDriveReport.ps1:
`Get-NetworkDriveReport` generates a report for each drive specified by the accompanying `drives.csv` file. The report for each drive cosists of the number of folders in the drive, number of files in the drive, and the overall size in GB.

The `drives.csv` file contains two columns: the first with a `Server` heading, which consists of the name of the server that the drive is on (eg. Server1), the second with a `Location` heading, which consists of the locations of the drive (eg. D:\Department1\NetDrive1).

The use case for this is simply that a report of each network drive's top-level folders in our infrastructure was requested, with the above fields included. Research was required to find all of the network drive locations (and their top-level folders) in our infrastructure, which was stored in `drives.csv`.

1. The script prompts for credentials (Admin)
2. The report filename is formatted (`networkdrive_month_day_year_time.csv`)
3. Following steps are for each entry in `drives.csv`:
    1. A `PSSession` is established on the server, if not already connected
    2. All contents of the drive are pulled (`Get-ChildItem`)
        1. This recurses if inside a top-level folder
    4. Data is gathered for the contents of the drive (file or folder)
    5. Resulting data is appended to an array of data objects
    6. TimeSpan is displayed (time elapsed for that specific drive)
4.  Data object array is exported as .csv to the path specified by `$reportPath`
5.  PSSessions are removed

Usage: `.\Get-NetworkDriveReport.ps1` (`drives.csv` must be in same directory and formatted accordingly)

# New-JabberCSV.ps1:
`New-JabberCSV` reads in two .csv files (one for iPhones, one for Androids) - each formatted to be used for Cisco Jabber - and fills in formatted user data from AD to their corresponding cells.

The use case for this script was simply that a Jabber import file needed to be filled out for every user in AD. Hence, the script pulls each user from AD and fills in a row of the .csv with that user's data. The script requires that two .csv files exist and are properly formatted: `jabber_iphone.csv` and `jabber_android.csv`. The specifics of the .csv formatting will not be shared.

This script requires Admin credentials.

1. The script sets constants and formats the export .csv filenames
2. The script prompts for credentials (Admin)
3. A list of AD users is acquired, with the properties `samAccountName`, `Name`, `ipPhone`, `OfficePhone`
4. the two .csv's are imported (jabber_iphone and jabber_android)
5. rows of each .csv are filled in with each user's AD data
6. The created reports are exported

Usage: `.\New-JabberCSV.ps1` (`jabber_iphone.csv` and `jabber_android.csv` must be in same directory and formatted accordingly)

# Remove-DeletedGroup.ps1:
`Remove-DeletedGroup` clears a previously deleted Microsoft 365 group from the "deleted groups" in AzureAD.

The use case for this script was that I was dealing with a M365 group that had configuration issues, and I needed to purge it from our infrastructure to rebuild it. Microsoft holds deleted M365 groups in a "deleted groups" folder for 30 days before completely clearing it (similar to how Windows holds items in the Recycle Bin), but manually deleting it (with `Remove-AzureADMSDeletedDirectoryObject`) sets the group to be removed after a maximum of 24 hours (I found that it usually took a couple hours at most for the changes to take effect).

1. The script tries to connect to AzureAD, and prompts for AzureAD Admin credentials
2. The existing deleted groups are listed and the user is prompted to enter the name of the deleted group they want to purge
3. The deleted groups are searched for the previously-entered group name (via `Get-AzureADMSDeletedGroup`)
    1. If no matches are found, the script restarts at step 2
4. When a match is found, the group is purged (via `Remove-AzureADMSDeletedDirectoryObject`)
5. The existing deleted groups are listed again and the user is prompted to confirm that the chosen group was actually deleted
    1. If no, the script restarts at step 2

Usage: `.\Remove-DeletedGroup.ps1`

# CreateADUser:
See [CreateADUser/README.md](https://github.com/AdamPumphrey/PowerShell/blob/main/CreateADUser/README.md) for more information.

# OneDrive:

## Get-PreMigrationReport.ps1
`Get-PreMigrationReport` creates a .csv file report of a specified user's homedrive.

The use case for this script was when I was overseeing migrations to OneDrive from an on-prem fileshare. This script was used to create reports for each user's homedrive prior to migration. A homedrive refers to the AD property "Home folder" (`homeDirectory` property in an `ADUser` object). In my environment, each user had a homedrive mapped as a network drive (Z:) which they could use for personal storage. As we were moving towards OneDrive, we needed the contents of each homedrive migrated to the corresponding user's OneDrive.

This script loops, allowing for reports to be generated for a number of users, but you have to manually enter the username for each user as it loops, and it only checks one server location.

1. The script requests credentials. These need to be Admin credentials
2. A `PSSession` is created on the target server
3. A prompt to enter a username is shown
4. The path to the user's drive is dynamically created, and the contents of the drive are acquired
5. The report filename is formatted
6. Data from each item in the drive is then pulled: file name, last write time, size in MB, file type (extension)
7. Data for each item is appended to the newly-created .csv report file, saved in the specified location
8. After the report is complete, a restart prompt is shown
9. If restarted, process repeats from step 3

Usage: `.\Get-PreMigrationReport.ps1`

## Get-BulkPreMigrationReport.ps1
`Get-BulkPreMigrationReport` is an improved version of `Get-PreMigrationReport`. The main improvements come from automating the entire process.

I eventually got tired of entering usernames one-by-one, and when I saw that I had large sets of report to make I had to automate it. This script now takes in a `users.csv` file that contains 1 column of data: usernames, with the header being `Folder`. Instead of entering usernames, the script reads the .csv file for the usernames. Additionally, the script checks two specified server locations for the presence of a homedrive (since my environment had two servers for that purpose - this can be easily expanded to more locations). Since the script runs through the `users.csv` file twice (once for each server), the script keeps track of which users have been reported on already and skips them accordingly.

The overall process is the same, just with no user interaction outside of entering Admin credentials.

Usage: `.\Get-BulkPreMigrationReport.ps1` (`users.csv` file must be in the same directory and formatted accordingly)

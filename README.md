# Powershell
Collection of Powershell scripts I created during my time working from May 2021 to Sept 2021

# Confirm-PrintNightmare.ps1:
`Confirm-PrintNightmare` checks to see if the local machine is vulnerable to the PrintNightmare exploit ([CVE-2021-34527](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2021-34527)) as of July 9, 2021, 12:00am.
    
1. The script first checks if the local machine's Print Spooler service is running. 
    1. If the service is running, the script checks to see if the machine has the proper Microsoft update installed.
        1. If so, the script checks to see if the correct values are set for specific registry keys, if they exist.

If the Print Spooler is not running, the system is safe. If the proper Microsoft update is not installed, the system is vulnerable. If the update is installed, but the specific registry keys (`NoWarningNoElevationOnInstall`, `UpdatePromptSettings`) exist and are not set to the correct values, the system is vulnerable.

Usage: `.\Confirm-PrintNightmare.ps1`
    
# Assign-CalendarPermission.ps1:
`Assign-CalendarPermission` assigns calendar permissions for one user to another user.
    
The use case for this script was a HR applicant tracking program that needed to be able to view every user's calendar availability. The HR system was an Azure AD-only user, which was assigned `AvailabilityOnly` permissions for every user. This script was used during the account creation process for new users, as the HR system would need permissions for each new user's calendar as well. Hence, it only handles one user at a time, though this could be very easily modified to support multiple users at a time.
    
1. The script installs the `ExchangeOnlineManagement` module (if not already installed). 
2. Next, it requests credentials (must be an Exchange Admin) and connects to Exchange Online. 
3. Hard-coded are the values for the user that receives permissions (in the use case this would never change), and the value for the user that is giving permissions (hard coded since its only for one user, and the client was indifferent when I asked if they were fine with this process. For each new user, the value of `$newUser` needs to be changed)
4. The script then checks to see if any permissions were previously granted for the chosen user.
    1. If so, the existing permissions are removed.
6. Finally, the permission specified by `$access` is assigned to the receiving user, and the connection to Exchange Online is terminated.
    
Usage: `.\Assign-CalendarPermission.ps1` (must change `$newUser` for each different granting user)

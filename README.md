# Powershell
Collection of Powershell scripts I created during my time working from May 2021 to Sept 2021

# Confirm-PrintNightmare.ps1:
    Confirm-PrintNightmare checks to see if the local machine is vulnerable to the PrintNightmare exploit (CVE-2021-34527) as of July 9, 2021, 12:00am.
    
    The script first checks if the local machine's Print Spooler service is running. If the service is running, the script checks to see if the machine has the proper Microsoft update installed, and has the correct values set for specific registry keys, if they exist.

    Usage: .\Confirm-PrintNightmare.ps1
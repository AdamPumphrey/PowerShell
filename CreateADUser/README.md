# ADUser Script Suite
A PowerShell module + cmdlets created to expedite the user account creation process in AD, making the process more efficient overall. The module itself could probably be cleaned up a bit, but it is functional.

This script suite assumes that the `ActiveDirectory` PowerShell module is installed already.

Admin credentials are required.

## Installation
1. Download the repository as a `.zip` file (`PowerShell-main.zip`)
    1. Go to [the repo homepage](https://github.com/AdamPumphrey/PowerShell)
    2. Click on the green Code button
    3. Select "Download ZIP"
2. Place the contents of `PowerShell-main.zip\PowerShell-main\CreateADUser` in your preferred location
3. Change `$moduleSourcePath` and `$manifestSourcePath` in `CreateADUser.ps1` and `EditADUser.ps1` to reflect their location(s) on your computer specified in step 2.
4. Change `$domain` in `CreateADUser.ps1` and `EditADUser.ps1` to your respective domain 

Example: 

`$moduleSourcePath = "C:\Sample Folder\Adam-ADUser.psm1"`

`$manifestSourcePath = "C:\Sample Folder\Adam-ADUser.psd1"`

`$domain = "@adam.com"`

You then have two choices:

Method 1: Module file install
1. Copy and paste `Adam-ADUser.psm1` into `C:\Program Files\WindowsPowerShell\Modules\Adam-ADUser\`
    1. Upon running `CreateADUser.ps1` or `EditADUser.ps1` the module (`Adam-ADUser.psm1`) and the manifest (`Adam-ADUser.psd1`) will be automatically placed into `C:\Program Files\WindowsPowerShell\Modules\Adam-ADUser\`

Method 2: Manifest file install
1. Edit the `RootModule` value (line 12) of `Adam-ADUser.psd1` to the path of `Adam-ADuser.psm1` on your computer (same as `$moduleSourcePath`)
    1. Upon running `CreateADUser.ps1` or `EditADUser.ps1` the module manifest (`Adam-ADUser.psd1`) will be automatically placed into `C:\Program Files\WindowsPowerShell\Modules\Adam-ADUser\`

`CreateADUser` and `EditADUser` both remove and replace the module manifest (and module, if installation method 1 was used) each time they are ran, which allows for you to edit `Adam-ADUser.psm1` or `Adam-ADUser.psd1` and not have to worry about replacing the old versions in the install location.

There are arbitrary password length and complexity requirements in this script (15 chars, capitals and lowercase, numbers and special chars. They are located from line 193 to 206 in Adam-ADUser.psm1. The only restriction I would support changing is the password length requirement. The others eliminate simple passwords from being created.

## Adam-ADUser.psd1
Module manifest for the Adam-ADUser.psm1 module. Contains information regarding the module.
This file is placed in `C:\Program Files\WindowsPowerShell\Modules\Adam-ADUser\` during the install process.

## Adam-ADUser.psm1
Module containing all of the functions necessary for `CreateADUser` and `EditADUser` to work properly.

## CreateADUser.ps1
This script creates a new AD user via copying an existing user's properties, and filling in the gaps with new information provided by the user.

1. The script prompts for Admin credentials
2. The module manifest (and module, if applicable) are removed (if existing) and replaced in their install location. This is to keep the files up to date if changes are made to the manifest/module files

The script then jumps into functions contained within `Adam-ADUser.psm1`:

3. User is prompted to enter the username of the AD account they want to use as a template
4. Template user's data is gathered
5. User is prompted to enter the first and last name of the new user
6. A username is generated for the user (format: 1st letter of first name + last name. e.g. adam pumphrey = apumphrey)
    1. If the generated username already exists, the user is prompted to manually enter a username
7. User is prompted to enter and confirm a password for the new user
8. The new user is created in AD, and its information is displayed
    1. Note that an exception will show if a Manager for the user is not present
9. User is prompted to confirm the new user's information. If no (n), `EditADUser` is executed for the new user (see the section for `EditADUser.ps1`)
10. User is prompted to create another user
    1. If yes (y), process repeates at step 3

Usage: `.\CreateADUser.ps1` (ensure that the module is installed)

## EditADUser.ps1
This script facilitates editing an AD user's properties. The properties that can be edited are: first name, last name, username, department, office, address, postal code, phone (three choices - office/IP/mobile), fax, description, title, home page, manager. Home directory and home drive were previously included, but are now legacy properties. The commands that reference the home directory/home drive properties are included in the script, but are commented out.

1. The script prompts for Admin credentials
2. The module manifest (and module, if applicable) are removed (if existing) and replaced in their install location. This is to keep the files up to date if changes are made to the manifest/module files

The script then jumps into functions contained within `Adam-ADUser.psm1`:
(skip to step 5 if editing after creating via `CreateADUser`)

3. User is prompted to the the username of the AD account they want to edit 
4. AD account's data is gathered
5. A menu is displayed, showing the properties available to be edited
6. Depending on the user's choice, they will be prompted to enter new information for the property they chose to edit
    1. if phone is chosen, the user will be prompted to choose from office phone, mobile phone, or IP phone
7. When finished, the values that have been changed are applied and displayed to the user

Usage: `.\EditADUser.ps1` (ensure that the module is installed)

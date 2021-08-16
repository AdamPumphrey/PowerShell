<#

Get-MailboxReport V1.00
Adam Pumphrey

This script connects to Exchange Online and generates a report for each mailbox, consisting of the Display Name (eg. Adam Pumphrey), 
the email address, the date and time of the last time the user logged into their mailbox, the number of items in their mailbox,
the cumulative space those items take up (KB, MB, GB, etc.), the number of deleted items in their mailbox, and the cumulative space those 
deleted items take up.

The credentials provided must be for an exchange admin.

Based off https://social.technet.microsoft.com/Forums/lync/en-US/d8aae4c8-36df-41f2-b03e-f1c6b26b828e/combining-getmailbox-and-getmailboxstatistics?forum=Exch2016PS

Last updated: 8/4/2021

Changelog

Adam Pumphrey V1.00
- initial script
- Chained .Replace functions

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
    } catch [System.Management.Automation.ParameterBindingException] {
        Read-Host "`nExiting program..."
        Exit
    }
}

# install exchange online module if not present
if (Get-Module -ListAvailable -Name ExchangeOnlineManagement) {
}
else {
    Install-Module -Name ExchangeOnlineManagement
}

# exchange admin credentials required
$Credential = Get-UserCredential

$validated = $false

do {
    try {
        # connect to exchange online
        Connect-ExchangeOnline -Credential $Credential -ShowProgress $true -ShowBanner:$false
        $validated = $true
    } catch [System.AggregateException] {
        Write-Host
        Write-Error "Invalid credentials - try again"
        $Credential = Get-UserCredential
    }
} until ($validated)

# list each mailbox user
$users = Get-EXOMailbox | Select -ExpandProperty PrimarySmtpAddress
# initialize empty data array
$data = @()
# format date
# eg. 07_29_2021_1400 = July 29, 2021 at 2:00pm
$date = Get-Date -Format "MM/dd/yyyy HH:mm"
$date = $date.Replace(" ", "_").Replace(":", "").Replace("/", "_")
# report filename
$newFile = "mailboxreport_" + $date + ".csv"
# save path
$reportPath = "<savepath>" + $newFile

# for each mailbox user
foreach ($u in $users) {
    # get data for that user's mailbox
    $mailbox = Get-EXOMailboxStatistics -Identity $u -PropertySets All
    # change item/deleted item sizes to string for later manipulation
    $mailbox.TotalItemSize.Value | % { $totalItemSize = $_.ToString(); }
    $mailbox.TotalDeletedItemSize.Value | % { $delTotalItemSize = $_.ToString(); }

    # create a new object and add it to the data array
    $data += New-Object psobject -Property @{ 
        # object contains data for that user's mailbox
        DisplayName = $mailbox.DisplayName; 
        Email = $u; 
        LastLogonTime = $mailbox.LastLogonTime; 
        ItemCount = $mailbox.ItemCount; 
        # cut off unnecessary data
        TotalItemSize = $totalItemSize.Substring(0, $totalItemSize.IndexOf('(') - 1); 
        DeletedItemCount = $mailbox.DeletedItemCount; 
        # cut off unnecessary data
        TotalDeletedItemSize = $delTotalItemSize.Substring(0, $delTotalItemSize.IndexOf('(') - 1); 
    }

}

# write data to .csv file
$data | Select DisplayName, Email, LastLogonTime, ItemCount, TotalItemSize, DeletedItemCount, TotalDeletedItemSize | Export-Csv $reportPath -Append -NoTypeInformation

# close exchange online session
Disconnect-ExchangeOnline

Read-Host "`nPress enter to exit"
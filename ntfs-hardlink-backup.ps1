<#
.DESCRIPTION
    This software is used for creating hard-link-backups.
	The real magic is done by DeLoreanCopy of ln: http://schinagl.priv.at/nt/ln/ln.html	So all credit goes to Hermann Schinagl.
	INSTALLATION:
	1. Read the documentation of "ln" http://schinagl.priv.at/nt/ln/ln.html
	2. Download "ln" and unpack the file.
	3. Place ntfs-hardlink-backup.ps1 into ln\bat directory
	4. run ntfs-hardlink-backup.ps1 with full path 
.SYNOPSIS
	c:\full\path\bat\ntfs-hardlink-backup.ps1 <Options>
.PARAMETER backupSources
    Source path of the backup. Can be a list separated by comma
.PARAMETER backupDestination
    Where the data should go to.
.PARAMETER backupsToKeep
    How many backup copies should be kept. All older copies will be deleted. Default=50
.PARAMETER timeTolerance
    Sometimes useful to not have an exact timestamp comparison bewteen source and dest, but kind of a fuzzy comparison, because the systemtime of NAS drives is not exactly synced with the host.
	To overcome this we use the -timeTolerance switch to specify a value in milliseconds 
.PARAMETER traditional
	Some NAS boxes only support a very outdated version of the SMB protocol. SMB is used when network drives are connected. This old version of SMB in certain situations does not support the fast enumeration methods of ln.exe, which causes ln.exe to simply do nothing.
	To overcome this use the -traditional switch, which forces ln.exe to enumerate files the old, but a little slower way
.PARAMETER emailTo
    Address to be notified about success and problems. If not given no Emails will be sent.
.PARAMETER emailFrom
    Address the notification email is sent from. If not given no Emails will be sent.
.PARAMETER SMTPServer
    Domainname of the SMTP Server. If not given no Emails will be sent.
.PARAMETER SMTPUser
    Username if the SMTP Server needs authentication
.PARAMETER SMTPPassword
    Password if the SMTP Server needs authentication	
.PARAMETER NoSMTPOverSSL
    Switch off the use of SSL to send Emails.
.PARAMETER NoShadowCopy
    Switch off the use of Shadow Copys.
.PARAMETER SMTPPort
    Port of the SMTP Server. Default=587
.PARAMETER emailSubject
    Subject for the notification Email	
.EXAMPLE
    PS D:\> d:\ln\bat\ntfs-hardlink-backup.ps1 -backupSources D:\backup_source1 -backupDestination D:\backup_dest -emailTo "me@address.org" -emailFrom "backup@ocompany.rg" -SMTPServer company.org -SMTPUser "backup@company.org" -SMTPPassword "secr4et" 
    Simple backup
.EXAMPLE
    PS D:\> d:\ln\bat\ntfs-hardlink-backup.ps1 -backupSources "D:\backup_source1","c:\backup_source2" -backupDestination D:\backup_dest -emailTo "me@address.org" -emailFrom "backup@ocompany.rg" -SMTPServer company.org -SMTPUser "backup@company.org" -SMTPPassword "secr4et" 
    Backup with more than one source
.NOTES
    Author: Artur Neumann *INFN*
    Date:   March 11 2014
	Version: 1.0_rc2
#>

[CmdletBinding()]
Param(
   [Parameter(Mandatory=$True)]
   [String[]]$backupSources,
   [Parameter(Mandatory=$True)]
   [String]$backupDestination,
   [Parameter(Mandatory=$False)]
   [Int32]$backupsToKeep=50,
   [Parameter(Mandatory=$False)]
   [string]$emailTo="",
   [Parameter(Mandatory=$False)]
   [string]$emailFrom="",
   [Parameter(Mandatory=$False)]
   [string]$SMTPServer="",
   [Parameter(Mandatory=$False)]
   [string]$SMTPUser="",
   [Parameter(Mandatory=$False)]
   [string]$SMTPPassword="",
   [Parameter(Mandatory=$False)]
   [switch]$NoSMTPOverSSL=$False,   
   [Parameter(Mandatory=$False)]
   [switch]$NoShadowCopy=$False,  
   [Parameter(Mandatory=$False)]
   [Int32]$SMTPPort=587,   
   [Parameter(Mandatory=$False)]
   [Int32]$timeTolerance=0,
   [Parameter(Mandatory=$False)]
   [switch]$traditional,    
   [Parameter(Mandatory=$False)]
   [string]$emailSubject="Backup" 
)

$emailBody = ""
$error_during_backup = $false


$script_path = Split-Path -parent $MyInvocation.MyCommand.Definition
$log_file="$script_path\backup.log"

If (Test-Path $log_file){
	Remove-Item $log_file
}


foreach($backup_source in $backupSources)
{
          
	$backup_source_drive_letter = split-path $backup_source -qualifier
	$backup_source_path =  split-path $backup_source -noQualifier
	$backup_source_folder =  split-path $backup_source -leaf
	$dateTime = get-date -f "yyyy-MM-dd HH-mm-ss"
	$actualBackupDestination = "$backupDestination\$backup_source_folder - $dateTime"

	
	echo $backup_source_folder

	echo "============Creating Backup of $backup_source============" 
	if ($NoShadowCopy -eq $False) {
		
		echo "1. Creating Shadow Volume Copy..."
		try {
			$s1 = (gwmi -List Win32_ShadowCopy).Create("$backup_source_drive_letter\", "ClientAccessible")
			$s2 = gwmi Win32_ShadowCopy | ? { $_.ID -eq $s1.ShadowID }
		}
		catch { 
			$output = "ERROR: Could not create Shadow Copy`r`n"
			$emailBody = "$emailBody`r`n$output`r`n$_ `r`n"
			$error_during_backup = $true
			echo $output  $_
		}
		
		$id = $s2.ID
		echo "Shadow Volume ID: $id"
		echo "Shadow Volume DeviceObject: $s2.DeviceObject"
		
		
		$shadowCopies = Get-WMIObject -Class Win32_ShadowCopy 

		cmd /c mklink /d "$backup_source_drive_letter\shadowcopy_$id" "$s2.DeviceObject"
		echo "done`n"

		$backup_source_path = $s2.DeviceObject+$backup_source_path
	}
	else { 
		echo "1. Skipping creation of Shadow Volume Copy. ATTENTION: if files are changed during the backup process, they might end up being corrupted in the backup!"
		$backup_source_path = $backup_source
	}
	
	echo "2. Running backup..."
	echo "Source: $backup_source_path"
	echo "Destination: $actualBackupDestination"


	$oldBackupItems = Get-ChildItem -Path $backupDestination
	$lastBackupFolderName = ""
	# get me the last backup if any
	foreach ($item in $oldBackupItems)
	{
		if ($item.Attributes -eq "Directory" -AND $item.Name  -match '^'+$backup_source_folder+' - \d{4}-\d{2}-\d{2} \d{2}-\d{2}-\d{2}$' )
		{
			$lastBackupFolderName = $item.Name
		}
	}
	
	if ($traditional -eq $True) {
		$traditionalArgument = " --traditional "
	} else {
		$traditionalArgument = ""
	}	
	
	if ($lastBackupFolderName -eq "" ) {
		echo "full copy"
		#echo "$script_path\..\ln.exe $traditionalArgument --copy `"$backup_source_path`" `"$actualBackupDestination`"  >> $log_file"
		`cmd /c  "$script_path\..\ln.exe $traditionalArgument --copy `"$backup_source_path`" `"$actualBackupDestination`"  >> $log_file"`
	
	} else {
		if ($timeTolerance -ne 0) {
			$timeToleranceArgument = " --timetolerance $timeTolerance "
		} else {
			$timeToleranceArgument = ""
		}
	
		
		echo "Delorian copy against $lastBackupFolderName"
		#echo "$script_path\..\ln.exe $traditionalArgument $timeToleranceArgument --delorean `"$backup_source_path`" `"$backupDestination\$lastBackupFolderName`" `"$actualBackupDestination`"  >> $log_file"
		`cmd /c  "$script_path\..\ln.exe $traditionalArgument $timeToleranceArgument --delorean `"$backup_source_path`" `"$backupDestination\$lastBackupFolderName`" `"$actualBackupDestination`"  >> $log_file"`
	
	
	}
	
	$summary = ""
	$backup_response = get-content "$log_file" 
	#TODO catch warnings and errors during delorian copy
	foreach( $line in $backup_response.length..1 ){
		$summary =  $backup_response[$line] + "`n" + $summary		
		if ($backup_response[$line] -match '.*Total\s+Copied\s+Linked\s+Skipped.*\s+Excluded\s+Failed.*') {

			break
		}
	}

	echo "done`n"
	$summary = "`n------Summary-----`nBackup FROM: $backup_source TO: $backupDestination`n" + $summary	
	echo $summary

	$emailBody = $emailBody + $summary
	
	if ($NoShadowCopy -eq $False) {
		foreach ($shadowCopy in $shadowCopies){
		if ($s2.ID -eq $shadowCopy.ID) {
			echo  "3. Deleting Shadow Copy ..."
			try {
				$shadowCopy.Delete()
				}
			catch {
				$output = "ERROR: Could not delete Shadow Copy"
				$emailBody = $emailBody + $output + $_
				$error_during_backup = $true
				echo $output  $_	
			}
			echo "done`n"
			break
			}
		} 
	} 
	echo "`n"
}

if ($emailTo -AND $emailFrom -AND $SMTPServer) {
	echo "============Sending Email============"

	if ($error_during_backup) {
		$EmailSubject = "ERROR - $EmailSubject"
	}
	$SMTPMessage = New-Object System.Net.Mail.MailMessage($emailFrom,$emailTo,$emailSubject,$emailBody)
	$attachment = New-Object System.Net.Mail.Attachment("$log_file" )
	$SMTPMessage.Attachments.Add($attachment)
	$SMTPClient = New-Object Net.Mail.SmtpClient($SMTPServer, $SMTPPort) 
	if ($NoSMTPOverSSL -eq $False) {
		$SMTPClient.EnableSsl = $True
	}

	$SMTPClient.Credentials = New-Object System.Net.NetworkCredential($SMTPUser, $SMTPPassword); 
	$SMTPClient.Send($SMTPMessage)
	$attachment.Dispose()
	echo "done"
}

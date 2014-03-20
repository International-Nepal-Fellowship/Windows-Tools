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
.PARAMETER exclude
	Exclude files via wildcards. Can be a list separated by comma
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
    Switch off the use of Shadow Copies. Can be useful if you have no permissions to create Shadow Copies
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
    Date:   March 20 2014
	Version: 1.0_rc5
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
   [string]$emailSubject="Backup",
   [Parameter(Mandatory=$False)]
   [String[]]$exclude 
)

$emailBody = ""
$error_during_backup = $false
$maxMsToSleepForZipCreation = 1000*60*30
$msToWaitDuringZipCreation = 500

$script_path = Split-Path -parent $MyInvocation.MyCommand.Definition
$log_file="$script_path\backup.log"

If (Test-Path $log_file){
	try
	{
		Remove-Item $log_file -erroraction stop
	}
	catch
	{
		$output = "ERROR: Could not delete old log file`r`n$_`r`n"
		$emailBody = "$emailBody`r`n$output`r`n"
		echo $output
		$error_during_backup = $True
	}
}

try
{
	New-Item $log_file -type file -force | Out-Null
}
catch
{
	$output = "ERROR: Could not create new log file`r`n$_`r`n"
	$emailBody = "$emailBody`r`n$output`r`n"
	echo $output
	$log_file=$False
	$error_during_backup = $True
}

foreach($backup_source in $backupSources)
{
    $stepCounter = 1     
	$backup_source_drive_letter = split-path $backup_source -qualifier
	$backup_source_path =  split-path $backup_source -noQualifier
	$backup_source_folder =  split-path $backup_source -leaf
	$dateTime = get-date -f "yyyy-MM-dd HH-mm-ss"
	$actualBackupDestination = "$backupDestination\$backup_source_folder - $dateTime"

	echo "============Creating Backup of $backup_source============" 
	if ($NoShadowCopy -eq $False) {
		
		echo "$stepCounter. Creating Shadow Volume Copy..."
		$stepCounter++
		try {
			$s1 = (gwmi -List Win32_ShadowCopy).Create("$backup_source_drive_letter\", "ClientAccessible")
			$s2 = gwmi Win32_ShadowCopy | ? { $_.ID -eq $s1.ShadowID }

			$id = $s2.ID
			echo "Shadow Volume ID: $id"
			echo "Shadow Volume DeviceObject: $s2.DeviceObject"
			
			$shadowCopies = Get-WMIObject -Class Win32_ShadowCopy 

			echo "done`n"

			$backup_source_path = $s2.DeviceObject+$backup_source_path		
		}
		catch { 
			$output = "ERROR: Could not create Shadow Copy`r`n$_ `r`nATTENTION: Skipping creation of Shadow Volume Copy. ATTENTION: if files are changed during the backup process, they might end up being corrupted in the backup!`r`n"
			$emailBody = "$emailBody`r`n$output`r`n"
			$error_during_backup = $true
			echo $output 
			if ($log_file) {
				$output | Out-File $log_file -encoding ASCII -append
			}
			$backup_source_path = $backup_source
			$NoShadowCopy = $True
		}

	}
	else { 
		echo "$stepCounter. Skipping creation of Shadow Volume Copy. ATTENTION: if files are changed during the backup process, they might end up being corrupted in the backup!`n"
		$stepCounter++
		$backup_source_path = $backup_source
	}
	
	echo "$stepCounter. Running backup..."
	$stepCounter++
	echo "Source: $backup_source_path"
	echo "Destination: $actualBackupDestination"


	$oldBackupItems = Get-ChildItem -Path $backupDestination
	$lastBackupFolderName = ""
	$lastBackupFolders = @()
	# get me the last backup if any
	foreach ($item in $oldBackupItems)
	{
		if ($item.Attributes -eq "Directory" -AND $item.Name  -match '^'+$backup_source_folder+' - \d{4}-\d{2}-\d{2} \d{2}-\d{2}-\d{2}$' )
		{
			$lastBackupFolderName = $item.Name
			$lastBackupFolders += $item
		}
	}
	
	if ($traditional -eq $True) {
		$traditionalArgument = " --traditional "
	} else {
		$traditionalArgument = ""
	}	
	
	$excludeString=" "
	foreach($item in $exclude)
	{
		if ($item -AND $item.Trim())
		{
			$excludeString = "$excludeString --exclude $item "
		}
	}
	
	if ($log_file) {
		$logFileCommandAppend = " >> $log_file"
	}
	
	if ($lastBackupFolderName -eq "" ) {
		echo "full copy"

		#echo "$script_path\..\ln.exe $traditionalArgument $excludeString --copy `"$backup_source_path`" `"$actualBackupDestination`"    >> $log_file"
		`cmd /c  "$script_path\..\ln.exe $traditionalArgument $excludeString --copy `"$backup_source_path`" `"$actualBackupDestination`"    $logFileCommandAppend"`
	} else {
		if ($timeTolerance -ne 0) {
			$timeToleranceArgument = " --timetolerance $timeTolerance "
		} else {
			$timeToleranceArgument = ""
		}
			
		echo "Delorian copy against $lastBackupFolderName"
		
		#echo "$script_path\..\ln.exe $traditionalArgument $timeToleranceArgument $excludeString --delorean `"$backup_source_path`" `"$backupDestination\$lastBackupFolderName`" `"$actualBackupDestination`"  >> $log_file"
		`cmd /c  "$script_path\..\ln.exe $traditionalArgument $timeToleranceArgument $excludeString --delorean `"$backup_source_path`" `"$backupDestination\$lastBackupFolderName`" `"$actualBackupDestination`" $logFileCommandAppend"`	
	}
	
	$summary = ""
	if ($log_file) {
		$backup_response = get-content "$log_file" 
		#TODO catch warnings and errors during delorian copy
		foreach( $line in $backup_response.length..1 ){
			$summary =  $backup_response[$line] + "`n" + $summary		
			if ($backup_response[$line] -match '.*Total\s+Copied\s+Linked\s+Skipped.*\s+Excluded\s+Failed.*') {
				break
			}
		}
	}

	echo "done`n"
	
	$summary = "`n------Summary-----`nBackup FROM: $backup_source TO: $backupDestination`n" + $summary	
	echo $summary

	$emailBody = $emailBody + $summary
	
	if ($NoShadowCopy -eq $False) {
		foreach ($shadowCopy in $shadowCopies){
		if ($s2.ID -eq $shadowCopy.ID) {
			echo  "$stepCounter. Deleting Shadow Copy ..."
			$stepCounter++
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
	
	echo  "$stepCounter. Deleting Old Backups ..."
	$backupsToDelete=$lastBackupFolders.length - $backupsToKeep
	$backupsDeleted = 0
	while ($backupsDeleted -le $backupsToDelete)
	{
		$folderToDelete =  $backupDestination +"\"+ $lastBackupFolders[$backupsDeleted].Name
		echo "Deleting $folderToDelete"
		if ($log_file) {
			"`r`nDeleting $folderToDelete" | Out-File $log_file  -encoding ASCII -append
		}
		Remove-Item $folderToDelete -recurse
		$backupsDeleted++
	}
	
	$summary = "`nDeleted $backupsDeleted old backup(s)`n"
	echo $summary
	if ($log_file) {
		$summary | Out-File $log_file  -encoding ASCII -append
	}

	$emailBody = $emailBody + $summary
	
	echo "done`n"	
}

if ($emailTo -AND $emailFrom -AND $SMTPServer) {
	echo "============Sending Email============"
	if ($log_file) {
		$zipFilePath = "$log_file.zip"
		$fileToZip = get-item $log_file

		If (Test-Path $zipFilePath){
			try
			{
				Remove-Item "$zipFilePath" -erroraction stop
				if (-not (test-path $zipFilePath)) { 
				  set-content $zipFilePath ("PK" + [char]5 + [char]6 + ("$([char]0)" * 18)) 
				} 

				$ZipFile = (new-object -com shell.application).NameSpace($zipFilePath) 
				$zipfile.CopyHere($fileToZip.fullname)	
				
				$timeSlept = 0
				while ($zipfile.Items().Count -le 0 -AND $timeSlept -le $maxMsToSleepForZipCreation )
				{
					Start-sleep -milliseconds $msToWaitDuringZipCreation
					$timeSlept = $timeSlept + $msToWaitDuringZipCreation
				}			
				$attachment = New-Object System.Net.Mail.Attachment("$zipFilePath" )
			}
			catch
			{
				$error_during_backup = $True
				$output = "`r`nERROR: Could not create log ZIP file. Will try to attach the unziped log file and hope it's not to big.`r`n$_`r`n"
				$emailBody = "$emailBody`r`n$output`r`n"
				echo $output
				$output | Out-File $log_file  -encoding ASCII -append
				$attachment = New-Object System.Net.Mail.Attachment("$log_file" )
			}		
		}
	}
	
	if ($error_during_backup) {
		$EmailSubject = "ERROR - $EmailSubject"
	}
	$SMTPMessage = New-Object System.Net.Mail.MailMessage($emailFrom,$emailTo,$emailSubject,$emailBody)
	
	if ($log_file) {
		$SMTPMessage.Attachments.Add($attachment)
	}
	$SMTPClient = New-Object Net.Mail.SmtpClient($SMTPServer, $SMTPPort) 
	if ($NoSMTPOverSSL -eq $False) {
		$SMTPClient.EnableSsl = $True
	}

	$SMTPClient.Credentials = New-Object System.Net.NetworkCredential($SMTPUser, $SMTPPassword); 
	try {
		$SMTPClient.Send($SMTPMessage)
	} catch {
		$output = "ERROR: Could not send Email.`r`n$_`r`n"
		echo $output
		if ($log_file) {
			$output | Out-File $log_file -append
		}
	}
	
	if ($log_file) {
		$attachment.Dispose()
	}
	
	echo "done"
}

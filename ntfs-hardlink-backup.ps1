<#
.DESCRIPTION
    This software is used for creating hard-link-backups.
	The real magic is done by DeLoreanCopy of ln: http://schinagl.priv.at/nt/ln/ln.html	So all credit goes to Hermann Schinagl.
	INSTALLATION:
	1. Read the documentation of "ln" http://schinagl.priv.at/nt/ln/ln.html
	2. Download "ln" and unpack the file.
	3. Download and place ntfs-hardlink-backup.ps1 into .\bat directory below the ln program
	4. Navigate with Explorer to the .\bat folder
	5. Right Click on the ntfs-hardlink-backup.ps1 file and select "Properties"
	6. If you see in the bottom something like "Security: This file came from an other computer ..." Click on "Unblock"
	7. start powershell from windows start menu (you need Windows 7 or Win Server for that, on XP you would need to install PowerShell 2 first)
	8. allow local non-signed scripts to run by typing "Set-ExecutionPolicy RemoteSigned"
	9. run ntfs-hardlink-backup.ps1 with full path
.SYNOPSIS
	c:\full\path\bat\ntfs-hardlink-backup.ps1 <Options>
.PARAMETER backupSources
    Source path of the backup. Can be a list separated by comma.
.PARAMETER backupDestination
    Where the data should go to.
.PARAMETER backupsToKeep
    How many backup copies should be kept. All older copies will be deleted. 1 means mirror. Default=50
.PARAMETER timeTolerance
    Sometimes useful to not have an exact timestamp comparison bewteen source and dest, but kind of a fuzzy comparison, because the systemtime of NAS drives is not exactly synced with the host.
	To overcome this we use the -timeTolerance switch to specify a value in milliseconds.
.PARAMETER exclude
	Exclude files via wildcards. Can be a list separated by comma.
.PARAMETER traditional
	Some NAS boxes only support a very outdated version of the SMB protocol. SMB is used when network drives are connected. This old version of SMB in certain situations does not support the fast enumeration methods of ln.exe, which causes ln.exe to simply do nothing.
	To overcome this use the -traditional switch, which forces ln.exe to enumerate files the old, but a little slower way.
.PARAMETER emailTo
    Address to be notified about success and problems. If not given no Emails will be sent.
.PARAMETER emailFrom
    Address the notification email is sent from. If not given no Emails will be sent.
.PARAMETER SMTPServer
    Domainname of the SMTP Server. If not given no Emails will be sent.
.PARAMETER SMTPUser
    Username if the SMTP Server needs authentication.
.PARAMETER SMTPPassword
    Password if the SMTP Server needs authentication.
.PARAMETER NoSMTPOverSSL
    Switch off the use of SSL to send Emails.
.PARAMETER NoShadowCopy
    Switch off the use of Shadow Copies. Can be useful if you have no permissions to create Shadow Copies.
.PARAMETER SMTPPort
    Port of the SMTP Server. Default=587
.PARAMETER emailSubject
    Subject for the notification Email.
.PARAMETER LogFile
    Path and filename for the logfile. If none is given backup.log in the script source is used.
.EXAMPLE
    PS D:\> d:\ln\bat\ntfs-hardlink-backup.ps1 -backupSources D:\backup_source1 -backupDestination E:\backup_dest -emailTo "me@address.org" -emailFrom "backup@ocompany.rg" -SMTPServer company.org -SMTPUser "backup@company.org" -SMTPPassword "secr4et"
    Simple backup.
.EXAMPLE
    PS D:\> d:\ln\bat\ntfs-hardlink-backup.ps1 -backupSources "D:\backup_source1","c:\backup_source2" -backupDestination E:\backup_dest -emailTo "me@address.org" -emailFrom "backup@ocompany.rg" -SMTPServer company.org -SMTPUser "backup@company.org" -SMTPPassword "secr4et"
    Backup with more than one source.
.NOTES
    Author: Artur Neumann *INFN*
    Date:   March 21 2014
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
   [string]$emailSubject="",
   [Parameter(Mandatory=$False)]
   [String[]]$exclude,
   [Parameter(Mandatory=$False)]
   [string]$LogFile=""
)

$emailBody = ""
$error_during_backup = $false
$maxMsToSleepForZipCreation = 1000*60*30
$msToWaitDuringZipCreation = 500
$shadow_drive_letter = ""
$num_shadow_copies = 0

if ([string]::IsNullOrEmpty($emailSubject)) {
	$emailSubject = "Backup of: {0} by: {1}" -f $(Get-WmiObject Win32_Computersystem).name, [Environment]::UserName
}

$script_path = Split-Path -parent $MyInvocation.MyCommand.Definition
if ([string]::IsNullOrEmpty($LogFile)) {
	$LogFile="$script_path\backup.log"
}

try
{
	New-Item $LogFile -type file -force -erroraction stop | Out-Null
}
catch
{
	$output = "ERROR: Could not create new log file`r`n$_`r`n"
	$emailBody = "$emailBody`r`n$output`r`n"
	echo $output
	$LogFile=""
	$error_during_backup = $True
}

$backupDestinationArray = $backupDestination.split("\")
if (($backupDestinationArray[0] -eq "") -and ($backupDestinationArray[1] -eq "")) {
	# The destination is a UNC path (file share)
	$backupDestinationTop = "\\" + $backupDestinationArray[2] + "\" + $backupDestinationArray[3] + "\"
} else {
	# Hopefully the destination is on an ordinary drive letter
	$backupDestinationTop = split-path $backupDestination -Qualifier
	$backupDestinationTop = $backupDestinationTop + "\"
}

# Just test for the existence of the top of the backup destination. "ln" will create any folders as needed, as long as the top exists.
if (test-path $backupDestinationTop) {
	foreach($backup_source in $backupSources)
	{
		if (test-path $backup_source) {
			$stepCounter = 1
			$backupSourceArray = $backup_source.split("\")
			if (($backupSourceArray[0] -eq "") -and ($backupSourceArray[1] -eq "")) {
				# The source is a UNC path (file share) which has no drive letter. We cannot do volume shadowing from that.
				$backup_source_drive_letter = ""
			} else {
				# Hopefully the source is on an ordinary drive letter
				$backup_source_drive_letter = split-path $backup_source -Qualifier
				$backup_source_path =  split-path $backup_source -noQualifier
			}
			$backup_source_folder =  split-path $backup_source -leaf
			$dateTime = get-date -f "yyyy-MM-dd HH-mm-ss"

			$actualBackupDestination = "$backupDestination\$backup_source_folder"
			#if the user wants to keep just one backup we do a mirror without any date, so we don't need
			#to copy files that are already there
			if ($backupsToKeep -gt 1) {
				$actualBackupDestination = "$actualBackupDestination - $dateTime"
			}

			echo "============Creating Backup of $backup_source============"
			if ($NoShadowCopy -eq $False) {
				if ($backup_source_drive_letter -ne "") {
				# We can try processing a shadow copy.
					if ($shadow_drive_letter -eq $backup_source_drive_letter) {
						# The previous shadow copy must have succeeded because $NoShadowCopy is still false, and we are looping around with a matching shadow drive letter.
						echo "$stepCounter. Re-using previous Shadow Volume Copy..."
						$stepCounter++
						$backup_source_path = $s2.DeviceObject+$backup_source_path
					} else {
						if ($num_shadow_copies -gt 0) {
							# Delete the previous shadow copy that was from some other drive letter
							foreach ($shadowCopy in $shadowCopies){
							if ($s2.ID -eq $shadowCopy.ID) {
								echo  "$stepCounter. Deleting previous Shadow Copy ..."
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
								$num_shadow_copies--
								echo "done`n"
								break
								}
							}
						}
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
							$num_shadow_copies++
							$shadow_drive_letter = $backup_source_drive_letter
						}
						catch {
							$output = "ERROR: Could not create Shadow Copy`r`n$_ `r`nATTENTION: Skipping creation of Shadow Volume Copy. ATTENTION: if files are changed during the backup process, they might end up being corrupted in the backup!`r`n"
							$emailBody = "$emailBody`r`n$output`r`n"
							$error_during_backup = $true
							echo $output
							if ($LogFile) {
								$output | Out-File $LogFile -encoding ASCII -append
							}
							$backup_source_path = $backup_source
							$NoShadowCopy = $True
						}
					}
				} else {
					# We were asked to do shadow copy but the source is a UNC path.
					echo "$stepCounter. Skipping creation of Shadow Volume Copy because source is a UNC path. `r`nATTENTION: if files are changed during the backup process, they might end up being corrupted in the backup!`n"
					$stepCounter++
					$backup_source_path = $backup_source
				}
			}
			else {
				echo "$stepCounter. Skipping creation of Shadow Volume Copy. `r`nATTENTION: if files are changed during the backup process, they might end up being corrupted in the backup!`n"
				$stepCounter++
				$backup_source_path = $backup_source
			}

			echo "$stepCounter. Running backup..."
			$stepCounter++
			echo "Source: $backup_source_path"
			echo "Destination: $actualBackupDestination"

			$lastBackupFolderName = ""
			$lastBackupFolders = @()
			If (Test-Path $backupDestination){
				$oldBackupItems = Get-ChildItem -Path $backupDestination
				# get me the last backup if any
				foreach ($item in $oldBackupItems)
				{
					if ($item.Attributes -eq "Directory" -AND $item.Name  -match '^'+$backup_source_folder+' - \d{4}-\d{2}-\d{2} \d{2}-\d{2}-\d{2}$' )
					{
						$lastBackupFolderName = $item.Name
						$lastBackupFolders += $item
					}
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

			if ($LogFile) {
				$logFileCommandAppend = " >> $LogFile"
			}

			if ($lastBackupFolderName -eq "" ) {
				echo "full copy"

				#echo "$script_path\..\ln.exe $traditionalArgument $excludeString --copy `"$backup_source_path`" `"$actualBackupDestination`"    >> $LogFile"
				`cmd /c  "$script_path\..\ln.exe $traditionalArgument $excludeString --copy `"$backup_source_path`" `"$actualBackupDestination`"    $logFileCommandAppend"`
			} else {
				if ($timeTolerance -ne 0) {
					$timeToleranceArgument = " --timetolerance $timeTolerance "
				} else {
					$timeToleranceArgument = ""
				}

				echo "Delorian copy against $lastBackupFolderName"

				#echo "$script_path\..\ln.exe $traditionalArgument $timeToleranceArgument $excludeString --delorean `"$backup_source_path`" `"$backupDestination\$lastBackupFolderName`" `"$actualBackupDestination`"  >> $LogFile"
				`cmd /c  "$script_path\..\ln.exe $traditionalArgument $timeToleranceArgument $excludeString --delorean `"$backup_source_path`" `"$backupDestination\$lastBackupFolderName`" `"$actualBackupDestination`" $logFileCommandAppend"`
			}

			$summary = ""
			if ($LogFile) {
				$backup_response = get-content "$LogFile"
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

			echo "`n"

			echo  "$stepCounter. Deleting old backups ..."
			$stepCounter++
			#plus 1 because we just created a new backup
			$backupsToDelete=$lastBackupFolders.length + 1 - $backupsToKeep
			$backupsDeleted = 0
			while ($backupsDeleted -lt $backupsToDelete)
			{
				$folderToDelete =  $backupDestination +"\"+ $lastBackupFolders[$backupsDeleted].Name
				echo "Deleting $folderToDelete"
				if ($LogFile) {
					"`r`nDeleting $folderToDelete" | Out-File $LogFile  -encoding ASCII -append
				}
				Remove-Item $folderToDelete -recurse
				$backupsDeleted++
			}

			$summary = "`nDeleted $backupsDeleted old backup(s)`n"
			echo $summary
			if ($LogFile) {
				$summary | Out-File $LogFile  -encoding ASCII -append
			}

			$emailBody = $emailBody + $summary

			echo "done`n"
		} else {
			# The backup source does not exist - there was no point processing this source.
			$output = "ERROR: Backup source does not exist - $backup_source - backup NOT done for this source`r`n"
			$emailBody = "$emailBody`r`n$output`r`n"
			$error_during_backup = $true
			echo $output
			if ($LogFile) {
				$output | Out-File $LogFile -encoding ASCII -append
			}
		}
	}
	# We have processed each backup source. Now cleanup any remaining shadow copy.
	if ($num_shadow_copies -gt 0) {
		# Delete the last shadow copy
		foreach ($shadowCopy in $shadowCopies){
		if ($s2.ID -eq $shadowCopy.ID) {
			echo  "$stepCounter. Deleting last Shadow Copy ..."
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
			$num_shadow_copies--
			echo "done`n"
			break
			}
		}
	}

} else {
	# The destination drive or \\server\share does not exist.
	$output = "ERROR: Destination drive or share does not exist - backup NOT done`r`n"
	$emailBody = "$emailBody`r`n$output`r`n"
	$error_during_backup = $true
	echo $output
	if ($LogFile) {
		$output | Out-File $LogFile -encoding ASCII -append
	}
}

if ($emailTo -AND $emailFrom -AND $SMTPServer) {
	echo "============Sending Email============"
	if ($LogFile) {
		$zipFilePath = "$LogFile.zip"
		$fileToZip = get-item $LogFile

		try
		{
			New-Item $zipFilePath -type file -force -erroraction stop | Out-Null
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
			$output = "`r`nERROR: Could not create log ZIP file. Will try to attach the unzipped log file and hope it's not to big.`r`n$_`r`n"
			$emailBody = "$emailBody`r`n$output`r`n"
			echo $output
			$output | Out-File $LogFile  -encoding ASCII -append
			$attachment = New-Object System.Net.Mail.Attachment("$LogFile" )
		}
	}

	if ($error_during_backup) {
		$EmailSubject = "ERROR - $EmailSubject"
	}
	$SMTPMessage = New-Object System.Net.Mail.MailMessage($emailFrom,$emailTo,$emailSubject,$emailBody)

	if ($LogFile) {
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
		if ($LogFile) {
			$output | Out-File $LogFile -encoding ASCII -append
		}
	}

	if ($LogFile) {
		$attachment.Dispose()
	}

	echo "done"
}

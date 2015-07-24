<#
.DESCRIPTION
	ROBOCOPY-BACKUP Version: 1.1-ALPHA1

	This software is used for creating mirror copies/backups using Robocopy
	This code is based on ntfs-hardlink-backup.ps1 from https://github.com/individual-it/ntfs-hardlink-backup
	INSTALLATION:
	1. Download and place robocopy-backup.ps1 into a folder of your choice
	2. Navigate with Explorer to the .\bat folder
	3. Right Click on the robocopy-backup.ps1 file and select "Properties"
	6. If you see in the bottom something like "Security: This file came from an other computer ..." Click on "Unblock"
	7. Start powershell from windows start menu (you need Windows 7 or Win Server for that, on XP you would need to install PowerShell 2 first)
	8. Allow local non-signed scripts to run by typing "Set-ExecutionPolicy RemoteSigned"
	9. Run robocopy-backup.ps1 with full path
.SYNOPSIS
	c:\full\path\robocopy-backup.ps1 <Options>
.PARAMETER iniFile
	Path to an optional INI file that contains any of the parameters.
.PARAMETER backupSources
	Source path of the backup. Can be a list separated by comma.
.PARAMETER backupDestination
	Path where the data should go to. Can be a list separated by comma.
	The first destination that exists and, if localSubnetOnly is on, is in the local subnet, will be used.
	The backup is only ever really done to 1 destination
.PARAMETER subst
	Drive letter to substitute (subst) for the path specified in backupDestination.
	Often useful if a NAS or other device is a problem when accessed directly by UNC path.
	Sometimes if a drive letter is substituted for the UNC path then things work.
.PARAMETER logFilesToKeep
	How many log files should be kept. All older log files will be deleted. Default=50
.PARAMETER localSubnetOnly
	Switch on to only run the backup when the destination is a local disk or a server in the same subnet.
	This is useful for scheduled network backups that should only run when the laptop is on the home office network.
.PARAMETER localSubnetMask
	The IPv4 netmask that covers all the networks that should be considered local to the backup destination IPv4 address.
	Format like 255.255.255.0 (24 bits set) 255.255.240.0 (20 bits set)  255.255.0.0 (16 bits set)
	Or specify a CIDR prefix size (0 to 32)
	Use this in an office with multiple subnets that can all be covered (summarised) by a single netmask.
	Without this parameter the default is to use the subnet mask of the local machine interface(s), if localSubnetOnly is on.
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
.PARAMETER SMTPTimeout
	Timeout in ms for the Email to be sent. Default 60000.
.PARAMETER NoSMTPOverSSL
	Switch off the use of SSL to send Emails.
.PARAMETER NoShadowCopy
	Switch off the use of Shadow Copies. Can be useful if you have no permissions to create Shadow Copies.
.PARAMETER SMTPPort
	Port of the SMTP Server. Default=587
.PARAMETER emailJobName
	This is added in to the auto-generated email subject "Robocopy mirror of: hostname emailJobName by: username"
.PARAMETER emailSubject
	Subject for the notification Email. This overrides the auto-generated email subject and emailJobName.
.PARAMETER emailSendRetries
	How many times should we try to resend the Email. Default = 100
.PARAMETER msToPauseBetweenEmailSendRetries
	Time in ms to wait between the resending of the Email. Default = 60000
.PARAMETER LogFile
	Path and filename for the logfile. If just a path is given, then "yyyy-mm-dd hh-mm-ss.log" is written to that folder.
	Default is to write "yyyy-mm-dd hh-mm-ss.log" in the backup destination folder.
.PARAMETER StepTiming
	Switch on display of the time at each step of the job.
.PARAMETER preExecutionCommand
	Command to run before the start of the backup.
.PARAMETER preExecutionDelay
	Time in milliseconds to pause between running the preExecutionCommand and the start of the backup. Default = 0
.PARAMETER postExecutionCommand
	Command to run after the backup is done.
.PARAMETER version
	print the version information and exit.
.EXAMPLE
	PS D:\> d:\scripts\robocopy-backup.ps1 -backupSources D:\backup_source1 -backupDestination E:\backup_dest -emailTo "me@example.org" -emailFrom "backup@example.org" -SMTPServer example.org -SMTPUser "backup@example.org" -SMTPPassword "secr4et"
	Simple backup that will create a mirror of the D:\backup_source1 folder tree to a matching tree E:\backup_dest\backup_source1
.EXAMPLE
	PS D:\> d:\scripts\robocopy-backup.ps1 -backupSources "D:\backup_source1","C:\backup_source2" -backupDestination E:\backup_dest -emailTo "me@example.org" -emailFrom "backup@example.org" -SMTPServer example.org -SMTPUser "backup@example.org" -SMTPPassword "secr4et"
	Backup with more than one source that will create a mirror of the D:\backup_source1 folder tree to a matching tree E:\backup_dest\backup_source1 and the C:\backup_source2 folder tree to a matching tree E:\backup_dest\backup_source2
.NOTES
	Author: Phil Davis *INFN*
#>

[CmdletBinding()]
Param(
	[Parameter(Mandatory=$False)]
	[String]$iniFile,
	[Parameter(Mandatory=$False)]
	[String[]]$backupSources,
	[Parameter(Mandatory=$False)]
	[String[]]$backupDestination,
	[Parameter(Mandatory=$False)]
	[String]$subst,
	[Parameter(Mandatory=$False)]
	[Int32]$logFilesToKeep,
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
	[Int32]$SMTPPort,
	[Parameter(Mandatory=$False)]
	[Int32]$SMTPTimeout,
	[Parameter(Mandatory=$False)]
	[Int32]$emailSendRetries,
	[Parameter(Mandatory=$False)]
	[Int32]$msToPauseBetweenEmailSendRetries,
	[Parameter(Mandatory=$False)]
	[switch]$localSubnetOnly,
	[Parameter(Mandatory=$False)]
	[string]$localSubnetMask,
	[Parameter(Mandatory=$False)]
	[string]$emailSubject="",
	[Parameter(Mandatory=$False)]
	[string]$emailJobName="",
	[Parameter(Mandatory=$False)]
	[string]$LogFile="",
	[Parameter(Mandatory=$False)]
	[switch]$StepTiming=$False,
	[Parameter(Mandatory=$False)]
	[string]$preExecutionCommand="",
	[Parameter(Mandatory=$False)]
	[Int32]$preExecutionDelay,
	[Parameter(Mandatory=$False)]
	[string]$postExecutionCommand="",
	[Parameter(Mandatory=$False)]
	[switch]$version=$False
)

#The path and filename of the script it self
$script_path = Split-Path -parent $MyInvocation.MyCommand.Definition

Function Get-IniContent
{
	<#
	.Synopsis
		Gets the content of an INI file

	.Description
		Gets the content of an INI file and returns it as a hashtable

	.Notes
		Author    : Oliver Lipkau <oliver@lipkau.net>
		Blog      : http://oliver.lipkau.net/blog/
		Date      : 2014/06/23
		Version   : 1.1

		#Requires -Version 2.0

	.Inputs
		System.String

	.Outputs
		System.Collections.Hashtable

	.Parameter FilePath
		Specifies the path to the input file.

	.Example
		$FileContent = Get-IniContent "C:\myinifile.ini"
		-----------
		Description
		Saves the content of the c:\myinifile.ini in a hashtable called $FileContent

	.Example
		$inifilepath | $FileContent = Get-IniContent
		-----------
		Description
		Gets the content of the ini file passed through the pipe into a hashtable called $FileContent

	.Example
		C:\PS>$FileContent = Get-IniContent "c:\settings.ini"
		C:\PS>$FileContent["Section"]["Key"]
		-----------
		Description
		Returns the key "Key" of the section "Section" from the C:\settings.ini file

	.Link
		Out-IniFile
	#>

	[CmdletBinding()]
	Param(
		[ValidateNotNullOrEmpty()]
		[ValidateScript({(Test-Path $_) -and ((Get-Item $_).Extension -eq ".ini")})]
		[Parameter(ValueFromPipeline=$True,Mandatory=$True)]
		[string]$FilePath
	)

	Begin
		{Write-Verbose "$($MyInvocation.MyCommand.Name):: Function started"}

	Process
	{
		Write-Verbose "$($MyInvocation.MyCommand.Name):: Processing file: $Filepath"

		#changed from HashTable to OrderedDictionary to keep the sections in the order they were added - Artur Neumann
		$ini = New-Object System.Collections.Specialized.OrderedDictionary
		switch -regex -file $FilePath
		{
			"^\[(.+)\]$" # Section
			{
				$section = $matches[1]
				# Added ToLower line to make INI file case-insensitive - Phil Davis
				$section = $section.ToLower()
				$ini[$section] = @{}
				$CommentCount = 0
			}
			"^(;.*)$" # Comment
			{
				if (!($section))
				{
					$section = "No-Section"
					$ini[$section] = @{}
				}
				$value = $matches[1]
				$CommentCount = $CommentCount + 1
				$name = "Comment" + $CommentCount
				$ini[$section][$name] = $value
			}
			"(.+?)\s*=\s*(.*)" # Key
			{
				if (!($section))
				{
					$section = "No-Section"
					$ini[$section] = @{}
				}
				$name,$value = $matches[1..2]
				# Added ToLower line to make INI file case-insensitive - Phil Davis
				$name = $name.ToLower()
				$ini[$section][$name] = $value
			}
		}
		Write-Verbose "$($MyInvocation.MyCommand.Name):: Finished Processing file: $FilePath"
		Return $ini
	}

	End
	{Write-Verbose "$($MyInvocation.MyCommand.Name):: Function ended"}
}

Function Get-IniParameter
{
	# Note: iniFileContent dictionary is not passed in each time.
	# Just use the global value to reference that.
	[CmdletBinding()]
	Param(
		[ValidateNotNullOrEmpty()]
		[Parameter(Mandatory=$True)]
		[string]$ParameterName,
		[ValidateNotNullOrEmpty()]
		[Parameter(Mandatory=$True)]
		[string]$FQDN,
		[ValidateNotNullOrEmpty()]
		[Parameter(Mandatory=$False)]
		[switch]$doNotSubstitute=$False
	)

	Begin
		{Write-Verbose "$($MyInvocation.MyCommand.Name):: Function started"}

	Process
	{
		Write-Verbose "$($MyInvocation.MyCommand.Name):: Processing for IniSection: $FQDN and ParameterName: $ParameterName"

		# Use ToLower to make all parameter name comparisons case-insensitive
		$ParameterName = $ParameterName.ToLower()
		$ParameterValue = $Null

		$FQDN=$FQDN.ToLower()

		#search first the "common" section for the parameter, this will have the lowest priority
		#as the parameter can be overwritten by other sections
		if ($global:iniFileContent.Contains("common")) {
			if (-not [string]::IsNullOrEmpty($global:iniFileContent["common"][$ParameterName])) {
				$ParameterValue = $global:iniFileContent["common"][$ParameterName]
			}
		}

		#search if there is a section that matches the FQDN
		#this is the second highest priority, as the parameter can still be overwritten by the
		#section that meets exactly the FQDN
		#If there is more than one section that matches the FQDN with the same parameter
		#the section furthest down in the ini file will be used
		foreach ($IniSection in $($global:iniFileContent.keys)){
			$EscapedIniSection=$IniSection -replace "([\-\[\]\{\}\(\)\+\?\.\,\\\^\$\|\#])",'\$1'
			$EscapedIniSection=$IniSection -replace "\*",'.*'
			if ($FQDN -match "^$EscapedIniSection$") {
				if (-not [string]::IsNullOrEmpty($global:iniFileContent[$IniSection][$ParameterName])) {
					$ParameterValue = $global:iniFileContent[$IniSection][$ParameterName]
				}
			}
		}

		#see if there is section that is called exactly the same as the computer (FQDN)
		#this is the highest priority, so if the same parameters are used in other sections
		#this section will overwrite them
		if ($global:iniFileContent.Contains($FQDN)) {
			if (-not [string]::IsNullOrEmpty($global:iniFileContent[$FQDN][$ParameterName])) {
				$ParameterValue = $global:iniFileContent[$FQDN][$ParameterName]
			}
		}

		#replace all <parameter> with the parameter values
		if ($doNotSubstitute -eq $False) {
			$substituteMatches=$ParameterValue | Select-String -AllMatches '<[^<]+?>' | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value

			foreach ($match in $substituteMatches) {
				if(![string]::IsNullOrEmpty($match)) {
					$match=$($match.Trim())
					$cleanMatch=$match.Replace("<","").Replace(">","")
					if ($(test-path env:$($cleanMatch))) {
						$substituteValue=$(get-childitem -path env:$($cleanMatch)).Value
						$ParameterValue =$ParameterValue.Replace($match,$substituteValue)
					}
				}
			}
		}

		Write-Verbose "$($MyInvocation.MyCommand.Name):: Finished Processing for IniSection: $FQDN and ParameterName: $ParameterName ParameterValue: $ParameterValue"
		Return $ParameterValue
	}

	End
	{Write-Verbose "$($MyInvocation.MyCommand.Name):: Function ended"}
}

Function Is-TrueString
{
	# Pass in a string (or nothing) and return a boolean deciding if the string
	# is "1", "true", "t" (True) or otherwise it is (False)
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory=$False)]
		[string]$TruthString
	)

	Begin
		{Write-Verbose "$($MyInvocation.MyCommand.Name):: Function started"}

	Process
	{
		Write-Verbose "$($MyInvocation.MyCommand.Name):: Processing for TruthString: $TruthString"

		# Use ToLower to make comparisons case-insensitive
		$TruthString = $TruthString.ToLower()
		$ParameterValue = $Null

		if (($TruthString -eq "t") -or ($TruthString -eq "true") -or ($TruthString -eq "1")) {
			$TruthValue = $True
		} else {
			$TruthValue = $False
		}

		Write-Verbose "$($MyInvocation.MyCommand.Name):: Finished Processing for TruthString: $TruthString TruthValue: $TruthValue"
		Return $TruthValue
	}

	End
	{Write-Verbose "$($MyInvocation.MyCommand.Name):: Function ended"}
}

Function Get-Version
{
<#
	.Synopsis
		Gets the version of this script

	.Description
		Parses the description for a line that looks like:
		ROBOCOPY-BACKUP Version: 1.0.ALPHA.1
		and gets the version information out of it
		The version string must be in the .DESCRIPTION scope and must start with
		"ROBOCOPY-BACKUP Version: "

	.Outputs
		System.String
	#>

	#Get the help-text of my self
	$helpText=Get-Help $script_path/robocopy-backup.ps1

	#Get-Help returns a PSObjects with other PSObjects inside
	#So we are trying some black magic to get a string out of it and then to parse the version

	Foreach ($object in $helpText.psobject.properties) {
		#loop through all properties of the PSObject and find the description
		if (($object.Value) -and  ($object.name -eq "description")) {
			#the description is a object of the class System.Management.Automation.PSNoteProperty
			#and inside of the properties of that are System.Management.Automation.PSPropertyInfo objects (in our case only one)
			#still we loop though, just in case there are more that one and see if the value (what is finally a string), does match the version string
			Foreach ($subObject in $object.Value[0].psobject.properties) {
				 if ($subObject.Value -match "ROBOCOPY-BACKUP Version: (.*)")	{
						return $matches[1]
				}
			}
		}
	}
}

$emailBody = ""
$error_during_backup = $false
$doBackup = $true
$maxMsToSleepForZipCreation = 1000*60*30
$msToWaitDuringZipCreation = 500
$shadow_drive_letter = ""
$num_shadow_copies = 0
$stepTime = ""
$backupMappedPath = ""
$backupHostName = ""
$deleteOldLogFiles = $False
$FQDN = [System.Net.DNS]::GetHostByName('').HostName
$userName = [Environment]::UserName
$tempLogContent = ""
$substDone = $False

$versionString=Get-Version

if ($version) {
	echo $versionString
	exit
} else {
	$output = "ROBOCOPY-BACKUP $versionString`r`n"
	$emailBody = "$emailBody`r`n$output`r`n"
	$tempLogContent += $output
	echo $output
}

if ($iniFile) {
	if (Test-Path -Path $iniFile -PathType leaf) {
		$output = "Using ini file`r`n$iniFile`r`n"
		$emailBody = "$emailBody`r`n$output`r`n"
		echo $output
		$global:iniFileContent = Get-IniContent "${iniFile}"
	} else {
		$global:iniFileContent =  New-Object System.Collections.Specialized.OrderedDictionary
		$output = "ERROR: Could not find ini file`r`n$iniFile`r`n"
		$emailBody = "$emailBody`r`n$output`r`n"
		echo $output
	}
} else {
		$global:iniFileContent =  New-Object System.Collections.Specialized.OrderedDictionary
}

$parameters_ok = $True

if ([string]::IsNullOrEmpty($backupSources)) {
	$backupsourcelist = Get-IniParameter "backupsources" "${FQDN}"
	if (-not [string]::IsNullOrEmpty($backupsourcelist)) {
		$backupSources = $backupsourcelist.split(",")
	}
}

if ([string]::IsNullOrEmpty($backupDestination)) {
	$backupDestinationList = Get-IniParameter "backupdestination" "${FQDN}"

	if (-not [string]::IsNullOrEmpty($backupDestinationList)) {
		$backupDestination = $backupDestinationList.split(",")
	}
}

if ([string]::IsNullOrEmpty($subst)) {
	$subst = Get-IniParameter "subst" "${FQDN}"
}

# This is always a drive-like letter, so it looks usual in Windows to be upper-case
$subst = $subst.toupper()

if ($logFilesToKeep -eq 0) {
	$logFilesToKeep = Get-IniParameter "logfilestokeep" "${FQDN}"
	if ($logFilesToKeep -eq 0) {
		$logFilesToKeep = 50;
	}
}

if ([string]::IsNullOrEmpty($emailTo)) {
	$emailTo = Get-IniParameter "emailTo" "${FQDN}"
}

if ([string]::IsNullOrEmpty($emailFrom)) {
	$emailFrom = Get-IniParameter "emailFrom" "${FQDN}"
}

if ([string]::IsNullOrEmpty($SMTPServer)) {
	$SMTPServer = Get-IniParameter "SMTPServer" "${FQDN}"
}

if ([string]::IsNullOrEmpty($SMTPUser)) {
	$SMTPUser = Get-IniParameter "SMTPUser" "${FQDN}"
}

if ([string]::IsNullOrEmpty($SMTPPassword)) {
	$SMTPPassword = Get-IniParameter "SMTPPassword" "${FQDN}" -doNotSubstitute
}

if (-not $NoSMTPOverSSL.IsPresent) {
	$IniFileString = Get-IniParameter "NoSMTPOverSSL" "${FQDN}"
	$NoSMTPOverSSL = Is-TrueString "${IniFileString}"
}

if (-not $NoShadowCopy.IsPresent) {
	$IniFileString = Get-IniParameter "NoShadowCopy" "${FQDN}"
	$NoShadowCopy = Is-TrueString "${IniFileString}"
}

if ($SMTPPort -eq 0) {
	$SMTPPort = Get-IniParameter "SMTPPort" "${FQDN}"
	if ($SMTPPort -eq 0) {
		$SMTPPort = 587;
	}
}

if ($SMTPTimeout -eq 0) {
	$SMTPTimeout = Get-IniParameter "SMTPTimeout" "${FQDN}"
	if ($SMTPTimeout -eq 0) {
		$SMTPTimeout = 60000;
	}
}

if ($emailSendRetries -eq 0) {
	$emailSendRetries = Get-IniParameter "emailSendRetries" "${FQDN}"
	if ($emailSendRetries -eq 0) {
		$emailSendRetries = 100;
	}
}

if ($msToPauseBetweenEmailSendRetries -eq 0) {
	$msToPauseBetweenEmailSendRetries = Get-IniParameter "msToPauseBetweenEmailSendRetries" "${FQDN}"
	if ($msToPauseBetweenEmailSendRetries -eq 0) {
		$msToPauseBetweenEmailSendRetries = 60000;
	}
}

if (-not $localSubnetOnly.IsPresent) {
	$IniFileString = Get-IniParameter "localSubnetOnly" "${FQDN}"
	$localSubnetOnly = Is-TrueString "${IniFileString}"
}

if ([string]::IsNullOrEmpty($localSubnetMask)) {
	$localSubnetMask = Get-IniParameter "localSubnetMask" "${FQDN}"
}

if (![string]::IsNullOrEmpty($localSubnetMask)) {
	$CIDRbitCount = 0
	# Check if we have an integer
	if ([int]::TryParse($localSubnetMask, [ref]$CIDRbitCount)) {
		# That is also in the range 0 to 32
		if (($CIDRbitCount -ge 0) -and ($CIDRbitCount -le 32)) {
			# And turn it into a 255.255.255.0 style string
			$CIDRremainder = $CIDRbitCount % 8
			$CIDReights = [Math]::Floor($CIDRbitCount / 8)
			switch ($CIDRremainder) {
				0 { $CIDRbitText = "0" }
				1 { $CIDRbitText = "128" }
				2 { $CIDRbitText = "192" }
				3 { $CIDRbitText = "224" }
				4 { $CIDRbitText = "240" }
				5 { $CIDRbitText = "248" }
				6 { $CIDRbitText = "252" }
				7 { $CIDRbitText = "254" }
			}
			switch ($CIDReights) {
				0 { $localSubnetMask = $CIDRbitText + ".0.0.0" }
				1 { $localSubnetMask = "255." + $CIDRbitText + ".0.0" }
				2 { $localSubnetMask = "255.255." + $CIDRbitText + ".0" }
				3 { $localSubnetMask = "255.255.255." + $CIDRbitText }
				4 { $localSubnetMask = "255.255.255.255" }
			}
		}
	}
	$validNetMaskNumbers = '0|128|192|224|240|248|252|254|255'
	$netMaskRegexArray = @(
		"(^($validNetMaskNumbers)\.0\.0\.0$)"
		"(^255\.($validNetMaskNumbers)\.0\.0$)"
		"(^255\.255\.($validNetMaskNumbers)\.0$)"
		"(^255\.255\.255\.($validNetMaskNumbers)$)"
	)
	$netMaskRegex = [string]::Join('|', $netMaskRegexArray)

	if (!(($localSubnetMask -Match $netMaskRegex))) {
		# The string is not a valid network mask.
		# It should be something like 255.255.255.0
		$output = "`nERROR: localSubnetMask $localSubnetMask is not valid`n"
		echo $output
		$emailBody = "$emailBody`r`n$output`r`n"

		$tempLogContent += $output

		$parameters_ok = $False
		$localSubnetMask = ""
	}
}

if ([string]::IsNullOrEmpty($emailSubject)) {
	$emailSubject = Get-IniParameter "emailSubject" "${FQDN}"
}

if ([string]::IsNullOrEmpty($emailJobName)) {
	$emailJobName = Get-IniParameter "emailJobName" "${FQDN}"
}

if (-not $StepTiming.IsPresent) {
	$IniFileString = Get-IniParameter "StepTiming" "${FQDN}"
	$StepTiming = Is-TrueString "${IniFileString}"
}

if ([string]::IsNullOrEmpty($emailSubject)) {
	if (-not ([string]::IsNullOrEmpty($emailJobName))) {
		$emailJobName += " "
	}
	$emailSubject = "Robocopy mirror of: ${FQDN} ${emailJobName}by: ${userName}"
}

if ([string]::IsNullOrEmpty($preExecutionCommand)) {
	$preExecutionCommand = Get-IniParameter "preExecutionCommand" "${FQDN}" -doNotSubstitute
}

if (![string]::IsNullOrEmpty($preExecutionCommand)) {
	$output = "`nrunning preexecution command ($preExecutionCommand)`n"
	$output += `cmd /c  `"$preExecutionCommand`" 2`>`&1`

	#if the command fails we want a message in the Email, otherwise the details will be only shown in the log file
	#make sure this if statement is directly after the cmd command
	if(!$?) {
		$output += "`n`nERROR: the pre-execution-command ended with an error"
		$emailBody = "$emailBody`r$output`r`n"
		$error_during_backup = $True
	}

	$output += "`n"
	echo $output
	$tempLogContent += $output
	}

if ($preExecutionDelay -eq 0) {
	$preExecutionDelay = Get-IniParameter "preExecutionDelay" "${FQDN}"
	if ($preExecutionDelay -eq 0) {
		# Looks dumb, but left here if you want to change the default from zero.
		$preExecutionDelay = 0;
	}
}

if ($preExecutionDelay -gt 0) {
	echo "I'm gona be lazy now"

	Write-Host -NoNewline "

         ___    z
       _/   |  z
      |_____|{)_
        --- ==\/\ |
      [_____]  __)|
      |   |  //| |
	"
	$CursorTop=[Console]::CursorTop
	[Console]::SetCursorPosition(18,$CursorTop-7)
	for ($msSleeped=0;$msSleeped -lt $preExecutionDelay; $msSleeped+=1000){
		Start-sleep -milliseconds 1000
		Write-Host -NoNewline "z "
	}
	[Console]::SetCursorPosition(0,$CursorTop)
	Write-Host "I guess it's time to wake up.`n"
}

if ([string]::IsNullOrEmpty($postExecutionCommand)) {
	$postExecutionCommand = Get-IniParameter "postExecutionCommand" "${FQDN}" -doNotSubstitute
}

$dateTime = get-date -f "yyyy-MM-dd HH-mm-ss"

if ([string]::IsNullOrEmpty($backupDestination)) {
	# No backup destination on command line or in INI file
	# backup destination is mandatory, so flag the problem.
	$output = "`nERROR: No backup destination specified`n"
	echo $output
	$emailBody = "$emailBody`r`n$output`r`n"

	$tempLogContent += $output

	$parameters_ok = $False
} else {
	foreach ($possibleBackupDestination in $backupDestination) {
		# Initialize vars used in this loop to ensure they do not end up with values from previous loop iterations.
		$backupDestinationTop = ""
		$backupMappedPath = ""
		$backupHostName = ""

		# If the user wants to substitute a drive letter for the backup destination, do that now.
		# Then following code can process the resulting "subst" in the same way as if the user had done it externally.
		if (-not ([string]::IsNullOrEmpty($subst))) {
			if ($subst -match "^[A-Z]:?$") { #TODO add check if we try to subst a not UNC path
				$substDrive = $subst.Substring(0,1) + ":"
				# Delete any previous or externally-defined subst-ed drive on this letter.
				# Send the output to null, as usually the first attempted delete will give an error, and we do not care.
				$substDone = $False
				subst "$substDrive" /d | Out-Null
				try {
					if (!(Test-Path -Path $possibleBackupDestination)) {
						New-Item $possibleBackupDestination -type directory -ea stop | Out-Null
					}
					subst "$substDrive" $possibleBackupDestination
					$possibleBackupDestination = $substDrive
					$substDone = $True
				}
				catch {
					$output = "`nWARNING: Destination $possibleBackupDestination was not found and could not be created. $_`n"
					echo $output
					$destWarningText = "$destWarningText`r`n$output`r`n"

					$tempLogContent += $output
				}

			} else {
				$output = "`nERROR: subst parameter $subst is invalid`n"
				echo $output
				$emailBody = "$emailBody`r`n$output`r`n"

				$tempLogContent += $output

				# Flag that there is a problem, but let following code process and report any other problems before bailing out.
				$parameters_ok = $False
			}
		}

		# Process the backup destination to find out where it might be
		$backupDestinationArray = $possibleBackupDestination.split("\")

		if (($backupDestinationArray[0] -eq "") -and ($backupDestinationArray[1] -eq "")) {
			# The destination is a UNC path (file share)
			$backupDestinationTop = "\\" + $backupDestinationArray[2] + "\" + $backupDestinationArray[3] + "\"
			$backupMappedPath = $backupDestinationTop
			$backupHostName = $backupDestinationArray[2]
		} else {
			if (-not ($possibleBackupDestination -match ":")) {
				# No drive letter specified. This could be an attempt at a relative path, so first resolve it to the full path.
				# This allows us to use split-path -Qualifier below to get the actual drive letter
				$possibleBackupDestination = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($possibleBackupDestination)
			}
			$backupDestinationDrive = split-path $possibleBackupDestination -Qualifier
			# toupper the backupDestinationDrive string to help findstr below match the upper-case output of subst.
			# Also seems a reasonable thing to do in Windows, since drive letters are usually displayed in upper-case.
			$backupDestinationDrive = $backupDestinationDrive.toupper()
			$backupDestinationTop = $backupDestinationDrive + "\"
			# See if the disk letter is mapped to a file share somewhere.
			$backupDriveObject = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='$backupDestinationDrive'"
			$backupMappedPath = $backupDriveObject.ProviderName
			if ($backupMappedPath) {
				$backupPathArray = $backupMappedPath.split("\")
				if (($backupPathArray[0] -eq "") -and ($backupPathArray[1] -eq "")) {
					# The underlying destination is a UNC path (file share)
					$backupHostName = $backupPathArray[2]
				}
			} else {
				# Maybe the user did a "subst" command. Check for that.
				$substText = (Subst) | findstr "$backupDestinationDrive\\"
				# Looks like one of:
				# R:\: => UNC\hostname.myoffice.company.org\sharename
				# R:\: => C:\some\folder\path
				# If a subst exists, it should always split into 3 space-separated parts
				$parts = $substText -Split " "
				if (($parts[0]) -and ($parts[1]) -and ($parts[2])) {
					$backupMappedPath = $parts[2]
					if ($backupMappedPath -match "^UNC\\") {
						$host_FQDN = $backupMappedPath.split("\")[1]
						$backupMappedPath = "\" + $backupMappedPath.Substring(3)
						if ($host_FQDN) {
							$backupHostName = $host_FQDN
						}
					}
				}
			}
		}

		if ($backupMappedPath) {
			$backupMappedString = " (" + $backupMappedPath + ")"
		} else {
			$backupMappedString = ""
		}

		if (($localSubnetOnly -eq $True) -and ($backupHostName)) {
			# Check that the name is in the same subnet as us.
			# Note: This also works if the user gives a real IPv4 like "\\10.20.30.40\backupshare"
			# $backupHostName would be 10.20.30.40 in that case.
			# TODO: Handle IPv6 addresses also some day.
			$doBackup = $false
			try {
				$destinationIpAddresses = [System.Net.Dns]::GetHostAddresses($backupHostName)
				[IPAddress]$destinationIp = $destinationIpAddresses[0]

				$localAdapters = (Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter 'ipenabled = "true"')

				foreach ($adapter in $localAdapters) {
					# Belts and braces here - we have seen some systems that returned unusual adapters that had IPaddress 0.0.0.0 and no IPsubnet
					# We want to ignore that sort of rubbish - the mask comparisons do not work.
					if ($adapter.IPAddress[0]) {
						[IPAddress]$IPv4Address = $adapter.IPAddress[0]
						if ($adapter.IPSubnet[0]) {
							if ([string]::IsNullOrEmpty($localSubnetMask)) {
								[IPAddress]$mask = $adapter.IPSubnet[0]
							} else {
								[IPAddress]$mask = $localSubnetMask
							}

							if (($IPv4address.address -band $mask.address) -eq ($destinationIp.address -band $mask.address)) {
								$doBackup = $true
							}
						}
					}
				}
			}
			catch {
				$output = "WARNING: Could not get IP address for destination $possibleBackupDestination mapped to $backupMappedPath"
				$destWarningText = "$destWarningText`r`n$output`r`n$_"
				$error_during_backup = $true
				echo $output  $_
			}
		}

		if (($parameters_ok -eq $True) -and ($doBackup -eq $True) -and (test-path $backupDestinationTop)) {
				$selectedBackupDestination = $possibleBackupDestination
				break
		}
	}
}

if ([string]::IsNullOrEmpty($LogFile)) {
	$LogFile = Get-IniParameter "LogFile" "${FQDN}"
}

if ([string]::IsNullOrEmpty($LogFile)) {
	# No log file specified from command line - put one in the backup destination with date-time stamp.
	$logFileDestination = $selectedBackupDestination
	if ($logFileDestination) {
		$LogFile = "$logFileDestination\$dateTime.log"
	} else {
		# This can happen if both the logfile and backup destination parameters were not in the INI file and not on the command line.
		# In this case no log file is made. But we do proceed so there will be an email body and the receiver can find out what is wrong.
		$LogFile = ""
	}
	$deleteOldLogFiles = $True
} else {
	if (Test-Path -Path $LogFile -pathType container) {
		# The log file parameter points to a folder, so generate log file names in that folder.
		$logFileDestination = $LogFile
		$LogFile = "$logFileDestination\$dateTime.log"
		$deleteOldLogFiles = $True
	} else {
		# The log file name has been fully specified - just calculate the parent folder.
		$logFileDestination = Split-Path -parent $LogFile
	}
}

try
{
	New-Item "$LogFile" -type file -force -erroraction stop | Out-Null
}
catch
{
	$output = "ERROR: Could not create new log file`r`n$_`r`n"
	$emailBody = "$emailBody`r`n$output`r`n"
	echo $output
	$LogFile=""
	$error_during_backup = $True
	$deleteOldLogFiles = $False
}

#write the logs from the time we hadn't a logfile into the file
if ($LogFile) {
	$tempLogContent | Out-File "$LogFile"  -encoding ASCII -append
}

if ([string]::IsNullOrEmpty($backupSources)) {
	# No backup sources on command line, in host-specific or common section of ini file
	# backup sources are mandatory, so flag the problem.
	$output = "`nERROR: No backup source(s) specified`n"
	echo $output
	$emailBody = "$emailBody`r`n$output`r`n"
	if ($LogFile) {
		$output | Out-File "$LogFile"  -encoding ASCII -append
	}
	$parameters_ok = $False
}

# Just test for the existence of the top of the backup destination. "ln" will create any folders as needed, as long as the top exists.
if (($parameters_ok -eq $True) -and ($doBackup -eq $True) -and (test-path $backupDestinationTop)) {
	foreach ($backup_source in $backupSources)
	{
		# Remove any "\" at the end as it is not needed
		if ($backup_source.substring($backup_source.length-1,1) -eq "\") {
			$backup_source=$backup_source.Substring(0,$backup_source.Length-1)
		}

		if (test-path -LiteralPath $backup_source) {
			$stepCounter = 1
			$backupSourceArray = $backup_source.split("\")
			if (($backupSourceArray[0] -eq "") -and ($backupSourceArray[1] -eq "")) {
				# The source is a UNC path (file share) which has no drive letter. We cannot do volume shadowing from that.
				$backup_source_drive_letter = ""
				$backup_source_path = ""
			} else {
				if (-not ($backup_source -match ":")) {
					# No drive letter specified. This could be an attempt at a relative path, so first resolve it to the full path.
					# This allows us to use split-path -Qualifier below to get the actual drive letter
					$backup_source = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($backup_source)
				}
				$backup_source_drive_letter = split-path $backup_source -Qualifier
				$backup_source_path =  split-path $backup_source -noQualifier
			}

			#check if we try to backup a complete drive
			if (($backup_source_drive_letter -ne "") -and ($backup_source_path -eq "")) {
				if ($backup_source_drive_letter -match "([A-Z]):") {
					$backup_source_folder = "["+$matches[1]+"]"
				}
			} else {
				$backup_source_folder =  split-path $backup_source -leaf
			}

			$actualBackupDestination = "$selectedBackupDestination\$backup_source_folder"

			echo "============Creating Robocopy mirror of $backup_source============"
			if ($NoShadowCopy -eq $False) {
				if ($backup_source_drive_letter -ne "") {
				# We can try processing a shadow copy.
					if ($shadow_drive_letter -eq $backup_source_drive_letter) {
						# The previous shadow copy must have succeeded because $NoShadowCopy is still false, and we are looping around with a matching shadow drive letter.
						if ($StepTiming -eq $True) {
							$stepTime = get-date -f "yyyy-MM-dd HH-mm-ss"
						}
						echo "$stepCounter. $stepTime Re-using previous Shadow Volume Copy"
						$stepCounter++
						$backup_source_path = $s2.DeviceObject+$backup_source_path
					} else {
						if ($num_shadow_copies -gt 0) {
							# Delete the previous shadow copy that was from some other drive letter
							foreach ($shadowCopy in $shadowCopies) {
								if ($s2.ID -eq $shadowCopy.ID) {
									if ($StepTiming -eq $True) {
										$stepTime = get-date -f "yyyy-MM-dd HH-mm-ss"
									}
									echo  "$stepCounter. $stepTime Deleting previous Shadow Copy"
									$stepCounter++
									try {
										$shadowCopy.Delete()
									}
									catch {
										$output = "ERROR: Could not delete Shadow Copy"
										$emailBody = "$emailBody`r`n$output`r`n$_"
										$error_during_backup = $true
										echo $output  $_
									}
									$num_shadow_copies--
									echo "done`n"
									break
								}
							}
						}
						if ($StepTiming -eq $True) {
							$stepTime = get-date -f "yyyy-MM-dd HH-mm-ss"
						}
						echo "$stepCounter. $stepTime Creating Shadow Volume Copy"
						$stepCounter++
						try {
							$s1 = (gwmi -List Win32_ShadowCopy).Create("$backup_source_drive_letter\", "ClientAccessible")
							$s2 = gwmi Win32_ShadowCopy | ? { $_.ID -eq $s1.ShadowID }

							if ($s1.ReturnValue -ne 0 -OR !$s2) {
								#ToDo add explanation of return codes http://msdn.microsoft.com/en-us/library/aa389391%28v=vs.85%29.aspx
								throw "Shadow Copy Creation failed. Return Code: " + $s1.ReturnValue
							}

							echo "Shadow Volume ID: $($s2.ID)"
							echo "Shadow Volume DeviceObject: $($s2.DeviceObject)"

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
								$output | Out-File "$LogFile" -encoding ASCII -append
							}
							$backup_source_path = $backup_source
							$NoShadowCopy = $True
						}
					}
				} else {
					# We were asked to do shadow copy but the source is a UNC path.
					$output = "Skipping creation of Shadow Volume Copy because source is a UNC path `r`nATTENTION: if files are changed during the backup process, they might end up being corrupted in the backup!`n"
					if ($StepTiming -eq $True) {
						$stepTime = get-date -f "yyyy-MM-dd HH-mm-ss"
					}
					echo "$stepCounter. $stepTime $output"
					if ($LogFile) {
						$output | Out-File "$LogFile" -encoding ASCII -append
					}
					$stepCounter++
					$backup_source_path = $backup_source
				}
			}
			else {
				$output = "Skipping creation of Shadow Volume Copy `r`nATTENTION: if files are changed during the backup process, they might end up being corrupted in the backup!`n"
				if ($StepTiming -eq $True) {
					$stepTime = get-date -f "yyyy-MM-dd HH-mm-ss"
				}
				echo "$stepCounter. $stepTime $output"
				if ($LogFile) {
					$output | Out-File "$LogFile" -encoding ASCII -append
				}
				$stepCounter++
				$backup_source_path = $backup_source
			}

			if ($StepTiming -eq $True) {
				$stepTime = get-date -f "yyyy-MM-dd HH-mm-ss"
			}
			echo "$stepCounter. $stepTime Running backup"
			$stepCounter++
			echo "Source: $backup_source_path"
			echo "Destination: $actualBackupDestination$backupMappedString"

			if ($LogFile) {
				$logFileCommandAppend = " >> `"$LogFile`""
			}

			$start_time = get-date -f "yyyy-MM-dd HH-mm-ss"

			echo "Robocopy mirror from $backup_source_path to $actualBackupDestination$backupMappedString"
			if ($LogFile) {
				"`r`nRobocopy mirror from $backup_source_path to $actualBackupDestination$backupMappedString" | Out-File "$LogFile"  -encoding ASCII -append
			}

			# Z = restartable mode
			# MIR = mirror (copy all new/changed files from whole source tree, delete files in destination that are not in source)
			# XJ = exclude Junction Points - sometimes there are DFS hidden folders on shares that are junction points managed by DFS, we do not want those
			#echo "robocopy /Z /MIR /XJ `"$backup_source_path`" `"$actualBackupDestination`" $logFileCommandAppend"
			`cmd /c  "robocopy /Z /MIR /XJ `"$backup_source_path`" `"$actualBackupDestination`" $logFileCommandAppend 2`>`&1 "`

			# Robocopy exit codes are documented at http://support.microsoft.com/kb/954404
			# and here is the table of codes:
			# The following table lists and describes the return codes that are used by the Robocopy utility.
			# Value	Description
			# 0		No files were copied. No failure was encountered. No files were mismatched. The files already exist in the destination directory; therefore, the copy operation was skipped.
			# 1		All files were copied successfully.
			# 2		There are some additional files in the destination directory that are not present in the source directory. No files were copied.
			# 3		Some files were copied. Additional files were present. No failure was encountered.
			# 5		Some files were copied. Some files were mismatched. No failure was encountered.
			# 6		Additional files and mismatched files exist. No files were copied and no failures were encountered. This means that the files already exist in the destination directory.
			# 7		Files were copied, a file mismatch was present, and additional files were present.
			# 8		Several files did not copy.
			# Note Any value greater than 8 indicates that there was at least one failure during the copy operation.

			# Here are my comments and observations on these codes:
			# 0		All files in the mirror were already up-to-date. Note that if only some new empty folders are created the exit code is still 0.
			# 1		There were only new and/or changed files to be copied from source to destination and that worked.
			# 2		There was nothing new to copy, but there were extra files in the destination that needed to be deleted, and were deleted successfully.
			# 3		This =1+2 - there were new and/or changed files copied to the destination, and files deleted from the destination. It all worked and the destination is a good mirror of the source.
			# 5,6,7,8 refer to mismatched files. Some research says that mismatch means a file in the source and a directory of the same name in the destination.
			# I have tested that, and it works and returns 3 - the deletion of the directory from the destination (2) plus copy of the file from source to destination (1)
			# I have not been able to produce exit codes 5,6,7 or 8.
			# So any exit code greater than 3 will flag up as an error for now.

			$saved_lastexitcode = $LASTEXITCODE
			if ($saved_lastexitcode -gt 3) {
				$output = "`n`nERROR: the robocopy command ended with exit code [$saved_lastexitcode]"
				$error_during_backup = $true
				$robocopy_error = $true
			} else {
				$output = ""
				$robocopy_error = $false
			}

			$summary = ""
			if ($LogFile) {
				$backup_response = get-content "$LogFile"
				foreach ( $line in $backup_response.length..1 ) {
					$summary =  $backup_response[$line] + "`n" + $summary

					if ($backup_response[$line] -match '.*Total\s+Copied\s+Skipped\s+Mismatch.*\s+FAILED\s+Extras.*') {
						break
					}
				}
			}

			echo "done`n"

			$summary = "`n------Summary-----`nBackup AT: $start_time FROM: $backup_source TO: $selectedBackupDestination$backupMappedString`n" + $summary
			echo $summary
			echo "`n"
			$emailBody = $emailBody + $summary

			if ($robocopy_error)
			{
				$emailBody = "$emailBody`r$output`r`n"
				echo $output
				if ($LogFile) {
					$output | Out-File "$LogFile" -encoding ASCII -append
				}
			}

		} else {
			# The backup source does not exist - there was no point processing this source.
			$output = "ERROR: Backup source does not exist - $backup_source - backup NOT done for this source`r`n"
			$emailBody = "$emailBody`r`n$output`r`n"
			$error_during_backup = $true
			echo $output
			if ($LogFile) {
				$output | Out-File "$LogFile" -encoding ASCII -append
			}
		}
	}

	if (($deleteOldLogFiles -eq $True) -and ($logFileDestination)) {
		$lastLogFiles = @()
		If (Test-Path $logFileDestination -pathType container) {
			$oldLogItems = Get-ChildItem -Force -Path $logFileDestination | Where-Object {$_ -is [IO.FileInfo]} | Sort-Object -Property Name

			# get me the old logs if any
			foreach ($item in $oldLogItems) {
				if ($item.Name  -match '^\d{4}-\d{2}-\d{2} \d{2}-\d{2}-\d{2}.log$' ) {
					$lastLogFiles += $item
				}
			}
		}

		if ($StepTiming -eq $True) {
			$stepTime = get-date -f "yyyy-MM-dd HH-mm-ss"
		}
		echo  "$stepCounter. $stepTime Deleting old log files"
		$stepCounter++

		#No need to add 1 here because the new log existed already when we checked for old log files
		$logFilesInDestination = $lastLogFiles.length
		$summary = "`nFound $logFilesInDestination log file(s), keeping maximum of $logFilesToKeep log file(s)`n"
		echo $summary
		if ($LogFile) {
			$summary | Out-File "$LogFile"  -encoding ASCII -append
		}
		$emailBody = $emailBody + $summary

		$logFilesToDelete=$logFilesInDestination - $logFilesToKeep
		if ($logFilesToDelete -gt 0) {
			echo  "Deleting $logFilesToDelete old logfile(s)"
			if ($LogFile) {
				"`r`nDeleting $logFilesToDelete old logfile(s)" | Out-File "$LogFile"  -encoding ASCII -append
			}
			$logFilesDeleted = 0
			while ($logFilesDeleted -lt $logFilesToDelete) {
				$logFileToDelete = $logFileDestination +"\"+ $lastLogFiles[$logFilesDeleted].Name

				echo "Deleting $logFileToDelete(.zip)"
				if ($LogFile) {
					"`r`nDeleting $logFileToDelete(.zip)" | Out-File "$LogFile"  -encoding ASCII -append
				}

				If (Test-Path "$logFileToDelete") {
					Remove-Item "$logFileToDelete"
				}
				If (Test-Path "$logFileToDelete.zip") {
					Remove-Item "$logFileToDelete.zip"
				}

				$logFilesDeleted++
			}

			$summary = "`nDeleted $logFilesDeleted old logfile(s)`n"
			echo $summary
			if ($LogFile) {
				$summary | Out-File "$LogFile"  -encoding ASCII -append
			}
			$emailBody = $emailBody + $summary
		} else {
			$summary = "`nNo old logfiles were deleted`n"
			echo $summary
			if ($LogFile) {
				$summary | Out-File "$LogFile"  -encoding ASCII -append
			}
			$emailBody = $emailBody + $summary
		}
	}

	# We have processed each backup source. Now cleanup any remaining shadow copy.
	if ($num_shadow_copies -gt 0) {
		# Delete the last shadow copy
		foreach ($shadowCopy in $shadowCopies) {
		if ($s2.ID -eq $shadowCopy.ID) {
			if ($StepTiming -eq $True) {
				$stepTime = get-date -f "yyyy-MM-dd HH-mm-ss"
			}
			echo  "$stepCounter. $stepTime Deleting last Shadow Copy"
			$stepCounter++
			try {
				$shadowCopy.Delete()
			}
			catch {
				$output = "ERROR: Could not delete Shadow Copy. "
				$emailBody = "$emailBody`r`n$output`r`n$_"
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
	if ($destWarningText) {
		# We might have tested multiple backup destinations and in the end not found a good destination
		# Write out the messages about those checks to the email body so the recipient can see easily the process and problems that happened along the way.
		$emailBody = "$emailBody`r`n$destWarningText`r`n"
	}

	if ($parameters_ok -eq $True) {
		if ($doBackup -eq $True) {
			# The destination drive or \\server\share does not exist.
			$output = "ERROR: Destination drive or share $backupDestinationTop$backupMappedString does not exist - backup NOT done`r`n"
		} else {
			# The backup was not done because localSubnetOnly was on, and the destination \\server\share is not in the local subnet.
			$output = "ERROR: Destination share $backupDestinationTop$backupMappedString is not in a local subnet - backup NOT done`r`n"
		}
	} else {
		# There was some error in the supplied parameters.
		# The specific problem will have been mentioned in the email body/log file earlier.
		# Put a general message here.
		$output = "ERROR: There was a problem with the input parameters"
	}
	$emailBody = "$emailBody`r`n$output`r`n"
	$error_during_backup = $true
	echo $output
	if ($LogFile) {
		$output | Out-File "$LogFile" -encoding ASCII -append
	}
}

if ($emailTo -AND $emailFrom -AND $SMTPServer) {
	echo "============Sending Email============"
	$stepCounter = 1

	if ($LogFile) {
		if ($StepTiming -eq $True) {
			$stepTime = get-date -f "yyyy-MM-dd HH-mm-ss"
		}
		echo  "$stepCounter. $stepTime Zipping log file"
		$stepCounter++
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
			while ($zipfile.Items().Count -le 0 -AND $timeSlept -le $maxMsToSleepForZipCreation ) {
				Start-sleep -milliseconds $msToWaitDuringZipCreation
				$timeSlept = $timeSlept + $msToWaitDuringZipCreation
			}
			$attachment = New-Object System.Net.Mail.Attachment("$zipFilePath" )
		}
		catch {
			$error_during_backup = $True
			$output = "`r`nERROR: Could not create log ZIP file. Will try to attach the unzipped log file and hope it's not to big.`r`n$_`r`n"
			$emailBody = "$emailBody`r`n$output`r`n"
			echo $output
			$output | Out-File "$LogFile"  -encoding ASCII -append
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

	$SMTPClient.Timeout = $SMTPTimeout
	if ($NoSMTPOverSSL -eq $False) {
		$SMTPClient.EnableSsl = $True
	}

	$SMTPClient.Credentials = New-Object System.Net.NetworkCredential($SMTPUser, $SMTPPassword);

	$emailSendSucess = $False
	if ($StepTiming -eq $True) {
		$stepTime = get-date -f "yyyy-MM-dd HH-mm-ss"
	}
	echo  "$stepCounter. $stepTime Sending email"
	$stepCounter++
	while ($emailSendRetries -gt 0 -AND !$emailSendSucess) {
		try {
			$emailSendRetries--
			$SMTPClient.Send($SMTPMessage)
			$emailSendSucess = $True
		} catch {
			if ($StepTiming -eq $True) {
				$stepTime = get-date -f "yyyy-MM-dd HH-mm-ss"
			}
			$output = "ERROR: $stepTime Could not send Email.`r`n$_`r`n"
			echo $output
			if ($LogFile) {
				$output | Out-File "$LogFile" -encoding ASCII -append
			}
		}

		if (!$emailSendSucess) {
			Start-sleep -milliseconds $msToPauseBetweenEmailSendRetries
		}
	}

	if ($LogFile) {
		$attachment.Dispose()
	}

	echo "done"
}

if ($substDone) {
	# Delete any drive letter substitution done earlier
	# Note: the subst drive might have contained the log file, so we cannot delete earlier since it is needed to zip and email.
	echo "`nRemoving subst of $substDrive`n"
	subst "$substDrive" /D
}

if (-not ([string]::IsNullOrEmpty($postExecutionCommand))) {
	echo "`nrunning postexecution command ($postExecutionCommand)`n"
	$output = `cmd /c  `"$postExecutionCommand`"`

	$output += "`n"
	echo $output
}

#List Files that have CreationTime older than x days (parameter)
#extra days to list folders based on LastWriteTime
#switch for deleting files
#exclude folders/files INF-Offices
#write log file (with timestamp)
#parameter logfilelocation


<#
.DESCRIPTION
DELETE-OLD-FILES Version: 1.0.ALPHA.1
This software is used to find and list or delete files/folders that are older than a specified age
.SYNOPSIS
c:\full\path\delete-old-files.ps1 <Options>
.PARAMETER location
Path of the files/folders to be processed.
.PARAMETER iniFile
Path to an optional INI file that contains any of the parameters.
.PARAMETER fileAge
Files with that age (in days) and older will be listed and/or deleted (based on CreationTime)
default = 7
.PARAMETER extraFolderAge
Folder with fileAge + extraFolderAge and older will be listed and/or deleted (based on LastWriteTime)
default = 7
.PARAMETER delete
actually delete the files/folders.
.PARAMETER excludeFiles
Exclude files via wildcards. Can be a list separated by comma.
.PARAMETER excludeDirs
Exclude directories via wildcards. Can be a list separated by comma.
.PARAMETER LogFile
Path and filename for the logfile. If just a path is given, then "yyyy-mm-dd hh-mm-ss.log" is written to that folder.
Default is to write "yyyy-mm-dd hh-mm-ss.log" in the delete-old-files script folder.
.PARAMETER StepTiming
Switch on display of the time at each step of the job.
.PARAMETER version
print the version information and exit.
.EXAMPLE
PS D:\> #ToDo
.NOTES
Author: Artur Neumann *INFN*
#>

[CmdletBinding()]
Param(
[Parameter(Mandatory=$False)]
[String]$iniFile,
[Parameter(Mandatory=$False)]
[String]$location,
[Parameter(Mandatory=$False)]
[String[]]$excludeFiles,
[Parameter(Mandatory=$False)]
[String[]]$excludeDirs,
[Parameter(Mandatory=$False)]
[Int32]$fileAge,
[Parameter(Mandatory=$False)]
[Int32]$extraFolderAge,
[Parameter(Mandatory=$False)]
[string]$LogFile="",
[Parameter(Mandatory=$False)]
[switch]$StepTiming=$False,
[Parameter(Mandatory=$False)]
[switch]$version=$False,
[Parameter(Mandatory=$False)]
[switch]$delete=$False
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
		DELETE-OLD-FILES Version: 2.0.ALPHA.8
		and gets the version information out of it
		The version string must be in the .DESCRIPTION scope and must start with
		"DELETE-OLD-FILES Version: "

	.Outputs
		System.String
	#>
	
	#Get the help-text of my self
	$helpText=Get-Help $script_path\delete-old-files.ps1 
	
	#Get-Help returns a PSObjects with other PSObjects inside
	#So we are trying some black magic to get a string out of it and then to parse the version
	
	Foreach ($object in $helpText.psobject.properties) { 
		#loop through all properties of the PSObject and find the description
		if (($object.Value) -and  ($object.name -eq "description")) {
			#the description is a object of the class System.Management.Automation.PSNoteProperty
			#and inside of the properties of that are System.Management.Automation.PSPropertyInfo objects (in our case only one)
			#still we loop though, just in case there are more that one and see if the value (what is finally a string), does match the version string
			Foreach ($subObject in $object.Value[0].psobject.properties) { 	
				 if ($subObject.Value -match "DELETE-OLD-FILES Version: (.*)")	{
						return $matches[1]
				} 
			} 
		}
	}
}


$FQDN = [System.Net.DNS]::GetHostByName('').HostName
$tempLogContent = ""

$versionString=Get-Version

if ($version) {
	echo $versionString
	exit
} else {
	$output = "DELETE-OLD-FILES $versionString`r`n"
	$tempLogContent += $output
	echo $output
}

if ($iniFile) {
	if (Test-Path -Path $iniFile -PathType leaf) {
		$output = "Using ini file`r`n$iniFile`r`n"
		$global:iniFileContent = Get-IniContent "${iniFile}"
	} else {
		$global:iniFileContent =  New-Object System.Collections.Specialized.OrderedDictionary
		$output = "ERROR: Could not find ini file`r`n$iniFile`r`n"
	}
	echo $output
} else {
		$global:iniFileContent =  New-Object System.Collections.Specialized.OrderedDictionary
}

$parameters_ok = $True

if ([string]::IsNullOrEmpty($location)) {
	$location = Get-IniParameter "location" "${FQDN}"

	if ([string]::IsNullOrEmpty($location)) {
		$output = "ERROR: no location was given cannot progress`r`n"
		$parameters_ok = $False
	}	
}

if ([string]::IsNullOrEmpty($excludeFiles)) {
	$excludeFilesList = Get-IniParameter "excludeFiles" "${FQDN}"
	if (-not [string]::IsNullOrEmpty($excludeFilesList)) {
		$excludeFiles = $excludeFilesList.split(",")
	}
}

if ([string]::IsNullOrEmpty($excludeDirs)) {
	$excludeDirsList = Get-IniParameter "excludeDirs" "${FQDN}"
	if (-not [string]::IsNullOrEmpty($excludeDirsList)) {
		$excludeDirs = $excludeDirsList.split(",")
	}
}

if (-not $StepTiming.IsPresent) {
	$IniFileString = Get-IniParameter "StepTiming" "${FQDN}"
	$StepTiming = Is-TrueString "${IniFileString}"
}

if ($fileAge -eq 0) {
	$fileAge = Get-IniParameter "fileAge" "${FQDN}"
	if ($fileAge -eq 0) {
		$fileAge = 7;
	}
}

if ($extraFolderAge -eq 0) {
	$extraFolderAge = Get-IniParameter "extraFolderAge" "${FQDN}"
	if ($extraFolderAge -eq 0) {
		$extraFolderAge = 7;
	}
}

if (-not $delete.IsPresent) {
	$IniFileString = Get-IniParameter "delete" "${FQDN}"
	$delete = Is-TrueString "${IniFileString}"
}

if ([string]::IsNullOrEmpty($LogFile)) {
	$LogFile = Get-IniParameter "LogFile" "${FQDN}"
}

$dateTime = get-date -f "yyyy-MM-dd HH-mm-ss"

if ([string]::IsNullOrEmpty($LogFile)) {
	# No log file specified from command line - put one in the script path destination with date-time stamp.
	$logFileDestination = $script_path
	$LogFile = "$logFileDestination\$dateTime.log"
} else {
	if (Test-Path -Path $LogFile -pathType container) {
		# The log file parameter points to a folder, so generate log file names in that folder.
		$logFileDestination = $LogFile
		$LogFile = "$logFileDestination\$dateTime.log"
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
	echo $output
	$LogFile=""
	$error_during_process = $True
}

#write the logs from the time we hadn't a logfile into the file
if ($LogFile) {
	$tempLogContent | Out-File "$LogFile"  -encoding ASCII -append
}

if ($parameters_ok -eq $True) {
	$olderThanDate = (Get-Date).adddays(-$fileAge)

	$filesToDelete=Get-ChildItem -Path  $location -Recurse -force | ? {$_.creationtime -lt $olderThanDate} | where {!$_.PsIsContainer}

	$olderThanDate = (Get-Date).adddays(-($fileAge-$extraFolderAge))

	$foldersToDelete=Get-ChildItem -Path  $location -Recurse -force | ? {$_.LastWriteTime -lt $olderThanDate} | where {$_.PsIsContainer} | Select-Object -Property FullName,LastWriteTime, @{Name="FullNameLength";Expression={($_.FullName.Length)}} | Sort-Object -Property FullNameLength -Descending 
	
	
	if ($delete) {
		$output = "DELETING FOLDERS:`r`n"
	} else {
		$output = "LIST FILES:`r`n"
	}
	echo $output
	if ($LogFile) {
		$output | Out-File "$LogFile" -encoding ASCII -append
	}
	
	foreach ($file in $filesToDelete) {
		if ($delete) {
			Remove-Item -Force $file.FullName
		}
	
		Write-Host $file.FullName  " - "  $file.CreationTime
		if ($LogFile) {
			$file.FullName + " - " + $file.CreationTime | Out-File "$LogFile" -encoding ASCII -append
		}
	
	}	

	if ($delete) {
		$output = "`r`nDELETING FOLDERS:`r`n"
	} else {
		$output = "`r`nLIST FOLDERS:`r`n"
	}
	echo $output
	if ($LogFile) {
		$output | Out-File "$LogFile" -encoding ASCII -append
	}
	
	foreach ($folder in $foldersToDelete) {
		if ($delete) {
			$subitems = Get-ChildItem -Recurse -Path $folder.FullName
				if($subitems -eq $null)	{
                  Remove-Item $folder.FullName
				  $output = $folder.FullName + " - " + $folder.LastWriteTime
				} else {
					$output=""
				}
				$subitems = $null	
		} else {
			$output = $folder.FullName + " - " + $folder.LastWriteTime
		}
	
		if ($output) {
			Write-Host $output
			if ($LogFile) {
				$output | Out-File "$LogFile" -encoding ASCII -append
			}
		}
	
	}
} else {
	echo "ERROR: nothing was done due to problems in the parameters`r`n"
}

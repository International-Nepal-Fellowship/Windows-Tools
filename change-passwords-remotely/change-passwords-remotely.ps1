<#
    .Synopsis 
        This script changes local user passwords on remote Windows computers. List of computers and users are given in a CSV file
		Tested on Windows 7
        
    .Description
		CHANGE-PASSWORDS-REMOTELY Version: 1.0-BETA1
		
        This script picks up the computer and user names from a CSV file, collects the password from the console input and tries to change the passwords.
		To make it work you need to turn on "file and printer sharing" in "Control Panel\Network and Internet\Network Sharing Centre\Advanced sharing settings"
		In a domain enviroment you can allow the remote change of passwords by GPO.
		Create a new GPO and:
		1. enable "Allow ICMP exceptions" & "Allow inbound remote administration exception" in 
		   "Computer Configuration/Policies/Administrative Templates Policy definitions/Network/Network Connections/Windows Firewall/Domain Profile"
		   This will open certain ports in the firewall of the client
		2. enable "Allow automatic configuration of listeners" & "Allow Basic authentication" in
		   "Computer Configuration/Policies/Administrative Templates Policy definitions/Windows Components/Windows Remote Management (WinRM)/WinRM Service"
		3. enable "Allow Remote Shell Access"  in
		   "Computer Configuration/Policies/Administrative Templates Policy definitions/Windows Components/Windows Remote Shell"
		4. apply the policy to the OU you want to update the passwords
		
 
    .Parameter InputFile    
        The full path of the CSV file name where computer names and user names are stored. E.g.: C:\temp\computers.csv
		The file has to have two columns called "name" and "users". The columns have to be separated by semicolon. 
		The users column can contain multiple user names separated by comma.
		
		Example:
		---------
		name;users
		COMPUTER-001;Administrator
		COMPUTER-002;Administrator,user1
		COMPUTER-003;user1,user2
 
	.Parameter ResultFile
        The full path of the CSV Result file namer names and user names are stored. E.g.: C:\temp\result.csv
        
    .Example
        change-passwords-remotely.ps1 -InputFile c:\temp\Computers.csv -ResultFile C:\temp\result.csv
   
    .Notes
        NAME:      	change-passwords-remotely.ps1
        AUTHOR:    	Artur Neumann *INFN*
		WEBSITE:	https://github.com/International-Nepal-Fellowship/Windows-Tools
		CREDITS:	This Script is largly based on the ideas of Sitaram Pamarthi http://techibee.com You can find the original Script here: https://4sysops.com/archives/change-the-local-administrator-password-on-multiple-computers-with-powershell/

#>
[cmdletbinding()]
param (
	[parameter(mandatory = $true)]
	$InputFile,
	[parameter(mandatory = $true)]
	$ResultFile
)

if(!(Test-Path $InputFile)) {
	Write-Error "File ($InputFile) not found. Script is exiting"
	exit
}

#list of all unique users, we will collect a password for every user later
[String[]]$uniqueUsers=@()

$Computers =  Import-Csv  -Delimiter ";" $InputFile

#fill $uniqueUsers & make $Computers[x].users into a hash
$Computers | ForEach-Object { 
								$users=$_.users.split(",")
								$uniqueUsers = $uniqueUsers + $users
								$_.users=@()
								foreach ($user in $users) {
									$_.users += @{'name'=$user;"status"="SUCCESS";"error"=""}
								}
							}
						
$uniqueUsers = $uniqueUsers | select -uniq

# collect a password per user
$userPasswords=@{}
foreach ($user in $uniqueUsers) {
		
	do { 
	$password = Read-Host "enter password for $user" -AsSecureString
	$confirmpassword = Read-Host "confirm password for $user" -AsSecureString

	$password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))
	$confirmpassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($confirmpassword))

		if($password -ne $confirmpassword) {
			Write-Warning "Password and confirm password does not match. Please retry"
		} else {
			$userPasswords[$user]=$password
		}
		
	} until($password -eq $confirmpassword)  
   
 }

$outputObj = @()

foreach ($Computer in $Computers) {
	
	$Computer | Add-Member Noteproperty Isonline "OFFLINE"
	Write-Verbose "Working on $($Computer.name)"
	if((Test-Connection -ComputerName $Computer.name -count 1 -ErrorAction 0)) {
		$Computer.Isonline = "ONLINE"
	}
	Write-Verbose "`t$($Computer.name) is $($Computer.Isonline)"

	if ($Computer.Isonline -eq "ONLINE") {
		foreach ($user in $Computer.users) {

			try {
				$account = [ADSI]("WinNT://$($Computer.name)/$($user.name),user")
				$account.psbase.invoke("setpassword",$userPasswords[$user.name])
				Write-Verbose "`tPassword of user $($user.name) was changed successfully"
			}
			catch {
				$user.status = "FAILED"
				$user.errorMessage = $_ -replace "`n|`r",""
				
				Write-Verbose "`tFailed to Change the password of the user $($user.name). Error: $($user.errorMessage)"
			}
			
				$outputLine = New-Object -TypeName PSObject -Property @{
					ComputerName = $($Computer.name)
					IsOnline = $($Computer.Isonline)
					User = $($user.name)
					PasswordChangeStatus = $($user.status)
					Error = $($user.errorMessage)
				}

				$outputLine  | Select ComputerName, IsOnline, User, PasswordChangeStatus
				$outputObj += $outputLine
		}
	} else {
			$outputLine = New-Object -TypeName PSObject -Property @{
					ComputerName = $($Computer.name)
					IsOnline = $($Computer.Isonline)
					User = "*"
					PasswordChangeStatus = "FAILED"
					Error = ""
				}

				$outputLine | Select ComputerName, IsOnline, User, PasswordChangeStatus
				$outputObj += $outputLine
	}

}
$outputObj | Select ComputerName, IsOnline, User, PasswordChangeStatus, Error | export-csv -delimiter ";" -NoTypeInformation -Encoding UTF8 -path $ResultFile
Write-Host "`n`nResult are saved in $ResultFile"
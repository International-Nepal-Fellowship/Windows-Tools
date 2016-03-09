This script changes local user passwords on remote Windows computers. List of computers and users are given in a CSV file
Tested on Windows 7


The script picks up the computer and user names from a CSV file, collects the password from the console input and tries to change the passwords.
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

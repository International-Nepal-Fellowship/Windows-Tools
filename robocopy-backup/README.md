robocopy-backup
====================

This software is used for creating backup mirrors using Robocopy.
It is based on the ntfs-hardlink-backup Powershell code also in this repo.
All kudos to the contributors to that code - it has been cut down here to use just the parameters needed
for making Robocopy mirror copies of data.

FEATURES
--------
* NO GUI
* easy to run a scheduled task
* backup multiple sources to one destination
* create Shadow Volume copy before making backup
* send notification emails
* creates ZIP file of the logfile before sending it by Email
* delete old log files
* optionally read parameters from an INI file
* flexible way of using one INI file for a lot of computers
* keep historical log files

INSTALLATION
-------------
1. Download and place robocopy-backup.ps1 into a folder
2. Navigate with the Explorer to that folder
3. Right Click on the robocopy-backup.ps1 file and select "Properties"
4. If you see in the bottom something like "Security: This file came from an other computer ..." Click on "Unblock"
5. start powershell from windows start menu (you need Windows 7 or Win Server for that, on XP you would need to install PowerShell 2 first)
6. allow local non-signed scripts to run by typing “Set-ExecutionPolicy RemoteSigned“
7. make a batch file and INI file similar to the examples here, as needed
9. run the batch file interactively, or add a task to Task Scheduler to run as required

V1.1 RELEASE NOTES
------------------
1. Error messages are improved when checking possible destinations for the Robocopy.
2. Only try to send email if the computer has at least a network connection that has a default gateway. This saves big delays repeatedly trying to send email if the computer is off-line.
3. Report host IP addresses and gateways in the log file. This helps with problem diagnosis "after the event".
4. Use the Powershell "&" "invoke" command to execute the pre-execution, robocopy and post-execution commands rather than "cmd /c". This is more portable across Windows 7/8/8.1/10 and various Windows Server releases with different Powershell versions.

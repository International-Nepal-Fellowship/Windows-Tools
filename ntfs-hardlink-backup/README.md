ntfs-hardlink-backup
====================

This software is used for creating hard-link-backups.
The real magic is done by DeLoreanCopy of ln: http://schinagl.priv.at/nt/ln/ln.html	
So all credit goes to [Hermann Schinagl](http://schinagl.priv.at)!
FEATURES
--------
* NO GUI
* easy to run a scheduled task
* backup multiple sources to one destination
* create Shadow Volume copy before making backup
* send notification emails
* takes extra options for ln (timetolerance, traditional, exclude, noads, ...)
* creates ZIP file of the logfile before sending it by Email
* delete old backups and log files
* optionally read parameters from an INI file
* flexible way of using one INI file for a lot of computers
* keep historical log files
* can keep min. old backups per year 
* try to run ln.exe from path
* option to choose where ln.exe lives


INSTALLATION
-------------
1. Read the documentation of "ln" http://schinagl.priv.at/nt/ln/ln.html
2. Download "ln" and unpack the file.
3. Download and place ntfs-hardlink-backup.ps1 into ln\bat directory
4. Navigate with the Explorer to the ln\bat folder
5. Right Click on the ntfs-hardlink-backup.ps1 file and select "Properties"
6. If you see in the bottom something like "Security: This file came from an other computer ..." Click on "Unblock"
7. start powershell from windows start menu (you need Windows 7 or Win Server for that, on XP you would need to install PowerShell 2 first)
8. allow local non-signed scripts to run by typing “Set-ExecutionPolicy RemoteSigned“
9. run ntfs-hardlink-backup.ps1 with full path

V2.1 RELEASE NOTES
------------------
1. Error messages are improved when checking possible destinations for the backup.
2. Only try to send email if the computer has at least a network connection that has a default gateway. This saves big delays repeatedly trying to send email if the computer is off-line.
3. Report host IP addresses and gateways in the log file. This helps with problem diagnosis "after the event".
4. Use the Powershell "&" "invoke" command to execute the pre-execution, robocopy and post-execution commands rather than "cmd /c". This is more portable across Windows 7/8/8.1/10 and various Windows Server releases with different Powershell versions.

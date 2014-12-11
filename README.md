ntfs-hardlink-backup
====================

This software is used for creating hard-link-backups.
The real magic is done by DeLoreanCopy of ln: http://schinagl.priv.at/nt/ln/ln.html	
So all credit goes to [Hermann Schinagl](http://schinagl.priv.at)!
FEATURES
--------
* backuping multiple sources in one destination
* creating Shadow Volume copy before making backup
* sending notification emails
* takes extra options for ln (timetolerance, traditional, exclude)
* creates ZIP file of the logfile before sending it by Email
* delete old backups
* optionally read parameters from an INI file
* Keeping min old backups per year / per month (TODO)
* try to run ln.exe from path (TODO)
* option to choose where ln.exe lives (TODO)
* multiple Email receptient (TODO)
* keep historical log files (TODO)

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


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
* takes extra options for ln (timetolerance and traditional)

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

CHANGELOG
-------------
**1.0_rc3**
* delets old backups

**1.0_rc2**
* sending email is optional.
* shadow copy is optional
* ln does not use a link to the shadow copy any more but the deviceobject itself

**1.0_rc1**
* added timetolerance and traditional options
* does not run DeLoreanCopy.bat anymore
* changed SMTPOverSSL to NoSMTPOverSSL

**0.9**
* initial public release


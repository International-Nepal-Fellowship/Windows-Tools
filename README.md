ntfs-hardlink-backup
====================

This software is used for creating hard-link-backups.
The real magic is done by DeLoreanCopy of ln: http://schinagl.priv.at/nt/ln/ln.html	
So all credit goes to [http://schinagl.priv.at](Hermann Schinagl)!
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
3. Place ntfs-hardlink-backup.ps1 into ln\bat directory
4. start powershell from windows start menu (you need Windows 7 or Win Server for that, on XP you would need to install PowerShell 2 first)
5. allow local non-signed scripts to run by typing “Set-ExecutionPolicy RemoteSigned“
6. run ntfs-hardlink-backup.ps1 with full path 

CHANGELOG
-------------
**1.0_rc1**
* added timetolerance and traditional options
* does not run DeLoreanCopy.bat anymore
* changed SMTPOverSSL to NoSMTPOverSSL

**0.9**
* initial public release


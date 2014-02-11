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
4. run ntfs-hardlink-backup.ps1 with full path 

CHANGELOG
-------------
**1.0_rc1**
* added timetolerance and traditional options
* does not run DeLoreanCopy.bat anymore
* changed SMTPOverSSL to NoSMTPOverSSL

**0.9**
* initial public release


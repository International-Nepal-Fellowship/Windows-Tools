Crypt-scripts
=============

These scripts are used to manage the mount and dismount of a secure TrueCrypt (or VeraCrypt)
container on an external USB disk, and call ntfs-hardlink-backup to make a backup in that container.

INSTALLATION AND USE
--------------------
* On an external USB disk, make a folder "TrueCrypt"
* Make a small TrueCrypt container inside "TrueCrypt". Call it after the user or user title (e.g. CEO.tc).
* Give that container some authentication (password...) that is known to the user.
* Make a TrueCrypt key file with matching name to the small container (e.g. CEO.tckf) and put it in the small container.
* Keep a copy of the key file in some other place secured by the IT department - it can be used to open the large container if the user has forgotten/changed their password to the small container.
* Make a TrueCrypt main container called externalbackup.tc in the "TrueCrypt" folder.
* Use the previously generated key file as the authentication for the main container.
* Put portable-mount.vbs and portable-dismount.vbs in the "TrueCrypt" folder.
* Use TrueCrypt, Tools, Traveler Disk Setup to put the necessary TrueCrypt binaries into the TrueCrypt folder.
* Dismount the TrueCrypt containers you made, disconnect the USB disk.
* Put backup-to-disk.cmd somewhere the user can run it from
* Put ntfs-hardlink-backup.ps1 and a backup-to-disk.ini somewhere (e.g. the scripts use C:\Tools\Backup\bat folder)
* Run backup-to-disk.cmd
* It will prompt the user to connect the USB disk, and check every 10 seconds for a disk with a TrueCrypt folder...
* portable-mount will be run. That will mount the small container as Z:, prompting the user for credentials.
* The key file from the small container will be used to open the large container as X:
* The backup is run into the large container.
* The container/s are closed.

Modify whatever of the scripts you need to, to change the default drive letters used for the containers (Z and X),
or the expected folder names (like "TrueCrypt" on the external USB disk).

Note: There is (obviously) no attempt made here to hide the use of TrueCrypt.
If you have high-security needs for plausible deniability, then do not use this method.

@ECHO OFF
Setlocal EnableDelayedExpansion
:wait
set found=0
rem drivetype 4 is network shares so we do not want to enumerate those
rem that might take some time if the laptop is offline and the share access has to time out
rem also needed lots of those ^ signs to escape the exclamation mark in the string
set disk_cmd="wmic logicaldisk where drivetype^^^!=4 get caption"

rem the wmic command outputs a top column heading so ignore that first line "skip=1"
rem there is also a blank line at the end, but that does no harm
for /f "skip=1" %%D in ('%disk_cmd%') do (
	rem The folder and file name check here is actually not case sensitive
	if exist %%D\Truecrypt\ExternalBackup.tc (
		rem Success - we found a disk with ExternalBackup.tc in the Truecrypt folder
		set found=1
		set externaldrive=%%D
	)
)

if %found% equ 0 (
rem No ExternalBackup.tc found on any disk
echo PLEASE CONNECT YOUR BACKUP DISK
rem Use a devious way to wait about 10 seconds
ping -n 10 localhost> nul
goto wait
)

echo Opening TrueCrypt on disk: %externaldrive%

rem Looking good - now check that the mount and dismount scripts are there
if exist %externaldrive%\portable-mount.vbs (
	if exist %externaldrive%\portable-dismount.vbs (
		rem All looks good as far as we can check - now mount, do the backup and dismount
		%externaldrive%\portable-mount.vbs

		powershell.exe -Command "& C:\Tools\Backup\bat\ntfs-hardlink-backup.ps1 -iniFile C:\Tools\Backup\bat\Backup-To-Disk.ini"

		%externaldrive%\portable-dismount.vbs
	) else (
		echo Error: portable-dismount.vbs script not found on drive %externaldrive%
		echo ######## BACKUP WAS NOT DONE ########
		pause
	)
) else (
	echo Error: portable-mount.vbs script not found on drive %externaldrive%
	echo ######## BACKUP WAS NOT DONE ########
	pause
)

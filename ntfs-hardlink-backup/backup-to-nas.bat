REM In this example there is a NAS with a "backup" share and we want to put backups in the "server-01" folder
REM For some models of NAS, backing up directly to the share gives trouble
REM So you can try making the share look like a local drive (B: in this example)
REM Then in the INI file you can just specify backupDestination=B:
REM This method sometimes helps a dumb NAS to accept the backup and hard-links.
%SystemRoot%\System32\subst.exe B: \\nas-01.mycompany.example.org\backup\server-01
%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe -Command "& C:\Tools\Backup\bat\ntfs-hardlink-backup.ps1 -iniFile C:\Tools\Backup\bat\backup-sample.ini"
%SystemRoot%\System32\subst.exe B: /D

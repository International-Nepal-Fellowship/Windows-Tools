' Dismount any TrueCrypt containers used for the portable external backup
'
' TrueCrypt parameters:
'   "/q" - quiet - the TrueCrypt dialog is not displayed
'   "/d" - dismount
'
currentDirectory = left(WScript.ScriptFullName,(Len(WScript.ScriptFullName))-(len(WScript.ScriptName)))
truecryptFolder = currentDirectory + "truecrypt\"
Set WshShell = CreateObject("WScript.Shell")
firstDriveLetter = "Z"
secondDriveLetter = "X"
firstDriveSpec = firstDriveLetter + ":\"
secondDriveSpec = secondDriveLetter + ":\"
Set objFSO = CreateObject("Scripting.FileSystemObject")
If (objFSO.DriveExists(firstDriveSpec)) Then
	' Dismount the first container
	command = truecryptFolder + "truecrypt.exe /q /d " + firstDriveLetter
	' WScript.Echo command
	cmds=WshShell.RUN(command, 0, true)
End If
If (objFSO.DriveExists(secondDriveSpec)) Then
	' Dismount the second container
	command = truecryptFolder + "truecrypt.exe /q /d " + secondDriveLetter
	' WScript.Echo command
	cmds=WshShell.RUN(command, 0, true)
End If

' Cleanup
Set WshShell = Nothing

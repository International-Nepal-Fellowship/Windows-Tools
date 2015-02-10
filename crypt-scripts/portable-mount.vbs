' Mount a small TrueCrypt container to one drive letter (e.g. Z:) - there should be a keyfile in the container
' then mount another container using the keyfiles to another drive letter (e.g. X:)
' then dismount the first drive
' this leaves the second drive mounted
' Now start an explorer window displaying the contents of the second drive
'
' TrueCrypt parameters:
'   "/q" - quiet - the TrueCrypt dialog is not displayed
'   "/v" - volume to mount
'   "/l" - drive letter to mount to
'   "/k" - keyfile to use
'   "/d" - dismount all drives
'   "/m ts" - mountoptions, modify the timestamp on the container when something changes inside it
'   "/e" - open an Explorer window displaying the container contents
'
' The run method creates a shell object and uses it to execute commands with the RUN method
' Run method parameters are:
' 1) Command to execute
' 2) Integer 0 - do not display in a window, 1 - display the window for the command
' 3) True - wait for command to complete, False - do not wait for command to complete
'
currentDirectory = left(WScript.ScriptFullName,(Len(WScript.ScriptFullName))-(len(WScript.ScriptName)))
' WScript.Echo currentDirectory
post = ""
firstDriveLetter = "Z"
secondDriveLetter = "X"

Set objFSO = CreateObject("Scripting.FileSystemObject")
truecryptFolder = currentDirectory + "truecrypt\"
Set objFolder = objFSO.GetFolder(truecryptFolder)
Set colFiles = objFolder.Files
For Each objFile in colFiles 
    strFileName = objFile.Name

    If objFSO.GetExtensionName(strFileName) = "tc" Then
		If Lcase(objFSO.GetBaseName(strFileName)) <> "externalbackup" Then
			' Wscript.Echo objFile.Name
			post = objFSO.GetBaseName(strFileName)
		End If
    End If
Next

If post = "" Then
	Wscript.Echo "Error: No TrueCrypt keyfile container found in " + truecryptFolder
Else
	Set WshShell = CreateObject("WScript.Shell")
	'
	' Mount the users own container that should have the keyfile in it
	command = truecryptFolder + "truecrypt.exe /q /v " + truecryptFolder + post + ".tc /l " + firstDriveLetter
	' WScript.Echo command
	cmds=WshShell.RUN(command, 0, true)
	'
	firstDriveSpec = firstDriveLetter + ":\"
	keyfile = firstDriveSpec + post + ".tckf"
	If (objFSO.FileExists(keyfile)) Then
		' Mount the main container using the keyfile in the first container
		command = truecryptFolder + "truecrypt.exe /q /v " + truecryptFolder + "ExternalBackup.tc /k " + keyfile + " /l " + secondDriveLetter + " /m ts"
		' WScript.Echo command
		cmds=WshShell.RUN(command, 0, true)
	Else
		Wscript.Echo "Error: TrueCrypt keyfile not found (" + keyfile + ")"
	End If
	' Only try to dismount the small container if it exists - the user might have cancelled giving the password for that
	If (objFSO.DriveExists(firstDriveSpec)) Then
		'
		' Dismount the first container
		command = truecryptFolder + "truecrypt.exe /q /d " + firstDriveLetter
		' WScript.Echo command
		cmds=WshShell.RUN(command, 0, true)
	End If
	secondDriveSpec = secondDriveLetter + ":\"
	If (objFSO.DriveExists(secondDriveSpec)) Then
		'
		' Open an explorer window displaying the files in the main container
		cmds=WshShell.RUN(secondDriveSpec, 1, false)
	Else
		Wscript.Echo "Error: TrueCrypt backup drive letter not found (" + secondDriveSpec + ")"
	End If
	'
	' Cleanup
	Set WshShell = Nothing
End If

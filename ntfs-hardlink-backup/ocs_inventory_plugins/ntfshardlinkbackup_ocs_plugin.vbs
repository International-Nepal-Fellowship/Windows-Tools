Dim xmlstatusfiles(1)
xmlstatusfiles(0) = "C:\Logs\network-backup\status.xml"
xmlstatusfiles(1) = "C:\Logs\Backup-To-External-HDD\status.xml"

Const ForReading = 1
Set objFSO = CreateObject("Scripting.FileSystemObject")
For Each file In xmlstatusfiles
	if objFSO.FileExists(file) Then
		Set objTest = objFSO.GetFile(file)
		If objTest.Size > 0 Then
			Set objFile = objFSO.OpenTextFile(file, ForReading)
			strText = objFile.ReadAll
			wscript.echo strText
			objFile.Close
		end if
	end if
Next

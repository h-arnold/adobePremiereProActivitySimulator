Option Explicit

Const ExitInvalidArguments = 1
Const ExitActivationFailed = 2
Const ExitUnsupportedCommand = 3

Sub Fail(message, exitCode)
	WScript.StdErr.WriteLine message
	WScript.Quit exitCode
End Sub

Function ReadLongArgument(index, defaultValue)
	If WScript.Arguments.Count > index Then
		ReadLongArgument = CLng(WScript.Arguments(index))
	Else
		ReadLongArgument = defaultValue
	End If
End Function

Function ExpandKeys(token)
	If token = "__SPACE__" Then
		ExpandKeys = " "
	Else
		ExpandKeys = token
	End If
End Function

If WScript.Arguments.Count < 2 Then
	Fail "Usage: premiere-input-helper.vbs <activate|sendkeys> <processId> [keys] [activateDelayMs] [sendKeysDelayMs]", ExitInvalidArguments
End If

Dim command
Dim processId
Dim activateDelayMs
Dim sendKeysDelayMs
Dim keys
Dim shell

command = LCase(WScript.Arguments(0))
processId = CLng(WScript.Arguments(1))
Set shell = CreateObject("WScript.Shell")

If Not shell.AppActivate(processId) Then
	Fail "Could not activate process id " & processId & ".", ExitActivationFailed
End If

Select Case command
	Case "activate"
		activateDelayMs = ReadLongArgument(2, 0)
		If activateDelayMs > 0 Then
			WScript.Sleep activateDelayMs
		End If
		WScript.Echo "Activated process " & processId & "."
	Case "sendkeys"
		If WScript.Arguments.Count < 5 Then
			Fail "sendkeys requires keys, activateDelayMs, and sendKeysDelayMs arguments.", ExitInvalidArguments
		End If

		keys = ExpandKeys(CStr(WScript.Arguments(2)))
		activateDelayMs = CLng(WScript.Arguments(3))
		sendKeysDelayMs = CLng(WScript.Arguments(4))

		If activateDelayMs > 0 Then
			WScript.Sleep activateDelayMs
		End If

		shell.SendKeys keys

		If sendKeysDelayMs > 0 Then
			WScript.Sleep sendKeysDelayMs
		End If

		WScript.Echo "Sent keys to process " & processId & "."
	Case Else
		Fail "Unsupported command '" & command & "'.", ExitUnsupportedCommand
End Select
Option Explicit

Dim shell, command, i
If WScript.Arguments.Count < 2 Then WScript.Quit 2

command = QuoteArgument(WScript.Arguments(0)) & _
    " -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File " & _
    QuoteArgument(WScript.Arguments(1))

For i = 2 To WScript.Arguments.Count - 1
    command = command & " " & QuoteArgument(WScript.Arguments(i))
Next

Set shell = CreateObject("WScript.Shell")
WScript.Quit shell.Run(command, 0, True)

Function QuoteArgument(value)
    QuoteArgument = Chr(34) & CStr(value) & Chr(34)
End Function

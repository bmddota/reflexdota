dim steampath
dim steampaths(20)
steampath = readfromRegistry("HKEY_CURRENT_USER\Software\Valve\Steam\SteamPath", "")

dim count
count = 0
steampaths(count) = steampath
count = count + 1

if steampath = "" then
	wscript.echo "Failed to find the steam directory.  If you're sure steam is installed, follow the manual installation."
	wscript.quit(1)
end if


Set objFSO = CreateObject("Scripting.FileSystemObject")
Set objFile = objFSO.OpenTextFile(steampath & "\config\config.vdf", 1)

dim line
Set myRegExp = New RegExp
myRegExp.IgnoreCase = True
myRegExp.Global = True
myRegExp.Pattern = """BaseInstallFolder_.+""[^""]+""(.*)"""

i = 0
Do Until objFile.AtEndOfStream
	line = objFile.ReadLine
	if InStr(line, """BaseInstallFolder_") <> 0 then
		Set mc = myRegExp.Execute(line)
		if mc.Count = 0 then
			wscript.echo "Couldn't find steam base install path in config.vdf"
		else
			
			Set match = mc.Item(0)
			
			steampaths(count) = match.SubMatches.Item(0)
			count = count + 1
		end if 
	end if
i = i + 1
Loop
objFile.Close

dim found
found = False

Wscript.echo "INSTALLING REFLEX"
For each path In steampaths
	if path <> "" then
		if objFSO.FolderExists(path & "\steamapps\common\dota 2 beta\") then
			found = True
			Wscript.echo "Installing in path: " & path & "\steamapps\common\dota 2 beta\"
			
			Dim objShell
			Set objShell = WScript.CreateObject ("WScript.shell")
			objShell.run "xcopy dota """ & path & "\steamapps\common\dota 2 beta\dota\""" & " /Y /E ", 7, true
			Set objShell = Nothing
		end if 
	end if
Next

if found then
	Wscript.echo "DONE INSTALLING"
else
	Wscript.echo "Unable to find dota directory.  Installation failed."
end if 

GoSleep(2)

wscript.quit(0)


Function GoSleep(seconds) 

wsv = WScript.Version 

if wsv >= "5.1" then 
WScript.Sleep(seconds * 1000) 
else 

startTime = Time() ' gets the current time 
endTime = TimeValue(startTime) + TimeValue(elapsed) ' calculates when time is up 

While endTime > Time() 

DoEvents 
Wend 
end if 
End Function 

function readFromRegistry (strRegistryKey, strDefault )
    Dim WSHShell, value

    On Error Resume Next
    Set WSHShell = CreateObject("WScript.Shell")
    value = WSHShell.RegRead( strRegistryKey )

    if err.number <> 0 then
        readFromRegistry= strDefault
    else
        readFromRegistry=value
    end if

    set WSHShell = nothing
end function
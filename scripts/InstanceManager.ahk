; v1.2.1

#NoEnv
#NoTrayIcon
#WinActivateForce
#SingleInstance, Off
SetWorkingDir, %A_ScriptDir%

SetKeyDelay, 0
SetWinDelay, 1

#Include %A_ScriptDir%\constants.ahk
LoadSettings()

global resetState := STATE_READY

global pid := 0
global idx := A_Args[1]
global instName := StrReplace(multiMCNameFormat, "*", idx)
global instDir := multiMCLocation . "\instances\" . instName
global mcDir := instDir . "\.minecraft\"
global instanceMods := []
global settings := []
global frozen := False
global lastResetTime := 0
global lastNewWorld := 0
global readFromLine := 0
global resetValidated := False
global wideHeight := Floor(A_ScreenHeight / widthMultiplier)
global toValidateReset := ["Resetting a random seed", "Resetting the set seed", "Done waiting for save lock", "Preparing spawn area"]

Log("Instance Manager launched")

if (autoBop) {
    cmd := Format("python.exe " . A_ScriptDir . "\worldBopper9000.py {1}", mcDir)
    Run, %cmd%,, Hide
}
if (syncConfigs) {
    mainConfig := Format("{1}\instances\{2}\.minecraft\config\", multiMCLocation, StrReplace(multiMCNameFormat, "*", 1))
    thisConfig := Format("{1}\instances\{2}\.minecraft\config\", multiMCLocation, StrReplace(multiMCNameFormat, "*", idx))
    FileCopy, %mainConfig%\*.*, %thisConfig%\*.*, 1
}

if (!pid := IsInstanceOpen()) {
    Log("No Minecraft instance found, launching")
    centralModsDir := A_ScriptDir . "\..\mods\"
    instModsDir := mcDir . "mods\"
    if (syncMods && DesyncedMods(centralModsDir . "*", instModsDir . "*") && FileExist(centralModsDir)) {
        Loop, Files, %instModsDir%*
        {
            FileDelete, %A_LoopFileLongPath%
        }
        FileCopyDir, %centralModsDir%, %instModsDir%, 1
    }
    mmcpack := instDir . "\mmc-pack.json"
    FileGetTime, packModified, %mmcpack%, M
    Run, %multiMCLocation%\MultiMC.exe -l "%instName%"
    while (!pid := IsInstanceOpen())
        Sleep, 500
    Loop, {
        FileGetTime, packModifiedAgain, %mmcpack%, M
        if (packModifiedAgain > packModified)
            break
        Sleep, 500
    }
    FileAppend, %pid%, inst%idx%open.tmp
    Sleep, 12000
} else {
    Log("Minecraft instance found")
    FileAppend, %pid%, inst%idx%open.tmp
}

WinGetTitle, mcTitle, ahk_pid %pid%
if (!InStr(mcTitle, "-"))
    ControlClick, x0 y0, ahk_pid %pid%,, RIGHT
ControlSend,, {Blind}{Esc}{F3 down}{Esc}{F3 up}, ahk_pid %pid%

GetControls()
GetSettings()

if (settings.fullscreen == "true") {
    fs := settings["key_key.fullscreen"]
    ControlSend,, {Blind}{%fs%}, ahk_pid %pid%
}
if (borderless)
    WinSet, Style, -0xC40000, ahk_pid %pid%
else
    WinSet, Style, +0xC40000, ahk_pid %pid%
if (mode == "Multi")
    wideResets := False
if (wideResets)
    Widen()
else
    WinMaximize, ahk_pid %pid%

OnMessage(MSG_RESET, "Reset")
OnMessage(MSG_SWITCH, "Switch")

SetTitle()
FileAppend,, IM%idx%ready.tmp

Reset(msgTime) { ; msgTime is wParam from PostMessage
    global performanceMethod, resetSounds, useObsWebsocket, screenshotWorlds, fullscreen, fullscreenDelay, mode, wideResets
    if (resetState == STATE_RESETTING || resetState == STATE_LOADING || (msgTime > lastResetTime && msgTime < lastNewWorld) || (msgTime < lastNewWorld + 400)) {
        Log("Discarding reset")
        return
    } else {
        Log("Resetting")
        if (performanceMethod == "F" && frozen)
            Unfreeze()
        if (resetSounds)
            SoundPlay, %A_ScriptDir%\..\media\reset.wav
        if (WinActive("ahk_pid " . pid)) {
            GetSettings()
            if (useObsWebsocket && screenshotWorlds)
                SendOBSCommand("SaveImg," . A_NowUTC . "," . CurrentWorldEntered())
            if (fullscreen && settings.fullscreen == "true") {
                fs := settings["key_key.fullscreen"]
                ControlSend,, {Blind}{%fs%}, ahk_pid %pid%
                DllCall("Sleep", "UInt", fullscreenDelay)
            }
            if (wideResets)
                Widen()
        }

        reset := settings["key_CreateNewWorld"]
        leavePreview := settings["key_LeavePreview"]
        lastResetTime := A_TickCount
        ControlSend,, {Blind}{%reset%}{%leavePreview%}, ahk_pid %pid%
        resetState := STATE_RESETTING
        SetTimer, ManageState, -200
        SetTimer, % Func("CountReset").Bind("Resets"), -0
        SetTimer, % Func("CountReset").Bind("Daily Resets"), -0
    }
}

ManageState() {
    global mode, performanceMethod
    Critical
    while (resetState != STATE_READY) {
        if (resetState == STATE_PREVIEWING) {
            Critical, Off
            Sleep, -1
            Critical, On
        }
        numLines := 0
        Loop, Read, %mcDir%\logs\latest.log
            numLines++
        Loop, Read, %mcDir%\logs\latest.log
        {
            if ((A_Index >= readFromLine) && (numLines - A_Index < 5)) {
                line := A_LoopReadLine
                lineNum := A_Index
                if (resetState == STATE_RESETTING && A_TickCount - lastResetTime > 2500) {
                    for each, value in toValidateReset {
                        if (InStr(line, value)) {
                            resetState := STATE_LOADING
                            readFromLine := lineNum
                            break
                        }
                    }
                }
                if (resetState != STATE_PREVIEWING && InStr(line, "Starting Preview")) {
                    Log("Found preview at line " . lineNum . ":`n" . line)
                    ControlSend,, {Blind}{F3 Down}{Esc}{F3 Up}, ahk_pid %pid%
                    readFromLine := lineNum + 1
                    lastNewWorld := A_TickCount
                    resetState := STATE_PREVIEWING
                    continue 2
                } else if ((resetState == STATE_LOADING || resetState == STATE_PREVIEWING) && InStr(line, "advancements")) {
                    if (resetState != STATE_PREVIEWING)
                        lastNewWorld := A_TickCount
                    readFromLine := lineNum
                    Log("Found load at line " . lineNum . " Log:`n" . line)
                    if (mode == "Wall" || !WinActive("ahk_pid " . pid)) {
                        ControlSend,, {Blind}{F3 Down}{Esc}{F3 Up}, ahk_pid %pid%
                        resetState := STATE_READY
                        if (performanceMethod == "F")
                            SetTimer, % Func("Freeze").Bind(), -%bfd%
                    } else {
                        Play()
                    }
                    return
                }
            }
        }
        if (resetState == STATE_RESETTING && (A_TickCount - lastResetTime > 25000)) {
            Log("Found failed reset. Forcing reset")
            lastResetTime := A_NowUTC
            reset := settings["key_CreateNewWorld"]
            ControlSend,, {Blind}{%reset%}, ahk_pid %pid%
        }
        Sleep, 50
    }
}

Switch() {
    global screenshotWorlds, mode, fullscreen, fullscreenDelay, performanceMethod, wideResets
    if ((mode == "Wall" && resetState == STATE_READY) || (mode == "Multi" && (resetState == STATE_PREVIEWING || resetState == STATE_READY))) {
        Log("Switched to instance")

        if (performanceMethod == "F")
            Unfreeze()
        if (wideResets) ; && !fullscreen)
            WinMaximize, ahk_pid %pid%
        WinSet, AlwaysOnTop, On, ahk_pid %pid%
        WinSet, AlwaysOnTop, Off, ahk_pid %pid%
        if (mode == "Wall")
            WinMinimize, Fullscreen Projector
        if (fullscreen && mode == "Wall") {
            fs := settings["key_key.fullscreen"]
            ControlSend,, {Blind}{%fs%}, ahk_pid %pid%
            Sleep, %fullscreenDelay%
        }

        Send, {RButton}
        if (resetState == STATE_READY)
            Play()

        return 0
    } else {
        return resetState
    }
}

Play() {
    global fullscreen, mode, fullscreenDelay, unpauseOnSwitch, coopResets, renderDistance
    if (fullscreen && mode == "Multi") {
        fs := settings["key_key.fullscreen"]
        ControlSend,, {Blind}{%fs%}, ahk_pid %pid%
        Sleep, %fullscreenDelay%
    }
    if (resetState == STATE_READY && (unpauseOnSwitch || coopResets))
        ControlSend,, {Blind}{Esc}, ahk_pid %pid%
    if (coopResets) {
        Sleep, 50
        ControlSend,, {Blind}{Esc}{Tab 7}{Enter}{Tab 4}{Enter}{Tab}{Enter}, ahk_pid %pid%
        if (!unpauseOnSwitch)
            ControlSend,, {Blind}{Esc}, ahk_pid %pid%
    }
    
    Log("Playing")
}

Freeze() {
    if (resetState == STATE_READY && frozen == False) {
        Log("Freezing")
        hProcess := DllCall("OpenProcess", "UInt", 0x1F0FFF, "Int", 0, "Int", pid)
        if (hProcess) {
            DllCall("ntdll.dll\NtSuspendProcess", "Int", hProcess)
            DllCall("CloseHandle", "Int", hProcess)
        }

        ; hProcess := DllCall("OpenProcess", "UInt", 0x001F0FFF, "Int", 0, "Int", pid)
        ; DllCall("SetProcessWorkingSetSize", "UInt", hProcess, "Int", -1, "Int", -1)
        ; DllCall("CloseHandle", "Int", hProcess)
        ; Log("Freeing memory")

        ; Freeing memory is disabled by default, as it doesn't achieve much except more unfreezing lag.
        ; It can in theory let you run more than the max # of instances your ram can handle, but this macro doesn't support that anyway.
        ; You can uncomment these lines to enable it if you want.

        frozen := True
    }
}

Unfreeze() {
    global resumeDelay
    Log("Unfreezing")
    hProcess := DllCall("OpenProcess", "UInt", 0x1F0FFF, "Int", 0, "Int", pid)
    if (hProcess) {
        DllCall("ntdll.dll\NtResumeProcess", "Int", hProcess)
        DllCall("CloseHandle", "Int", hProcess)
        Sleep, %resumeDelay%
    }
    frozen := False
}

GetSettings() {
    Loop, Read, %mcDir%/options.txt
    {
        line := A_LoopReadLine
        if (!InStr(line, "key")) {
            kv := StrSplit(line, ":")
            if (kv.MaxIndex() == 2) {
                key := kv[1]
                value := kv[2]
                StringReplace, key, key, %A_Space%,, All
                StringReplace, value, value, %A_Space%,, All
                settings[key] := value
            }
        }
    }
}

GetControls() {
    atumKeyFound := False
    Loop, Read, %mcDir%/options.txt
    {
        line = %A_LoopReadLine%
        if (InStr(line, "key")) {
            kv := StrSplit(line, ":")
            if (kv.MaxIndex() == 2) {
                key = % kv[1]
                value = % kv[2]
                StringReplace, key, key, %A_Space%,, All
                StringReplace, value, value, %A_Space%,, All
                settings[key] := TranslateKey(value)
                if (key == "key_CreateNewWorld")
                    atumKeyFound := True
            }
        }
    }
    if (!atumKeyFound)
        settings["key_CreateNewWorld"] := "f6"
}

SetTitle() {
    WinSetTitle, ahk_pid %pid%,, Minecraft* - Instance %idx%
}

SendOBSCommand(cmd) {
    static cmdNum := 1
    cmdFile := A_ScriptDir . "\pyCmds\IM" . idx . "CMD" . cmdNum . ".txt"
    cmdNum++
    FileAppend, %cmd%, %cmdFile%
}

CurrentWorldEntered() {
    FileRead, logContents, %mcDir%\logs\latest.log
    return (InStr(logContents, "We Need To Go Deeper",, 0) > InStr(logContents, "spawn area",, 0))
}

Widen() {
    WinRestore, ahk_pid %pid%
    WinMove, ahk_pid %pid%,, 0, 0, %A_ScreenWidth%, %wideHeight%
}

IsInstanceOpen() {
    for proc in ComObjGet("winmgmts:").ExecQuery("SELECT * from Win32_Process WHERE Name LIKE ""%java%""") {
        if (InStr(proc.ExecutablePath, "javapath"))
            continue
        cmdLine := proc.Commandline
        if(RegExMatch(cmdLine, "-Djava\.library\.path=(?P<Dir>[^\""]+?)(?:\/|\\)natives", thisInst)) {
            thisInstDir := StrReplace(thisInstDir, "/", "\")
            if (instDir == thisInstDir)
                return proc.ProcessId
        }
    }
    return False
}

DesyncedMods(dir1, dir2) {
    centralMods := [""]
    instMods := [""]
    Loop, Files, %dir1%
    {
        centralMods[A_Index] := A_LoopFileName
    }
    Loop, Files, %dir2%
    {
        instMods[A_Index] := A_LoopFileName
    }
    if (centralMods[1] == "")
        return False
    if (centralMods.MaxIndex() != instMods.MaxIndex())
        return True
    for each, ctrlMod in centralMods {
        for each, instMod in instMods {
            if (ctrlMod != instMod)
                return True
        }
    }
    return False
}

GetMods() {
    if (!RegExMatch(mcDir, "^.:.*MultiMC\\instances\\.*\\\.minecraft\\$")) {
        MsgBox, Invalid Minecraft Directory provided. The script will now exit.
        ExitApp
    }
    Loop, Files, %mcDir%mods\*
    {
        if (InStr(A_LoopFileName, "jar") && !InStr(A_LoopFileName, "disabled")) {
            rawName := StrSplit(A_LoopFileName, ".jar")[1]
            pattern := "(?P<Name>.*?)(?:-|\+)v?(?=\d)((?:[\dx]+[.+]?){2,}).*?(?:-|\+)v?(?=\d)((?:[\dx]+[.+]?){2,})"
            RegExMatch(rawName, pattern, mod)
            instanceMods[A_Index] := modName
        }
    }
}

HasMod(modName) {
    for each, mod in instanceMods {
        if (InStr(mod, modName))
            return True
    }
    return False
}

LoadSettings() {
    global
    local filename, file, sect, equalsPos, key, value
    filename := A_ScriptDir . "\..\settings.ini"
    FileRead, file, %filename%

    Loop, Parse, file, `n`r, %A_Space%%A_Tab%
    {
        switch (SubStr(A_LoopField, 1, 1))
        {
            case ";":
                continue
            case "[":
                sect := SubStr(A_LoopField, 2, -1)
            default:
                equalsPos := InStr(A_LoopField, "=")
                if equalsPos {
                    key := SubStr(A_LoopField, 1, equalsPos - 1)
                    IniRead, value, %filename%, %sect%, %key%
                    if (InStr(key, "arr")) {
                        value := StrReplace(value, """", "")
                        %key% := []
                        if (InStr(value, ",")) {
                            Loop, Parse, value, `,
                                %key%.Push(A_LoopField)
                        } else {
                            %key%.Push(value)
                        }
                    } else {
                        %key% := value
                    }
                }
        }
    }
}

Log(message) {
    FileAppend, [%A_YYYY%-%A_MM%-%A_DD% %A_Hour%:%A_Min%:%A_Sec%] | Current state: %resetState% | %message%`n, %mcDir%log.log
}

CountReset(resetType) {
    filePath := Format("../resets/{1}.txt", resetType)
    if (!FileExist(filePath))
        FileAppend, 0, %filePath%
    Loop, {
        file := FileOpen(filePath, "a -rw")
        if (IsObject(file)) {
            file.Seek(0)
            num := file.Read()
            num += 1
            file.Seek(0)
            file.Write(num)
            file.Close()
            break
        }
        file.Close()
    }
}

TranslateKey(mcKey) {
    static keyArray := Object("key.keyboard.f1", "F1"
    ,"key.keyboard.f2", "F2"
    ,"key.keyboard.f3", "F3"
    ,"key.keyboard.f4", "F4"
    ,"key.keyboard.f5", "F5"
    ,"key.keyboard.f6", "F6"
    ,"key.keyboard.f7", "F7"
    ,"key.keyboard.f8", "F8"
    ,"key.keyboard.f9", "F9"
    ,"key.keyboard.f10", "F10"
    ,"key.keyboard.f11", "F11"
    ,"key.keyboard.f12", "F12"
    ,"key.keyboard.f13", "F13"
    ,"key.keyboard.f14", "F14"
    ,"key.keyboard.f15", "F15"
    ,"key.keyboard.f16", "F16"
    ,"key.keyboard.f17", "F17"
    ,"key.keyboard.f18", "F18"
    ,"key.keyboard.f19", "F19"
    ,"key.keyboard.f20", "F20"
    ,"key.keyboard.f21", "F21"
    ,"key.keyboard.f22", "F22"
    ,"key.keyboard.f23", "F23"
    ,"key.keyboard.f24", "F24"
    ,"key.keyboard.q", "q"
    ,"key.keyboard.w", "w"
    ,"key.keyboard.e", "e"
    ,"key.keyboard.r", "r"
    ,"key.keyboard.t", "t"
    ,"key.keyboard.y", "y"
    ,"key.keyboard.u", "u"
    ,"key.keyboard.i", "i"
    ,"key.keyboard.o", "o"
    ,"key.keyboard.p", "p"
    ,"key.keyboard.a", "a"
    ,"key.keyboard.s", "s"
    ,"key.keyboard.d", "d"
    ,"key.keyboard.f", "f"
    ,"key.keyboard.g", "g"
    ,"key.keyboard.h", "h"
    ,"key.keyboard.j", "j"
    ,"key.keyboard.k", "k"
    ,"key.keyboard.l", "l"
    ,"key.keyboard.z", "z"
    ,"key.keyboard.x", "x"
    ,"key.keyboard.c", "c"
    ,"key.keyboard.v", "v"
    ,"key.keyboard.b", "b"
    ,"key.keyboard.n", "n"
    ,"key.keyboard.m", "m"
    ,"key.keyboard.1", "1"
    ,"key.keyboard.2", "2"
    ,"key.keyboard.3", "3"
    ,"key.keyboard.4", "4"
    ,"key.keyboard.5", "5"
    ,"key.keyboard.6", "6"
    ,"key.keyboard.7", "7"
    ,"key.keyboard.8", "8"
    ,"key.keyboard.9", "9"
    ,"key.keyboard.0", "0"
    ,"key.keyboard.tab", "Tab"
    ,"key.keyboard.left.bracket", "["
    ,"key.keyboard.right.bracket", "]"
    ,"key.keyboard.backspace", "Backspace"
    ,"key.keyboard.equal", "="
    ,"key.keyboard.minus", "-"
    ,"key.keyboard.grave.accent", "`"
    ,"key.keyboard.slash", "/"
    ,"key.keyboard.space", "Space"
    ,"key.keyboard.left.alt", "LAlt"
    ,"key.keyboard.right.alt", "RAlt"
    ,"key.keyboard.print.screen", "PrintScreen"
    ,"key.keyboard.insert", "Insert"
    ,"key.keyboard.scroll.lock", "ScrollLock"
    ,"key.keyboard.pause", "Pause"
    ,"key.keyboard.right.control", "RControl"
    ,"key.keyboard.left.control", "LControl"
    ,"key.keyboard.right.shift", "RShift"
    ,"key.keyboard.left.shift", "LShift"
    ,"key.keyboard.comma", ","
    ,"key.keyboard.period", "."
    ,"key.keyboard.home", "Home"
    ,"key.keyboard.end", "End"
    ,"key.keyboard.page.up", "PgUp"
    ,"key.keyboard.page.down", "PgDn"
    ,"key.keyboard.delete", "Delete"
    ,"key.keyboard.left.win", "LWin"
    ,"key.keyboard.right.win", "RWin"
    ,"key.keyboard.menu", "AppsKey"
    ,"key.keyboard.backslash", "\"
    ,"key.keyboard.caps.lock", "CapsLock"
    ,"key.keyboard.semicolon", ";"
    ,"key.keyboard.apostrophe", "'"
    ,"key.keyboard.enter", "Enter"
    ,"key.keyboard.up", "Up"
    ,"key.keyboard.down", "Down"
    ,"key.keyboard.left", "Left"
    ,"key.keyboard.right", "Right"
    ,"key.keyboard.keypad.0", "Numpad0"
    ,"key.keyboard.keypad.1", "Numpad1"
    ,"key.keyboard.keypad.2", "Numpad2"
    ,"key.keyboard.keypad.3", "Numpad3"
    ,"key.keyboard.keypad.4", "Numpad4"
    ,"key.keyboard.keypad.5", "Numpad5"
    ,"key.keyboard.keypad.6", "Numpad6"
    ,"key.keyboard.keypad.7", "Numpad7"
    ,"key.keyboard.keypad.8", "Numpad8"
    ,"key.keyboard.keypad.9", "Numpad9"
    ,"key.keyboard.keypad.decimal", "NumpadDot"
    ,"key.keyboard.keypad.enter", "NumpadEnter"
    ,"key.keyboard.keypad.add", "NumpadAdd"
    ,"key.keyboard.keypad.subtract", "NumpadSub"
    ,"key.keyboard.keypad.multiply", "NumpadMult"
    ,"key.keyboard.keypad.divide", "NumpadDiv"
    ,"key.mouse.left", "LButton"
    ,"key.mouse.right", "RButton"
    ,"key.mouse.middle", "MButton"
    ,"key.mouse.4", "XButton1"
    ,"key.mouse.5", "XButton2")
    return keyArray[mcKey]
}
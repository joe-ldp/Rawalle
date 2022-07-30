; v1.2.0

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
global lastReset := 0
global lastNewWorld := 0
global lastResetAt := GetNumLogLines()
global resetPos := 0
global newWorldPos := 0
global resetValidated := False
global toValidateReset := ["Resetting a random seed", "Resetting the set seed", "Done waiting for save lock", "Preparing spawn area"]

Log("Instance Manager launched")

if (autoBop) {
    cmd := Format("python.exe " . A_ScriptDir . "\worldBopper9000.py {1}", mcDir)
    Run, %cmd%,, Hide
}

if (!pid := IsInstanceOpen()) {
    Log("No Minecraft instance found, launching")
    centralModsDir := A_ScriptDir . "\..\mods\"
    instModsDir := mcDir . "mods\"
    if (syncMods && DesyncedMods(centralModsDir . "*", instModsDir . "*") && FileExist(instModsDir)) {
        Loop, Files, %instModsDir%*
        {
            FileDelete, %A_LoopFileLongPath%
        }
        FileCopyDir, %centralModsDir%, %instModsDir%, 1
    }
    if (syncConfigs)
        SyncConfig()
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

ControlClick, x0 y0, ahk_pid %pid%,, RIGHT
ControlSend,, {Blind}{Esc}{F3 down}{Esc}{F3 up}, ahk_pid %pid%

GetControls()
GetSettings()

if (settings.fullscreen == "true") {
    fs := settings["key_key.fullscreen"]
    ControlSend,, {Blind}{%fs%}, ahk_pid %pid%
}
if (borderless) {
    WinSet, Style, -0xC40000, ahk_pid %pid%
} else {
    WinSet, Style, +0xC40000, ahk_pid %pid%
}
if (mode == "Multi")
    wideResets := False
if (wideResets) {
    Widen()
} else {
    WinMaximize, ahk_pid %pid%
}

OnMessage(MSG_RESET, "Reset")
OnMessage(MSG_SWITCH, "Switch")
OnMessage(MSG_SETTITLE, "SetTitle")
OnMessage(MSG_REVEAL, "Reveal")

SetTitle()
FileAppend,, IM%idx%ready.tmp

Reset(msgTime) { ; msgTime is wParam from PostMessage
    global performanceMethod, resetSounds, useObsWebsocket, screenshotWorlds, fullscreen, fullscreenDelay, mode, wideResets, settingsDelay
    if (resetState == STATE_RESETTING || resetState == STATE_LOADING || (msgTime > lastReset && msgTime < lastNewWorld) || (msgTime < lastNewWorld + 400)) {
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
            if (mode == "Wall") {
                WinMaximize, Fullscreen Projector
                WinActivate, Fullscreen Projector
            }
        }

        lastReset := A_TickCount
        resetPos := GetNumLogLines()
        resetValidated := False
        reset := settings["key_CreateNewWorld"]
        ControlSend,, {Blind}{%reset%}, ahk_pid %pid%
        resetState := STATE_RESETTING
        SetTimer, ManageState, -200
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
        Loop, Read, %mcDir%\logs\latest.log
        {
            if (A_Index >= (resetState == STATE_RESETTING ? resetPos : newWorldPos)) {
                line := A_LoopReadLine
                lineNum := A_Index
                if (resetState == STATE_RESETTING && A_TickCount - lastReset > 2000) {
                    for each, value in toValidateReset {
                        if (InStr(line, value)) {
                            resetState := STATE_LOADING
                            newWorldPos := lineNum
                            break
                        }
                    }
                }
                if (resetState != STATE_PREVIEWING && InStr(line, "Starting Preview")) {
                    Log("Found preview at line " . lineNum . ":`n" . line)
                    ControlSend,, {Blind}{F3 Down}{Esc}{F3 Up}, ahk_pid %pid%
                    newWorldPos := lineNum
                    lastNewWorld := A_TickCount
                    resetState := STATE_PREVIEWING
                    continue 2
                } else if ((resetState == STATE_LOADING || resetState == STATE_PREVIEWING) && InStr(line, "advancements")) {
                    if (resetState != STATE_PREVIEWING)
                        lastNewWorld := A_TickCount
                    Log("Found load at line " . lineNum . " Log:`n" . line)
                    if (mode == "Wall" || !WinActive("ahk_pid " . pid)) {
                        ControlSend,, {Blind}{F3 Down}{Esc}{F3 Up}, ahk_pid %pid%
                        resetState := STATE_READY
                        if (performanceMethod == "F") {
                            Frz := Func("Freeze").Bind()
                            bfd := 0 - beforeFreezeDelay
                            SetTimer, %Frz%, %bfd%
                        }
                    } else {
                        Play()
                    }
                    return
                }
            }
        }
        if (resetState == STATE_RESETTING && (A_TickCount - lastReset > 15000)) {
            Log("Found failed reset. Forcing reset")
            reset := settings["key_CreateNewWorld"]
            ControlSend,, {Blind}{%reset%}, ahk_pid %pid%
        }
        Sleep, 50
    }
}

Switch() {
    global useObsWebsocket, screenshotWorlds, obsDelay, mode, fullscreen, fullscreenDelay, performanceMethod, wideResets
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

        if (useObsWebsocket) {
            SendOBSCommand("Play," . idx)
            if (screenshotWorlds)
                SendOBSCommand("GetImg")
        } else {
            Send, {Numpad%idx% down}
            Sleep, %obsDelay%
            Send, {Numpad%idx% up}
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

GetNumLogLines() {
    numLines := 0
    Loop, Read, %mcDir%\logs\latest.log
        numLines++
    return numLines
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
                if (InStr(value, "key.keyboard.")) {
                    split := StrSplit(value, "key.keyboard.")
                    switch (split[2])
                    {
                        case "slash":
                            value := "/"
                        default:
                            StringLower, value, % split[2]
                    }
                }
                if (InStr(value, "key.mouse.")) {
                    split := StrSplit(value, "key.mouse.")
                    switch (split[2])
                    {
                        case "left":
                            value := "LButton"
                        case "right":
                            value := "RButton"
                        case "middle":
                            value := "MButton"
                        case "4":
                            value := "XButton1"
                        case "5":
                            value := "XButton2"
                    }
                }
                if (InStr(value, "left.")) {
                    split := StrSplit(value, "left.")
                    StringLower, value, % split[2]
                    value := "L" . value
                }
                if (InStr(value, "right.")) {
                    split := StrSplit(value, "right.")
                    StringLower, value, % split[2]
                    value := "R" . value
                }
                settings[key] := value
                if (key == "key_CreateNewWorld" && value == "")
                    settings[key] := "f6"
            }
        }
    }
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
    global widthMultiplier
    newHeight := Floor(A_ScreenHeight / widthMultiplier)
    WinRestore, ahk_pid %pid%
    WinMove, ahk_pid %pid%,, 0, 0, %A_ScreenWidth%, %newHeight%
}

IsInstanceOpen() {
    for proc in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process where ExecutablePath like ""%jdk%javaw.exe%""") {
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

SyncConfig() {
    global multiMCLocation, multiMCNameFormat
    mainConfig := Format("{1}\instances\{2}\.minecraft\config\", multiMCLocation, StrReplace(multiMCNameFormat, "*", 1))
    thisConfig := Format("{1}\instances\{2}\.minecraft\config\", multiMCLocation, StrReplace(multiMCNameFormat, "*", idx))
    FileCopy, %mainConfig%\*.*, %thisConfig%\*.*, 1
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
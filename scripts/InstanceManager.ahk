; v1.2.1

;region init

#NoEnv
#NoTrayIcon
#WinActivateForce
#SingleInstance, Off
SetWorkingDir, %A_ScriptDir%

SetKeyDelay, 0
SetWinDelay, 1

#Include %A_ScriptDir%\constants.ahk
#Include %A_ScriptDir%\functions.ahk
LoadSettings(A_ScriptDir . "\..\settings.ini")

;endregion

;region globals

global resetState := STATE_READY
global pid := 0
global idx := A_Args[1]
global instName := StrReplace(multiMCNameFormat, "*", idx)
global instDir := multiMCLocation . "\instances\" . instName
global mcDir := instDir . "\.minecraft\"
global instanceMods := []
global settings := []
global lastResetTime := 0
global lastNewWorld := 0
global readFromLine := 0
global resetValidated := False
global wideHeight := Floor(A_ScreenHeight / widthMultiplier)
global toValidateReset := ["Resetting a random seed", "Resetting the set seed", "Done waiting for save lock", "Preparing spawn area"]
global locked := False

;endregion

;region startup

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

if (!pid := IsInstanceOpen(instDir)) {
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
    while (!pid := IsInstanceOpen(instDir))
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
if (!InStr(mcTitle, "-")) {
    ControlClick, x0 y0, ahk_pid %pid%,, RIGHT
    ControlSend,, {Blind}{Esc}{F3 down}{Esc}{F3 up}, ahk_pid %pid%
}

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
OnMessage(MSG_GETSTATE, "GetState")
OnMessage(MSG_LOCK, "Lock")

WinSetTitle, ahk_pid %pid%,, Minecraft* - Instance %idx%
FileAppend,, IM%idx%ready.tmp

;endregion

;region funcs

Reset(msgTime) { ; msgTime is wParam from PostMessage
    global resetSounds, useObsWebsocket, screenshotWorlds, fullscreen, fullscreenDelay, mode, wideResets
    if (resetState == STATE_RESETTING && (A_TickCount - lastResetTime > 3000)) {
        Log("Found failed reset. Forcing reset")
        lastResetTime := A_TickCount
        reset := settings["key_CreateNewWorld"]
        ControlSend,, {Blind}{%reset%}, ahk_pid %pid%
    } else if (resetState == STATE_RESETTING || resetState == STATE_LOADING || (msgTime > lastResetTime && msgTime < lastNewWorld) || (msgTime < lastNewWorld + 400)) {
        Log("Discarding reset")
        return
    } else {
        Log("Resetting")
        if (resetSounds)
            SoundPlay, %A_ScriptDir%\..\media\reset.wav
        if (WinActive("ahk_pid " . pid)) {
            GetSettings()
            ControlSend,, {Blind}{F3}, ahk_pid %pid%
            if (useObsWebsocket && screenshotWorlds)
                SendOBSCommand("SaveImg," . A_NowUTC . "," . CurrentWorldEntered(), Format("IM{1}", idx))
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
        CountReset("Resets")
        CountReset("Daily Resets")
    }
}

ManageState() {
    Critical
    global mode
    while (resetState != STATE_READY) {
        Critical, Off
        Sleep, -1
        Critical, On
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
                            ValidateReset(STATE_LOADING, lineNum)
                            break
                        }
                    }
                }
                if (resetState != STATE_PREVIEWING && InStr(line, "Starting Preview")) {
                    Log("Found preview at line " . lineNum . ":`n" . line)
                    ControlSend,, {Blind}{F3 Down}{Esc}{F3 Up}, ahk_pid %pid%
                    ValidateReset(STATE_PREVIEWING, lineNum)
                    lastNewWorld := A_TickCount
                    continue 2
                } else if ((resetState == STATE_LOADING || resetState == STATE_PREVIEWING) && InStr(line, "advancements")) {
                    if (resetState != STATE_PREVIEWING)
                        lastNewWorld := A_TickCount
                    Log("Found load at line " . lineNum . " Log:`n" . line)
                    ValidateReset(STATE_READY, lineNum)
                    if (mode == "Wall" || !WinActive("ahk_pid " . pid)) {
                        ControlSend,, {Blind}{F3 Down}{Esc}{F3 Up}, ahk_pid %pid%
                    } else {
                        Play()
                    }
                }
            }
        }
        Sleep, 50
    }
}

ValidateReset(newState, lineNum) {
    resetState := newState
    readFromLine := lineNum + 1
}

Switch() {
    global screenshotWorlds, mode, fullscreen, fullscreenDelay, wideResets
    if ((mode == "Wall" && resetState == STATE_READY) || (mode == "Multi" && (resetState == STATE_PREVIEWING || resetState == STATE_READY))) {
        Log("Switched to instance")

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

GetState() {
    return resetState
}

Lock(nowLocked) {
    locked := nowLocked
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

CurrentWorldEntered() {
    FileRead, logContents, %mcDir%\logs\latest.log
    return (InStr(logContents, "We Need To Go Deeper",, 0) > InStr(logContents, "spawn area",, 0))
}

Widen() {
    WinRestore, ahk_pid %pid%
    WinMove, ahk_pid %pid%,, 0, 0, %A_ScreenWidth%, %wideHeight%
}

IsInstanceOpen(instDir) {
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

GetMods(mcDir) {
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

Log(message) {
    FileAppend, [%A_YYYY%-%A_MM%-%A_DD% %A_Hour%:%A_Min%:%A_Sec%] | Current state: %resetState% | %message%`n, %mcDir%log.log
}

CountReset(resetType) {
    filePath := Format("../resets/{1}.txt", resetType)
    if (!FileExist(filePath))
        FileAppend, 0, %filePath%
    ; Loop, {
    ;     file := FileOpen(filePath, "a -rw")
    ;     if (IsObject(file)) {
    ;         file.Seek(0)
    ;         num := file.Read()
    ;         num += 1
    ;         file.Seek(0)
    ;         file.Write(num)
    ;         file.Close()
    ;         break
    ;     }
    ;     file.Close()
    ; }

    file := FileOpen(filePath, "a -rw")
    if (!IsObject(file)) {
        cr := Func("CountReset").Bind(resetType)
        SetTimer, %cr%, -500
        return
    }
    file.Seek(0)
    num := file.Read()
    num += 1
    file.Seek(0)
    file.Write(num)
    file.Close()
}

;endregion

; v1.3.0

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
LoadSettings(Format("{1}\..\settings.ini", A_ScriptDir))

;endregion

;region globals

global idx           := A_Args[1]
global instName      := StrReplace(multiMCNameFormat, "*", idx)
global instDir       := Format("{1}\instances\{2}", multiMCLocation, instName)
global mcDir         := Format("{1}\.minecraft\", instDir)
global settings      := []
global pid           := 0
global lastResetTime := 0
global lastNewWorld  := 0
global locked        := False
global playing       := False
global resetState    := STATE_READY
global wideHeight    := Floor(A_ScreenHeight / widthMultiplier)
global doF1          := IsStandardSettingsF1()

EnvGet, threadCount, NUMBER_OF_PROCESSORS
global maxMask   := BitMaskify(threadCount)
global boostMask := BitMaskify(boostThreads == -1 ? Ceil(threadCount * 0.8) : boostThreads)
global loadMask  := BitMaskify(loadThreads  == -1 ? Ceil(threadCount * 0.5) : loadThreads)
global lowMask   := BitMaskify(lowThreads   == -1 ? Ceil(threadCount * 0.5) : lowThreads)
global bgMask    := BitMaskify(bgThreads    == -1 ? Ceil(threadCount * 0.4) : bgThreads)

;endregion

;region startup

Log("Instance Manager launched")

if (autoBop) {
    cmd := Format("python.exe {1}\worldBopper9000.py {2}", A_ScriptDir, mcDir)
    Run, %cmd%,, Hide
}

if (syncConfigs) {
    mainConfig := Format("{1}\instances\{2}\.minecraft\config\", multiMCLocation, StrReplace(multiMCNameFormat, "*", 1))
    thisConfig := Format("{1}\instances\{2}\.minecraft\config\", multiMCLocation, StrReplace(multiMCNameFormat, "*", idx))
    FileCopy, %mainConfig%\*.*, %thisConfig%\*.*, 1
    if (ErrorLevel == 0)
        Log("Synced configs successfully")
    else
        Log("Something went wrong when syncing configs")
}

if (!pid := IsInstanceOpen(instDir)) {
    Log("No Minecraft instance found")

    centralModsDir := Format("{1}\..\mods\", A_ScriptDir)
    instModsDir := Format("{1}mods\", mcDir)
    if (syncMods && DesyncedMods(centralModsDir . "*", instModsDir . "*") && FileExist(centralModsDir)) {
        Log("Syncing mods...")
        Loop, Files, %instModsDir%*
        {
            FileDelete, %A_LoopFileLongPath%
        }
        FileCopyDir, %centralModsDir%, %instModsDir%, 1
        if (ErrorLevel == 0)
            Log("Synced mods successfully")
        else
            Log("Something went wrong when syncing mods")
    }

    Log(Format("Launching MultiMC instance {1}", instName))
    mmcpack := Format("{1}\mmc-pack.json", instDir)
    FileGetTime, packModified, %mmcpack%, M
    Run, %multiMCLocation%\MultiMC.exe -l "%instName%"
    while (!pid := IsInstanceOpen(instDir))
        Sleep, 500
    Log("Minecraft instance launched and found")
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
if (borderless) {
    WinSet, Style, -0xC40000, ahk_pid %pid%
} else {
    WinSet, Style, +0xC40000, ahk_pid %pid%
}
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
OnMessage(MSG_AFFINITY, "UpdateAffinity")

WinSetTitle, ahk_pid %pid%,, Minecraft* - Instance %idx%
FileAppend,, IM%idx%ready.tmp

Log("Instance Manager fully initialised, ready to play")

;endregion

;region funcs

Reset(msgTime) { ; msgTime is wParam from PostMessage
    global resetSounds, useObsWebsocket, screenshotWorlds, fullscreen, fullscreenDelay, mode, wideResets
    if (resetState == STATE_RESETTING && (A_TickCount - lastResetTime > 3000)) {
        Log("Found potential failed reset (reset still not validated after 3s). Resetting again")
        lastResetTime := A_TickCount
        reset := settings["key_CreateNewWorld"]
        ControlSend,, {Blind}{%reset%}, ahk_pid %pid%
    } else if (resetState == STATE_RESETTING || resetState == STATE_LOADING || (msgTime > lastResetTime && msgTime < lastNewWorld) || (msgTime < lastNewWorld + 400)) {
        Log("Discarding reset")
        return
    } else {
        if (resetSounds)
            SoundPlay, %A_ScriptDir%\..\media\reset.wav
        if (playing) {
            Log("Exiting world (unfullscreening and widening)")
            playing := False
            GetSettings()
            ControlSend,, {Blind}{F3}, ahk_pid %pid%
            if (useObsWebsocket && screenshotWorlds)
                SendOBSCommand(Format("SaveImg{1},{2}", A_NowUTC, CurrentWorldEntered()), Format("IM{1}", idx))
            if (fullscreen && settings.fullscreen == "true") {
                fs := settings["key_key.fullscreen"]
                ControlSend,, {Blind}{%fs%}, ahk_pid %pid%
                DllCall("Sleep", "UInt", fullscreenDelay)
            }
            if (wideResets)
                Widen()
        }

        Log("Resetting")
        resetState := STATE_RESETTING
        UpdateAffinity()
        reset := settings["key_CreateNewWorld"]
        leavePreview := settings["key_LeavePreview"]
        lastResetTime := A_TickCount
        ControlSend,, {Blind}{%reset%}{%leavePreview%}, ahk_pid %pid%
        SetTimer, ManageState, -200
        Loop, Read, %mcDir%\logs\latest.log
            readFromLine := A_Index + 1
        CountReset("Resets")
        CountReset("Daily Resets")
    }
}

ManageState() {
    global mode
    static toValidateReset := ["Resetting a random seed", "Resetting the set seed", "Done waiting for save lock", "Preparing spawn area"]
    global readFromLine := 0
    Critical
    while (resetState != STATE_READY) {
        Critical, Off
        Sleep, -1
        Critical, On
        numLines := 0
        Loop, Read, %mcDir%\logs\latest.log
            numLines++
        Loop, Read, %mcDir%\logs\latest.log
        {
            if ((A_Index > readFromLine) && (numLines - A_Index < 5)) {
                line := A_LoopReadLine
                lineNum := A_Index
                if (resetState == STATE_RESETTING && A_TickCount - lastResetTime > 2500) {
                    for each, value in toValidateReset {
                        if (InStr(line, value)) {
                            readFromLine := ValidateReset(STATE_LOADING, lineNum, False)
                            Log(Format("Validated reset at line {1}. Log:`n{2}", lineNum, line))
                            break
                        }
                    }
                }
                if (resetState != STATE_PREVIEWING && InStr(line, "Starting Preview")) {
                    Log(Format("Found preview at line {1}. Log:`n{2}", lineNum, line))
                    ControlSend,, {Blind}{F3 Down}{Esc}{F3 Up}, ahk_pid %pid%
                    readFromLine := ValidateReset(STATE_PREVIEWING, lineNum, True)
                    UpdateAffinity()
                    continue 2
                } else if ((resetState == STATE_LOADING || resetState == STATE_PREVIEWING) && InStr(line, "advancements")) {
                    Log(Format("Found world load at line {1}. Log:`n{2}", lineNum, line))
                    readFromLine := ValidateReset(STATE_READY, lineNum, resetState != STATE_PREVIEWING)
                    SetAffinity(pid, boostMask)
                    SetTimer, UpdateAffinity, -500
                    if (mode == "Wall" || !WinActive("ahk_pid " . pid)) {
                        ControlSend,, {Blind}{F3 Down}{Esc}{F3 Up}, ahk_pid %pid%
                    } else {
                        Play()
                    }
                } else {
                    readFromLine := A_Index
                }
            }
        }
        Sleep, 50
    }
}

ValidateReset(newState, lineNum, updateNewWorld) {
    resetState := newState
    if (updateNewWorld)
        lastNewWorld := A_TickCount
    return lineNum
}

Switch() {
    global screenshotWorlds, mode, fullscreen, fullscreenDelay, wideResets
    if ((mode == "Wall" && resetState == STATE_READY) || (mode == "Multi" && (resetState == STATE_PREVIEWING || resetState == STATE_READY))) {
        Log("Switched to instance")

        playing := True
        SetTimer, UpdateAffinity, Off
        UpdateAffinity()
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
        Log("Switch requested but instance was not ready")
        return resetState
    }
}

Play() {
    global fullscreen, mode, fullscreenDelay, unpauseOnSwitch, coopResets
    Log("Playing instance")

    if (fullscreen && mode == "Multi") {
        fs := settings["key_key.fullscreen"]
        ControlSend,, {Blind}{%fs%}, ahk_pid %pid%
        Sleep, %fullscreenDelay%
    }
    if (resetState == STATE_READY && (unpauseOnSwitch || coopResets)) {
        ControlSend,, {Blind}{Esc}, ahk_pid %pid%
        if (doF1)
            ControlSend,, {Blind}{F1}, ahk_pid %pid%
    }
    if (coopResets) {
        Sleep, 50
        ControlSend,, {Blind}{Esc}{Tab 7}{Enter}{Tab 4}{Enter}{Tab}{Enter}, ahk_pid %pid%
        if (!unpauseOnSwitch)
            ControlSend,, {Blind}{Esc}, ahk_pid %pid%
    }
}

GetState() {
    return resetState
}

Lock(nowLocked) {
    Log(Format("Instance lock state set to ", nowLocked))
    locked := nowLocked
    UpdateAffinity()
}

UpdateAffinity(isBg := 0) {
    if (isBg) {
        SetAffinity(pid, bgMask)
    } else if (playing) {
        SetAffinity(pid, maxMask)
    } else if (WinActive("Fullscreen Projector")) {
        if (resetState == STATE_RESETTING || resetState == STATE_LOADING) {
            SetAffinity(pid, maxMask)
        } else if (resetState == STATE_PREVIEWING && (A_TickCount - lastNewWorld <= 500 || locked)) {
            SetAffinity(pid, boostMask)
        } else if (resetState == STATE_READY) {
            SetAffinity(pid, lowMask)
            return
        } else {
            SetAffinity(pid, loadMask)
        }
        SetTimer, UpdateAffinity, -100
    } else {
        SetAffinity(pid, lowMask)
    }
}

SetAffinity(pid, mask) {
    static laskMask := 0
    if (mask == lastMask)
        return
    lastMask := mask
    hProc := DllCall("OpenProcess", "UInt", 0x0200, "Int", false, "UInt", pid, "Ptr")
    DllCall("SetProcessAffinityMask", "Ptr", hProc, "Ptr", mask)
    DllCall("CloseHandle", "Ptr", hProc)
}

BitMaskify(threads) {
    return (2 ** threads) - 1
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
    static logPath := Format("{1}\..\logs\instance{2}.log", A_ScriptDir, A_Args[1])
    FileAppend, [%A_YYYY%-%A_MM%-%A_DD% %A_Hour%:%A_Min%:%A_Sec%] | Current state: %resetState% | %message%`n, %logPath%
}

CountReset(resetType) {
    filePath := Format("../resets/{1}.txt", resetType)
    if (!FileExist(filePath))
        FileAppend, 0, %filePath%

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

IsStandardSettingsF1() {
    Loop, Read, %mcDir%\config\standardoptions.txt
    {
        if (InStr(A_LoopReadLine, "f1:")) {
            if (InStr(A_LoopReadLine, "true"))
                return true
            else
                break
        }
    }
    return false
}

;endregion

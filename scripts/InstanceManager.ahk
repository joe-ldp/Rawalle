; v1.4.0

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
global pid           := 0
global hwnd          := 0
global lastResetTime := 0
global lastNewWorld  := 0
global warming       := 0
global locked        := False
global playing       := False
global resetState    := STATE_READY
global wideHeight    := Floor(A_ScreenHeight / widthMultiplier)
global doF1          := GetSetting("f1", "false", "/config/standardoptions.txt") == "true"

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

if (syncConfigs && idx != 1) {
    mainConfig := Format("{1}\instances\{2}\.minecraft\config\", multiMCLocation, StrReplace(multiMCNameFormat, "*", 1))
    thisConfig := Format("{1}\instances\{2}\.minecraft\config\", multiMCLocation, StrReplace(multiMCNameFormat, "*", idx))
    FileCopy, %mainConfig%\*.*, %thisConfig%\*.*, 1
    if (ErrorLevel == 0)
        Log("Synced configs successfully")
    else
        Log("Something went wrong when syncing configs")
    doF1 := GetSetting("f1", "false", "/config/standardoptions.txt") == "true"
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
    ControlSend,, {Blind}{Esc}, ahk_pid %pid%
    WinMinimize, ahk_pid %pid%
    WinRestore, ahk_pid %pid%
}

GetControls()
WinGet, hwnd, ID, ahk_pid %pid%

if (GetSetting("fullscreen") == "true")
    ControlSend,, {Blind}{%key_fullscreen%}, ahk_pid %pid%
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

OnMessage(MSG_RESET,    "Reset")
OnMessage(MSG_SWITCH,   "Switch")
OnMessage(MSG_LOCK,     "Lock")
OnMessage(MSG_AFFINITY, "UpdateAffinity")
OnMessage(MSG_GETSTATE, "GetState")
OnMessage(MSG_WARMUP,   "Warmup")

WinSetTitle, ahk_pid %pid%,, Minecraft* - Instance %idx%
FileAppend,, IM%idx%ready.tmp

Log("Instance Manager fully initialised, ready to play")

;endregion

;region funcs

Reset(msgTime) { ; msgTime is wParam from PostMessage
    global resetSounds, fullscreen, fullscreenDelay, wideResets, key_createnewworld, key_leavepreview, key_fullscreen, spawnProtection
    if (resetState == STATE_RESETTING || (msgTime > lastResetTime && msgTime < lastNewWorld) || (msgTime < lastNewWorld + spawnProtection)) {
        Log("Discarding reset")
        return
    } else {
        if (resetSounds && !warming)
            SoundPlay, %A_ScriptDir%\..\media\reset.wav
        if (playing) {
            Log("Exiting world (unfullscreening and widening)")
            playing := False
            ControlSend,, {Blind}{F3}{Esc 3}, ahk_pid %pid%
            if (fullscreen && GetSetting("fullscreen") == "true") {
                ControlSend,, {Blind}{%key_fullscreen%}, ahk_pid %pid%
                DllCall("Sleep", "UInt", fullscreenDelay)
            }
            if (wideResets) {
                WinRestore, ahk_pid %pid%
                SetTimer, Widen, -100, -1
            } else {
                WinMaximize, ahk_pid %pid%
            }
            SetTimer, ActualReset, -0
            return 0
        }

        ActualReset:
            Log("Resetting")
            resetState := STATE_RESETTING
            UpdateAffinity()
            lastResetTime := A_TickCount
            ControlSend,, {Blind}{%key_createnewworld%}{%key_leavepreview%}, ahk_pid %pid%
            SetTimer, ManageState, -200
            if (!warming) {
                CountReset("Resets")
                CountReset("Daily Resets")
            }
        return 1
    }
}

GetState() {
    return resetState
}

ManageState() {
    global mode
    Critical
    readFromLine := GetNumLogLines()
    while (resetState != STATE_READY) {
        Critical, Off
        Sleep, -1
        Critical, On
        Loop, Read, %mcDir%\logs\latest.log
        {
            if (A_Index > readFromLine) {
                line := A_LoopReadLine
                lineNum := A_Index
                readFromLine := lineNum
                if (resetState == STATE_RESETTING && InStr(line, "Starting Preview")) {
                    Log(Format("Found preview at line {1}. Log:`n{2}", lineNum, line))
                    ControlSend,, {Blind}{F3 Down}{Esc}{F3 Up}, ahk_pid %pid%
                    resetState := STATE_PREVIEWING
                    lastNewWorld := A_TickCount
                    UpdateAffinity()
                    continue 2
                } else if (resetState == STATE_PREVIEWING && InStr(line, "advancements")) {
                    Log(Format("Found world load at line {1}. Log:`n{2}", lineNum, line))
                    resetState := STATE_READY
                    SetAffinity(pid, boostMask)
                    SetTimer, UpdateAffinity, -500
                    ControlSend,, {Blind}{F3 Down}{Esc}{F3 Up}, ahk_pid %pid%
                    if (warming) {
                        Sleep, 400
                        Reset(A_NowUTC)
                    }
                    if (mode == "Multi" && WinActive("ahk_pid " . pid))
                        Play()
                    return
                }
            }
        }
        Sleep, 50
    }
}

GetNumLogLines() {
    numLines := 0
    Loop, Read, %mcDir%\logs\latest.log
        numLines++
    return numLines
}

Switch() {
    global screenshotWorlds, mode, fullscreen, fullscreenDelay, wideResets, key_fullscreen
    if ((mode == "Wall" && resetState == STATE_READY) || (mode == "Multi" && (resetState == STATE_PREVIEWING || resetState == STATE_READY))) {
        Log("Switched to instance")

        playing := True
        SetTimer, UpdateAffinity, Off
        UpdateAffinity()

        if (fullscreen && mode == "Wall")
            ControlSend,, {Blind}{%key_fullscreen%}, ahk_pid %pid%

        foregroundWindow := DllCall("GetForegroundWindow")
        windowThreadProcessId := DllCall("GetWindowThreadProcessId", "UInt", foregroundWindow, "UInt", 0)
        currentThreadId := DllCall("GetCurrentThreadId")
        DllCall("AttachThreadInput", "UInt", windowThreadProcessId, "UInt", currentThreadId, "Int", 1)
        if (wideResets && !fullscreen)
            DllCall("SendMessage", "UInt", hwnd, "UInt", 0x0112, "UInt", 0xF030, "Int", 0) ; fast maximise
        DllCall("SetForegroundWindow", "UInt", hwnd) ; helps application take input without a Send Click
        DllCall("BringWindowToTop", "UInt", hwnd)
        DllCall("AttachThreadInput", "UInt", windowThreadProcessId, "UInt", currentThreadId, "Int", 0)

        if (resetState == STATE_READY)
            Play()

        return 0
    } else {
        Log("Switch requested but instance was not ready")
        return resetState
    }
}

Play() {
    global fullscreen, mode, fullscreenDelay, unpauseOnSwitch, coopResets, key_fullscreen
    Log("Playing instance")

    if (fullscreen && mode == "Multi")
        ControlSend,, {Blind}{%key_fullscreen%}, ahk_pid %pid%
    if (unpauseOnSwitch || coopResets || doF1) {
        ControlSend,, {Blind}{Esc}, ahk_pid %pid%
        if (doF1)
            ControlSend,, {Blind}{F1}, ahk_pid %pid%
        if (coopResets) {
            Sleep, 50
            ControlSend,, {Blind}{Esc}{Tab 7}{Enter}{Tab 4}{Enter}{Tab}{Enter}, ahk_pid %pid%
        }
        if (!unpauseOnSwitch) {
            if (coopResets)
                ControlSend,, {Blind}{Esc}, ahk_pid %pid%
            else
                ControlSend,, {Blind}{F3 Down}{Esc}{F3 Up}, ahk_pid %pid%
        } else {
            ControlSend,, {Blind}{Esc 2}, ahk_pid %pid%
        }
    }
}

Lock(nowLocked) {
    Log(Format("Instance lock state set to {1}", nowLocked ? "True" : "False"))
    locked := nowLocked
    UpdateAffinity()
}

UpdateAffinity(bgOverride := 0, anyLocked := -1) {
    static doAdvanced := 0
    doAdvanced := anyLocked != -1 ? anyLocked : doAdvanced
    if (doAdvanced) {
        if (bgOverride) {
            SetAffinity(pid, bgMask)
        } else if (playing) {
            SetAffinity(pid, maxMask)
        } else if ((WinActive("Full") && WinActive("screen Projector")) || WinActive("ahk_exe obs64.exe")) {
            WinGetPos,,, w, h, A
            if (w == A_ScreenWidth && h == A_ScreenHeight) {
                if (resetState == STATE_RESETTING) {
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
            }
        } else {
            SetAffinity(pid, lowMask)
        }
    } else {
        if (playing || !bgOverride) {
            SetAffinity(pid, maxMask)
        } else {
            SetAffinity(pid, bgMask)
        }
    }
}

SetAffinity(pid, mask) {
    static lastMask := 0
    if (mask != lastMask) {
        lastMask := mask
        hProc := DllCall("OpenProcess", "UInt", 0x0200, "Int", false, "UInt", pid, "Ptr")
        DllCall("SetProcessAffinityMask", "Ptr", hProc, "Ptr", mask)
        DllCall("CloseHandle", "Ptr", hProc)
    }
}

BitMaskify(threads) {
    return (2 ** threads) - 1
}

GetSetting(setting, default := "", file := "options.txt") {
    Loop, Read, %mcDir%/%file%
    {
        kv := StrSplit(Format("{:L}", A_LoopReadLine), ":")
        if (kv.MaxIndex() == 2 && kv[1] == setting)
            return StrReplace(kv[2], A_Space)
    }
    return default
}

GetControls() {
    global
    local atumKeyFound := False
    Loop, Read, %mcDir%/options.txt
    {
        kv := StrSplit(A_LoopReadLine, ":")
        if (kv.MaxIndex() == 2 && InStr(kv[1], "key")) {
            key := StrReplace(StrReplace(StrReplace(StrReplace(Format("{:L}", kv[1]), A_Space), "key"), "_"), ".")
            value := StrReplace(Format("{:L}", kv[2]), A_Space)
            key_%key% := TranslateKey(value)
            if (key == "createnewworld")
                atumKeyFound := True
        }
    }
    if (!atumKeyFound)
        key_createnewworld := "f6"
}

Widen() {
    WinMove, ahk_pid %pid%,, 0, 0, %A_ScreenWidth%, %wideHeight%
}

Warmup(wParam) {
    warming := wParam
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

DesyncedMods(centralModsDir, instModsDir) {
    centralMods := [""]
    instMods := [""]
    Loop, Files, %centralModsDir%
    {
        centralMods[A_Index] := A_LoopFileName
    }
    Loop, Files, %instModsDir%
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

;endregion

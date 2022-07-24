; v1.1.1

Reset(idx := -1) {
    global isOnWall, activeInstance, IM_PIDs, mode, bypassWall
    idx := (idx == -1) ? (isOnWall ? MousePosToInstNumber() : activeInstance) : idx
    IM_PID := IM_PIDs[idx]
    UnlockInstance(idx, False)
    PostMessage, MSG_RESET, A_TickCount,,,ahk_pid %IM_PID%
    CountResets("Resets")
    CountResets("Daily Resets")

    if (activeInstance == idx) {
        if (mode == "Wall") {
            activeInstance := 0
            if (bypassWall)
                ToWallOrNextInstance()
            else
                ToWall()
        } else {
            NextInstance()
        }
        LogAction(idx, "exitworld")
    } else {
        LogAction(idx, "reset")
    }
    SetAffinities()
}

Play(idx := -1) {
    global IM_PIDs, activeInstance, isOnWall
    idx := (idx == -1) ? MousePosToInstNumber() : idx
    pid := IM_PIDs[idx]
    SendMessage, MSG_SWITCH,,,,ahk_pid %pid%,,1000
    if (ErrorLevel == 0) { ; errorlevel is set to 0 if the instance was ready to be played; 1 otherwise
        LogAction(idx, "play")
        LockInstance(idx, False)
        activeInstance := idx
        isOnWall := False
        SetAffinities()
    } else if (ErrorLevel == 3) {
        LockInstance(idx, False)
    }
}

Reveal(idx) {
    global IM_PIDs
    pid := IM_PIDs[idx]
    PostMessage, MSG_REVEAL,,,,ahk_pid %pid%
}

FocusReset(idx := -1) {
    global numInstances, locked
    idx := (idx == -1) ? MousePosToInstNumber() : idx
    Play(idx)
    Loop, %numInstances%
        if (idx != A_Index && !locked[A_Index])
            Reset(A_Index)
}

BackgroundReset(idx) {
    global activeInstance
    if (idx != activeInstance)
        Reset(idx)
}

ResetAll() {
    global numInstances, locked
    Loop, %numInstances%
        if (!locked[A_Index])
            Reset(A_Index)
}

LockInstance(idx := -1, sound := True) {
    global isOnWall, activeInstance, lockSounds, locked, useObsWebsocket, lockIndicators
    idx := (idx == -1) ? (isOnWall ? MousePosToInstNumber() : activeInstance) : idx
    if (lockSounds && sound)
        SoundPlay, media\lock.wav
    if (locked[idx])
        return
    if (useObsWebsocket && lockIndicators)
        SendOBSCommand("Lock," . idx . "," . 1)
    locked[idx] := A_TickCount
    LogAction(idx, "lock")
}

UnlockInstance(idx := -1, sound := True) {
    global isOnWall, activeInstance, lockSounds, locked, useObsWebsocket, lockIndicators
    idx := (idx == -1) ? (isOnWall ? MousePosToInstNumber() : activeInstance) : idx
    if (lockSounds && sound)
        SoundPlay, media\lock.wav
    if (!locked[idx])
        return
    if (useObsWebsocket && lockIndicators)
        SendOBSCommand("Lock," . idx . "," . 0)
    locked[idx] := 0
    LogAction(idx, "unlock")
}

ToggleLock(idx := -1) {
    global isOnWall, activeInstance, locked
    idx := (idx == -1) ? (isOnWall ? MousePosToInstNumber() : activeInstance) : idx
    if (locked[idx])
        UnlockInstance(idx)
    else
        LockInstance(idx)
}

WallLock(idx := -1) {
    global isOnWall, activeInstance, lockIndicators, useObsWebsocket
    idx := (idx == -1) ? (isOnWall ? MousePosToInstNumber() : activeInstance) : idx
    if (useObsWebsocket && lockIndicators)
        ToggleLock(idx)
    else
        LockInstance(idx)
}

Freeze(pid) {
    hProcess := DllCall("OpenProcess", "UInt", 0x1F0FFF, "Int", 0, "Int", pid)
    if (hProcess) {
        DllCall("ntdll.dll\NtSuspendProcess", "Int", hProcess)
        DllCall("CloseHandle", "Int", hProcess)
    }

    ; hProcess := DllCall("OpenProcess", "UInt", 0x1F0FFF, "Int", 0, "Int", pid)
    ; DllCall("SetProcessWorkingSetSize", "UInt", hProcess, "Int", -1, "Int", -1)
    ; DllCall("CloseHandle", "Int", hProcess)
    ; Log("Freeing memory")

    ; Freeing memory is disabled by default, as it doesn't achieve much except more unfreezing lag.
    ; It can in theory let you run more than the max # of instances your ram can handle, but this macro doesn't support that anyway.
    ; You can uncomment these lines to enable it if you want.
}

Unfreeze(pid) {
    global resumeDelay
    hProcess := DllCall("OpenProcess", "UInt", 0x1F0FFF, "Int", 0, "Int", pid)
    if (hProcess) {
        DllCall("ntdll.dll\NtResumeProcess", "Int", hProcess)
        DllCall("CloseHandle", "Int", hProcess)
        Sleep, %resumeDelay%
    }
}

FreezeAll() {
    global MC_PIDs
    for each, pid in MC_PIDs {
        Freeze(pid)
    }
}

UnfreezeAll() {
    global MC_PIDs
    for each, pid in MC_PIDs {
        Unfreeze(pid)
    }
}

SetAffinities() {
    global MC_PIDs, activeInstance, highBitMask, midBitMask, lowBitMask
    for idx, pid in MC_PIDs {
        mask := activeInstance == idx ? highBitMask : activeInstance == 0 ? midBitMask : lowBitMask
        hProc := DllCall("OpenProcess", "UInt", 0x0200, "Int", false, "UInt", pid, "Ptr")
        DllCall("SetProcessAffinityMask", "Ptr", hProc, "Ptr", mask)
        DllCall("CloseHandle", "Ptr", hProc)
    }
}

SetTitles() {
    global IM_PIDs
    for each, pid in IM_PIDs {
        PostMessage, MSG_SETTITLE,,,,ahk_pid %pid%
    }
}

MousePosToInstNumber() {
    global cols, instHeight, instWidth
    MouseGetPos, mX, mY
    return (Floor(mY / instHeight) * cols) + Floor(mX / instWidth) + 1
}

NextInstance() {
    global activeInstance, numInstances
    Loop, {
        activeInstance := activeInstance + 1 > numInstances ? 1 : activeInstance + 1
        Play(activeInstance)
        if (ErrorLevel == 0)
            break
    }
}

ToWall() {
    global useObsWebsocket, obsDelay, isOnWall
    if (useObsWebsocket) {
        SendOBSCommand("ToWall")
    } else {
        Send, {F12 Down}
        Sleep, %obsDelay%
        Send, {F12 Up}
    }
    isOnWall := True
}

ToWallOrNextInstance() {
    local minTime := A_TickCount, goToIdx := 0
    for idx, lockTime in locked {
        if (lockTime && lockTime < minTime) {
            minTime := lockTime
            goToIdx := idx
        }
    }
    
    if (goToIdx != 0) {
        Play(goToIdx)
    } else {
        ToWall()
    }
}

SendOBSCommand(cmd) {
    static cmdNum := 1
    cmdFile := A_ScriptDir . "\scripts\pyCmds\TWCMD" . cmdNum . ".txt"
    cmdNum++
    FileAppend, %cmd%, %cmdFile%
}

CountResets(resetType) {
    filename := A_ScriptDir . "\resets\" . resetType . ".txt"
    FileRead, numResets, %filename%
    if (ErrorLevel)
        numResets := 0
    else
        FileDelete, %filename%
    numResets += 1
    FileAppend, %numResets%, %filename%
}

LogAction(idx, action) {
    FileAppend, %A_YYYY%-%A_MM%-%A_DD% %A_Hour%:%A_Min%:%A_Sec%`,%idx%`,%action%`n, actions.csv
}

LoadSettings() {
    global
    local filename, file, sect, equalsPos, key, value
    FileRead, file, %settingsFile%
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
                    IniRead, value, %settingsFile%, %sect%, %key%
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

LoadHotkeys() {
    global numInstances
    #If, WinActive("Minecraft") && WinActive("ahk_exe javaw.exe")
    #If, WinActive("Fullscreen Projector")
    #If
    FileRead, file, %A_ScriptDir%\hotkeys.ini
    Loop, Parse, file, `n`r, %A_Space%%A_Tab%
    {
        equalsPos := InStr(A_LoopField, "=")
        if (InStr(A_LoopField, "WinActive")) {
            Hotkey, If, % SubStr(A_LoopField, 2)
        } else if (equalsPos && (InStr(A_LoopField, ";") != 1)) {
            function := SubStr(A_LoopField, 1, equalsPos - 1)
            keybind := StrReplace(SubStr(A_LoopField, equalsPos + 1), """", "")
            if (keybind == "unbound")
                continue
            if(!RegExMatch(keybind, "([<>]?[#^!+*])+"))
                keybind := "*" . keybind
            if (InStr(keybind, "idx")) {
                Loop, %numInstances% {
                    fn := Func(function).Bind(A_Index)
                    Hotkey, % StrReplace(keybind, "idx", A_Index), %fn%, UseErrorLevel
                    if (ErrorLevel == 2) {
                        MsgBox, I think you're using more than 9 instances or tried to assign an invalid hotkey! Check the readme on the Rawalle GitHub page for help.
                        break
                    } else if (ErrorLevel > 0) {
                        MsgBox, Unhandled error code %ErrorLevel% when creating a hotkey. Contact Ravalle if you need help 😅
                        break
                    }
                }
            } else {
                Hotkey, %keybind%, %function%, %A_Index%, UseErrorLevel
                if (ErrorLevel)
                    MsgBox, Error code %ErrorLevel% when creating a hotkey. Check the readme on the Rawalle GitHub page for help.
            }
        }
    }
}
; v1.0.0-beta

Reset(idx := -1) {
    global isOnWall, activeInstance, IM_PIDs, mode, bypasWall
    idx := (idx == -1) ? (isOnWall ? MousePosToInstNumber() : activeInstance) : idx
    IM_PID := IM_PIDs[idx]
    UnlockInstance(idx, False)
    PostMessage, MSG_RESET, A_TickCount,,,ahk_pid %IM_PID%
    CountResets("Attempts")
    CountResets("Daily Attempts")

    if (activeInstance == idx) {
        if (mode == "Wall") {
            activeInstance := 0
            if (fullscreen)
                Sleep, %fullscreenDelay%
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
    }
}

Freeze(idx) {
    global IM_PIDs
    pid := IM_PIDs[idx]
    PostMessage, MSG_FREEZE,,,,ahk_pid %pid%
}

Unfreeze(idx) {
    global IM_PIDs
    pid := IM_PIDs[idx]
    PostMessage, MSG_UNFREEZE,,,,ahk_pid %pid%
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
    global locked
    if (!locked[idx])
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

UnlockInstance(idx := 1, sound := True) {
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

ToggleLock(idx := 1) {
    global isOnWall, activeInstance, locked
    idx := (idx == -1) ? (isOnWall ? MousePosToInstNumber() : activeInstance) : idx
    if (locked[idx])
        UnlockInstance(idx)
    else
        LockInstance(idx)
}

FreezeAll() {
    global numInstances
    Loop, %numInstances%
        Freeze(A_Index)
}

UnfreezeAll() {
    global numInstances, resumeDelay
    Loop, %numInstances%
        Unfreeze(A_Index)
    Sleep, %resumeDelay%
}

SetAffinities() {
    global MC_PIDs, activeInstance, highBitMask, lowBitMask
    for idx, pid in MC_PIDs {
        mask := (activeInstance == 0 || activeInstance == idx) ? highBitMask : lowBitMask
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
    WinMaximize, Fullscreen Projector
    WinActivate, Fullscreen Projector
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

global cmdNum := 1
SendOBSCommand(cmd) {
    cmdDir := A_ScriptDir . "\scripts\pyCmds\"
    cmdFile := cmdDir . "TWCMD" . cmdNum . ".txt"
    cmdNum++
    FileAppend, %cmd%, %cmdFile%
}

CountResets(attemptType) {
    filename := A_ScriptDir . "\attempts\" . attemptType . ".txt"
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
    filename := A_ScriptDir . "\settings.ini"
    FileRead, file, %filename%

    Loop, Parse, file, `n`r, %A_Space%%A_Tab%
    {
        switch (SubStr(A_LoopField, 1, 1))
        {
            case "[":
                sect := SubStr(A_LoopField, 2, -1)
            case ";":
                continue
            default:
                equalsPos := InStr(A_LoopField, "=")
                if equalsPos {
                    key := SubStr(A_LoopField, 1, equalsPos - 1)
                    IniRead, value, %filename%, %sect%, %key%
                    if (InStr(value, ",")) {
                        value := StrReplace(value, """", "")
                        %key% := []
                        Loop, Parse, value, `,
                            %key%.Push(A_LoopField)
                    } else {
                        %key% := value
                    }
                }
        }
    }
}
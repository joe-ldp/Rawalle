; v0.6.0-beta

Reset(idx := -1) {
    idx := idx == -1 ? activeInstance : idx
    IM_PID := IM_PIDs[idx]
    UnlockInstance(idx, False)
    PostMessage, MSG_RESET, A_NowUTC,,,ahk_pid %IM_PID%
    CountResets("Attempts")
    CountResets("Daily Attempts")
    LogAction(idx, "reset")

    if (activeInstance == idx) {
        if (!multiMode) {
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
    }
    SetAffinities()
}

Play(idx) {
    pid := IM_PIDs[idx]
    SendMessage, MSG_SWITCH,,,,ahk_pid %pid%,,1000
    if (ErrorLevel == 0) { ; errorlevel is set to 0 if the instance was ready to be played; 1 otherwise
        LogAction(idx, "play")
        LockInstance(idx, False)
        activeInstance := idx
        SetAffinities()
    }
}

Freeze(idx) {
    pid := IM_PIDs[idx]
    PostMessage, MSG_FREEZE,,,,ahk_pid %pid%
}

Unfreeze(idx) {
    pid := IM_PIDs[idx]
    PostMessage, MSG_UNFREEZE,,,,ahk_pid %pid%
}

Reveal(idx) {
    pid := IM_PIDs[idx]
    PostMessage, MSG_REVEAL,,,,ahk_pid %pid%
}

FocusReset(focusInstance) {
    Play(focusInstance)
    Loop, %numInstances%
        if (focusInstance != A_Index && !locked[A_Index])
            Reset(A_Index)
}

BackgroundReset(idx) {
    if (!locked[idx])
        Reset(idx)
}

ResetAll() {
    Loop, %numInstances%
        if (!locked[A_Index])
            Reset(A_Index)
}

LockInstance(idx, sound := True) {
    if (locked[idx])
        return
    SendOBSCommand("Lock," . idx . "," . 1)
    locked[idx] := A_TickCount
    LogAction(idx, "lock")
    if (lockSounds && sound)
        SoundPlay, media\lock.wav
}

UnlockInstance(idx, sound := True) {
    if (!locked[idx])
        return
    SendOBSCommand("Lock," . idx . "," . 0)
    locked[idx] := 0
    LogAction(idx, "unlock")
    if (lockSounds && sound)
        SoundPlay, media\lock.wav
}

ToggleLock(idx) {
    if (locked[idx])
        UnlockInstance(idx)
    else
        LockInstance(idx)
}

FreezeAll() {
    Loop, %numInstances%
        Freeze(A_Index)
}

UnfreezeAll() {
    Loop, %numInstances%
        Unfreeze(A_Index)
}

SetAffinities() {
    for idx, pid in MC_PIDs {
        mask := (activeInstance == 0 || activeInstance == idx) ? highBitMask : lowBitMask
        hProc := DllCall("OpenProcess", "UInt", 0x0200, "Int", false, "UInt", pid, "Ptr")
        DllCall("SetProcessAffinityMask", "Ptr", hProc, "Ptr", mask)
        DllCall("CloseHandle", "Ptr", hProc)
    }
}

SetTitles() {
    for each, pid in IM_PIDs {
        PostMessage, MSG_SETTITLE,,,,ahk_pid %pid%
    }
}

MousePosToInstNumber() {
    MouseGetPos, mX, mY
    return (Floor(mY / instHeight) * cols) + Floor(mX / instWidth) + 1
}

NextInstance() {
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
    minTime := A_TickCount
    goToIdx := 0
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
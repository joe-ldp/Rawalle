; v0.6.0-beta

MousePosToInstNumber() {
    MouseGetPos, mX, mY
    return (Floor(mY / instHeight) * cols) + Floor(mX / instWidth) + 1
}

NextInstance() {
    ErrorLevel := 1
    while (ErrorLevel != 0) {
        activeInstance := activeInstance + 1 > numInstances ? 1 : activeInstance + 1
        Play(activeInstance)
    }
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

ToWall() {
    if (useObsWebsocket) {
        SendOBSCommand("ToWall")
    } else {
        Send, {F12 Down}
        Sleep, %obsDelay%
        Send, {F12 Up}
    }
    WinActivate, Fullscreen Projector
    WinSet, AlwaysOnTop, On, Fullscreen Projector
    WinSet, AlwaysOnTop, Off, Fullscreen Projector
    isOnWall := True
}

global cmdNum := 1
SendOBSCommand(cmd) {
    idx = %3%
    cmdDir := A_ScriptDir . "\scripts\pyCmds\"
    cmdFile := cmdDir . "TWCMD" . cmdNum . ".txt"
    cmdNum++
    FileAppend, %cmd%, %cmdFile%
}

ResetAll() {
    Loop, %numInstances%
        if (!locked[A_Index])
            Reset(A_Index)
}

FreezeAll() {
    Loop, %numInstances%
        Freeze(A_Index)
}

UnfreezeAll() {
    Loop, %numInstances%
        Unfreeze(A_Index)
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

ToggleLock(idx) {
    if (locked[idx])
        UnlockInstance(idx)
    else
        LockInstance(idx)
}

LockInstance(idx, sound := True) {
    if (!locked[idx])
        SendOBSCommand("Lock," . idx . "," . 1)
    locked[idx] := A_TickCount
    if (lockSounds && sound)
        SoundPlay, media\lock.wav
}

UnlockInstance(idx, sound := True) {
    if (locked[idx])
        SendOBSCommand("Lock," . idx . "," . 0)
    locked[idx] := 0
    if (lockSounds && sound)
        SoundPlay, media\lock.wav
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

Log(message) {
    FileAppend, [%A_YYYY%-%A_MM%-%A_DD% %A_Hour%:%A_Min%:%A_Sec%] | Active instance: %activeInstance% | %message%`n, log.log
}
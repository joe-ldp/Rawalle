; Ravalle's new Multi Instance Macro
; Author: Ravalle / Joe
; v0.5.0-alpha

#NoEnv
#Persistent
#SingleInstance Force
SetWorkingDir, %A_ScriptDir%

SetKeyDelay, 0
SetWinDelay, 1
SetTitleMatchMode, 2

#Include Settings.ahk
#Include scripts\messages.ahk
#Include %A_ScriptDir%\scripts\functions.ahk
#Include %A_ScriptDir%\scripts\utilities.ahk

EnvGet, threadCount, NUMBER_OF_PROCESSORS
global McDirectories := []
global instances := 0
global rawPIDs := []
global MC_PIDs := []
global IM_PIDs := []
global instWidth := Floor(A_ScreenWidth / cols)
global instHeight := Floor(A_ScreenHeight / rows)
global isOnWall := True
global locked := []
global highBitMask := (2 ** threadCount) - 1
global lowBitMask := (2 ** Ceil(threadCount * Min(affinityLevel, 1))) - 1

OnExit("Shutdown")
GetAllPIDs(McDirectories, MC_PIDs, instances)
SetAffinities()
ToWall()
DetectHiddenWindows, On

Loop, %instances%
{
    McPID := MC_PIDs[A_Index]
    McDir := McDirectories[A_Index]
    Run, scripts\InstanceManager.ahk %McPID% %McDir% %A_Index%, A_ScriptDir\scripts,, IM_PID
    WinWait, ahk_pid %IM_PID%
    IM_PIDs[A_Index] := IM_PID
    if (!SendMessage, MSG_WAIT_LOAD,,,,ahk_pid %IM_PID%,,10000) {
        MsgBox, Something went wrong launching instance managers, rebooting.
        Reboot()
    }
    if (autoBop) {
        cmd := Format("python.exe " . A_ScriptDir . "\scripts\worldBopper9000.py {1}", McDir)
        Run, %cmd%,, Hide
    }
}

file = %A_ScriptDir%/media/ready.wav
Random, pos, 0, 7
wmp := ComObjCreate("WMPlayer.OCX")
wmp.controls.currentPosition := pos
wmp.url := file
Sleep, 1000
wmp.close

Reset(idx := -1) {
    if (idx == -1)
        idx := GetActiveInstanceNum()
    
    locked[idx] := False
    pid := IM_PIDs[idx]
    PostMessage, MSG_RESET,,,,ahk_pid %pid%
    SetAffinities()

    if (GetActiveInstanceNum() == idx) {
        if (bypassWall) {
            ToWallOrNextInstance()
        } else {
            ToWall()
        }
    }
}

Play(idx) {
    locked[idx] := True
    pid := IM_PIDs[idx]
    SendMessage, MSG_PLAY,,,,ahk_pid %pid%,,10000
    Sleep, 50
    if (ErrorLevel == 0) { ; errorlevel is set to 0 if the instance was ready to be played; 1 otherwise
        if (useObsWebsocket) {
            cmd := Format("python.exe " . A_ScriptDir . "\scripts\obs.py 1 {1}", idx)
            Run, %cmd%,, Hide
        } else {
            Send, {Numpad%idx% down}
            Sleep, %obsDelay%
            Send, {Numpad%idx% up}
        }
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

SetTitles() {
    for i, pid in MC_PIDs {
        PostMessage, MSG_SETTITLE,,,,ahk_pid %pid%
    }
}

FreezeAll() {
    Loop, %instances%
    {
        Freeze(A_Index)
    }
}

UnfreezeAll() {
    Loop, %instances%
    {
        Unfreeze(A_Index)
    }
}

Shutdown() {
    UnfreezeAll()
    for each, pid in IM_PIDs {
        cmd := Format("taskkill /f /pid {1}", pid)
        RunHide(cmd)
        WinWaitClose, ahk_pid %pid%
    }
}

Reboot() {
    Shutdown()
    Reload
}

MousePosToInstNumber() {
    MouseGetPos, mX, mY
    return (Floor(mY / instHeight) * cols) + Floor(mX / instWidth) + 1
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
    WinActivate, Fullscreen Projector
    isOnWall := True
    if (useObsWebsocket) {
        cmd := Format("python.exe " . A_ScriptDir . "\scripts\obs.py 0")
        Run, %cmd%,, Hide
    } else {
        Send, {F12 down}
        Sleep, %obsDelay%
        Send, {F12 up}
    }
}

FocusReset(focusInstance) {
    Play(focusInstance)
    Loop, %instances% {
        if (A_Index != focusInstance && !locked[A_Index]) {
            Reset(A_Index)
        }
    }
}

ResetAll() {
    Loop, %instances% {
        if (!locked[A_Index]) {
            Reset(A_Index)
        }
    }
}

ToggleLock(idx) {
    if (locked[idx]) {
        UnlockInstance(idx)
    } else {
        LockInstance(idx)
    }
}

LockInstance(idx) {
    locked[idx] := A_TickCount
    if (lockSounds) {
        SoundPlay, media\lock.wav
    }
}

UnlockInstance(idx) {
    locked[idx] := 0
}

#Include Hotkeys.ahk
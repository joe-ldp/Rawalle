; A Wall-Style Multi-Instance macro for Minecraft
; By Specnr, forked by Ravalle
; v0.4.2

#NoEnv
#SingleInstance Force
SetWorkingDir, %A_ScriptDir%

SetKeyDelay, 0
SetWinDelay, 1
SetTitleMatchMode, 2

#Include Settings.ahk

global instWidth := Floor(A_ScreenWidth / cols)
global instHeight := Floor(A_ScreenHeight / rows)
global isOnWall := True
global locked := []

#Include scripts/MultiFunctions.ahk

if (performanceMethod == "F") {
    UnsuspendAll()
    sleep, %restartDelay%
}
GetAllPIDs(McDirectories, PIDs, instances)
SetTitles()
ToWall()

for i, mcdir in McDirectories {
    idle := mcdir . "idle.tmp"
    if (autoBop) {
        cmd := Format("python.exe " . A_ScriptDir . "\scripts\worldBopper9000.py {1}", mcdir)
        Run, %cmd%,, Hide
    }
    if (!FileExist(idle))
        FileAppend,,%idle%
    pid := PIDs[i]
    if (borderless) {
        WinSet, Style, -0xC40000, ahk_pid %pid%
    }
    if (wideResets) {
        WinRestore, ahk_pid %pid%
        WinMove, ahk_pid %pid%,,0,0,%A_ScreenWidth%,%A_ScreenHeight%
        newHeight := Floor(A_ScreenHeight / 2.5)
        WinMove, ahk_pid %pid%,,0,0,%A_ScreenWidth%,%newHeight%
    }
    UnlockInstance(i)
    WinSet, AlwaysOnTop, Off, ahk_pid %pid%
}

if (affinity) {
    for i, tmppid in PIDs {
        SetAffinity(tmppid, highBitMask)
    }
}

if (!disableTTS)
    ComObjCreate("SAPI.SpVoice").Speak("Ready")

#Persistent
    SetTimer, FreezeInstances, 20
return

FreezeInstances:
    Critical
        if (performanceMethod == "F") {
            Loop, %instances% {
                rIdx := A_Index
                idleCheck := McDirectories[rIdx] . "idle.tmp"
                if (resetIdx[rIdx] && FileExist(idleCheck) && (A_TickCount - resetScriptTime[i]) > scriptBootDelay) {
                    SuspendInstance(PIDs[rIdx])
                    resetScriptTime[i] := 0
                    resetIdx[rIdx] := False
                }
            }
        }
return

MousePosToInstNumber() {
    MouseGetPos, mX, mY
    return (Floor(mY / instHeight) * cols) + Floor(mX / instWidth) + 1
}

Play(idx) {
    locked[idx] := True
    SwitchInstance(idx)
}

Reset(idx := -1) {
    if (idx == -1)
        idx := GetActiveInstanceNum()
    locked[idx] := False
    if (GetActiveInstanceNum() == idx) {
        ExitWorld()
        if (bypassWall) {
            ToWallOrNextInstance()
        } else {
            ToWall()
        }
    }
    ResetInstance(idx)
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

; Focus hovered instance and background reset all other instances
FocusReset(focusInstance) {
    Play(focusInstance)
    loop, %instances% {
        if (A_Index != focusInstance && !locked[A_Index]) {
            Reset(A_Index)
        }
    }
}

; Reset all instances
ResetAll() {
    loop, %instances% {
        if (!locked[A_Index])
            Reset(A_Index)
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
    ;LockInstanceIndicator(idx)
    ;cmd := Format("python.exe obs.py 3 {1}", idx)
    ;Run, %cmd%,, Hide

    if (lockSounds) {
        SoundPlay, A_ScriptDir\..\media\lock.wav
    }
}

UnlockInstance(idx) {
    locked[idx] := 0
    ;LockInstanceIndicator(idx)
    ;cmd := Format("python.exe obs.py 2 {1}", idx)
    ;Run, %cmd%,, Hide
}

#Include Hotkeys.ahk
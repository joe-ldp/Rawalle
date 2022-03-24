; Ravalle's new Multi Instance Macro
; Author: Ravalle / Joe
; v0.5.1-alpha

#NoEnv
#Persistent
#SingleInstance Force
SetWorkingDir, %A_ScriptDir%

SetKeyDelay, 0
SetWinDelay, 1
SetTitleMatchMode, 2

#Include %A_ScriptDir%\Settings.ahk
#Include %A_ScriptDir%\scripts\messages.ahk
#Include %A_ScriptDir%\scripts\functions.ahk
#Include %A_ScriptDir%\scripts\utilities.ahk

global numInstances := 0
global activeInstance := 0
global McDirectories := []
global MC_PIDs := []
global IM_PIDs := []

EnvGet, threadCount, NUMBER_OF_PROCESSORS
global highBitMask := (2 ** threadCount) - 1
global lowBitMask := (2 ** Ceil(threadCount * Min(affinityLevel, 1))) - 1

global instWidth := Floor(A_ScreenWidth / cols)
global instHeight := Floor(A_ScreenHeight / rows)
global isOnWall := True
global locked := []

OnExit("Shutdown")
GetInstances()
SetAffinities()
DetectHiddenWindows, On
FileAppend,, scripts/runPy.tmp

Loop, %numInstances% {
    McPID := MC_PIDs[A_Index]
    McDir := McDirectories[A_Index]
    Run, scripts\InstanceManager.ahk %McPID% %McDir% %A_Index%, A_ScriptDir\scripts,, IM_PID
    WinWait, ahk_pid %IM_PID%
    IM_PIDs[A_Index] := IM_PID
    if (autoBop) {
        cmd := Format("python.exe " . A_ScriptDir . "\scripts\worldBopper9000.py {1}", McDir)
        Run, %cmd%,, Hide
    }
}

Run, scripts\obs.py "%host%" "%port%" "%password%" "%wallScene%" "%mainScene%" "%instanceSourceFormat%" "%lockLayerFormat%" "%numInstances%",, Hide

if (multiMode) {
    NextInstance()
    isOnWall := False
} else {
    ToWall()
}

file = %A_ScriptDir%/media/ready.wav
Random, pos, 0, 7
wmp := ComObjCreate("WMPlayer.OCX")
wmp.controls.currentPosition := pos
wmp.url := file
Sleep, 1000
wmp.close

Reset(idx := -1) {
    idx := idx == -1 ? activeInstance : idx
    pid := IM_PIDs[idx]
    PostMessage, MSG_RESET,,,,ahk_pid %pid%
    UnlockInstance(idx, False)

    if (activeInstance == idx) {
        if (!multiMode) {
            activeInstance := 0
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
    Sleep, 50
    if (ErrorLevel == 0) { ; errorlevel is set to 0 if the instance was ready to be played; 1 otherwise
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

SetTitles() {
    for i, pid in IM_PIDs {
        PostMessage, MSG_SETTITLE,,,,ahk_pid %pid%
    }
}

SoftReboot() {
    for i, pid in IM_PIDs {
        PostMessage, MSG_RELOAD,,,,ahk_pid %pid%
        UnlockInstance(i, False)
    }
    ToWall()
}

Shutdown() {
    FileDelete, scripts/runPy.tmp
    DetectHiddenWindows, On
    UnfreezeAll()
    for each, pid in IM_PIDs {
        SendMessage, MSG_CLOSE,,,,ahk_pid %pid%,,1000 ; 0x0010
        if (ErrorLevel != 0) {
            cmd := Format("taskkill /f /pid {1}", pid)
            RunHide(cmd)
        }
        WinWaitClose, ahk_pid %pid%
    }
}

Reboot() {
    Shutdown()
    Reload
}

#Include Hotkeys.ahk
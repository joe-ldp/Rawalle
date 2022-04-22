; Ravalle's new Multi Instance & Wall Macro
; Author: Ravalle / Joe
; v0.6.0-beta

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

global activeInstance := 0
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
DetectHiddenWindows, On
FileAppend,, scripts/runPy.tmp
enteredScreenshots := A_ScriptDir . "\screenshots\entered"
if (!FileExist(enteredScreenshots))
    FileCreateDir, %enteredScreenshots%
unenteredScreenshots := A_ScriptDir . "\screenshots\unentered"
if (!FileExist(unenteredScreenshots))
    FileCreateDir, %unenteredScreenshots%

for each, program in launchPrograms {
    SplitPath, program, filename, dir
    isOpen := False
    for proc in ComObjGet("winmgmts:").ExecQuery(Format("Select * from Win32_Process where CommandLine like ""%{1}%""", filename))
        isOpen := True
    if (!isOpen)
        Run, %filename%, %dir%
}

Loop, %numInstances% {
    readyFile := A_ScriptDir . "\scripts\IM" . A_Index . "ready.tmp"
    if (FileExist(readyFile))
        FileDelete, %readyFile%
    
    Run, scripts\InstanceManager.ahk %A_Index%, A_ScriptDir\scripts,, IM_PID
    WinWait, ahk_pid %IM_PID%
    IM_PIDs[A_Index] := IM_PID

    openFile := A_ScriptDir . "\scripts\inst" . A_Index . "open.tmp"
    while (!FileExist(openFile))
        Sleep, 100
    FileRead, MC_PID, %openFile%
    MC_PIDs[A_Index] := MC_PID
    while (FileExist(openFile))
        FileDelete, %openFile%
}

if (useObsWebsocket) {
    ErrorLevel := 0
    While, ErrorLevel == 0 {
        Run, scripts\obs.py "%host%" "%port%" "%password%" "%lockLayerFormat%" "%wallScene%" "%instanceSceneFormat%" "%singleScene%" "%playingScene%" "%instanceSourceFormat%" "%numInstances%",, Hide, OBS_PID
        Sleep, 2000
        Process, Exist, %OBS_PID%
    }
}

checkIdx := 1
while (checkIdx <= numInstances) {
    readyFile := A_ScriptDir . "\scripts\IM" . checkIdx . "ready.tmp"
    if (FileExist(readyFile)) {
        while (FileExist(readyFile))
            FileDelete, %readyFile%
        checkIdx++
    }
}

SetAffinities()
if (multiMode) {
    NextInstance()
    isOnWall := False
} else {
    ToWall()
}

if (!disableTTS) {
    file = %A_ScriptDir%/media/ready.wav
    Random, pos, 0, 7
    wmp := ComObjCreate("WMPlayer.OCX")
    wmp.controls.currentPosition := pos
    wmp.url := file
    Sleep, 1000
    wmp.close
}

Reset(idx := -1) {
    idx := idx == -1 ? activeInstance : idx
    IM_PID := IM_PIDs[idx]
    UnlockInstance(idx, False)
    PostMessage, MSG_RESET,,,,ahk_pid %IM_PID%
    CountResets("Attempts")
    CountResets("Daily Attempts")

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

Shutdown() {
    FileDelete, scripts/runPy.tmp
    DetectHiddenWindows, On
    UnfreezeAll()
    for idx, pid in IM_PIDs {
        if (WinExist("ahk_pid " . pid))
            WinClose,,, 1
        if (WinExist("ahk_pid " . pid)) {
            Process, Close, %pid%
            WinWaitClose, ahk_pid %pid%
        }
        openFile := A_ScriptDir . "\scripts\inst" . idx . "open.tmp"
        if (FileExist(openFile))
            FileDelete, %openFile%
        readyFile := A_ScriptDir . "\scripts\IM" . idx . "ready.tmp"
        if (FileExist(readyFile))
            FileDelete, %readyFile%
    }
}

Reboot() {
    Shutdown()
    Reload
}

#Include Hotkeys.ahk
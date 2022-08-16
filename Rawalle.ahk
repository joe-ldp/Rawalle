; Ravalle's Wall & Multi Instance Macro (Rawalle)
; Author: Ravalle / Joe
; v1.2.1

;region imports

#NoEnv
#Persistent
#SingleInstance Force
SetWorkingDir, %A_ScriptDir%

SetKeyDelay, 0
SetWinDelay, 1
SetTitleMatchMode, 2

#Include %A_ScriptDir%\scripts\constants.ahk
#Include %A_ScriptDir%\scripts\functions.ahk
#Include %A_ScriptDir%\scripts\utilities.ahk
global settingsFile := A_ScriptDir . "\settings.ini"

;endregion

;region init

currVersion := 1.21
UrlDownloadToFile, https://raw.githubusercontent.com/joe-ldp/Rawalle/main/versionCheck.ini, versionCheck.ini
IniRead, versionCheck, versionCheck.ini, Check, version
IniRead, versionString, versionCheck.ini, Check, name
IniRead, verCheckSkip, %settingsFile%, Init, verCheckSkip
if (versionCheck > currVersion && verCheckSkip < versionCheck) {
    global downloadTag
    global execute := false
    IniRead, notes, versionCheck.ini, Check, notes, Couldn't fetch patch notes. Oops!
    IniRead, downloadTag, versionCheck.ini, Check, tag
    Gui, New
    Gui, Margin, 10, 10
    Gui, Add, Text,, Hey! A new version of Rawalle is available (%versionString%). Would you like to download it?
    Gui, Add, Text, x10, % StrReplace(notes, "|", "`n")
    Gui, Add, Button, w100 h25 gDownloadLatest, Exit && Download
    Gui, Add, Button, x+10 w80 h25 gSkipVersion, Skip Version
    Gui, Add, Button, x+10 w100 h25 gRemindLater, Remind me later
    Gui, -SysMenu
    Gui, +AlwaysOnTop
    Gui, Show
    Loop, {
        if (execute)
            break
        Sleep, 50
    }
    Gui, Destroy
}
FileDelete, versionCheck.ini

IniRead, firstLaunch, %settingsFile%, Init, firstLaunch
if (firstLaunch) {
    MsgBox, 4,,Hey! It looks like this is your first time launching Rawalle.`nWould you like to configure your settings?
    IfMsgBox Yes
        RunWait, Rawalle Config.exe
    IniWrite, 0, %settingsFile%, Init, firstLaunch
}
LoadSettings(settingsFile)

OnExit("Shutdown")
DetectHiddenWindows, On
if (!FileExist(enteredScreenshots := A_ScriptDir . "\screenshots\entered"))
    FileCreateDir, %enteredScreenshots%
if (!FileExist(unenteredScreenshots := A_ScriptDir . "\screenshots\unentered"))
    FileCreateDir, %unenteredScreenshots%
if (!FileExist(resetsFolder := A_ScriptDir . "\resets"))
    FileCreateDir, %resetsFolder%

;endregion

;region globals

global activeInstance := 0
global MC_PIDs := []
global IM_PIDs := []

EnvGet, threadCount, NUMBER_OF_PROCESSORS
global highThreads := threadCount
global midThreads := Max(Floor(threadCount * 0.8), threadCount - 4)
global lowThreads := Ceil(threadCount * Min(affinityLevel, 1))

global instWidth := Floor(A_ScreenWidth / cols)
global instHeight := Floor(A_ScreenHeight / rows)
global isOnWall := True
global locked := []

EnvGet, userProfileDir, USERPROFILE
global userProfileDir

;endregion

;region startup

Loop, %numInstances% {
    if (FileExist(readyFile := A_ScriptDir . "\scripts\IM" . A_Index . "ready.tmp"))
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

if (autoCloseInstances) {
    Menu, Tray, Add, Exit and Close Instances, Shutdown, 0
}

for each, program in arrLaunchPrograms {
    SplitPath, program, filename, dir
    isOpen := False
    for proc in ComObjGet("winmgmts:").ExecQuery(Format("Select * from Win32_Process where CommandLine like ""%{1}%""", filename)) {
        isOpen := True
        break
    } 
    if (!isOpen)
        Run, %filename%, %dir%
}

if (useObsWebsocket) {
    while (!FileExist(Format("{1}\scripts\runPy.tmp", A_ScriptDir)))
        FileAppend,, %A_ScriptDir%\scripts\runPy.tmp
    Run, %A_ScriptDir%\scripts\obs.py, %A_ScriptDir%\scripts\, Hide
}

checkIdx := 1
while (checkIdx <= numInstances) {
    if (FileExist(readyFile := A_ScriptDir . "\scripts\IM" . checkIdx . "ready.tmp")) {
        while (FileExist(readyFile))
            FileDelete, %readyFile%
        checkIdx++
    }
}

LoadHotkeys()

SetAffinities()
if (mode == "Multi") {
    isOnWall := False
    NextInstance()
} else {
    ToWall()
}

if (readySound) {
    numSounds := 0
    Loop, Files, %A_ScriptDir%/media/ready/*
    {
        numSounds++
    }
    Random, sound, 1, %numSounds%
    SoundPlay, %A_ScriptDir%/media/ready/ready%sound%.wav
}

;endregion

;region funcs

Reset(idx := -1, timestamp := -1) {
    global isOnWall, activeInstance, IM_PIDs, mode, bypassWall
    idx := (idx == -1) ? (isOnWall ? MousePosToInstNumber() : activeInstance) : idx
    timestamp := (timestamp == -1) ? A_TickCount : timestamp
    IM_PID := IM_PIDs[idx]
    UnlockInstance(idx, False)
    PostMessage, MSG_RESET, timestamp,,,ahk_pid %IM_PID%

    if (activeInstance == idx) {
        if (mode == "Wall") {
            ToWall()
        } else {
            NextInstance()
        }
        LogAction(idx, "exitworld")
        FileDelete, %userProfileDir%\sleepbg.lock
    } else {
        LogAction(idx, "reset")
    }
}

Play(idx := -1) {
    Critical
    global IM_PIDs, activeInstance, isOnWall, useObsWebsocket, screenshotWorlds, obsDelay
    idx := (idx == -1) ? MousePosToInstNumber() : idx
    pid := IM_PIDs[idx]
    SendMessage, MSG_SWITCH,,,,ahk_pid %pid%,,1000
    if (ErrorLevel == 0) { ; errorlevel is set to 0 if the instance was ready to be played; 1 otherwise
        SetTimer, BypassWall, Off
        if (useObsWebsocket) {
            SendOBSCommand("Play," . idx)
            if (screenshotWorlds)
                SendOBSCommand("GetImg")
        } else {
            Send, {Numpad%idx% down}
            Sleep, %obsDelay%
            Send, {Numpad%idx% up}
        }
        LogAction(idx, "play")
        LockInstance(idx, False)
        FileAppend,, %userProfileDir%\sleepbg.lock
        activeInstance := idx
        isOnWall := False
        SetAffinities()
        return 0
    } else if (ErrorLevel == STATE_PREVIEWING) {
        LockInstance(idx, False)
        return 1
    }
}

FocusReset(idx := -1) {
    global numInstances, locked
    idx := (idx == -1) ? MousePosToInstNumber() : idx
    timestamp := A_TickCount
    Play(idx)
    Loop, %numInstances%
        if (idx != A_Index && !locked[A_Index])
            Reset(A_Index, timestamp)
}

BackgroundReset(idx) {
    global activeInstance
    if (idx != activeInstance)
        Reset(idx)
}

ResetAll() {
    global numInstances, locked
    timestamp := A_TickCount
    Loop, %numInstances%
        if (!locked[A_Index])
            Reset(A_Index, timestamp)
}

LockInstance(idx := -1, sound := True) {
    global isOnWall, activeInstance, lockSounds, locked, useObsWebsocket, lockIndicators, bypassWall
    idx := (idx == -1) ? (isOnWall ? MousePosToInstNumber() : activeInstance) : idx
    IM_PID := IM_PIDs[idx]
    SendMessage, MSG_GETSTATE,,,,ahk_pid %IM_PID%,,100
    state := ErrorLevel
    if (state == STATE_RESETTING) {
        return
    } else {
        if (lockSounds && sound)
            SoundPlay, media\lock.wav
        if (!locked[idx]) {
            if (useObsWebsocket && lockIndicators)
                SendOBSCommand("Lock," . idx . "," . 1)
            locked[idx] := A_TickCount
            LogAction(idx, "lock")
        }
        PostMessage, MSG_LOCK, locked[idx],,,ahk_pid %IM_PID%
    }
    if (bypassWall && (state == STATE_LOADING || state == STATE_PREVIEWING))
        SetTimer, BypassWall, 100
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
    IM_PID := IM_PIDs[idx]
    PostMessage, MSG_LOCK, locked[idx],,,ahk_pid %IM_PID%
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

FreezeAll() {
    for each, pid in MC_PIDs {
        Freeze(pid)
    }
}

UnfreezeAll() {
    for each, pid in MC_PIDs {
        Unfreeze(pid)
    }
}

SetAffinities() {
    for each, pid in IM_PIDs {
        PostMessage, MSG_AFFINITY,,,,ahk_pid %IM_PID%
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
    global useObsWebsocket, obsDelay, bypassWall, fullscreen, fullscreenDelay
    activeInstance := 0
    isOnWall := True
    if (fullscreen)
        Sleep, %fullscreenDelay%
    if (bypassWall && BypassWall())
        return
    if (useObsWebsocket) {
        SendOBSCommand("ToWall")
    } else {
        Send, {F12 Down}
        Sleep, %obsDelay%
        Send, {F12 Up}
    }
    WinMaximize, Fullscreen Projector
    WinActivate, Fullscreen Projector
}

BypassWall() { ; returns 1 if instance was played
    global locked
    for idx, lockTime in locked {
        if (lockTime)
            if (Play(idx) == 0)
                return 1
    }
}

Shutdown(ExitReason, ExitCode) {
    FileDelete, scripts/runPy.tmp
    DetectHiddenWindows, On
    UnfreezeAll()
    for idx, pid in IM_PIDs {
        if (WinExist("ahk_pid " . pid))
            WinClose,,, 1
        if (WinExist("ahk_pid " . pid))
            Process, Close, %pid%
        WinWaitClose, ahk_pid %pid%
        if (FileExist(openFile := A_ScriptDir . "\scripts\inst" . idx . "open.tmp"))
            FileDelete, %openFile%
        if (FileExist(readyFile := A_ScriptDir . "\scripts\IM" . idx . "ready.tmp"))
            FileDelete, %readyFile%
    }
    if (ExitReason == "Exit and Close Instances") {
        for each, pid in MC_PIDs
            Process, Close, %pid%
        ExitApp
    }
}

Reboot() {
    Shutdown("Reload", 0)
    Reload
}

;endregion

#Include customHotkeys.ahk

;region labels

return

DownloadLatest:
    Run, https://github.com/joe-ldp/Rawalle/releases/%downloadTag%
    ExitApp
return

SkipVersion:
    IniRead, versionCheck, versionCheck.ini, Check, version
    IniWrite, %versionCheck%, %settingsFile%, Init, verCheckSkip
    execute := True
return

RemindLater:
    execute := True
return

;endregion

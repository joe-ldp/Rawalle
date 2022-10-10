; Ravalle's Wall & Multi Instance Macro (Rawalle)
; Author: Ravalle / Joe
; v1.3.0

;region imports

#NoEnv
#Persistent
#SingleInstance Force
SetWorkingDir, %A_ScriptDir%

SetKeyDelay, 0
SetWinDelay, 1
SetTitleMatchMode, 2
DetectHiddenWindows, On

#Include %A_ScriptDir%\scripts\constants.ahk
#Include %A_ScriptDir%\scripts\functions.ahk
#Include %A_ScriptDir%\scripts\utilities.ahk
global settingsFile := Format("{1}\settings.ini", A_ScriptDir)
global hotkeysFile := Format("{1}\hotkeys.ini", A_ScriptDir)

;endregion

;region init

currVersion := 1.3
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

if (!FileExist(resetsFolder := Format("{1}\resets", A_ScriptDir)))
    FileCreateDir, %resetsFolder%
if (!FileExist(logsFolder := Format("{1}\logs", A_ScriptDir)))
    FileCreateDir, %logsFolder%

OnExit("Shutdown")

Menu, Tray, Add, Open Settings, OpenSettings
Menu, Tray, Add, Close Instances, CloseInstances
Menu, Tray, Add, Exit and Close Instances, Shutdown, 0

;endregion

;region globals

global activeInstance := 0
global MC_PIDs := []
global IM_PIDs := []

global instWidth := Floor(A_ScreenWidth / cols)
global instHeight := Floor(A_ScreenHeight / rows)
global isOnWall := True
global locked := []
global numLocked := 0
global projectorID := 0

EnvGet, userProfileDir, USERPROFILE
global userProfileDir

;endregion

;region startup

Loop, %numInstances% {
    if (FileExist(readyFile := Format("{1}\scripts\IM{2}ready.tmp", A_ScriptDir, A_Index)))
        FileDelete, %readyFile%
    
    Run, scripts\InstanceManager.ahk %A_Index%, A_ScriptDir\scripts,, IM_PID
    WinWait, ahk_pid %IM_PID%
    IM_PIDs[A_Index] := IM_PID

    openFile := Format("{1}\scripts\inst{2}open.tmp", A_ScriptDir, A_Index)
    while (!FileExist(openFile))
        Sleep, 100
    FileRead, MC_PID, %openFile%
    MC_PIDs[A_Index] := MC_PID
    while (FileExist(openFile))
        FileDelete, %openFile%
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

if (useObsScript) {
    obsSettingsFile := Format("{1}\scripts\obsSettings.py", A_ScriptDir)
    FileDelete, %obsSettingsFile%
    FileAppend, lock_layer_format     = "%lockLayerFormat%"`n,     %obsSettingsFile%
    FileAppend, wall_scene            = "%wallScene%"`n,           %obsSettingsFile%
    FileAppend, instance_scene_format = "%instanceSceneFormat%"`n, %obsSettingsFile%
    FileAppend, num_instances         = %numInstances%`n,          %obsSettingsFile%
    SendOBSCmd("Reload")
}

checkIdx := 1
while (checkIdx <= numInstances) {
    if (FileExist(readyFile := Format("{1}\scripts\IM{2}ready.tmp", A_ScriptDir, checkIdx))) {
        while (FileExist(readyFile))
            FileDelete, %readyFile%
        checkIdx++
    }
}

LoadHotkeys(hotkeysFile)
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

HandleHotkey(context, func, param := "") {
    boundFunc := Func(func).Bind()
    if (param != "")
        boundFunc := Func(func).Bind(param)
    switch (context)
    {
        case "General":
            boundFunc.Call()
        case "InGame":
            if (WinActive("Minecraft") && (WinActive("ahk_exe javaw.exe") || WinActive("ahk_exe java.exe")))
                boundFunc.Call()
        case "OnWall":
            WinGetPos,,, w, h, A
            if ((WinActive("Full") && WinActive("screen Projector")) || (WinActive("ahk_exe obs64.exe") && w == A_ScreenWidth && h == A_ScreenHeight)) {
                boundFunc.Call()
            }
        default:
            Log("Unknown context: %context% provided. Attempting to match to window title, may cause unexpected behaviour.")
            if (WinActive(context))
                boundFunc.Call()

    }
}

Reset(idx := -1, timestamp := -1) {
    global mode
    idx := (idx == -1) ? (isOnWall ? MousePosToInstNumber() : activeInstance) : idx
    timestamp := (timestamp == -1) ? A_TickCount : timestamp
    IM_PID := IM_PIDs[idx]
    UnlockInstance(idx, False)

    if (activeInstance == idx) {
        FileDelete, %userProfileDir%\sleepbg.lock
        SendMessage, MSG_RESET, timestamp,,,ahk_pid %IM_PID%,,1000
        LogAction(idx, "exitworld")
        if (fullscreen)
            Sleep, %fullscreenDelay%
        if (mode == "Wall") {
            if (bypassWall && BypassWall())
                return
            ToWall()
        } else {
            NextInstance()
        }
    } else {
        PostMessage, MSG_RESET, timestamp,,,ahk_pid %IM_PID%
        LogAction(idx, "reset")
    }
}

Play(idx := -1) {
    Critical
    global useObsScript, obsDelay
    idx := (idx == -1) ? MousePosToInstNumber() : idx
    IM_PID := IM_PIDs[idx]
    SendMessage, MSG_SWITCH,,,,ahk_pid %IM_PID%,,1000
    if (ErrorLevel == 0) { ; errorlevel is set to 0 if the instance was ready to be played; 1 otherwise
        SetTimer, BypassWall, Off
        if (useObsScript) {
            SendOBSCmd("Play," . idx)
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
        if (mode == "Wall") {
            GetProjectorID(projectorID)
            WinMinimize, ahk_id %projectorID%
        }
        return 0
    } else if (ErrorLevel == STATE_PREVIEWING) {
        LockInstance(idx, False)
        return 1
    }
}

FocusReset(idx := -1) {
    global numInstances
    idx := (idx == -1) ? MousePosToInstNumber() : idx
    timestamp := A_TickCount
    Play(idx)
    Loop, %numInstances%
        if (idx != A_Index && !locked[A_Index])
            Reset(A_Index, timestamp)
}

BackgroundReset(idx) {
    if (idx != activeInstance)
        Reset(idx)
}

ResetAll() {
    global numInstances
    timestamp := A_TickCount
    Loop, %numInstances%
        if (!locked[A_Index])
            Reset(A_Index, timestamp)
}

LockInstance(idx := -1, sound := True) {
    global lockSounds, useObsScript, lockIndicators, autoJoinInstances
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
            if (useObsScript && lockIndicators)
                SendOBSCmd(Format("Lock,{1},{2}", idx, 1))
            locked[idx] := A_TickCount
            numLocked++
            LogAction(idx, "lock")
        }
        PostMessage, MSG_LOCK, locked[idx],,,ahk_pid %IM_PID%
    }
    if (autoJoinInstances && state == STATE_PREVIEWING)
        SetTimer, BypassWall, 100
    SetAffinities()
}

UnlockInstance(idx := -1, sound := True) {
    global useObsScript, lockIndicators, lockSounds
    idx := (idx == -1) ? (isOnWall ? MousePosToInstNumber() : activeInstance) : idx
    if (lockSounds && sound)
        SoundPlay, media\unlock.wav
    if (!locked[idx])
        return
    if (useObsScript && lockIndicators)
        SendOBSCmd(Format("Lock,{1},{2}", idx, 0))
    IM_PID := IM_PIDs[idx]
    PostMessage, MSG_LOCK, locked[idx],,,ahk_pid %IM_PID%
    locked[idx] := 0
    numLocked--
    LogAction(idx, "unlock")
    SetAffinities()
}

ToggleLock(idx := -1) {
    idx := (idx == -1) ? (isOnWall ? MousePosToInstNumber() : activeInstance) : idx
    if (locked[idx])
        UnlockInstance(idx)
    else
        LockInstance(idx)
}

WallLock(idx := -1) {
    global lockIndicators, useObsScript
    idx := (idx == -1) ? (isOnWall ? MousePosToInstNumber() : activeInstance) : idx
    if (useObsScript && lockIndicators)
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
    for idx, IM_PID in IM_PIDs {
        isBg := (activeInstance != 0) && (idx != activeInstance)
        PostMessage, MSG_AFFINITY, isBg, numLocked,,ahk_pid %IM_PID%
    }
}

MousePosToInstNumber() {
    global cols
    MouseGetPos, mX, mY
    return (Floor(mY / instHeight) * cols) + Floor(mX / instWidth) + 1
}

NextInstance() {
    global numInstances
    Loop, {
        activeInstance := activeInstance + 1 > numInstances ? 1 : activeInstance + 1
        Play(activeInstance)
        if (ErrorLevel == 0)
            break
    }
}

GetProjectorID(ByRef projID) {
    if (HwndIsFullscreen(projID))
        return
    WinGet, IDs, List, ahk_exe obs64.exe
    Loop %IDs%
    {
        projID := IDs%A_Index%
        if (HwndIsFullscreen(projID))
            return
    }
    projID := -1
    MsgBox, Could not detect OBS Fullscreen Projector window. Will try again at next Wall action. If this persists, contact Rawalle tech support.
}

HwndIsFullscreen(hwnd) { ; ahk_id or ID is HWND
    WinGetPos,,, w, h, ahk_id %hwnd%
    return (w == A_ScreenWidth && h == A_ScreenHeight)
}

ToWall() {
    global useObsScript, obsDelay, bypassWall, fullscreen, fullscreenDelay
    activeInstance := 0
    isOnWall := True
    if (useObsScript) {
        SendOBSCmd("ToWall")
    } else {
        Send, {F12 Down}
        Sleep, %obsDelay%
        Send, {F12 Up}
    }
    GetProjectorID(projectorID)
    WinMaximize, ahk_id %projectorID%
    WinActivate, ahk_id %projectorID%
}

BypassWall() { ; returns 1 if instance was played
    for idx, lockTime in locked {
        if (lockTime)
            if (Play(idx) == 0)
                return 1
    }
}

SendOBSCmd(cmd) {
    static cmdNum := 1
    static cmdDir := Format("{1}\scripts\pyCmds\", A_ScriptDir)
    FileAppend, %cmd%, %cmdDir%%cmdNum%.txt
    cmdNum++
}

LogAction(idx, action) {
    FileAppend, %A_YYYY%-%A_MM%-%A_DD% %A_Hour%:%A_Min%:%A_Sec%`,%idx%`,%action%`n, actions.csv
}

OpenSettings() {
    RunWait, Rawalle Config.exe
    Reboot()
}

CloseInstances() {
    for each, pid in MC_PIDs
        Process, Close, %pid%
}

Shutdown(ExitReason, ExitCode) {
    DetectHiddenWindows, On
    UnfreezeAll()
    for idx, pid in IM_PIDs {
        if (WinExist("ahk_pid " . pid))
            WinClose,,, 1
        if (WinExist("ahk_pid " . pid))
            Process, Close, %pid%
        WinWaitClose, ahk_pid %pid%
        if (FileExist(openFile := Format("{1}\scripts\inst{2}open.tmp", A_ScriptDir, idx)))
            FileDelete, %openFile%
        if (FileExist(readyFile := Format("{1}\scripts\IM{2}ready.tmp", A_ScriptDir, idx)))
            FileDelete, %readyFile%
    }
    if (ExitReason == "Exit and Close Instances") {
        CloseInstances()
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

; Ravalle's new Multi Instance & Wall Macro
; Author: Ravalle / Joe
; v1.2.1

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
LoadSettings()

global activeInstance := 0
global MC_PIDs := []
global IM_PIDs := []

EnvGet, threadCount, NUMBER_OF_PROCESSORS
global highBitMask := (2 ** threadCount) - 1
global midBitMask := (2 ** Max(Floor(threadCount * 0.8), threadCount - 4)) - 1
global lowBitMask := (2 ** Ceil(threadCount * Min(affinityLevel, 1))) - 1

global instWidth := Floor(A_ScreenWidth / cols)
global instHeight := Floor(A_ScreenHeight / rows)
global isOnWall := True
global locked := []

OnExit("Shutdown")
DetectHiddenWindows, On
if (!FileExist(enteredScreenshots := A_ScriptDir . "\screenshots\entered"))
    FileCreateDir, %enteredScreenshots%
if (!FileExist(unenteredScreenshots := A_ScriptDir . "\screenshots\unentered"))
    FileCreateDir, %unenteredScreenshots%
if (!FileExist(resetsFolder := A_ScriptDir . "\resets"))
    FileCreateDir, %resetsFolder%

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
    WinMaximize, Fullscreen Projector
    WinActivate, Fullscreen Projector
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

Shutdown(ExitReason, ExitCode) {
    global IM_PIDs, MC_PIDs
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
        for each, pid in MC_PIDs {
            Process, Close, %pid%
        }
        ExitApp
    }
}

Reboot() {
    Shutdown("Reload", 0)
    Reload
}

#Include customHotkeys.ahk

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
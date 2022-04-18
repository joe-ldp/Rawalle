; Instance Manager for Ravalle's Multi Instance Macro
; Author: Ravalle / Joe
; v0.6.0-beta

#NoEnv
#SingleInstance, Off
SetWorkingDir, %A_ScriptDir%

SetKeyDelay, 0
SetWinDelay, 1

#Include %A_ScriptDir%/messages.ahk
#Include %A_ScriptDir%/../Settings-Joe.ahk

global STATE_INIT       := 0
global STATE_READY      := 1
global STATE_PLAYING    := 2
global STATE_RESETTING  := 3
global STATE_PREVIEWING := 4

global idx := A_Args[1]
global pid := 0
global options := []
global frozen := False
global logFileSize := 0
global percentLoaded := 0
global currentWorldEntered := False
global currentState := STATE_INIT
global instName := StrReplace(multiMCNameFormat, "#", idx)
global instDir := multiMCLocation . "\instances\" . instName
global mcDir := instDir . "\.minecraft\"

I_Icon = ../media/IM.ico
if (FileExist(I_Icon))
    Menu, Tray, Icon, %I_Icon%
Menu, Tray, Tip, Instance %idx% Manager

if (autoBop) {
    cmd := Format("python.exe " . A_ScriptDir . "\worldBopper9000.py {1}", mcDir)
    Run, %cmd%,, Hide
}

if (!pid := IsInstanceOpen()) {
    centralModsDir := A_ScriptDir . "\..\mods\"
    instModsDir := mcDir . "mods\"
    if (syncMods && DesyncedMods(centralModsDir . "*", instModsDir . "*")) {
        Loop, Files, %instModsDir%*
        {
            FileDelete, %A_LoopFileLongPath%
        }
        FileCopyDir, %centralModsDir%, %instModsDir%, 1
    }
    Run, %multiMCLocation%\MultiMC.exe -l "%instName%"
    while (!pid := IsInstanceOpen())
        Sleep, 500
    WinActivate, ahk_pid %pid%
    FileAppend, %pid%, inst%idx%open.tmp
    wait := 12000 + (idx * 1500)
    Sleep, %wait%
} else {
    FileAppend, %pid%, inst%idx%open.tmp
    ; if (options.fullscreen) {
    ;     fs := options["key_key.fullscreen"]
    ;     ControlSend,, {Blind}{%fs%}, ahk_pid %pid%
    ;     Sleep, %fullscreenDelay%
    ; }
}

OnMessage(MSG_RESET, "Reset")
OnMessage(MSG_SWITCH, "Switch")
OnMessage(MSG_SETTITLE, "SetTitle")
OnMessage(MSG_REVEAL, "Reveal")

SetTitle()
GetSettings()
LogFileSize()

if (multiMode)
    wideResets := False
if (wideResets) {
    Widen()
} else {
    WinMaximize, ahk_pid %pid%
}
if (borderless) {
    WinSet, Style, -0xC40000, ahk_pid %pid%
} else {
    WinSet, Style, +0xC40000, ahk_pid %pid%
}

FileAppend,, IM%idx%ready.tmp

Reveal() {
    ToolTip, `%: %percentLoaded% state: %currentState%
}

Reset(force := False) {
    if (currentState == STATE_RESETTING) {
        return
    } else {
        CurrentWorldEntered()
        LogFileSize()
        percentLoaded := 0
        if (!force) {
            Log("Resetting")
            if (currentState == STATE_PLAYING) {
                if (!multiMode)
                    WinMaximize, Fullscreen Projector
                if (useObsWebsocket && screenshotWorlds)
                    SendOBSCommand("SaveImg," . A_NowUTC . "," . currentWorldEntered)
            }
            if (instanceFreezing && frozen)
                Unfreeze()
            if (resetSounds)
                SoundPlay, %A_ScriptDir%\..\media\reset.wav
            GetSettings()
            if (fullscreen && options.fullscreen == "true") {
                fs := options["key_key.fullscreen"]
                ControlSend,, {Blind}{%fs%}, ahk_pid %pid%
                Sleep, %fullscreenDelay%
            }
            
            switch currentState
            {
                case STATE_READY:
                    ControlSend,, {Blind}{Esc 2}{Tab 9}{Enter}, ahk_pid %pid%
                case STATE_PREVIEWING:
                    lp := options["key_LeavePreview"]
                    ControlSend,, {Blind}{%lp%}, ahk_pid %pid%
                case STATE_PLAYING:
                    if (wideResets)
                        Widen()
                    Sleep, %settingsDelay%
                    ResetSettings()
                    ControlSend,, {Blind}{Esc}{Shift down}{Tab}{Shift up}{Enter}, ahk_pid %pid%
                default:
                    ControlSend,, {Blind}/, ahk_pid %pid%
                    Sleep, 120
                    ControlSend,, {Blind}{Esc 2}{Shift down}{Tab}{Shift up}{Enter}, ahk_pid %pid%
            }
        } else {
            Log("Found failed reset. Forcing reset")
            lp := options["key_LeavePreview"]
            ControlSend,, {Blind}{%lp%}, ahk_pid %pid%
            ControlSend,, {Blind}/, ahk_pid %pid%
            Sleep, 120
            ControlSend,, {Blind}{Esc 2}{Tab 9}{Enter}/, ahk_pid %pid%
            Sleep, 120
            ControlSend,, {Blind}{Esc 2}{Tab 8}{Enter}, ahk_pid %pid%
        }
    }
    if (currentState == STATE_PREVIEWING) {
        SetTimer, CheckReset, -300
    } else {
        SetTimer, CheckReset, -1250
    }
    currentState := STATE_RESETTING
    SetTimer, ManageState, 250
    return
}

Switch() {
    if ((currentState != STATE_RESETTING && (multiMode || currentState != STATE_PREVIEWING))) { ; || (currentState == STATE_PREVIEWING && percentLoaded >= 70)) {
        Log("Switched to instance")

        if (useObsWebsocket) {
            SendOBSCommand(Format("Play,{1}", idx))
            if (screenshotWorlds)
                SendOBSCommand("GetImg")
        } else {
            Send, {Numpad%idx% down}
            Sleep, %obsDelay%
            Send, {Numpad%idx% up}
        }

        WinActivate, ahk_pid %pid%
        if (!multiMode)
            WinMinimize, Fullscreen Projector
        if (wideResets)
            WinMaximize, ahk_pid %pid%
        if (fullscreen) {
            ControlSend,, {Blind}{F11}, ahk_pid %pid%
            Sleep, %fullScreenDelay%
        }

        Send, {LButton}
        if (currentState == STATE_READY || currentState == STATE_INIT)
            Play()

        return 0
    } else {
        return -1
    }
}

Play() {
    if (instanceFreezing)
        Unfreeze()
    if (unpauseOnSwitch || coopResets)
        ControlSend,, {Blind}{Esc}, ahk_pid %pid%
    if (coopResets) {
        Sleep, 50
        ControlSend,, {Blind}{Esc}{Tab 7}{Enter}{Tab 5}{Enter}, ahk_pid %pid%
        if (!unpauseOnSwitch)
            ControlSend,, {Blind}{Esc}, ahk_pid %pid%
    }
    
    Log("Playing")
    currentState := STATE_PLAYING
}

Freeze() {
    if (currentState == STATE_READY && frozen == False) {
        pid = %pid%
        hProcess := DllCall("OpenProcess", "UInt", 0x1F0FFF, "Int", 0, "Int", pid)
        If (hProcess) {
            DllCall("ntdll.dll\NtSuspendProcess", "Int", hProcess)
            DllCall("CloseHandle", "Int", hProcess)
        }
        Log("Freezing")

        ; hProcess := DllCall("OpenProcess", "UInt", 0x001F0FFF, "Int", 0, "Int", pid)
        ; DllCall("SetProcessWorkingSetSize", "UInt", hProcess, "Int", -1, "Int", -1)
        ; DllCall("CloseHandle", "Int", hProcess)
        ; Log("Freeing memory")

        ; Freeing memory is disabled by default, as it doesn't achieve much except more unfreezing lag.
        ; It can in theory let you run more than the max # of instances your ram can handle, but this macro doesn't support that anyway.
        ; You can uncomment these lines to enable it if you want.

        frozen := True
    }
}

Unfreeze() {
    hProcess := DllCall("OpenProcess", "UInt", 0x1F0FFF, "Int", 0, "Int", pid)
    If (hProcess) {
        DllCall("ntdll.dll\NtResumeProcess", "Int", hProcess)
        DllCall("CloseHandle", "Int", hProcess)
        Sleep, %resumeDelay%
    }
    Log("Unfreezing")
    frozen := False
}

SetAffinity() {
    mask := (currentState == STATE_PLAYING) ? highBitMask : lowBitMask
    hProc := DllCall("OpenProcess", "UInt", 0x0200, "Int", false, "UInt", pid, "Ptr")
    DllCall("SetProcessAffinityMask", "Ptr", hProc, "Ptr", mask)
    DllCall("CloseHandle", "Ptr", hProc)
}

ResetSettings() {
    GetSettings()
    fovPresses := (110 - FOV) * 143 / 80
    renderPresses := (32 - renderDistance) * 143 / 30
    entityPresses := (5 - entityDistance) * 143 / 4.5
    SetKeyDelay, 0
    if (FOV != (options.fov * 40 + 70) || renderDistance != options.renderDistance || entityDistance != options.entityDistanceScaling) {
        ControlSend,, {Blind}{Esc}{Tab 6}{Enter}{Tab}, ahk_pid %pid%
        if (FOV != currentFOV) {
            SetKeyDelay, 0
            ControlSend,, {Blind}{Right 143}, ahk_pid %pid%
            ControlSend,, {Blind}{Left %fovPresses%}, ahk_pid %pid%
            SetKeyDelay, 1
        }
        ControlSend,, {Blind}{Tab 5}{Enter}{RShift down}P{RShift up}{Tab 4}, ahk_pid %pid%
        if (renderDistance != currentRenderDistance) {
            SetKeyDelay, 0
            ControlSend,, {Blind}{Right 143}, ahk_pid %pid%
            ControlSend,, {Blind}{Left %renderPresses%}, ahk_pid %pid%
            SetKeyDelay, 1
        }
        if (entityDistance != currentEntityDistance) {
            ControlSend,, {Blind}{Tab 13}, ahk_pid %pid%
            SetKeyDelay, 0
            ControlSend,, {Blind}{Right 143}, ahk_pid %pid%
            ControlSend,, {Blind}{Left %entityPresses%}, ahk_pid %pid%
        }
        ControlSend,, {Blind}{Esc 2}, ahk_pid %pid%
    }
}

GetSettings() {
    Loop, Read, %mcDir%/options.txt
    {
        line = %A_LoopReadLine%
        kv := StrSplit(line, ":")
        if (kv.MaxIndex() == 2) {
            key = % kv[1]
            value = % kv[2]
            StringReplace, key, key, %A_Space%,, All
            StringReplace, value, value, %A_Space%,, All
            if (InStr(value, "key.keyboard.")) {
                split := StrSplit(value, "key.keyboard.")
                StringUpper, value, % split[2]
            }
            options[key] := value
        }
    }
}

GetLogLines(offset := 16) {
    logFile := FileOpen(mcDir . "logs/latest.log", "r")
    logFile.Position := logFileSize
    Loop, %offset%
        logFile.ReadLine()
    log := logFile.Read()
    Loop, Parse, log, "`n"
    {
        line = %A_LoopField%
        if(RegExMatch(line, "(?P<Loaded>[0-9]+)(?:\%)", pcnt))
            percentLoaded := pcntLoaded
    }
    logFile.Close()
    return log
}

LogFileSize() {
    logFile := FileOpen(mcDir . "logs/latest.log", "r")
    logFileSize := logFile.Length()
    logFile.Close()
}

SetTitle() {
    WinSetTitle, ahk_pid %pid%,, Minecraft* - Instance %idx%
}

global cmdNum := 1
SendOBSCommand(cmd) {
    cmdDir := A_ScriptDir . "\pyCmds\"
    cmdFile := cmdDir . "IM" . idx . "CMD" . cmdNum . ".txt"
    cmdNum++
    FileAppend, %cmd%, %cmdFile%
}

CurrentWorldEntered() {
    log := GetLogLines()
    currentWorldEntered := InStr(log, "We Need To Go Deeper")
}

Widen() {
    newHeight := Floor(A_ScreenHeight / 2.5)
    WinMaximize, ahk_pid %pid%
    WinRestore, ahk_pid %pid%
    Sleep, 200
    WinMove, ahk_pid %pid%,, 0, 0, %A_ScreenWidth%, %newHeight%
}

IsInstanceOpen() {
    for proc in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process where ExecutablePath like ""%jdk%javaw.exe%""") {
        cmdLine := proc.Commandline
        if(RegExMatch(cmdLine, "-Djava\.library\.path=(?P<Dir>[^\""]+?)(?:\/|\\)natives", thisInst)) {
            thisInstDir := StrReplace(thisInstDir, "/", "\")
            if (instDir == thisInstDir)
                return proc.ProcessId
        }
    }
    return False
}

DesyncedMods(dir1, dir2) {
    centralMods := []
    Loop, Files, %dir1%
    {
        centralMods[A_Index] := A_LoopFileName
    }
    anyInstMods := False
    Loop, Files, %dir2%
    {
        anyInstMods := True
        if (A_LoopFileName != centralMods[A_Index])
            return True
    }
    if (centralMods.Length > 0 && !anyInstMods)
        return True
    return False
}

Log(message) {
    FileAppend, [%A_YYYY%-%A_MM%-%A_DD% %A_Hour%:%A_Min%:%A_Sec%] | Current state: %currentState% | %message%`n, %mcDir%log.log
}

return ; end the auto-execute section so the labels don't get executed when the script opens (thanks ahk)

ManageState:
    SetTimer, ManageState, Off
    resetMsg := DllCall("PeekMessage", "UInt*", message, "UInt", 0, "UInt", MSG_RESET, "UInt", MSG_RESET, "UInt", 0)
    if (!(currentState == STATE_PREVIEWING && resetMsg)) {
        log := GetLogLines()
        if (currentState == STATE_RESETTING && InStr(log, "Starting Preview")) {
            Critical, On
            ;Log(log)
            Log("Found preview")
            currentState := STATE_PREVIEWING
            ControlSend,, {Blind}{F3 Down}{Esc}{F3 Up}, ahk_pid %pid%
            if (!multiMode)
                SetTimer, UpdatePreview, -2000
            SetTimer, ManageState, 250
            Critical, Off
            return

        } else if ((currentState == STATE_RESETTING || currentState == STATE_PREVIEWING) && InStr(log, "/minecraft:the_end") && InStr(log, "advancements")) {
            Critical, On
            WinGet, activePID, PID, A
            ;Log(log)
            if (activePID != pid) {
                Sleep, %beforePauseDelay%
                ControlSend,, {Blind}{F3 Down}{Esc}{F3 Up}, ahk_pid %pid%
                Log("World generated, paused")
                currentState := STATE_READY
                if (instanceFreezing) {
                    Frz := Func("Freeze").Bind()
                    bfd := 0 - beforeFreezeDelay
                    SetTimer, %Frz%, %bfd%
                }
                SetTimer, ManageState, Off
                Critical, Off
                return

            } else {
                Log("World generated, playing")
                Play()
                SetTimer, ManageState, Off
                Critical, Off
                return
            }
        }
    }
    SetTimer, ManageState, 250
return

UpdatePreview:
    if (currentState == STATE_PREVIEWING) {
        fp := options.key_FreezePreview
        ControlSend,, {Blind}{%fp%}, ahk_pid %pid%
        Sleep, 1200
        ControlSend,, {Blind}{%fp%}, ahk_pid %pid%
        Sleep, 300
        ControlSend,, {Blind}{%fp%}, ahk_pid %pid%
    }
return

CheckReset:
    logFile := FileOpen(mcDir . "logs/latest.log", "r")
    newLogFileSize := logFile.Length()
    logFile.Close()
    log := GetLogLines(0)
    if (!InStr(log, "Initializing") && (logFileSize == newLogFileSize || !InStr(log, "Stopping server"))) {
        currentState := STATE_INIT
        Reset(True)
    }
return

; CheckPause:
;     if (currentState == STATE_READY) {
;         if (instanceFreezing)
;             Unfreeze()
;         log := GetLogLines()
;         StrReplace(log, "Saving and pausing game",, count) ; get appearances of "Saving and pausing game" in log for this world
;         if (count == 1) {
;             Log(log)
;             Log("Found failed pause. Trying to pause again")
;             ControlSend,, {Blind}{F3 Down}{Esc}{F3 Up}, ahk_pid %pid%
;             SetTimer, CheckPause, -5000
;         }
;         if (instanceFreezing)
;             Freeze()
;     }
; return
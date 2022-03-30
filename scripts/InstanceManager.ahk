; Instance Manager for Ravalle's Multi Instance Macro
; Author: Ravalle / Joe
; v0.5.1-alpha

#NoEnv
#SingleInstance, Off
SetWorkingDir, %A_ScriptDir%

SetKeyDelay, 0
SetWinDelay, 1

#Include %A_ScriptDir%/messages.ahk
#Include %A_ScriptDir%/../Settings.ahk

OnMessage(MSG_RESET, "Reset")
OnMessage(MSG_SWITCH, "Switch")
OnMessage(MSG_SETTITLE, "SetTitle")
OnMessage(MSG_CLOSE, "Close")
OnMessage(MSG_REVEAL, "Reveal")
OnMessage(MSG_RELOAD, "Reload")

global STATE_INIT       := 0 ; Unknown
global STATE_READY      := 1 ; World fully loaded, game paused
global STATE_PLAYING    := 2 ; Playing. May be paused/in an inventory/etc
global STATE_RESETTING  := 3 ; Undergoing settings changes, widening, or on saving/loading screen
global STATE_PREVIEWING := 4 ; On preview screen

global 1
global 2
global 3
global options := []
global frozen := False
global lastLogLine := 0
global percentLoaded := 0
global currentWorldDir := ""
global currentWorldEntered := False
global currentState := STATE_INIT

I_Icon = ../media/IM.ico
if (FileExist(I_Icon))
    Menu, Tray, Icon, %I_Icon%
Menu, Tray, Tip, Instance %3% Manager

SetTitle()
GetSettings()
LastLogLine()

; if (options.fullscreen) {
;     fs := options["key_key.fullscreen"]
;     ControlSend,, {Blind}{%fs%}, ahk_pid %1%
;     Sleep, %fullscreenDelay%
; }
if (multiMode)
    wideResets := False
if (wideResets) {
    Widen()
} else {
    WinMaximize, ahk_pid %1%
}
if (borderless) {
    WinSet, Style, -0xC40000, ahk_pid %1%
} else {
    WinSet, Style, +0xC40000, ahk_pid %1%
}

Reveal() {
    ToolTip, `%: %percentLoaded% state: %currentState%
}

Reset(force := False) {
    if (currentState == STATE_RESETTING) {
        return
    } else {
        CurrentWorldEntered()
        LastLogLine()
        if (!force) {
            Log("Resetting")
            if (useObsWebsocket && currentState == STATE_PLAYING) {
                if (!multiMode)
                    SendOBSCommand("ToWall")
                if (screenshotWorlds && currentState == STATE_PLAYING)
                    SendOBSCommand("SaveImg," . A_NowUTC . "," . currentWorldEntered)
            }
            if (instanceFreezing && frozen)
                Unfreeze()
            if (resetSounds)
                SoundPlay, %A_ScriptDir%\..\media\reset.wav
            
            switch currentState
            {
                case STATE_READY:
                    ControlSend,, {Blind}{Esc 2}{Tab 9}{Enter}, ahk_pid %1%
                case STATE_PREVIEWING:
                    lp := options.key_LeavePreview
                    ControlSend,, {Blind}{%lp%}, ahk_pid %1%
                case STATE_PLAYING:
                    if (fullscreen)
                        ControlSend,, {Blind}{F11}, ahk_pid %1%
                    if (wideResets)
                        Widen()
                    ResetSettings()
                    ControlSend,, {Blind}{Esc}{Shift down}{Tab}{Shift up}{Enter}, ahk_pid %1%
                case STATE_INIT:
                    ControlSend,, {Blind}/, ahk_pid %1%
                    Sleep, 120
                    ControlSend,, {Blind}{Esc 2}{Shift down}{Tab}{Shift up}{Enter}, ahk_pid %1%
            }
        } else {
            Log("Found failed reset. Forcing reset")
            lp := options["key_LeavePreview"]
            ControlSend,, {Blind}{%lp%}, ahk_pid %1%
            ControlSend,, {Blind}/, ahk_pid %1%
            Sleep, 120
            ControlSend,, {Blind}{Esc 2}{Tab 9}{Enter}/, ahk_pid %1%
            Sleep, 120
            ControlSend,, {Blind}{Esc 2}{Tab 8}{Enter}, ahk_pid %1%
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
            idx = %3%
            SendOBSCommand("Play," . idx)
            if (screenshotWorlds)
                SendOBSCommand("GetImg")
        } else {
            Send, {Numpad%3% down}
            Sleep, %obsDelay%
            Send, {Numpad%3% up}
        }

        WinActivate, ahk_pid %1%
        if (!multiMode)
            WinMinimize, Fullscreen Projector
        if (wideResets)
            WinMaximize, ahk_pid %1%
        if (fullscreen) {
            ControlSend,, {Blind}{F11}, ahk_pid %1%
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
    if (instanceFreezing && frozen)
        Unfreeze()
    if ((unpauseOnSwitch || coopResets) && (currentState == STATE_READY || currentState == STATE_INIT))
        ControlSend,, {Blind}{Esc}, ahk_pid %1%
    if (coopResets) {
        Sleep, 50
        ControlSend,, {Blind}{Esc}{Tab 7}{Enter}{Tab 5}{Enter}, ahk_pid %1%
        if (unpauseOnSwitch)
            ControlSend,, {Blind}{Esc}, ahk_pid %1%
    }
    
    Log("Playing")
    currentState := STATE_PLAYING
}

Freeze() {
    if (currentState == STATE_READY && frozen == False) {
        pid = %1%
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
        ; You can uncomment these lines to enable it if you want.

        frozen := True
    }
}

Unfreeze() {
    pid = %1%
    hProcess := DllCall("OpenProcess", "UInt", 0x1F0FFF, "Int", 0, "Int", pid)
    If (hProcess) {
        DllCall("ntdll.dll\NtResumeProcess", "Int", hProcess)
        DllCall("CloseHandle", "Int", hProcess)
        Sleep, %resumeDelay%
    }
    Log("Unfreezing")
    frozen := False
}

ResetSettings() {
    GetSettings()
    fovPresses := (110 - FOV) * 143 / 80
    renderPresses := (32 - renderDistance) * 143 / 30
    entityPresses := (5 - entityDistance) * 143 / 4.5
    SetKeyDelay, 1
    if (FOV != (options.fov * 40 + 70) || renderDistance != options.renderDistance || entityDistance != options.entityDistanceScaling) {
        ControlSend,, {Blind}{Esc}{Tab 6}{Enter}{Tab}, ahk_pid %1%
        if (FOV != currentFOV) {
            SetKeyDelay, 0
            ControlSend,, {Blind}{Right 143}, ahk_pid %1%
            ControlSend,, {Blind}{Left %fovPresses%}, ahk_pid %1%
            SetKeyDelay, 1
        }
        ControlSend,, {Blind}{Tab 5}{Enter}{RShift down}P{RShift up}{Tab 4}, ahk_pid %1%
        if (renderDistance != currentRenderDistance) {
            SetKeyDelay, 0
            ControlSend,, {Blind}{Right 143}, ahk_pid %1%
            ControlSend,, {Blind}{Left %renderPresses%}, ahk_pid %1%
            SetKeyDelay, 1
        }
        if (entityDistance != currentEntityDistance) {
            ControlSend,, {Blind}{Tab 13}, ahk_pid %1%
            SetKeyDelay, 0
            ControlSend,, {Blind}{Right 143}, ahk_pid %1%
            ControlSend,, {Blind}{Left %entityPresses%}, ahk_pid %1%
            ControlSend,, {Blind}{Esc}, ahk_pid %1%
        }
        ControlSend,, {Blind}{Esc}, ahk_pid %1%
    }
    SetKeyDelay, 0
}

SetTitle() {
    WinSetTitle, ahk_pid %1%,, Minecraft* - Instance %3%
}

GetLogLines(offset := 16) {
    out := ""
    Loop Read, %2%logs/latest.log
    {
        line := A_LoopReadLine
        if (A_Index > lastLogLine + offset)
            out := % out . line . "`n"
        RegExMatch(line, "[0-9]+%", percentLoaded)
    }
    StringTrimRight, percentLoaded, percentLoaded, 1
    return out
}

LastLogLine() {
    Loop, Read, %2%logs/latest.log
    {
        lastLogLine := A_Index
    }
}

GetSettings() {
    Loop, Read, %2%options.txt
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

global cmdNum := 1
SendOBSCommand(cmd) {
    idx = %3%
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
    if (multiMode)
        return
    newHeight := Floor(A_ScreenHeight / 2.5)
    WinMaximize, ahk_pid %1%
    WinRestore, ahk_pid %1%
    Sleep, 200
    WinMove, ahk_pid %1%,, 0, 0, %A_ScreenWidth%, %newHeight%
}

Log(message) {
    FileAppend, [%A_YYYY%-%A_MM%-%A_DD% %A_Hour%:%A_Min%:%A_Sec%] | Current state: %currentState% | %message%`n, %2%log.log
    FileAppend, [%A_YYYY%-%A_MM%-%A_DD% %A_Hour%:%A_Min%:%A_Sec%] | Instance %3% | Current state: %currentState% | %message%`n, log.log
}

Reload() {
    if (instanceFreezing)
        Unfreeze()
    global lastLogLine := 0
    global percentLoaded := 0
    global currentWorldEntered := False
    global currentState := STATE_INIT
    SetTitle()
    LastLogLine()
}

Close() {
    ExitApp
}

return ; end the auto-execute section so the labels don't get executed when the script opens (thanks ahk)

ManageState:
    SetTimer, ManageState, Off
    resetMsg := DllCall("PeekMessage", "UInt*", message, "UInt", 0, "UInt", MSG_RESET, "UInt", MSG_RESET, "UInt", 0)
    if (!(currentState == STATE_PREVIEWING && resetMsg)) {
        log := GetLogLines()
        if (currentState == STATE_RESETTING && InStr(log, "Starting Preview")) {
            ;Log(log)
            Log("Found preview")
            currentState := STATE_PREVIEWING
            Sleep, 50
            ControlSend,, {Blind}{F3 Down}{Esc}{F3 Up}, ahk_pid %1%
            if (!multiMode)
                SetTimer, UpdatePreview, -2000
            SetTimer, ManageState, 250
            return

        } else if ((currentState == STATE_RESETTING || currentState == STATE_PREVIEWING) && InStr(log, "Saving chunks for") && InStr(log, "/minecraft:the_end")) {
            WinGet, activePID, PID, A
            pid = %1%
            ;Log(log)
            if (activePID != pid) {
                Sleep, %beforePauseDelay%
                ControlSend,, {Blind}{F3 Down}{Esc}{F3 Up}, ahk_pid %1%
                Log("World generated, paused")
                currentState := STATE_READY
                if (instanceFreezing) {
                    Frz := Func("Freeze").Bind()
                    bfd := 0 - beforeFreezeDelay
                    SetTimer, %Frz%, %bfd%
                }
                SetTimer, ManageState, Off
                return

            } else {
                Log("World generated, playing")
                Play()
                SetTimer, ManageState, Off
                return
            }
        }
    }
    SetTimer, ManageState, 250
return

UpdatePreview:
    if (currentState == STATE_PREVIEWING) {
        fp := options.key_FreezePreview
        ControlSend,, {Blind}{%fp%}, ahk_pid %1%
        Sleep, 1200
        ControlSend,, {Blind}{%fp%}, ahk_pid %1%
        Sleep, 300
        ControlSend,, {Blind}{%fp%}, ahk_pid %1%
    }
return

CheckReset:
    newLastLogLine := 0
    Loop, Read, %2%logs/latest.log
    {
        newLastLogLine := A_Index
    }
    log := GetLogLines(0)
    if (!InStr(log, "Initializing") && (lastLogLine == newLastLogLine || !InStr(log, "Stopping server"))) {
        currentState := STATE_INIT
        Reset(True)
    } ;else { ; confirmed successful reset
        ;if (screenshotWorlds)
        ;    SaveScreenshot()
    ;}
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
;             ControlSend,, {Blind}{F3 Down}{Esc}{F3 Up}, ahk_pid %1%
;             SetTimer, CheckPause, -5000
;         }
;         if (instanceFreezing)
;             Freeze()
;     }
; return
; Instance Manager for Ravalle's Multi Instance Macros
; Author: Ravalle / Joe
; v0.5.0-alpha

#NoEnv
#SingleInstance, Off
SetWorkingDir, %A_ScriptDir%

SetKeyDelay, 0
SetWinDelay, 1

#include %A_ScriptDir%/states.ahk
#include %A_ScriptDir%/messages.ahk
#Include %A_ScriptDir%/../Settings.ahk

OnMessage(MSG_RESET, "Reset")
OnMessage(MSG_PLAY, "Play")
OnMessage(MSG_FREEZE, "Freeze")
OnMessage(MSG_UNFREEZE, "Unfreeze")
OnMessage(MSG_SETTITLE, "SetTitle")
OnMessage(MSG_WAIT_LOAD, "WaitForLoad")

global ready := False
global 1
global 2
global 3
global options := []
global frozen := False
global lastLogLine := 0
global currentState := STATE_INIT

I_Icon = ../media/IM.ico
IfExist, %I_Icon%
    Menu, Tray, Icon, %I_Icon%
Menu, Tray, Tip, Instance %3% Manager

SetTitle()
GetSettings()

if (borderless)
    WinSet, Style, -0xC40000, ahk_pid %1%
if (wideResets)
    Widen()

ready := True

WaitForLoad() {
    while (!ready) {
    }
    return ready
}

Reset(force := False) {
    if (currentState == STATE_RESETTING) {
        return
    } else {
        GetEndOfLog()
        if (!force) {
            Log("Resetting")
            if (instanceFreezing && frozen)
                Unfreeze()
            if (resetSounds)
                SoundPlay, %A_ScriptDir%\..\media\reset.wav

            if (currentState == STATE_READY) {
                ControlSend,, {Blind}{Esc 2}{Tab 9}{Enter}, ahk_pid %1%

            } else if (currentState == STATE_PREVIEWING) {
                lp := options.key_LeavePreview
                ControlSend,, {Blind}{%lp%}, ahk_pid %1%

            } else if (currentState == STATE_PLAYING) {
                if (fullscreen) {
                    Send, {F11}
                    Sleep, fullScreenDelay
                }
                if (wideResets)
                    Widen()
                ResetSettings()

                ControlSend,, {Blind}{Esc}{Shift down}{Tab}{Shift up}{Enter}, ahk_pid %1%

            } else if (currentState == STATE_INIT) {
                ControlSend,, {Blind}/, ahk_pid %1%
                Sleep, 120
                ControlSend,, {Blind}{Esc 2}{Shift down}{Tab}{Shift up}{Enter}, ahk_pid %1%
            }
        } else {
            Log("Found failed reset. Forcing reset")
            lp := options.key_LeavePreview
            ControlSend,, {Blind}{%lp%}, ahk_pid %1%
            ControlSend,, {Blind}/, ahk_pid %1%
            Sleep, 120
            ControlSend,, {Blind}{Esc 2}{Tab 9}{Enter}, ahk_pid %1%
            ControlSend,, {Blind}/, ahk_pid %1%
            Sleep, 120
            ControlSend,, {Blind}{Esc 2}{Tab 8}{Enter}, ahk_pid %1%
        }
    }
    currentState := STATE_RESETTING
    SetTimer, ManageState, 250
    SetTimer, ForceReset, -1250
    return
}

Play() {
    if (currentState != STATE_RESETTING && currentState != STATE_PREVIEWING) {
        Log("Playing")
        currentState := STATE_PLAYING

        if (instanceFreezing && frozen)
            Unfreeze()
        if (unpauseOnSwitch || coopResets)
            ControlSend,, {Blind}{Esc}, ahk_pid %1%
        if (coopResets) {
            Sleep, 50
            ControlSend,, {Blind}{Esc}{Tab 7}{Enter}{Tab 5}{Enter}, ahk_pid %1%
            if (unpauseOnSwitch)
                ControlSend,, {Blind}{Esc}, ahk_pid %1%
        }

        WinSet, AlwaysOnTop, On, ahk_pid %1%
        WinSet, AlwaysOnTop, Off, ahk_pid %1%
        WinRestore, ahk_pid %1%
        WinMinimize, Fullscreen Projector

        if (wideResets)
            WinMaximize, ahk_pid %1%
        if (fullscreen) {
            ControlSend,, {Blind}{F11}, ahk_pid %1%
            Sleep, fullScreenDelay
        }

        Sleep, 100
        Send, {LButton}
        return 0
    } else {
        return 1
    }
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
        Sleep, resumeDelay
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
        if (A_Index > lastLogLine + offset) {
            out := % out . A_LoopReadLine . "`n"
            i := Mod(i+nLines-1,nLines)
        }
    }
    return out
}

GetEndOfLog() {
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

Widen() {
    newHeight := Floor(A_ScreenHeight / 2.5)
    WinMaximize, ahk_pid %1%
    WinRestore, ahk_pid %1%
    Sleep, 200
    WinMove, ahk_pid %1%,,0,0,%A_ScreenWidth%,%newHeight%
}

Log(message) {
    FileAppend, [%A_YYYY%-%A_MM%-%A_DD% %A_Hour%:%A_Min%:%A_Sec%] | Current state: %currentState% | %message%`n, %2%log.log
    FileAppend, [%A_YYYY%-%A_MM%-%A_DD% %A_Hour%:%A_Min%:%A_Sec%] | Instance %3% | Current state: %currentState% | %message%`n, log.log
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
            SetTimer, UpdatePreview, -2000
            SetTimer, ManageState, 250
            return

        } else if ((currentState == STATE_RESETTING || currentState == STATE_PREVIEWING) && InStr(log, "Saving chunks for") && InStr(log, "/minecraft:the_end")) {
            WinGet, activePID, PID, A
            pid = %1%
            if (activePID != pid) {
                Sleep, beforePauseDelay
                ControlSend,, {Blind}{F3 Down}{Esc}{F3 Up}, ahk_pid %1%
                ;Log(log)
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
                currentState := STATE_PLAYING
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

ForceReset:
    newLastLogLine := 0
    Loop, Read, %2%logs/latest.log
    {
        newLastLogLine := A_Index
    }
    log := GetLogLines(0)
    if (!InStr(log, "Initializing") && (lastLogLine == newLastLogLine || !InStr(log, "Stopping server"))) {
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
;             ControlSend,, {Blind}{F3 Down}{Esc}{F3 Up}, ahk_pid %1%
;             SetTimer, CheckPause, -5000
;         }
;         if (instanceFreezing)
;             Freeze()
;     }
; return
; v1.0.0-beta

#NoEnv
#WinActivateForce
#SingleInstance, Off
SetWorkingDir, %A_ScriptDir%
Process, Priority, % ahk_pid DllCall("GetCurrentProcessId"), AboveNormal

SetKeyDelay, 0
SetWinDelay, 1

#Include %A_ScriptDir%/messages.ahk
#Include %A_ScriptDir%/../Settings.ahk

global STATE_UNKNOWN    := -1
global STATE_INIT       := 0
global STATE_READY      := 1
global STATE_PLAYING    := 2
global STATE_RESETTING  := 3
global STATE_PREVIEWING := 4

global pid := 0
global idx := A_Args[1]
global instName := StrReplace(multiMCNameFormat, "#", idx)
global instDir := multiMCLocation . "\instances\" . instName
global mcDir := instDir . "\.minecraft\"
global settings := []
global frozen := False
global resetPos := 0
global newWorldPos := 0
global lastReset := 0
global lastNewWorld := 0
global resetValidated := True
global toValidateReset := ["Resetting a random seed", "Resetting the set seed", "Done waiting for save lock", "Preparing spawn area"]

I_Icon = ../media/IM.ico
if (FileExist(I_Icon))
    Menu, Tray, Icon, %I_Icon%
Menu, Tray, Tip, Instance %idx% Manager

Log("Instance Manager launched")
OnExit("Exit")

if (autoBop) {
    cmd := Format("python.exe " . A_ScriptDir . "\worldBopper9000.py {1}", mcDir)
    Run, %cmd%,, Hide
}

if (!pid := IsInstanceOpen()) {
    Log("No Minecraft instance found, launching")
    centralModsDir := A_ScriptDir . "\..\mods\"
    instModsDir := mcDir . "mods\"
    if (syncMods && DesyncedMods(centralModsDir . "*", instModsDir . "*")) {
        Loop, Files, %instModsDir%*
        {
            FileDelete, %A_LoopFileLongPath%
        }
        FileCopyDir, %centralModsDir%, %instModsDir%, 1
    }
    mmcpack := instDir . "\mmc-pack.json"
    FileGetTime, packModified, %mmcpack%, M
    Run, %multiMCLocation%\MultiMC.exe -l "%instName%"
    while (!pid := IsInstanceOpen())
        Sleep, 500
    Loop, {
        FileGetTime, packModifiedAgain, %mmcpack%, M
        if (packModifiedAgain > packModified)
            break
        Sleep, 500
    }
    FileAppend, %pid%, inst%idx%open.tmp
    Sleep, 12000
} else {
    Log("Minecraft instance found")
    FileAppend, %pid%, inst%idx%open.tmp
    newWorldPos := GetNumLogLines()
}

SetTitle()
GetControls()
GetSettings()
Loop, Read, %mcDir%\logs\latest.log
{
    if(InStr(A_LoopReadLine, "recipes")) {
        global currentState := STATE_UNKNOWN
        Log("State initalised to unknown")
        break
    }
}
if (currentState != STATE_UNKNOWN) {
    global currentState := STATE_INIT
    Log("State initialised to init")
}

if (settings.fullscreen == "true") {
    fs := settings["key_key.fullscreen"]
    ControlSend,, {Blind}{%fs%}, ahk_pid %pid%
}
if (mode == "Multi")
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

OnMessage(MSG_RESET, "Reset")
OnMessage(MSG_SWITCH, "Switch")
OnMessage(MSG_SETTITLE, "SetTitle")
OnMessage(MSG_REVEAL, "Reveal")

FileAppend,, IM%idx%ready.tmp

Reset(wParam) {
    Critical, On
    if (currentState == STATE_RESETTING || (wParam > lastReset && wParam < lastNewWorld)) {
        return
    } else if (currentState == STATE_INIT) {
        ControlSend,, {Blind}{Shift down}{Tab}{Shift up}{Enter}, ahk_pid %pid%
        Loop, {
            Loop, Read, %mcDir%\logs\latest.log
                if (InStr(A_LoopReadLine, "the_end", -7))
                    break 2
            Sleep, 100
        }
        Sleep, 100
        persp := settings["key_key.togglePerspective"]
        ControlSend,, {Blind}{Shift down}{F3}{Shift up}{%persp%}, ahk_pid %pid%
        Sleep, 2000
        ControlSend,, {Blind}11900219003190041900519006190071900819009190019029014605602460560346056044605605460560, ahk_pid %pid%
        ;ControlSend,, {Blind}4113, ahk_pid %pid%
        ControlSend,, {Blind}{F3 Down}{B}{Esc}{F3 Up}, ahk_pid %pid%
        currentState := STATE_READY
    } else {
        Log("Resetting")
        lastReset := A_TickCount
        if (instanceFreezing && frozen)
            Unfreeze()
        if (resetSounds && currentState != STATE_UNKNOWN)
            SoundPlay, %A_ScriptDir%\..\media\reset.wav
        GetSettings()

        switch currentState
        {
            case STATE_UNKNOWN:
                lp := settings["key_LeavePreview"]
                ControlSend,, {Blind}{%lp%}/, ahk_pid %pid%
                Sleep, 120
                ControlSend,, {Blind}{Esc 2}{Shift down}{Tab}{Shift up}{Enter}, ahk_pid %pid%
            case STATE_READY:
                ControlSend,, {Blind}{Esc 2}{Tab 9}{Enter}, ahk_pid %pid%
            case STATE_PLAYING:
                if (useObsWebsocket && screenshotWorlds)
                    SendOBSCommand("SaveImg," . A_NowUTC . "," . CurrentWorldEntered())
                if (fullscreen && settings.fullscreen == "true") {
                    fs := settings["key_key.fullscreen"]
                    ControlSend,, {Blind}{%fs%}, ahk_pid %pid%
                }
                if (wideResets)
                    Widen()
                DllCall("Sleep", "UInt", settingsDelay)
                ResetSettings()
                ControlSend,, {Blind}{Esc}{Shift down}{Tab}{Shift up}{Enter}, ahk_pid %pid%
                ; ControlSend,, {Blind}{Text}summon elder_guardian, ahk_pid %pid%
                ; ControlSend,, {Blind}{Enter}42112, ahk_pid %pid%
            case STATE_PREVIEWING:
                lp := settings["key_LeavePreview"]
                SetKeyDelay, 1
                ControlSend,, {Blind}{%lp%}{%lp%}{%lp%}{%lp%}{%lp%}{%lp%}{%lp%}{%lp%}, ahk_pid %pid%
                SetKeyDelay, 0
        }

        currentState := STATE_RESETTING
        resetValidated := False
        newWorldPos := resetPos := GetNumLogLines()
        SetTimer, ManageState, -200
    }
    Critical, Off
}

Switch() {
    if ((currentState != STATE_RESETTING && (mode == "Multi" || currentState != STATE_PREVIEWING))) {
        Log("Switched to instance")

        if (useObsWebsocket) {
            SendOBSCommand("Play," . idx)
            if (screenshotWorlds)
                SendOBSCommand("GetImg")
        } else {
            Send, {Numpad%idx% down}
            Sleep, %obsDelay%
            Send, {Numpad%idx% up}
        }

        WinSet, AlwaysOnTop, On, ahk_pid %pid%
        WinSet, AlwaysOnTop, Off, ahk_pid %pid%
        if (mode == "Wall")
            WinMinimize, Fullscreen Projector
        if (wideResets)
            WinMaximize, ahk_pid %pid%
        if (fullscreen && mode == "Wall") {
            ControlSend,, {Blind}{F11}, ahk_pid %pid%
            Sleep, %fullScreenDelay%
        }

        Send, {LButton}
        if (currentState == STATE_READY || currentState == STATE_UNKNOWN)
            Play()

        return 0
    } else {
        return -1
    }
}

Play() {
    if (instanceFreezing)
        Unfreeze()
    if (fullscreen && mode == "Multi") {
        ControlSend,, {Blind}{F11}, ahk_pid %pid%
        Sleep, %fullScreenDelay%
    }
    if ((currentState == STATE_READY || currentState == STATE_UNKNOWN) && (unpauseOnSwitch || coopResets || performanceMethod == "S"))
        ControlSend,, {Blind}{Esc}, ahk_pid %pid%
    if (performanceMethod == "S") {
        renderPresses := renderDistance - 2
        ControlSend,, {Blind}{Shift down}{F3 down}{F 32}{F3 up}{Shift up}, ahk_pid %pid%
        ControlSend,, {Blind}{F3 down}{F %renderPresses%}{D}{F3 up}, ahk_pid %pid%
        if (!unpauseOnSwitch)
            ControlSend,, {Blind}{F3 down}{Esc}{F3 up}, ahk_pid %pid%
    }
    if (coopResets) {
        Sleep, 50
        ControlSend,, {Blind}{Esc}{Tab 7}{Enter}{Tab 5}{Enter}, ahk_pid %pid%
        if (!unpauseOnSwitch)
            ControlSend,, {Blind}{Esc}, ahk_pid %pid%
    }
    
    Log("Playing")
    currentState := STATE_PLAYING
}

ValidateReset() {
    if (!resetValidated)
        Log("Successful reset confirmed.")
    lastNewWorld := A_TickCount
    resetValidated := True
    return GetNumLogLines()
}

GetNumLogLines() {
    numLines := 0
    Loop, Read, %mcDir%\logs\latest.log
        numLines++
    return numLines
}

Freeze() {
    if (currentState == STATE_READY && frozen == False) {
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

ResetSettings() {
    GetSettings()
    fovPresses := (110 - FOV) * 143 / 80
    desiredRd := performanceMethod == "S" && currentState == STATE_PLAYING ? lowRender : renderDistance
    renderPresses := desiredRd - 2
    entityPresses := (5 - entityDistance) * 143 / 4.5
    SetKeyDelay, 0
    if (desiredRd != settings.renderDistance) {
        ControlSend,, {Blind}{Shift down}{F3 down}{F 32}{F3 up}{Shift up}, ahk_pid %pid%
        ControlSend,, {Blind}{F3 down}{F %renderPresses%}{D}{F3 up}, ahk_pid %pid%
    }
    if (FOV != (settings.fov * 40 + 70) || entityDistance != settings.entityDistanceScaling) {
        ControlSend,, {Blind}{Esc}{Tab 6}{Enter}{Tab}, ahk_pid %pid%
        if (FOV != currentFOV) {
            ControlSend,, {Blind}{Right 143}, ahk_pid %pid%
            ControlSend,, {Blind}{Left %fovPresses%}, ahk_pid %pid%
        }
        if (entityDistance != settings.entityDistanceScaling) {
            ControlSend,, {Blind}{Tab 5}{Enter}{Tab 17}, ahk_pid %pid%
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
        if (!InStr(line, "key")) {
            kv := StrSplit(line, ":")
            if (kv.MaxIndex() == 2) {
                key = % kv[1]
                value = % kv[2]
                StringReplace, key, key, %A_Space%,, All
                StringReplace, value, value, %A_Space%,, All
                settings[key] := value
            }
        }
    }
}

GetControls() {
    Loop, Read, %mcDir%/options.txt
    {
        line = %A_LoopReadLine%
        if (InStr(line, "key")) {
            kv := StrSplit(line, ":")
            if (kv.MaxIndex() == 2) {
                key = % kv[1]
                value = % kv[2]
                StringReplace, key, key, %A_Space%,, All
                StringReplace, value, value, %A_Space%,, All
                if (InStr(value, "key.keyboard.")) {
                    split := StrSplit(value, "key.keyboard.")
                    StringLower, value, % split[2]
                }
                if (InStr(value, "key.mouse.")) {
                    split := StrSplit(value, "key.mouse.")
                    switch (split[2])
                    {
                        case "left":
                            value := "LButton"
                        case "right":
                            value := "RButton"
                        case "middle":
                            value := "MButton"
                        case "4":
                            value := "XButton1"
                        case "5":
                            value := "XButton2"
                    }
                }
                if (InStr(value, "left.")) {
                    split := StrSplit(value, "left.")
                    StringLower, value, % split[2]
                    value := "L" . value
                }
                if (InStr(value, "right.")) {
                    split := StrSplit(value, "right.")
                    StringLower, value, % split[2]
                    value := "R" . value
                }
                settings[key] := value
            }
        }
    }
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
    log := ""
    Loop, Read, %mcDir%\logs\latest.log
    {
        if (A_Index > newWorldPos)
            log := log . A_LoopReadLine . "\n"
    }
    return InStr(log, "We Need To Go Deeper")
}

Widen() {
    newHeight := Floor(A_ScreenHeight / 2.5)
    yPos := (A_ScreenHeight/2) - (newHeight/2)
    WinMaximize, ahk_pid %pid%
    WinRestore, ahk_pid %pid%
    Sleep, 200
    WinMove, ahk_pid %pid%,, 0, %yPos%, %A_ScreenWidth%, %newHeight%
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
    centralMods := instMods := []
    Loop, Files, %dir1%
    {
        centralMods[A_Index] := A_LoopFileName
    }
    Loop, Files, %dir2%
    {
        instMods[A_Index] := A_LoopFileName
    }
    if (centralMods.MaxIndex() != instMods.MaxIndex())
        return True
    for each, ctrlMod in centralMods {
        for each, instMod in instMods {
            if (ctrlMod != instMod)
                return True
        }
    }
    return False
}

Log(message) {
    FileAppend, [%A_YYYY%-%A_MM%-%A_DD% %A_Hour%:%A_Min%:%A_Sec%] | Current state: %currentState% | %message%`n, %mcDir%log.log
}

Exit() {
    logFile.Close()
}

return ; end the auto-execute section

ManageState:
    Critical
    Loop, Read, %mcDir%\logs\latest.log
    {
        if (A_Index > (resetValidated ? newWorldPos : resetPos)) {
            line = %A_LoopReadLine%
            if (!resetValidated) {
                for each, value in toValidateReset
                    if (InStr(line, value))
                        newWorldPos := ValidateReset()
            }
            if (currentState == STATE_RESETTING && InStr(line, "Starting Preview", -16)) {
                Log("Found preview. Log:`n" . line)
                newWorldPos := ValidateReset()
                ControlSend,, {Blind}{F3 Down}{Esc}{F3 Up}, ahk_pid %pid%
                currentState := STATE_PREVIEWING
            }
            if (resetValidated && (currentState == STATE_RESETTING || currentState == STATE_PREVIEWING) && InStr(line, "the_end", -7)) {
                newWorldPos := ValidateReset()
                WinGet, activePID, PID, A
                if (activePID != pid) {
                    Log("World generated, pausing. Log:`n" . line)
                    DllCall("Sleep", "UInt", beforePauseDelay)
                    ControlSend,, {Blind}{F3 Down}{Esc}{F3 Up}, ahk_pid %pid%
                    currentState := STATE_READY
                    if (instanceFreezing) {
                        Frz := Func("Freeze").Bind()
                        bfd := 0 - beforeFreezeDelay
                        SetTimer, %Frz%, %bfd%
                    }
                } else {
                    Log("World generated, playing. Log:`n" . line)
                    Play()
                }
                return
            }
        }
    }
    if (!resetValidated && (A_TickCount - lastReset > 2000)) {
        log := ""
        Loop, Read, %mcDir%\logs\latest.log
        {
            if (A_Index > resetPos)
                log := log . A_LoopReadLine . "`n"
        }
        if (InStr(log, "Stopping worker threads", -23) || InStr(log, "Leaving world generation", -24)) { ; || InStr(log, "Preparing spawn area", -26)) {
            newWorldPos := ValidateReset()
        } else { ; the instance didn't reset
            Log("Found failed reset. Forcing reset. Log:`n" . log)
            currentState := STATE_UNKNOWN
            Reset(A_TickCount)
            return
        }
    }
    if (!(currentState == STATE_PREVIEWING && DllCall("PeekMessage", "UInt*", &msg, "UInt", 0, "UInt", MSG_RESET, "UInt", MSG_RESET, "UInt", 0))) {
        Goto, ManageState
    }
return
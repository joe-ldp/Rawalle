; v0.4.2

EnvGet, threadCount, NUMBER_OF_PROCESSORS
global McDirectories := []
global instances := 0
global rawPIDs := []
global PIDs := []
global resetScriptTime := []
global resetIdx := []
global highBitMask := (2 ** threadCount) - 1
global lowBitMask := (2 ** Ceil(threadCount * lowBitmaskMultiplier)) - 1

SetKeyDelay, 0

SetTitles() {
    for i, pid in PIDs {
        WinSetTitle, ahk_pid %pid%, , Minecraft* - Instance %i%
    }
}

RunHide(Command) {
    dhw := A_DetectHiddenWindows
    DetectHiddenWindows, On
    Run, %ComSpec%,, Hide, cPid
    WinWait, ahk_pid %cPid%
    DetectHiddenWindows, %dhw%
    DllCall("AttachConsole", "uint", cPid)

    Shell := ComObjCreate("WScript.Shell")
    Exec := Shell.Exec(Command)
    Result := Exec.StdOut.ReadAll()

    DllCall("FreeConsole")
    Process, Close, %cPid%
    return Result
}

GetMcDir(pid) {
    command := Format("powershell.exe $x = Get-WmiObject Win32_Process -Filter \""ProcessId = {1}\""; $x.CommandLine", pid)
    rawOut := RunHide(command)
    if (InStr(rawOut, "--gameDir")) {
        strStart := RegExMatch(rawOut, "P)--gameDir (?:""(.+?)""|([^\s]+))", strLen, 1)
        return SubStr(rawOut, strStart+10, strLen-10) . "\"
    } else {
        strStart := RegExMatch(rawOut, "P)(?:-Djava\.library\.path=(.+?) )|(?:\""-Djava\.library.path=(.+?)\"")", strLen, 1)
        if (SubStr(rawOut, strStart+20, 1) == "=") {
            strLen -= 1
            strStart += 1
        }
        return StrReplace(SubStr(rawOut, strStart+20, strLen-28) . ".minecraft\", "/", "\")
    }
}

GetInstanceTotal() {
    idx := 1
    global rawPIDs
    WinGet, all, list
    Loop, %all%
    {
        WinGet, pid, PID, % "ahk_id " all%A_Index%
        WinGetTitle, title, ahk_pid %pid%
        if (InStr(title, "Minecraft*")) {
            rawPIDs[idx] := pid
            idx += 1
        }
    }
    return rawPIDs.MaxIndex()
}

GetInstanceNumberFromMcDir(mcdir) {
    numFile := mcdir . "instanceNumber.txt"
    num := -1
    if (mcdir == "" || mcdir == ".minecraft" || mcdir == ".minecraft\" || mcdir == ".minecraft/") ; Misread something
        Reload
    if (!FileExist(numFile))
        MsgBox, Missing instanceNumber.txt in %mcdir%
    else
        FileRead, num, %numFile%
    return num
}

SetAffinity(pid, mask) {
    hProc := DllCall("OpenProcess", "UInt", 0x0200, "Int", false, "UInt", pid, "Ptr")
    DllCall("SetProcessAffinityMask", "Ptr", hProc, "Ptr", mask)
    DllCall("CloseHandle", "Ptr", hProc)
}

FreeMemory(pid) {
    h:=DllCall("OpenProcess", "UInt", 0x001F0FFF, "Int", 0, "Int", pid)
    DllCall("SetProcessWorkingSetSize", "UInt", h, "Int", -1, "Int", -1)
    DllCall("CloseHandle", "Int", h)
}

UnsuspendAll() {
    WinGet, all, list
    Loop, %all%
    {
        WinGet, pid, PID, % "ahk_id " all%A_Index%
        WinGetTitle, title, ahk_pid %pid%
        if (InStr(title, "Minecraft*"))
        ResumeInstance(pid)
    }
}

SuspendInstance(pid) {
    hProcess := DllCall("OpenProcess", "UInt", 0x1F0FFF, "Int", 0, "Int", pid)
    If (hProcess) {
        DllCall("ntdll.dll\NtSuspendProcess", "Int", hProcess)
        DllCall("CloseHandle", "Int", hProcess)
    }
    FreeMemory(pid)
}

ResumeInstance(pid) {
    hProcess := DllCall("OpenProcess", "UInt", 0x1F0FFF, "Int", 0, "Int", pid)
    If (hProcess) {
        sleep, %resumeDelay%
        DllCall("ntdll.dll\NtResumeProcess", "Int", hProcess)
        DllCall("CloseHandle", "Int", hProcess)
    }
}

GetAllPIDs(ByRef McDirectories, ByRef PIDs, ByRef instances) {
    instances := GetInstanceTotal()
    ; Generate mcdir and order PIDs
    Loop, %instances%
    {
        mcdir := GetMcDir(rawPIDs[A_Index])
        if (num := GetInstanceNumberFromMcDir(mcdir)) == -1
        ExitApp
        PIDs[num] := rawPIDs[A_Index]
        McDirectories[num] := mcdir
    }
}

GetActiveInstanceNum() {
    WinGet, pid, PID, A
    WinGetTitle, title, ahk_pid %pid%
    if (InStr(title, " - ")) {
        for i, tmppid in PIDs {
        if (tmppid == pid)
            return i
        }
    }
    return -1
}

ExitWorld()
{
    if (fullscreen) {
        Send, {F11}
        Sleep, %fullScreenDelay%
    }
    if ((idx := GetActiveInstanceNum()) > 0) {
        pid := PIDs[idx]
        if (wideResets) {
            newHeight := Floor(A_ScreenHeight / 2.5)
            WinRestore, ahk_pid %pid%
            Sleep, 200
            WinMove, ahk_pid %pid%,,0,0,%A_ScreenWidth%,%newHeight%
        }
        if (performanceMethod == "S") {
            ResetSettings(pid, lowRender)
        } else {
            ResetSettings(pid, renderDistance)
        }
        ResetInstance(idx)
        if (affinity) {
            for i, tmppid in PIDs {
                SetAffinity(tmppid, highBitMask)
            }
        }
    }
}

ResetInstance(idx) {
    idleFile := McDirectories[idx] . "idle.tmp"
    if (idx <= instances && FileExist(idleFile)) {
        pid := PIDs[idx]
        
        if (performanceMethod == "F") {
            bfd := beforeFreezeDelay
            ResumeInstance(pid)
        } else {
            bfd := 0
        }

        logFile := McDirectories[idx] . "logs\latest.log"
        If (FileExist(idleFile))
            FileDelete, %idleFile%
        
        Run, %A_ScriptDir%\scripts\reset.ahk %pid% %logFile% %maxLoops% %bfd% %idleFile% %beforePauseDelay% %resetSounds%

        if (performanceMethod == "F") {
            Critical, On
            resetScriptTime[idx] := A_TickCount
            resetIdx[idx] := True
            Critical, Off
        }

        if (countAttempts) {
            attemptsDir := A_ScriptDir . "\attempts\"
            countResets(attemptsDir, "ATTEMPTS")
            countResets(attemptsDir, "ATTEMPTS_DAY")
            if (idx != currentInstance)
                countResets(attemptsDir, "BG")
        }
    }
}

SwitchInstance(idx) {
    if (idx <= instances) {
        if (useObsWebsocket) {
            cmd := Format("python.exe " . A_ScriptDir . "\scripts\obs.py 1 {1}", idx)
            Run, %cmd%,, Hide
        }
        pid := PIDs[idx]
        if (affinity) {
            for i, tmppid in PIDs {
                if (tmppid != pid) {
                    SetAffinity(tmppid, lowBitMask)
                }
            }
        }
        if (performanceMethod == "F")
            ResumeInstance(pid)
        if (performanceMethod == "S") {
            ControlSend, ahk_parent, {Blind}{Esc}, ahk_pid %pid%
            Sleep, %settingsDelay%
            ResetSettings(pid, renderDistance, True)
            ControlSend, ahk_parent, {Blind}{F3 Down}{D}{F3 Up}, ahk_pid %pid%
            ControlSend, ahk_parent, {Blind}{F3 Down}{Esc}{F3 Up}, ahk_pid %pid%
        }
        if (unpauseOnSwitch)
            ControlSend, ahk_parent, {Blind}{Esc}, ahk_pid %pid%
        
        WinSet, AlwaysOnTop, On, ahk_pid %pid%
        WinSet, AlwaysOnTop, Off, ahk_pid %pid%
        WinMinimize, Fullscreen Projector
        if (wideResets)
            WinMaximize, ahk_pid %pid%
        if (fullscreen) {
            ControlSend, ahk_parent, {Blind}{F11}, ahk_pid %pid%
            Sleep, %fullScreenDelay%
        }
        if (!useObsWebsocket) {
            Send, {Numpad%idx% down}
            Sleep, %obsDelay%
            Send, {Numpad%idx% up}
        }
        if (coopResets) {
            ControlSend, ahk_parent, {Blind}{Esc}{Tab 7}{Enter}{Tab 4}{Enter}{Tab}{Enter}, ahk_pid %pid%
            Sleep, 500
            ControlSend, ahk_parent, /, ahk_pid %pid%
            Sleep, 100
            ControlSend, ahk_parent, {Text}time set 0, ahk_pid %pid%
        }
        Sleep, 100
        Send, {LButton} ; Make sure the window is activated
    }
}

; Reset your settings to preset settings preferences
ResetSettings(pid, rd, justRD := False) {
    ; Find required presses to set FOV, sensitivity, and render distance
    if (rd) {
        RDPresses := rd-2
        ; Reset then preset render distance to custom value with f3 shortcuts
        ControlSend, ahk_parent, {Blind}{Shift down}{F3 down}{F 32}{F3 up}{Shift up}, ahk_pid %pid%
        ControlSend, ahk_parent, {Blind}{F3 down}{F %RDPresses%}{F3 up}, ahk_pid %pid%
    }
    if (FOV && !justRD) {
        FOVPresses := ceil((FOV-30)*1.763)
        ; Tab to FOV
        ControlSend, ahk_parent, {Blind}{Esc}{Tab 6}{enter}{Tab}, ahk_pid %pid%
        ; Reset then preset FOV to custom value with arrow keys
        ControlSend, ahk_parent, {Blind}{Left 151}, ahk_pid %pid%
        ControlSend, ahk_parent, {Blind}{Right %FOVPresses%}{Esc}, ahk_pid %pid%
    }
    if (mouseSensitivity && !justRD) {
        SensPresses := ceil(mouseSensitivity/1.408)
        ; Tab to mouse sensitivity
        ControlSend, ahk_parent, {Blind}{Esc}{Tab 6}{enter}{Tab 7}{enter}{tab}{enter}{tab}, ahk_pid %pid%
        ; Reset then preset mouse sensitivity to custom value with arrow keys
        ControlSend, ahk_parent, {Blind}{Left 146}, ahk_pid %pid%
        ControlSend, ahk_parent, {Blind}{Right %SensPresses%}{Esc 3}, ahk_pid %pid%
    }
}

countResets(dir, attemptType) {
    filename := dir . attemptType . ".txt"
    FileRead, WorldNumber, %filename%
    if (ErrorLevel)
        WorldNumber = 0
    else
        FileDelete, %filename%
    WorldNumber += 1
    FileAppend, %WorldNumber%, %filename%
}
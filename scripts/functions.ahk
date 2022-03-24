; v0.5.1-alpha

MousePosToInstNumber() {
    MouseGetPos, mX, mY
    return (Floor(mY / instHeight) * cols) + Floor(mX / instWidth) + 1
}

NextInstance() {
    ErrorLevel := 1
    while (ErrorLevel != 0) {
        activeInstance := activeInstance + 1 > numInstances ? 1 : activeInstance + 1
        Play(activeInstance)
    }
}

ToWallOrNextInstance() {
    minTime := A_TickCount
    goToIdx := 0
    for idx, lockTime in locked {
        if (lockTime && lockTime < minTime) {
            minTime := lockTime
            goToIdx := idx
        }
    }
    
    if (goToIdx != 0) {
        Play(goToIdx)
    } else {
        ToWall()
    }
}

ToWall() {
    WinActivate, Fullscreen Projector
    isOnWall := True
}

global cmdNum := 1
SendOBSCommand(cmd) {
    idx = %3%
    cmdDir := A_ScriptDir . "\scripts\pyCmds\"
    cmdFile := cmdDir . "TWCMD" . cmdNum . ".txt"
    cmdNum++
    FileAppend, %cmd%, %cmdFile%
}

ResetAll() {
    Loop, %numInstances%
        if (!locked[A_Index])
            Reset(A_Index)
}

FreezeAll() {
    Loop, %numInstances%
        Freeze(A_Index)
}

UnfreezeAll() {
    Loop, %numInstances%
        Unfreeze(A_Index)
}

FocusReset(focusInstance) {
    Play(focusInstance)
    Loop, %numInstances%
        if (focusInstance != A_Index && !locked[A_Index])
            Reset(A_Index)
}

BackgroundReset(idx) {
    if (!locked[idx])
        Reset(idx)
}

ToggleLock(idx) {
    if (locked[idx])
        UnlockInstance(idx)
    else
        LockInstance(idx)
}

LockInstance(idx, sound := True) {
    locked[idx] := A_TickCount
    SendOBSCommand("Lock," . idx . "," . 1)
    if (lockSounds && sound)
        SoundPlay, media\lock.wav
}

UnlockInstance(idx, sound := True) {
    locked[idx] := 0
    SendOBSCommand("Lock," . idx . "," . 0)
    if (lockSounds && sound)
        SoundPlay, media\lock.wav
}

RunHide(command) {
    dhw := A_DetectHiddenWindows
    DetectHiddenWindows, On
    Run, %ComSpec%,, Hide, cPid
    WinWait, ahk_pid %cPid%
    DetectHiddenWindows, %dhw%
    DllCall("AttachConsole", "UInt", cPid)

    shell := ComObjCreate("WScript.Shell")
    exec := shell.Exec(command)
    result := exec.StdOut.ReadAll()

    DllCall("FreeConsole")
    Process, Close, %cPid%
    return result
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

GetInstanceNumberFromMcDir(mcdir) {
    numFile := mcdir . "instanceNumber.txt"
    num := -1
    if (mcdir == "" || mcdir == ".minecraft" || mcdir == ".minecraft\" || mcdir == ".minecraft/") ; Misread something
        Reboot()
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

SetAffinities() {
    Loop, %numInstances% {        
        mask := (activeInstance > 0 && activeInstance != A_Index) ? lowBitMask : highBitMask
        SetAffinity(MC_PIDs[A_Index], mask)
    }
}

GetInstances() {
    WinGet, allIDs, List
    Loop, %allIDs% {
        WinGet, pid, PID, % "ahk_id " allIDs%A_Index%
        WinGetTitle, title, ahk_pid %pid%
        if (InStr(title, "Minecraft*")) {
            mcdir := GetMcDir(pid)
            if (idx := GetInstanceNumberFromMcDir(mcdir)) == -1
                Shutdown()
            MC_PIDs[idx] := pid
            McDirectories[idx] := mcdir
        }
    }
    numInstances := MC_PIDs.MaxIndex()
}
; v0.5.0-alpha

RunHide(Command) {
    dhw := A_DetectHiddenWindows
    DetectHiddenWindows, On
    Run, %ComSpec%,, Hide, cPid
    WinWait, ahk_pid %cPid%
    DetectHiddenWindows, %dhw%
    DllCall("AttachConsole", "UInt", cPid)

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
    activeIdx := GetActiveInstanceNum()
    Loop, %instances%
    {        
        mask := (activeIdx > 0 && activeIdx != A_Index) ? lowBitMask : highBitMask
        SetAffinity(MC_PIDs[A_Index], mask)
    }
}

GetActiveInstanceNum() {
    WinGet, pid, PID, A
    WinGetTitle, title, ahk_pid %pid%
    if (InStr(title, " - ")) {
        for i, tmppid in MC_PIDs {
        if (tmppid == pid)
            return i
        }
    }
    return -1
}

GetAllPIDs(ByRef McDirectories, ByRef MC_PIDs, ByRef instances) {
    instances := GetInstanceTotal()
    Loop, %instances%
    {
        mcdir := GetMcDir(rawPIDs[A_Index])
        if (num := GetInstanceNumberFromMcDir(mcdir)) == -1
            ExitApp
        MC_PIDs[num] := rawPIDs[A_Index]
        McDirectories[num] := mcdir
    }
}
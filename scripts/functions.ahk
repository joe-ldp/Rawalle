; v1.2.1

Freeze(pid) {
    hProcess := DllCall("OpenProcess", "UInt", 0x1F0FFF, "Int", 0, "Int", pid)
    if (hProcess) {
        DllCall("ntdll.dll\NtSuspendProcess", "Int", hProcess)
        DllCall("CloseHandle", "Int", hProcess)
    }

    ; hProcess := DllCall("OpenProcess", "UInt", 0x1F0FFF, "Int", 0, "Int", pid)
    ; DllCall("SetProcessWorkingSetSize", "UInt", hProcess, "Int", -1, "Int", -1)
    ; DllCall("CloseHandle", "Int", hProcess)
    ; Log("Freeing memory")

    ; Freeing memory is disabled by default, as it doesn't achieve much except more unfreezing lag.
    ; It can in theory let you run more than the max # of instances your ram can handle, but this macro doesn't support that anyway.
    ; You can uncomment these lines to enable it if you want.
}

Unfreeze(pid) {
    global resumeDelay
    hProcess := DllCall("OpenProcess", "UInt", 0x1F0FFF, "Int", 0, "Int", pid)
    if (hProcess) {
        DllCall("ntdll.dll\NtResumeProcess", "Int", hProcess)
        DllCall("CloseHandle", "Int", hProcess)
        Sleep, %resumeDelay%
    }
}

SendOBSCommand(cmd, ref := "TW") {
    static cmdNum := 1
    cmdFile := Format("{1}\scripts\pyCmds\{2}CMD{3}.txt", A_ScriptDir, ref, cmdNum)
    cmdNum++
    FileAppend, %cmd%, %cmdFile%
}

LogAction(idx, action) {
    FileAppend, %A_YYYY%-%A_MM%-%A_DD% %A_Hour%:%A_Min%:%A_Sec%`,%idx%`,%action%`n, actions.csv
}

LoadSettings(settingsFile) {
    global
    local filename, file, sect, equalsPos, key, value
    FileRead, file, %settingsFile%
    Loop, Parse, file, `n`r, %A_Space%%A_Tab%
    {
        switch (SubStr(A_LoopField, 1, 1))
        {
            case ";":
                continue
            case "[":
                sect := SubStr(A_LoopField, 2, -1)
            default:
                equalsPos := InStr(A_LoopField, "=")
                if equalsPos {
                    key := SubStr(A_LoopField, 1, equalsPos - 1)
                    IniRead, value, %settingsFile%, %sect%, %key%
                    if (InStr(key, "arr")) {
                        value := StrReplace(value, """", "")
                        %key% := []
                        if (InStr(value, ",")) {
                            Loop, Parse, value, `,
                                %key%.Push(A_LoopField)
                        } else {
                            %key%.Push(value)
                        }
                    } else {
                        %key% := value
                    }
                }
        }
    }

    obsSettingsFile := Format("{1}\scripts\obsSettings.py", A_ScriptDir)
    FileDelete, %obsSettingsFile%
    FileAppend, host = "%host%"`n, %obsSettingsFile%
    FileAppend, port = %port%`n, %obsSettingsFile%
    FileAppend, password = "%password%"`n, %obsSettingsFile%
    FileAppend, lock_layer_format = "%lockLayerFormat%"`n, %obsSettingsFile%
    FileAppend, wall_scene = "%wallScene%"`n, %obsSettingsFile%
    FileAppend, instance_scene_format = "%instanceSceneFormat%"`n, %obsSettingsFile%
    FileAppend, single_scene = %singleSceneOBS%`n, %obsSettingsFile%
    FileAppend, playing_scene = "%playingScene%"`n, %obsSettingsFile%
    FileAppend, instance_source_format = "%instanceSourceFormat%"`n, %obsSettingsFile%
    FileAppend, num_instances = %numInstances%`n, %obsSettingsFile%
    FileAppend, width_multiplier = %widthMultiplier%`n, %obsSettingsFile%
    FileAppend, screen_height = %A_ScreenHeight%`n, %obsSettingsFile%
}

LoadHotkeys() {
    global numInstances
    #If, WinActive("Minecraft") && (WinActive("ahk_exe javaw.exe") || WinActive("ahk_exe java.exe"))
    #If, WinActive("Fullscreen Projector")
    FileRead, file, %A_ScriptDir%\hotkeys.ini
    Loop, Parse, file, `n`r, %A_Space%%A_Tab%
    {
        equalsPos := InStr(A_LoopField, "=")
        if (InStr(A_LoopField, "WinActive")) {
            Hotkey, If, % SubStr(A_LoopField, 2)
        } else if (equalsPos && (InStr(A_LoopField, ";") != 1)) {
            function := SubStr(A_LoopField, 1, equalsPos - 1)
            keybind := StrReplace(SubStr(A_LoopField, equalsPos + 1), """", "")
            if (keybind == "unbound")
                continue
            if(!RegExMatch(keybind, "([<>]?[#^!+*])+"))
                keybind := "*" . keybind
            if (InStr(keybind, "idx")) {
                Loop, %numInstances% {
                    fn := Func(function).Bind(A_Index)
                    Hotkey, % StrReplace(keybind, "idx", A_Index), %fn%, UseErrorLevel
                    if (ErrorLevel == 2) {
                        MsgBox, I think you're using more than 9 instances or tried to assign an invalid hotkey! Check the readme on the Rawalle GitHub page for help.
                        break
                    } else if (ErrorLevel > 0) {
                        MsgBox, Unhandled error code %ErrorLevel% when creating a hotkey. Contact Ravalle if you need help 😅
                        break
                    }
                }
            } else {
                Hotkey, %keybind%, %function%, %A_Index%, UseErrorLevel
                if (ErrorLevel)
                    MsgBox, Error code %ErrorLevel% when creating a hotkey. Check the readme on the Rawalle GitHub page for help.
            }
        }
    }
}

TranslateKey(mcKey) {
    static keyArray := Object("key.keyboard.f1", "F1"
    ,"key.keyboard.f2", "F2"
    ,"key.keyboard.f3", "F3"
    ,"key.keyboard.f4", "F4"
    ,"key.keyboard.f5", "F5"
    ,"key.keyboard.f6", "F6"
    ,"key.keyboard.f7", "F7"
    ,"key.keyboard.f8", "F8"
    ,"key.keyboard.f9", "F9"
    ,"key.keyboard.f10", "F10"
    ,"key.keyboard.f11", "F11"
    ,"key.keyboard.f12", "F12"
    ,"key.keyboard.f13", "F13"
    ,"key.keyboard.f14", "F14"
    ,"key.keyboard.f15", "F15"
    ,"key.keyboard.f16", "F16"
    ,"key.keyboard.f17", "F17"
    ,"key.keyboard.f18", "F18"
    ,"key.keyboard.f19", "F19"
    ,"key.keyboard.f20", "F20"
    ,"key.keyboard.f21", "F21"
    ,"key.keyboard.f22", "F22"
    ,"key.keyboard.f23", "F23"
    ,"key.keyboard.f24", "F24"
    ,"key.keyboard.q", "q"
    ,"key.keyboard.w", "w"
    ,"key.keyboard.e", "e"
    ,"key.keyboard.r", "r"
    ,"key.keyboard.t", "t"
    ,"key.keyboard.y", "y"
    ,"key.keyboard.u", "u"
    ,"key.keyboard.i", "i"
    ,"key.keyboard.o", "o"
    ,"key.keyboard.p", "p"
    ,"key.keyboard.a", "a"
    ,"key.keyboard.s", "s"
    ,"key.keyboard.d", "d"
    ,"key.keyboard.f", "f"
    ,"key.keyboard.g", "g"
    ,"key.keyboard.h", "h"
    ,"key.keyboard.j", "j"
    ,"key.keyboard.k", "k"
    ,"key.keyboard.l", "l"
    ,"key.keyboard.z", "z"
    ,"key.keyboard.x", "x"
    ,"key.keyboard.c", "c"
    ,"key.keyboard.v", "v"
    ,"key.keyboard.b", "b"
    ,"key.keyboard.n", "n"
    ,"key.keyboard.m", "m"
    ,"key.keyboard.1", "1"
    ,"key.keyboard.2", "2"
    ,"key.keyboard.3", "3"
    ,"key.keyboard.4", "4"
    ,"key.keyboard.5", "5"
    ,"key.keyboard.6", "6"
    ,"key.keyboard.7", "7"
    ,"key.keyboard.8", "8"
    ,"key.keyboard.9", "9"
    ,"key.keyboard.0", "0"
    ,"key.keyboard.tab", "Tab"
    ,"key.keyboard.left.bracket", "["
    ,"key.keyboard.right.bracket", "]"
    ,"key.keyboard.backspace", "Backspace"
    ,"key.keyboard.equal", "="
    ,"key.keyboard.minus", "-"
    ,"key.keyboard.grave.accent", "`"
    ,"key.keyboard.slash", "/"
    ,"key.keyboard.space", "Space"
    ,"key.keyboard.left.alt", "LAlt"
    ,"key.keyboard.right.alt", "RAlt"
    ,"key.keyboard.print.screen", "PrintScreen"
    ,"key.keyboard.insert", "Insert"
    ,"key.keyboard.scroll.lock", "ScrollLock"
    ,"key.keyboard.pause", "Pause"
    ,"key.keyboard.right.control", "RControl"
    ,"key.keyboard.left.control", "LControl"
    ,"key.keyboard.right.shift", "RShift"
    ,"key.keyboard.left.shift", "LShift"
    ,"key.keyboard.comma", ","
    ,"key.keyboard.period", "."
    ,"key.keyboard.home", "Home"
    ,"key.keyboard.end", "End"
    ,"key.keyboard.page.up", "PgUp"
    ,"key.keyboard.page.down", "PgDn"
    ,"key.keyboard.delete", "Delete"
    ,"key.keyboard.left.win", "LWin"
    ,"key.keyboard.right.win", "RWin"
    ,"key.keyboard.menu", "AppsKey"
    ,"key.keyboard.backslash", "\"
    ,"key.keyboard.caps.lock", "CapsLock"
    ,"key.keyboard.semicolon", ";"
    ,"key.keyboard.apostrophe", "'"
    ,"key.keyboard.enter", "Enter"
    ,"key.keyboard.up", "Up"
    ,"key.keyboard.down", "Down"
    ,"key.keyboard.left", "Left"
    ,"key.keyboard.right", "Right"
    ,"key.keyboard.keypad.0", "Numpad0"
    ,"key.keyboard.keypad.1", "Numpad1"
    ,"key.keyboard.keypad.2", "Numpad2"
    ,"key.keyboard.keypad.3", "Numpad3"
    ,"key.keyboard.keypad.4", "Numpad4"
    ,"key.keyboard.keypad.5", "Numpad5"
    ,"key.keyboard.keypad.6", "Numpad6"
    ,"key.keyboard.keypad.7", "Numpad7"
    ,"key.keyboard.keypad.8", "Numpad8"
    ,"key.keyboard.keypad.9", "Numpad9"
    ,"key.keyboard.keypad.decimal", "NumpadDot"
    ,"key.keyboard.keypad.enter", "NumpadEnter"
    ,"key.keyboard.keypad.add", "NumpadAdd"
    ,"key.keyboard.keypad.subtract", "NumpadSub"
    ,"key.keyboard.keypad.multiply", "NumpadMult"
    ,"key.keyboard.keypad.divide", "NumpadDiv"
    ,"key.mouse.left", "LButton"
    ,"key.mouse.right", "RButton"
    ,"key.mouse.middle", "MButton"
    ,"key.mouse.4", "XButton1"
    ,"key.mouse.5", "XButton2")
    return keyArray[mcKey]
}

SetAffinity(pid, threads) {
    mask := (2 ** threads) - 1
    hProc := DllCall("OpenProcess", "UInt", 0x0200, "Int", false, "UInt", pid, "Ptr")
    DllCall("SetProcessAffinityMask", "Ptr", hProc, "Ptr", mask)
    DllCall("CloseHandle", "Ptr", hProc)
}
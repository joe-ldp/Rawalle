; A Wall-Style Multi-Instance macro for Minecraft
; By Specnr, forked by Ravalle
; v0.4.2

#NoEnv
#SingleInstance Force
#Include %A_ScriptDir%\scripts\MultiFunctions.ahk
#Include Settings.ahk

SetKeyDelay, 0
SetWinDelay, 1
SetTitleMatchMode, 2

; Don't configure these
EnvGet, threadCount, NUMBER_OF_PROCESSORS
global instWidth := Floor(A_ScreenWidth / cols)
global instHeight := Floor(A_ScreenHeight / rows)
global McDirectories := []
global instances := 0
global rawPIDs := []
global PIDs := []
global resetScriptTime := []
global resetIdx := []
global locked := []
global isOnWall := True
global highBitMask := (2 ** threadCount) - 1
global lowBitMask := (2 ** Ceil(threadCount * lowBitmaskMultiplier)) - 1

if (performanceMethod == "F") {
    UnsuspendAll()
    sleep, %restartDelay%
}
GetAllPIDs(McDirectories, PIDs, instances)
SetTitles()
ToWall()

for i, mcdir in McDirectories {
    idle := mcdir . "idle.tmp"
    if (!FileExist(idle))
        FileAppend,,%idle%
    pid := PIDs[i]
    if (borderless) {
        WinSet, Style, -0xC40000, ahk_pid %pid%
    }
    if (wideResets) {
        WinRestore, ahk_pid %pid%
        WinMove, ahk_pid %pid%,,0,0,%A_ScreenWidth%,%A_ScreenHeight%
        newHeight := Floor(A_ScreenHeight / 2.5)
        WinMove, ahk_pid %pid%,,0,0,%A_ScreenWidth%,%newHeight%
    }
    UnlockInstance(i)
    WinSet, AlwaysOnTop, Off, ahk_pid %pid%
}

if (affinity) {
    for i, tmppid in PIDs {
        SetAffinity(tmppid, highBitMask)
    }
}

if (!disableTTS)
    ComObjCreate("SAPI.SpVoice").Speak("Ready")

#Persistent
    SetTimer, CheckScripts, 20
return

CheckScripts:
    Critical
        if (performanceMethod == "F") {
            Loop, %instances% {
                rIdx := A_Index
                idleCheck := McDirectories[rIdx] . "idle.tmp"
                if (resetIdx[rIdx] && FileExist(idleCheck) && (A_TickCount - resetScriptTime[i]) > scriptBootDelay) {
                    SuspendInstance(PIDs[rIdx])
                    resetScriptTime[i] := 0
                    resetIdx[rIdx] := False
                }
            }
        }
return

MousePosToInstNumber() {
    MouseGetPos, mX, mY
    return (Floor(mY / instHeight) * cols) + Floor(mX / instWidth) + 1
}

SwitchInstance(idx) {
    if (idx <= instances) {
        locked[idx] := True
        isOnWall := False
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
        Send, {LButton} ; Make sure the window is activated
    }
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
            Sleep, 20
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
        if (bypassWall) {
            ToWallOrNextInstance()
        } else {
            ToWall()
        }
    }
}

ResetInstance(idx) {
    idleFile := McDirectories[idx] . "idle.tmp"
    if (idx <= instances && FileExist(idleFile)) {
        UnlockInstance(idx)
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
            if (!isOnWall)
                countResets(attemptsDir, "BG")
            }
        }
}

ToWallOrNextInstance() {
    minTime := A_TickCount
    goToIdx := 0
    for idx, lockTime in locked
    {
        if (lockTime && lockTime < minTime) {
            minTime := lockTime
            goToIdx := idx
        }
    }
    
    if (goToIdx != 0) {
        SwitchInstance(goToIdx)
    } else {
        ToWall()
    }
}

ToWall() {
    WinActivate, Fullscreen Projector
    isOnWall := True
    if (useObsWebsocket) {
            cmd := Format("python.exe " . A_ScriptDir . "\scripts\obs.py 0 {1}", idx)
        Run, %cmd%,, Hide
    } else {
        Send, {F12 down}
        Sleep, %obsDelay%
        Send, {F12 up}
    }
}

; Focus hovered instance and background reset all other instances
FocusReset(focusInstance) {
    SwitchInstance(focusInstance)
    loop, %instances% {
        if (A_Index != focusInstance && !locked[A_Index]) {
            ResetInstance(A_Index)
        }
    }
}

; Reset all instances
ResetAll() {
    loop, %instances% {
        if (!locked[A_Index])
            ResetInstance(A_Index)
    }
}

ToggleLock(idx) {
    if (locked[idx]) {
        UnlockInstance(idx)
    } else {
        LockInstance(idx)
    }
}

LockInstance(idx) {
    locked[idx] := A_TickCount
    ;LockInstanceIndicator(idx)
    ;cmd := Format("python.exe obs.py 3 {1}", idx)
    ;Run, %cmd%,, Hide

    if (lockSounds) {
        SoundPlay, A_ScriptDir\..\media\lock.wav
    }
}

UnlockInstance(idx) {
    locked[idx] := 0
    ;LockInstanceIndicator(idx)
    ;cmd := Format("python.exe obs.py 2 {1}", idx)
    ;Run, %cmd%,, Hide
}

#Include Hotkeys.ahk
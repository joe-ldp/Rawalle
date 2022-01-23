; A Wall-Style Multi-Instance macro for Minecraft
; By Specnr, forked by Ravalle
; v0.4.0

#NoEnv
#SingleInstance Force
#Include MultiFunctions.ahk
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
    if (wideResets) {
        WinRestore, ahk_pid %pid%
        WinMove, ahk_pid %pid%,,0,0,%A_ScreenWidth%,%A_ScreenHeight%
        newHeight := Floor(A_ScreenHeight / 2.5)
        WinMove, ahk_pid %pid%,,0,0,%A_ScreenWidth%,%newHeight%
    }
    if (borderless) {
        WinSet, Style, -0xC40000, ahk_pid %pid%
    }
    UnlockInstance(i)
    WinSet, AlwaysOnTop, Off, ahk_pid %pid%
}

if (affinity) {
    for i, tmppid in PIDs {
        SetAffinity(tmppid, highBitMask)
    }
}

IfNotExist, %oldWorldsFolder%
    FileCreateDir %oldWorldsFolder%
if (!disableTTS)
    ComObjCreate("SAPI.SpVoice").Speak("Ready")

#Persistent
SetTimer, CheckScripts, 20
return

CheckScripts:
    Critical
    if (performanceMethod == "F") {
        toRemove := []
        for i, rIdx in resetIdx {
            idleCheck := McDirectories[rIdx] . "idle.tmp"
            if (A_TickCount - resetScriptTime[i] > scriptBootDelay && FileExist(idleCheck)) {
                SuspendInstance(PIDs[rIdx])
                toRemove.Push(resetScriptTime[i])
            }
        }
        for i, x in toRemove {
            idx := resetScriptTime.Length()
            while (idx) {
                resetTime := resetScriptTime[idx]
                if (x == resetTime) {
                    resetScriptTime.RemoveAt(idx)
                    resetIdx.RemoveAt(idx)
                }
                idx--
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
        if (useObsWebsocket) {
            cmd := Format("python.exe obs.py 1 {1}", idx)
            Run, %cmd%,, Hide
        }
        pid := PIDs[idx]
        if (affinity) {
            for i, tmppid in PIDs {
                if (tmppid != pid){
                SetAffinity(tmppid, lowBitMask)
                }
            }
        }
        if (performanceMethod == "F")
            ResumeInstance(pid)
        else if (performanceMethod == "S") {
            ControlSend, ahk_parent, {Blind}{Esc}, ahk_pid %pid%
            sleep, %settingsDelay%
            ResetSettings(pid, renderDistance, True)
            ControlSend, ahk_parent, {Blind}{F3 Down}{D}{F3 Up}, ahk_pid %pid%
        }
        WinSet, AlwaysOnTop, On, ahk_pid %pid%
        WinSet, AlwaysOnTop, Off, ahk_pid %pid%
        WinMinimize, Fullscreen Projector
        if (wideResets)
            WinMaximize, ahk_pid %pid%
        if (fullscreen) {
            ControlSend, ahk_parent, {Blind}{F11}, ahk_pid %pid%
            sleep, %fullScreenDelay%
        }
        send {LButton} ; Make sure the window is activated
        if (!useObsWebsocket) {
            send {Numpad%idx% down}
            sleep, %obsDelay%
            send {Numpad%idx% up}
        }
        if (coopResets) {
            ControlSend, ahk_parent, {Blind}{Esc}{Tab 7}{Enter}{Tab 4}{Enter}{Tab}{Enter}, ahk_pid %pid%
            Sleep, 500
            ControlSend, ahk_parent, /, ahk_pid %pid%
            Sleep, 100
            ControlSend, ahk_parent, {Text}time set 0, ahk_pid %pid%
        }
    }
}

ExitWorld()
{
    if (fullscreen) {
        send {F11}
        sleep, %fullScreenDelay%
    }
    if (idx := GetActiveInstanceNum()) > 0
    {
        pid := PIDs[idx]
        if (wideResets) {
            newHeight := Floor(A_ScreenHeight / 2.5)
            WinRestore, ahk_pid %pid%
            WinMove, ahk_pid %pid%,,0,0,%A_ScreenWidth%,%newHeight%
        }
        if (performanceMethod == "S") {
            ResetSettings(pid, lowRender)
        } else {
            ResetSettings(pid, renderDistance)
        }
        ControlSend, ahk_parent, {Blind}{Esc}, ahk_pid %pid%
        ResetInstance(idx)
        ToWall()
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
        UnlockInstance(idx)
        pid := PIDs[idx]
        if (performanceMethod == "F") {
            bfd := beforeFreezeDelay
            ResumeInstance(pid)
        } else {
            bfd := 0
        }
        ControlSend, ahk_parent, {Blind}{Esc 2}, ahk_pid %pid%
        ; Reset
        logFile := McDirectories[idx] . "logs\latest.log"
        If (FileExist(idleFile))
        FileDelete, %idleFile%
        Run, reset.ahk %pid% %logFile% %maxLoops% %bfd% %idleFile% %beforePauseDelay% %resetSounds%
        Critical, On
        resetScriptTime.Push(A_TickCount)
        resetIdx.Push(idx)
        Critical, Off
        
        ; Count Attempts
        if (countAttempts) {
            FileRead, WorldNumber, ATTEMPTS.txt
            if (ErrorLevel)
                WorldNumber = 0
            else
                FileDelete, ATTEMPTS.txt
            WorldNumber += 1
            FileAppend, %WorldNumber%, ATTEMPTS.txt
            FileRead, WorldNumber, ATTEMPTS_DAY.txt
            if (ErrorLevel)
                WorldNumber = 0
            else
                FileDelete, ATTEMPTS_DAY.txt
            WorldNumber += 1
            FileAppend, %WorldNumber%, ATTEMPTS_DAY.txt
        }
    }
}

ToWall() {
    WinActivate, Fullscreen Projector
    if (useObsWebsocket) {
        cmd := Format("python.exe obs.py 0", idx)
        Run, %cmd%,, Hide
    }
    else {
        send {F12 down}
        sleep, %obsDelay%
        send {F12 up}
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
    }
    else {
        LockInstance(idx)
    }
}

LockInstance(idx) {
    locked[idx] := True
    ;LockInstanceIndicator(idx)
    ;cmd := Format("python.exe obs.py 3 {1}", idx)
    ;Run, %cmd%,, Hide

    if (lockSounds)
        SoundPlay, lock.wav
}

UnlockInstance(idx) {
    locked[idx] := False
    ;LockInstanceIndicator(idx)
    ;cmd := Format("python.exe obs.py 2 {1}", idx)
    ;Run, %cmd%,, Hide
}
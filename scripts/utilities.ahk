; v1.4.0

CheckNetherStructures() {
	CheckBastions()
	CheckFortresses()
}

CheckBastions() {
	Send, /
	Sleep, 60
	Send, {Text}execute positioned 0 0 0 run locate bastion_remnant
	Send, {Enter}/
	Sleep, 60
	Send, {Text}execute positioned -1 0 0 run locate bastion_remnant
	Send, {Enter}/
	Sleep, 60
	Send, {Text}execute positioned 0 0 -1 run locate bastion_remnant
	Send, {Enter}/
	Sleep, 60
	Send, {Text}execute positioned -1 0 -1 run locate bastion_remnant
	Send, {Enter}
}

CheckFortresses() {
	Send, /
	Sleep, 60
	Send, {Text}execute positioned 0 0 0 run locate fortress
	Send, {Enter}/
	Sleep, 60
	Send, {Text}execute positioned -1 0 0 run locate fortress
	Send, {Enter}/
	Sleep, 60
	Send, {Text}execute positioned 0 0 -1 run locate fortress
	Send, {Enter}/
	Sleep, 60
	Send, {Text}execute positioned -1 0 -1 run locate fortress
	Send, {Enter}
}

CheckBuriedTreasure() {
	Send, /
	Sleep, 60
	Send, {Text}locate buried_treasure
	Send, {Enter}
}

CheckStronghold() {
	Send, /
	Sleep, 60
	Send, {Text}locate stronghold
	Send, {Enter}
}

OpenToLAN() {
    Send, {Esc}
	Sleep, 40
	Send, {Tab 7}{Enter}{Tab 4}{Enter}{Tab}{Enter}/
	Sleep, 60
	SetKeyDelay, 0
	Send, {Text}gamemode spectator
	Send, {Enter}/
	Sleep, 60
	Send, {Text}gamerule doImmediateRespawn true
	Send, {Enter}
}

SetPortal() {
	Send, /
	Sleep, 100
	Send, gamemode creative{Enter}
	Sleep, 50
	Send, /
	Sleep, 100
	Send, setblock ~ ~ ~ minecraft:nether_portal{Enter}
}

WideInst() {
	WinGetPos,,,, h, A
	if (h > wideHeight) {
		WinMove, A,, 0, %widePos%, %A_ScreenWidth%, %wideHeight%
	} else {
		WinRestore, A
		WinMaximize, A
	}
}

ThinInst() {
	WinGetPos,,, w,, A
	if (w > thinWidth) {
		WinMove, A,, %thinPos%, 0, %thinWidth%, %A_ScreenHeight%
	} else {
		WinRestore, A
		WinMaximize, A
	}
}

EyeZoom() {
	global eyeZoomWidth, eyeZoomHeight
	WinGetPos,,,,h,A
	if (h < eyeZoomHeight) {
		DllCall("SetWindowPos", "Ptr", WinExist("A"), "UInt", 0, "Int", 0, "Int", -(eyeZoomHeight/2.7), "Int", eyeZoomWidth, "Int", eyeZoomHeight, "UInt", 0x0400)	
	} else {
		WinRestore, A
		WinMaximize, A
	}
}
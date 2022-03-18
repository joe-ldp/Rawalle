SetKeyDelay, 0

CheckNetherStructures() {
	CheckBastions()
	CheckFortresses()
}

CheckBastions() {
	Send, /
	Sleep, 60
	Send, execute positioned 0 0 0 run locate bastion_remnant{Enter}
	Sleep, 60
	Send, /
	Sleep, 60
	Send, execute positioned -1 0 0 run locate bastion_remnant{Enter}
	Sleep, 60
	Send, /
	Sleep, 60
	Send, execute positioned 0 0 -1 run locate bastion_remnant{Enter}
	Sleep, 60
	Send, /
	Sleep, 60
	Send, execute positioned -1 0 -1 run locate bastion_remnant{Enter}
}

CheckFortresses() {
	Send, /
	Sleep, 60
	Send, execute positioned 0 0 0 run locate fortress{Enter}
	Sleep, 60
	Send, /
	Sleep, 60
	Send, execute positioned -1 0 0 run locate fortress{Enter}
	Sleep, 60
	Send, /
	Sleep, 60
	Send, execute positioned 0 0 -1 run locate fortress{Enter}
	Sleep, 60
	Send, /
	Sleep, 60
	Send, execute positioned -1 0 -1 run locate fortress{Enter}
}

CheckBuriedTreasure() {
	Send, /
	Sleep, 60
	Send, locate buried_treasure{Enter}
}

CheckStronghold() {
	Send, /
	Sleep, 60
	Send, locate stronghold{Enter}
}

OpenToLAN() {
    Send, {Esc}
	Sleep, 40
	Send, {Tab 7}{Enter}{Tab 4}{Enter}{Tab}{Enter}/
	Sleep, 100
	SetKeyDelay, 0
	Send, gamemode spectator{Enter}
	Send, /
	Sleep, 100
	Send, gamerule doImmediateRespawn true{Enter}
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

ResetPie() {
	Send, {RShift down}{F3}{RShift up}
	Sleep, 50
	Send, 00000000011900219003190041900519006190071900819009190019029014605602460560346056044605605460560
    Send, {RShift down}{F3}{RShift up}
	Sleep, 50
	Send, 00000000011900219003190041900519006190071900819009190019029014605602460560346056044605605460560
}
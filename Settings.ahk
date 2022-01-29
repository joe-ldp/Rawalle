; v0.4.1

; Wall Config
global rows := 4 ; Number of row on the wall scene
global cols := 3 ; Number of columns on the wall scene
global resetSounds := True ; :)
global lockSounds := True
global affinity := True ; A funky performance addition, enable for minor performance boost
global wideResets := True
global unpauseOnSwitch := True


; General Settings
global fullscreen := False
global disableTTS := False
global countAttempts := True
global borderless := True ; Sets instances to borderless windowed (like fullscreen, may have more input lag, but nicer otherwise)
global coopResets := False ; Use forceport and some method of forwarding port 25565


; Advanced settings
; General
global fullScreenDelay := 270 ; increase if fullscreening issues
global restartDelay := 200 ; increase if saying missing instanceNumber in .minecraft (and you ran setup)
global maxLoops := 50 ; increase if instance isnt resetting (or have to press reset twice)

; OBS settings
global obsDelay := 50 ; increase if not changing scenes in obs (only relevant if not using websocket)
global useObsWebsocket := True ; Allows for > 9 instances (Additional setup required)

; Performance related settings
global performanceMethod := "S" ; F = Instance Freezing, S = Settings Changing RD, N = Nothing
global lowBitmaskMultiplier := 0.5 ; for affinity, find a happy medium, max=1.0
; Instance freezing
global resumeDelay := 50 ; increase if instance isnt resetting (or have to press reset twice)
global beforeFreezeDelay := 500 ; increase if doesnt join world
global scriptBootDelay := 6000 ; increase if instance freezes before world gen
; Settings changes
global settingsDelay := 10 ; increase if settings arent changing
global beforePauseDelay := 500 ; basically the delay before dynamic FPS does its thing

; Set to 0 if you dont want to settings reset
; Sens and FOV may be off by 1, mess around with +-1 if you care about specifics
global renderDistance := 18
global FOV := 110 ; For quake pro put 110
global mouseSensitivity := 100
global lowRender := 5 ; For settings change performance method
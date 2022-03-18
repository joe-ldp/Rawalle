; v0.5.0-alpha

; General Settings
global fullscreen := False ; Enable to use fullscreen (as in F11)
global borderless := True ; Enable to use borderless windowed (like fullscreen, may have more input lag, but nicer otherwise)
; Fullscreen and borderless can both be set to True, it won't break anything, but there's little point in using both

global countAttempts := True
global coopResets := False ; Use forceport and some method of forwarding/sharing port 25565
global autoBop := True ; Automatically deletes old worlds when you open the macro

global renderDistance := 18
global fov := 110 ; Normal = 70, Quake pro = 110
global mouseSensitivity := 100
global entityDistance := 5 ; 50% = 0.5, 500% = 5


; Wall Config
global rows := 4 ; Number of rows on the wall scene
global cols := 3 ; Number of columns on the wall scene
global resetSounds := True ; :)
global lockSounds := True
global wideResets := True ; Wide resets for more vision on the wall
global bypassWall := False ; Switches directly to next locked instance when you reset, if one exists (only advised if you're background resetting)
global unpauseOnSwitch := True ; I personally recommend having this off if you use bypassWall, but try with and without


; Advanced settings
; General
global fullScreenDelay := 270 ; Increase if fullscreening issues
global restartDelay := 200 ; Increase if saying missing instanceNumber in .minecraft (and you ran setup)

; OBS settings
global obsDelay := 50 ; increase if not changing scenes in obs (only relevant if not using websocket)
global useObsWebsocket := True ; Allows for >9 instances (additional setup required)

; Performance related settings
; Affinity
global affinityLevel := 0.65 ; 1 = OFF, the lower it is, the less your active instance lags but the slower background instances generate
; Instance freezing
global instanceFreezing := False
global resumeDelay := 50 ; Increase if instance isn't resetting (or have to press reset twice)
global beforeFreezeDelay := 3000 ; increase if doesnt join world
; Settings changes
global settingsDelay := 10 ; Increase if settings aren't changing
global beforePauseDelay := 500 ; Basically the delay before dynamic FPS does its thing
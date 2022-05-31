; v1.0.0-beta

; General Settings
global numInstances := 12
global multiMCLocation := "C:\MultiMC"
global multiMCNameFormat := "1.16Inst#" ; Edit this to match your instance name formats (CASE SENSITIVE, beware)

global autoLaunchInstances := True ; Even if this is set to false, you must configure your MultiMC settings above
global autoCloseInstances := True ; Closes instances when you exit the macro via the taskbar
global launchPrograms := ["C:\Program Files\obs-studio\bin\64bit\obs64.exe", "C:\Documents\Speedrunning\Ninjabrain-Bot-1.2.0.jar"]
; If you don't want any programs auto launching (why not??) just set the above to []

global syncMods := False ; Syncs mods from the macro's central mod folder to all your instances before opening them
global mode := "Wall" ; Set to "Wall" for wall mode, "Multi" for multi mode
global fullscreen := False ; Enable to use fullscreen (as in F11)
global fullScreenDelay := 270 ; Increase if fullscreening issues
global borderless := False ; Enable to use borderless windowed (like fullscreen, may have more input lag, but nicer otherwise)
; Fullscreen and borderless can both be set to True, it won't break anything, but there's little point in using both
global disableTTS := False
global countResets := True
global coopResets := False ; Use forceport and some method of forwarding/sharing port 25565
global autoBop := False ; Automatically deletes old worlds when you open the macro

; Settings
global renderDistance := 18
global fov := 110 ; Normal = 70, Quake pro = 110
global mouseSensitivity := 100
global entityDistance := 5 ; 50% = 0.5, 500% = 5


; Wall Config
global rows := 3 ; Number of rows on the wall scene
global cols := 3 ; Number of columns on the wall scene
global resetSounds := True ; :)
global lockSounds := True
global wideResets := True ; Wide resets for more vision on the wall
global bypassWall := False ; Switches directly to next locked instance when you reset, if one exists (only advised if you're background resetting)
global unpauseOnSwitch := True ; I personally recommend having this off if you use bypassWall, but try with and without


; Performance related settings
global affinityLevel := 0.55 ; 1 = OFF, the lower it is, the less your active instance lags but the slower background instances generate
global performanceMethod := "S" ; S = Settings Changes, F = Instance Freezing, N = None
; Settings changes
global lowRender := 10
global settingsDelay := 30 ; Increase if settings aren't changing
; Instance freezing
global resumeDelay := 50 ; Increase if instance isn't resetting (or have to press reset twice)
global beforeFreezeDelay := 3000 ; increase if doesnt join world

; OBS settings
global obsDelay := 50 ; increase if not changing scenes in obs (only relevant if not using websocket)
; OBS WebSocket settings
global useObsWebsocket := True ; Allows for >9 instances, visual lock indicators, and world screenshotting
global screenshotWorlds := True
global host := "localhost"
global port := 4444
global password := "Multi"
global lockIndicators := True
global lockLayerFormat := "lock " ; obviously not relevant if you're not using lock indicators
global instanceSourceFormat := "mc "
global wallScene := "instance wall"
; Normal "multiple scene" setup
global instanceSceneFormat := "instance "
; Single scene setup
global singleSceneOBS := False
global playingScene := "playing scene"
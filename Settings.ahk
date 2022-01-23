; Variables to configure

; Wall Config
global rows := 4 ; Number of row on the wall scene
global cols := 3 ; Number of columns on the wall scene
global resetSounds := True ; :)
global lockSounds := True
global performanceMethod := "S" ; F = Instance Freezing, S = Settings Changing RD, N = Nothing
global affinity := True ; A funky performance addition, enable for minor performance boost
global wideResets := True
global fullscreen := False

; General Settings
global disableTTS := False
global countAttempts := True
global borderless := True
global coopResets := True ; Use forceport and some method of forwarding port 25565

; Advanced settings

global resumeDelay := 50 ; increase if instance isnt resetting (or have to press reset twice)
global maxLoops := 50 ; increase if instance isnt resetting (or have to press reset twice)
global beforeFreezeDelay := 500 ; increase if doesnt join world
global beforePauseDelay := 500 ; basically the delay before dynamic FPS does its thing
global fullScreenDelay := 270 ; increse if fullscreening issues
global restartDelay := 200 ; increase if saying missing instanceNumber in .minecraft (and you ran setup)
global scriptBootDelay := 6000 ; increase if instance freezes before world gen
global obsDelay := 50 ; increase if not changing scenes in obs
global settingsDelay := 10 ; increase if settings arent changing
global lowBitmaskMultiplier := 0.5 ; for affinity, find a happy medium, max=1.0
global useObsWebsocket := True ; Allows for > 9 instances (Additional setup required)

; Set to 0 if you dont want to settings reset
; Sense and FOV may be off by 1, mess around with +-1 if you care about specifics
global renderDistance := 18
global FOV := 110 ; For quake pro put 110
global mouseSensitivity := 100
global lowRender := 5 ; For settings change performance method

; Hotkeys

RAlt::Suspend ; Pause all macros
NumpadHome:: ; Reload if macro locks up
  Reload
return
#IfWinActive, Minecraft
{
  *F19:: ExitWorld() ; Reset

  *NumpadAdd::ResetAll()

  *NumpadDiv::LockInstance(1)
  *NumpadMult::LockInstance(2)
  *NumpadSub::LockInstance(3)
  *Numpad7::LockInstance(4)
  *Numpad8::LockInstance(5)
  *Numpad9::LockInstance(6)
  *Numpad4::LockInstance(7)
  *Numpad5::LockInstance(8)
  *Numpad6::LockInstance(9)
  *Numpad1::LockInstance(10)
  *Numpad2::LockInstance(11)
  *Numpad3::LockInstance(12)
}
return
NumpadIns::SetTitles()

#IfWinActive, Fullscreen Projector
{
  *E::ResetInstance(MousePosToInstNumber())
  *R::SwitchInstance(MousePosToInstNumber())
  *F::FocusReset(MousePosToInstNumber())
  *T::ResetAll()
  +LButton::LockInstance(MousePosToInstNumber()) ; lock an instance so the above "blanket reset" functions don't reset it
}
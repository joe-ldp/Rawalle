; v1.0.0-beta

*RAlt::Suspend ; Pause all hotkeys
^RAlt::Reboot()
;*I::SetTitles() ; Set titles if you are setting up obs

#If WinActive("Minecraft") && WinActive("ahk_exe javaw.exe")
{
    *U::Reset()
    *P::ResetPie()
    
    ; Checking functions lol
    ; Uncomment (remove ;s) from the following lines if you want these hotkeys
    ;*[::CheckNetherStructures()
    ;*]::CheckBuriedTreasure()
    ;*L::CheckStronghold()
    ;*J::OpenToLAN()
    ;*M::SetPortal()
}

#IfWinActive, Fullscreen Projector
{
    *E::Reset(MousePosToInstNumber())
    *R::Play(MousePosToInstNumber())
    *F::FocusReset(MousePosToInstNumber())
    *T::ResetAll()
    +LButton::ToggleLock(MousePosToInstNumber()) ; lock an instance so the above "blanket reset" functions don't reset it

    ; Reset keys (1-9)
    *1::Reset(1)
    *2::Reset(2)
    *3::Reset(3)
    *4::Reset(4)
    *5::Reset(5)
    *6::Reset(6)
    *7::Reset(7)
    *8::Reset(8)
    *9::Reset(9)

    ; Play instance keys (Shift + 1-9)
    +1::Play(1)
    +2::Play(2)
    +3::Play(3)
    +4::Play(4)
    +5::Play(5)
    +6::Play(6)
    +7::Play(7)
    +8::Play(8)
    +9::Play(9)
    
    ; Focus reset instance keys (Control + 1-9)
    ^1::FocusReset(1)
    ^2::FocusReset(2)
    ^3::FocusReset(3)
    ^4::FocusReset(4)
    ^5::FocusReset(5)
    ^6::FocusReset(6)
    ^7::FocusReset(7)
    ^8::FocusReset(8)
    ^9::FocusReset(9)

    ; Lock instance keys (Alt + 1-9)
    !1::LockInstance(1)
    !2::LockInstance(2)
    !3::LockInstance(3)
    !4::LockInstance(4)
    !5::LockInstance(5)
    !6::LockInstance(6)
    !7::LockInstance(7)
    !8::LockInstance(8)
    !9::LockInstance(9)
}

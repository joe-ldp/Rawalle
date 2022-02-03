; v0.4.2

RAlt::Suspend ; Pause all macros
NumpadHome:: ; Reload if macro locks up
    Reload
return

NumpadIns::SetTitles()

#IfWinActive, Minecraft
{
    *U::ExitWorld()

    *NumpadAdd::ResetAll()
    *`::ResetAll()
    
    *Numpad7::LockInstance(1)
    *Numpad8::LockInstance(2)
    *Numpad9::LockInstance(3)
    *Numpad4::LockInstance(4)
    *Numpad5::LockInstance(5)
    *Numpad6::LockInstance(6)
    *Numpad1::LockInstance(7)
    *Numpad2::LockInstance(8)
    *Numpad3::LockInstance(9)
}

#IfWinActive, Fullscreen Projector
{
    *E::ResetInstance(MousePosToInstNumber())
    *R::SwitchInstance(MousePosToInstNumber())
    *F::FocusReset(MousePosToInstNumber())
    *T::ResetAll()
    +LButton::LockInstance(MousePosToInstNumber()) ; lock an instance so the above "blanket reset" functions don't reset it

    ; Reset keys (1-9)
    *1::ResetInstance(1)
    *2::ResetInstance(2)
    *3::ResetInstance(3)
    *4::ResetInstance(4)
    *5::ResetInstance(5)
    *6::ResetInstance(6)
    *7::ResetInstance(7)
    *8::ResetInstance(8)
    *9::ResetInstance(9)

    ; Switch to instance keys (Shift + 1-9)
    +1::SwitchInstance(1)
    +2::SwitchInstance(2)
    +3::SwitchInstance(3)
    +4::SwitchInstance(4)
    +5::SwitchInstance(5)
    +6::SwitchInstance(6)
    +7::SwitchInstance(7)
    +8::SwitchInstance(8)
    +9::SwitchInstance(9)
    
    ; Focus reset instance keys (Shift + 1-9)
    ^1::FocusReset(1)
    ^2::FocusReset(2)
    ^3::FocusReset(3)
    ^4::FocusReset(4)
    ^5::FocusReset(5)
    ^6::FocusReset(6)
    ^7::FocusReset(7)
    ^8::FocusReset(8)
    ^9::FocusReset(9)
    }

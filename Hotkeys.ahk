; v0.4.3

RAlt::Suspend ; Pause all macros
^LAlt::Reload
^RCtrl::UnsuspendAll()
*I::SetTitles() ; Set titles if you are setting up obs

#IfWinActive, Minecraft
{
    *U::Reset()

    *NumpadAdd::ResetAll()
    *`::ResetAll() ; 2 hotkeys on opposite sides of the keyboard just for convenience
    
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
    *E::Reset(MousePosToInstNumber())
    *R::Play(MousePosToInstNumber())
    *F::FocusReset(MousePosToInstNumber())
    *T::ResetAll()
    +LButton::LockInstance(MousePosToInstNumber()) ; lock an instance so the above "blanket reset" functions don't reset it

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

    ; Switch to instance keys (Shift + 1-9)
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
}
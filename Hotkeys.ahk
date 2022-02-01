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
    *¬::ResetAll()
    
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
}
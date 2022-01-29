; v0.4.1

RAlt::Suspend ; Pause all macros
NumpadHome:: ; Reload if macro locks up
  Reload
return

NumpadIns::SetTitles()

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

#IfWinActive, Fullscreen Projector
{
  *E::ResetInstance(MousePosToInstNumber())
  *R::SwitchInstance(MousePosToInstNumber())
  *F::FocusReset(MousePosToInstNumber())
  *T::ResetAll()
  +LButton::LockInstance(MousePosToInstNumber()) ; lock an instance so the above "blanket reset" functions don't reset it
}
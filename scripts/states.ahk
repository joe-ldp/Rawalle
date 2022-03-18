global STATE_INIT       := 0 ; Unknown
global STATE_READY      := 1 ; World fully loaded, game paused
global STATE_PLAYING    := 2 ; Playing. May be paused/in an inventory/etc
global STATE_RESETTING  := 3 ; Undergoing settings changes, widening, or on saving/loading screen
global STATE_PREVIEWING := 4 ; On preview screen
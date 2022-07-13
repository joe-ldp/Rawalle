# Rawalle 

## Setup Video

Watch the [NEW Multi Instance & Wall Setup Video](https://youtu.be/0xAHMW93MQw)

## GUI for Settings & Hotkeys

Most settings & hotkeys are easily configurable using `Rawalle Config.exe`

You can add new/custom keybinds by editing customHotkeys.ahk. Hopefully this will be removed in the future as everything is planned to be editable via the GUI.

## Basic Usage

To use the macro, run TheWall.ahk and wait for it to say ready. Start up OBS, then start up a [Fullscreen projector](https://youtu.be/9YqZ6Ogv3rk).

On the Fullscreen Projector, you have a few hotkeys: 
- T: Reset All - Resets all instances
Mouse-based hotkeys:
- E: Reset - Resets the instance which your mouse is hovering over
- R: Play - Plays the instance which your mouse is hovering over
- F: Focus Reset - Plays the instance which your mouse is hovering over, and resets the rest
- Shift + Left Click: Lock instance so Reset All and Focus Reset skip over it
Keyboard-based hotkeys:
- (1-9): Resets the corresponding instance
- Shift + (1-9): Plays the corresponding instance
- Ctrl + (1-9): Plays the corresponding instance, and reset the rest
- Alt + (1-9): Locks the corresponding instance so Reset All and Focus Reset skip over it

## Background Resetting

When in-game, you can reset other instances in the background. To do this, I'd advise:

- Right click on wall scene (or your verification scene) in OBS scene list
- Open a windowed projector
- Make it small, put it somewhere convenient
- Right click it -> select stay on top

To actually background reset, lock good looking instances then reset all.

I'd advise messing with the default hotkeys for background resetting in customHotkeys.ahk (will be accessible via the config GUI later) and finding something you're comfortable with.
(Don't worry about these being bound to numpad keys and it affecting your OBS - when the macro is running, the key presses won't affect OBS)

## Other extra features

- Borderless: Like fullscreen, but less annoying and easier for OBS to capture. May have more input lag than fullscreen, but try it out.
- Coop resets: When enabled, the macro will open to lan (with cheats on) when you play an instance.
- Bypass wall: When you reset, if there are any other instances currently locked you will get sent straight to that instance, bypassing the wall entirely. I only recommend this if you're background resetting.
- Unpause on switch: Unpause or don't unpause when you play an instance
- Auto-bop: Automatically deletes old worlds when you load up the macro. Intend to improve the safety of this feature in the future in regards to accidental activation.

No longer actively moves worlds, it slows down the macro a lot. Use [this world moving macro](https://gist.github.com/Specnr/f7a5450d932a1277fdcd6c141ad7bf6a).

## OBS Websocket

1) Download [Python](https://www.python.org/downloads/)
2) Install [OBS websocket](https://obsproject.com/forum/resources/obs-websocket-remote-control-obs-studio-from-websockets.466/)
3) Open up command prompt, and run this command in `pip install obs-websocket-py`
4) You can use a password if you want. To set one, go to `Tools -> WebSockets Server Settings -> Enable Authentication` in OBS.

## Credit

- Specnr for creating the original public Wall macro which I learned a lot from
- Algorythm for backseating my code a bunch
- The collaborators listed on GitHub for minor enhancements (most of these are actually carried over from Specnr's macro and their code isn't here anymore lol)
- jojoe77777 for making the original wall macro
- Everyone I can't list who has contributed ideas
- Everyone who's tried early/buggy versions and reported issues

# Rawalle

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/ravalle)

## Tech Support

[Join the Discord](https://discord.gg/g4qVPMuYc4) and read the FAQ **AFTER** reading this page. If you still have unanswered questions, open a ticket in [#tech-support](https://discord.com/channels/913143777806417983/1000403129310924910).

## Setup

This macro doesn't need much setup outside of the config exe. All you need to do is make sure you're using MultiMC (the macro does not support vanilla launcher!) and make sure your instances are named the same as their folders (i.e. Inst1 is located at /MultiMC/instances/Inst1). Then as long as your instance names follow a pattern (like Inst1, Inst2 etc) you're fine.

## GUI for Settings & Hotkeys

Most settings & hotkeys are easily configurable using `Rawalle Config.exe`

You can add new/custom keybinds by editing customHotkeys.ahk. Hopefully this will be removed in the future as everything is planned to be editable via the GUI.

# Hotkey Error Codes

Due to technical restrictions when creating the GUI, some hotkey binds may cause errors when you load the macro.
- Error code 2: The GUI failed to translate the name of a key to a valid AutoHotkey key name. Check your hotkeys.ini, there should be a key with a weird name (probably "OemKeyX"). Change it to the valid key name listed [here](https://www.autohotkey.com/docs/KeyList.htm).
- Error code 3: [Unsupported prefix key](https://www.autohotkey.com/docs/commands/Hotkey.htm#ErrorLevel). Likely only encountered if you manually edited a hotkey in `hotkeys.ini` and didn't format it correctly.
- Other error codes not listed: If you encounter any of these, I'm guessing you edited the macro. If you didn't then [join the Discord](https://discord.gg/g4qVPMuYc4) and open a ticket in [#tech-support](https://discord.com/channels/913143777806417983/1000403129310924910). [More info on Hotkey error codes here](https://www.autohotkey.com/docs/commands/Hotkey.htm#ErrorLevel).

## Basic Usage

To use the macro, run Rawalle.ahk and wait for it to say ready. Then open an OBS [Fullscreen Projector](https://youtu.be/9YqZ6Ogv3rk).

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

## Other extra features

- Borderless: Like fullscreen, but less annoying and easier for OBS to capture. May have more input lag than fullscreen, but try it out.
- Co-op resets: When enabled, the macro will open to lan (with cheats on) when you play an instance.
- Bypass wall: When you reset, if there are any other instances currently locked you will get sent straight to that instance, bypassing the wall entirely. I only recommend this if you're background resetting.
- Unpause on switch: Unpause or don't unpause when you play an instance
- Auto-bop: Automatically deletes old worlds when you load up the macro.

## OBS Websocket

1) Download [Python](https://www.python.org/downloads/)
2) Install [OBS websocket](https://obsproject.com/forum/resources/obs-websocket-remote-control-obs-studio-from-websockets.466/)
3) Open command prompt, and run the following command: `pip install obs-websocket-py`
4) You can use a password if you want. To set one, go to `Tools -> WebSockets Server Settings -> Enable Authentication` in OBS.

## Credit

- Specnr for creating the original public Wall macro which I learned a lot from
- Algorythm for backseating my code a bunch
- The collaborators listed on GitHub for minor enhancements (most of these are actually carried over from Specnr's macro and their code isn't here anymore lol)
- jojoe77777 for making the original Wall macro (and general contribution to macros/tech)
- Everyone I can't list who has contributed ideas
- Everyone who's tried early/buggy versions and reported issues (Especially poni and priffin!)
- Everyone who's reported issues and been patient while I try to debug them

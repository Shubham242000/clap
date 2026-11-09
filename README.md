# lidsound

A tiny macOS menu bar app that plays a sound when you open or close your laptop lid.

## Build & run

```bash
swiftc -O lidsound.swift -o lidsound
./lidsound
```

A laptop icon appears in the menu bar. From its menu you can:

- **Enabled** — turn the sounds on/off without quitting
- **Open Sound / Close Sound** — pick from a few built-in macOS sounds, or choose your own audio file; picking an option previews it immediately
- **Launch at Login** — registers (or unregisters) a `launchd` agent so the app starts automatically when you log in
- **Quit**

## How it works

It polls `IOPMrootDomain`'s `AppleClamshellState` property (the same hardware flag macOS itself uses) every 0.1 seconds, and plays the chosen sound via `afplay` whenever that state flips.

## Requirements

macOS with Swift toolchain (Xcode Command Line Tools). No external dependencies.

# lidsound

A tiny macOS menu bar app that plays a sound when you open or close your laptop lid.

## Build & run

```bash
./build.sh         # builds LidSound.app
open LidSound.app  # launch it, or just double-click it in Finder
```

Drag `LidSound.app` into `/Applications` to keep it like any other app, and launch it from Spotlight or Launchpad.

A laptop icon appears in the menu bar. From its menu you can:

- **Enabled** — turn the sounds on/off without quitting
- **Open Sound / Close Sound** — pick from a few built-in macOS sounds, or choose your own audio file; picking an option previews it immediately
- **Launch at Login** — registers (or unregisters) a `launchd` agent so the app starts automatically when you log in
- **Quit**

The icon itself reflects lid state: a laptop glyph when open, a sleeping moon when closed.

## How it works

It polls `IOPMrootDomain`'s `AppleClamshellState` property (the same hardware flag macOS itself uses) every 0.1 seconds, and plays the chosen sound via `afplay` whenever that state flips.

## Requirements

macOS with Swift toolchain (Xcode Command Line Tools). No external dependencies.

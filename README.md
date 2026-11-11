# Clap

A tiny macOS menu bar app that plays a sound when you open or close your laptop lid.

[**shubham242000.github.io/clap →**](https://shubham242000.github.io/clap/)

## Install

```bash
git clone https://github.com/Shubham242000/clap.git
cd clap
./build.sh    # builds Clap.app
open Clap.app # launch it, or just double-click it in Finder
```

Drag `Clap.app` into `/Applications` to keep it like any other app, and launch it from Spotlight or Launchpad.

There's no prebuilt download — Clap isn't signed with a paid Apple Developer certificate, so a downloaded `.app` gets flagged by Gatekeeper as "damaged" and refuses to open. Building it locally takes 10 seconds and sidesteps that entirely, since locally-compiled apps aren't quarantined.

## Usage

A clapping-hands icon appears in the menu bar. From its menu you can:

- **Enabled** — turn the sounds on/off without quitting
- **Open Sound / Close Sound** — pick **None**, one of the built-in sounds, or your own audio file; picking an option previews it immediately
- **Launch at Login** — registers (or unregisters) a `launchd` agent so the app starts automatically when you log in
- **Quit**

## How it works

It polls `IOPMrootDomain`'s `AppleClamshellState` property (the same hardware flag macOS itself uses) every 0.1 seconds, and plays the chosen sound in-process (`NSSound`) whenever that state flips. Because closing the lid usually puts the Mac to sleep faster than the poll can react, it also registers for system sleep notifications (`IORegisterForSystemPower`): when sleep begins with the lid closed, it plays the close sound and holds off acknowledging the sleep until the sound finishes, so it isn't frozen mid-play and replayed on wake. It disables App Nap for itself (`ProcessInfo.beginActivity`) so the poll loop keeps running at full speed even while backgrounded — otherwise macOS throttles it enough to miss the lid-close transition before the Mac fully sleeps.

## Requirements

macOS. Building from source additionally requires the Swift toolchain (Xcode Command Line Tools). No external dependencies either way.

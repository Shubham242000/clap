# Clap

A tiny macOS menu bar app that plays a sound when you open or close your laptop lid.

[**shubham242000.github.io/clap →**](https://shubham242000.github.io/clap/)

## Install

### Option 1: Download (easiest)

1. Download the latest `Clap.app.zip` from [Releases](https://github.com/Shubham242000/clap/releases/latest)
2. Unzip it, then drag `Clap.app` into `/Applications`
3. Open it. Since it's not notarized, macOS will warn it's from an unidentified developer — right-click the app and choose **Open** the first time (or go to **System Settings → Privacy & Security → Open Anyway**)

### Option 2: Build from source

```bash
git clone https://github.com/Shubham242000/clap.git
cd clap
./build.sh    # builds Clap.app
open Clap.app # launch it, or just double-click it in Finder
```

Drag `Clap.app` into `/Applications` to keep it like any other app, and launch it from Spotlight or Launchpad.

## Usage

A clapping-hands icon appears in the menu bar. From its menu you can:

- **Enabled** — turn the sounds on/off without quitting
- **Open Sound / Close Sound** — pick from a few built-in macOS sounds, or choose your own audio file; picking an option previews it immediately
- **Launch at Login** — registers (or unregisters) a `launchd` agent so the app starts automatically when you log in
- **Quit**

## How it works

It polls `IOPMrootDomain`'s `AppleClamshellState` property (the same hardware flag macOS itself uses) every 0.1 seconds, and plays the chosen sound via `afplay` whenever that state flips. It disables App Nap for itself (`ProcessInfo.beginActivity`) so the poll loop keeps running at full speed even while backgrounded — otherwise macOS throttles it enough to miss the lid-close transition before the Mac fully sleeps.

## Requirements

macOS. Building from source additionally requires the Swift toolchain (Xcode Command Line Tools). No external dependencies either way.

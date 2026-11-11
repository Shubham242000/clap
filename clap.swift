// clap.swift — menu bar app that plays a sound when the MacBook lid closes or opens.
// Build:  ./build.sh
// Run:    open Clap.app
import Cocoa
import IOKit
import IOKit.pwr_mgt
import UniformTypeIdentifiers

func bundledSoundPath(_ filename: String) -> String {
    let resourceDir = Bundle.main.resourcePath
        ?? (URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().path)
    return resourceDir + "/Sounds/" + filename
}

// Original sounds shipped with the app.
let bundledSounds: [(name: String, path: String)] = [
    ("Chime", bundledSoundPath("chime.wav")),
    ("Drop", bundledSoundPath("drop.wav")),
    ("Pixel Blip", bundledSoundPath("blip.wav")),
    ("Swoosh", bundledSoundPath("swoosh.wav")),
    ("Marimba", bundledSoundPath("marimba.wav")),
]

// Stock macOS system sounds offered in the menu as well.
let systemSounds: [(name: String, path: String)] = [
    ("Glass", "/System/Library/Sounds/Glass.aiff"),
    ("Pop", "/System/Library/Sounds/Pop.aiff"),
    ("Ping", "/System/Library/Sounds/Ping.aiff"),
    ("Sosumi", "/System/Library/Sounds/Sosumi.aiff"),
    ("Bottle", "/System/Library/Sounds/Bottle.aiff"),
    ("Basso", "/System/Library/Sounds/Basso.aiff"),
]

let allSounds = bundledSounds + systemSounds

let defaults = UserDefaults.standard
let kOpenSoundPath = "openSoundPath"
let kCloseSoundPath = "closeSoundPath"
let kEnabled = "enabled"

let loginAgentLabel = "com.shubhamshrivastava.clap"
let loginAgentPlist = ("\(NSHomeDirectory())/Library/LaunchAgents/\(loginAgentLabel).plist")

// Empty path means "None" — no sound for that event.
let noSoundPath = ""

// Plays in-process (not via afplay) so playback starts instantly and can be
// stopped — a stray sound frozen by sleep must not resume on wake.
var currentSound: NSSound?

@discardableResult
func play(_ path: String) -> TimeInterval {
    currentSound?.stop()
    currentSound = nil
    guard !path.isEmpty, let sound = NSSound(contentsOfFile: path, byReference: true) else { return 0 }
    currentSound = sound
    sound.play()
    return sound.duration
}

func stopSound() {
    currentSound?.stop()
    currentSound = nil
}

// IOKit power message codes (the C macros aren't imported into Swift).
let kMsgCanSystemSleep: UInt32 = 0xE000_0270
let kMsgSystemWillSleep: UInt32 = 0xE000_0280
let kMsgSystemHasPoweredOn: UInt32 = 0xE000_0300

// Reads the lid state straight from the hardware (IOPMrootDomain).
func lidClosed() -> Bool? {
    let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
    guard service != 0 else { return nil }
    defer { IOObjectRelease(service) }
    guard let prop = IORegistryEntryCreateCFProperty(
        service, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0
    )?.takeRetainedValue() else { return nil }
    return prop as? Bool
}

func currentExecutablePath() -> String {
    URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL.path
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    var last = lidClosed() ?? false
    var timer: Timer?
    // Held for the app's lifetime: a menu-bar app with no visible window gets
    // throttled by App Nap, which would make the poll loop too slow to catch
    // the lid-close event before the Mac fully sleeps.
    var activity: NSObjectProtocol?
    // System power notifications: lets us delay sleep until the close sound finishes.
    var rootPort: io_connect_t = 0
    var notifyPort: IONotificationPortRef?
    var notifier: io_object_t = 0
    // When the in-flight close sound will finish (so sleep can wait for it).
    var closeSoundEndsAt: Date?

    func applicationDidFinishLaunching(_ notification: Notification) {
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep],
            reason: "Watching lid state to play open/close sounds"
        )
        if defaults.object(forKey: kEnabled) == nil { defaults.set(true, forKey: kEnabled) }
        if defaults.string(forKey: kOpenSoundPath) == nil { defaults.set(bundledSounds[0].path, forKey: kOpenSoundPath) }
        if defaults.string(forKey: kCloseSoundPath) == nil { defaults.set(bundledSounds[1].path, forKey: kCloseSoundPath) }

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "hands.clap.fill", accessibilityDescription: "Clap")
        }
        statusItem.menu = buildMenu()

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        registerForSleepNotifications()
    }

    func tick() {
        guard let now = lidClosed(), now != last else { return }
        last = now
        guard defaults.bool(forKey: kEnabled) else { return }
        if now {
            playCloseSound()
        } else {
            closeSoundEndsAt = nil
            play(defaults.string(forKey: kOpenSoundPath)!)
        }
    }

    func playCloseSound() {
        let duration = play(defaults.string(forKey: kCloseSoundPath)!)
        closeSoundEndsAt = duration > 0 ? Date().addingTimeInterval(duration) : nil
    }

    func registerForSleepNotifications() {
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        rootPort = IORegisterForSystemPower(refcon, &notifyPort, { refcon, _, messageType, messageArgument in
            guard let refcon = refcon else { return }
            let me = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()
            me.handlePower(messageType, Int(bitPattern: messageArgument))
        }, &notifier)
        if rootPort != 0, let port = notifyPort {
            CFRunLoopAddSource(CFRunLoopGetMain(),
                               IONotificationPortGetRunLoopSource(port).takeUnretainedValue(),
                               .commonModes)
        }
    }

    func handlePower(_ message: UInt32, _ token: Int) {
        switch message {
        case kMsgCanSystemSleep:
            IOAllowPowerChange(rootPort, token)
        case kMsgSystemWillSleep:
            // Lid-close sleep usually beats the poll loop. Play the close sound
            // now (if the poll hasn't already) and hold off sleep until it ends.
            if defaults.bool(forKey: kEnabled), lidClosed() == true, !last {
                last = true
                playCloseSound()
            }
            let remaining = min(max(closeSoundEndsAt?.timeIntervalSinceNow ?? 0, 0), 5)
            DispatchQueue.main.asyncAfter(deadline: .now() + remaining + 0.05) { [self] in
                closeSoundEndsAt = nil
                IOAllowPowerChange(rootPort, token)
            }
        case kMsgSystemHasPoweredOn:
            // Never let a leftover close sound bleed into the open sound.
            stopSound()
            closeSoundEndsAt = nil
        default:
            break
        }
    }

    func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let enabledItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        enabledItem.target = self
        enabledItem.state = defaults.bool(forKey: kEnabled) ? .on : .off
        menu.addItem(enabledItem)

        menu.addItem(.separator())

        let openItem = NSMenuItem(title: "Open Sound", action: nil, keyEquivalent: "")
        openItem.submenu = soundSubmenu(selectedPath: defaults.string(forKey: kOpenSoundPath)!, key: kOpenSoundPath, action: #selector(selectOpenSound(_:)), customAction: #selector(chooseCustomOpenSound))
        menu.addItem(openItem)

        let closeItem = NSMenuItem(title: "Close Sound", action: nil, keyEquivalent: "")
        closeItem.submenu = soundSubmenu(selectedPath: defaults.string(forKey: kCloseSoundPath)!, key: kCloseSoundPath, action: #selector(selectCloseSound(_:)), customAction: #selector(chooseCustomCloseSound))
        menu.addItem(closeItem)

        menu.addItem(.separator())

        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = FileManager.default.fileExists(atPath: loginAgentPlist) ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        return menu
    }

    func soundSubmenu(selectedPath: String, key: String, action: Selector, customAction: Selector) -> NSMenu {
        let submenu = NSMenu()
        let noneItem = NSMenuItem(title: "None", action: action, keyEquivalent: "")
        noneItem.target = self
        noneItem.representedObject = noSoundPath
        noneItem.state = selectedPath == noSoundPath ? .on : .off
        submenu.addItem(noneItem)
        submenu.addItem(.separator())
        for sound in bundledSounds {
            let item = NSMenuItem(title: sound.name, action: action, keyEquivalent: "")
            item.target = self
            item.representedObject = sound.path
            item.state = (sound.path == selectedPath) ? .on : .off
            submenu.addItem(item)
        }
        submenu.addItem(.separator())
        for sound in systemSounds {
            let item = NSMenuItem(title: sound.name, action: action, keyEquivalent: "")
            item.target = self
            item.representedObject = sound.path
            item.state = (sound.path == selectedPath) ? .on : .off
            submenu.addItem(item)
        }
        submenu.addItem(.separator())
        let isCustom = selectedPath != noSoundPath && !allSounds.contains { $0.path == selectedPath }
        let customLabel = isCustom ? "Choose File... (\((selectedPath as NSString).lastPathComponent))" : "Choose File..."
        let customItem = NSMenuItem(title: customLabel, action: customAction, keyEquivalent: "")
        customItem.target = self
        customItem.state = isCustom ? .on : .off
        submenu.addItem(customItem)
        return submenu
    }

    @objc func toggleEnabled() {
        defaults.set(!defaults.bool(forKey: kEnabled), forKey: kEnabled)
        statusItem.menu = buildMenu()
    }

    @objc func selectOpenSound(_ sender: NSMenuItem) {
        let path = sender.representedObject as! String
        defaults.set(path, forKey: kOpenSoundPath)
        statusItem.menu = buildMenu()
        play(path)
    }

    @objc func selectCloseSound(_ sender: NSMenuItem) {
        let path = sender.representedObject as! String
        defaults.set(path, forKey: kCloseSoundPath)
        statusItem.menu = buildMenu()
        play(path)
    }

    func pickCustomSound(completion: (String) -> Void) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            completion(url.path)
        }
    }

    @objc func chooseCustomOpenSound() {
        pickCustomSound { path in
            defaults.set(path, forKey: kOpenSoundPath)
            statusItem.menu = buildMenu()
            play(path)
        }
    }

    @objc func chooseCustomCloseSound() {
        pickCustomSound { path in
            defaults.set(path, forKey: kCloseSoundPath)
            statusItem.menu = buildMenu()
            play(path)
        }
    }

    @objc func toggleLaunchAtLogin() {
        if FileManager.default.fileExists(atPath: loginAgentPlist) {
            let unload = Process()
            unload.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            unload.arguments = ["unload", "-w", loginAgentPlist]
            try? unload.run()
            unload.waitUntilExit()
            try? FileManager.default.removeItem(atPath: loginAgentPlist)
        } else {
            let plist = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>Label</key><string>\(loginAgentLabel)</string>
                <key>ProgramArguments</key>
                <array><string>\(currentExecutablePath())</string></array>
                <key>RunAtLoad</key><true/>
                <key>KeepAlive</key><false/>
                <key>StandardOutPath</key><string>/tmp/clap.log</string>
                <key>StandardErrorPath</key><string>/tmp/clap.err</string>
            </dict>
            </plist>
            """
            let dir = (loginAgentPlist as NSString).deletingLastPathComponent
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try? plist.write(toFile: loginAgentPlist, atomically: true, encoding: .utf8)

            let load = Process()
            load.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            load.arguments = ["load", "-w", loginAgentPlist]
            try? load.run()
            load.waitUntilExit()
        }
        statusItem.menu = buildMenu()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

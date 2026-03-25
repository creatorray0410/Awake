import AppKit
import IOKit.pwr_mgt

// MARK: - SleepManager

class SleepManager {
    
    enum SleepPreventionMode: String {
        case displayAndSystem = "Display & System"
        case systemOnly = "System Only"
    }
    
    private var assertionID: IOPMAssertionID = 0
    private(set) var isActive = false
    private(set) var mode: SleepPreventionMode = .displayAndSystem
    private var timer: Timer?
    private(set) var remainingSeconds: Int = 0
    private(set) var isTimerMode = false
    
    var onTimerTick: (() -> Void)?
    var onTimerEnd: (() -> Void)?
    
    func activate(mode: SleepPreventionMode = .displayAndSystem) {
        if isActive { deactivate() }
        self.mode = mode
        
        let reason = "Awake is keeping your Mac awake" as NSString
        let assertionType: NSString
        
        switch mode {
        case .displayAndSystem:
            assertionType = kIOPMAssertionTypePreventUserIdleDisplaySleep as NSString
        case .systemOnly:
            assertionType = kIOPMAssertionTypePreventUserIdleSystemSleep as NSString
        }
        
        let result = IOPMAssertionCreateWithName(
            assertionType,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )
        isActive = (result == kIOReturnSuccess)
    }
    
    func activateWithTimer(minutes: Int, mode: SleepPreventionMode = .displayAndSystem) {
        activate(mode: mode)
        guard isActive else { return }
        
        isTimerMode = true
        remainingSeconds = minutes * 60
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.remainingSeconds -= 1
            self.onTimerTick?()
            
            if self.remainingSeconds <= 0 {
                self.deactivate()
                self.onTimerEnd?()
            }
        }
    }
    
    func deactivate() {
        timer?.invalidate()
        timer = nil
        isTimerMode = false
        remainingSeconds = 0
        
        guard isActive else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
        isActive = false
    }
    
    func formattedRemainingTime() -> String {
        let hours = remainingSeconds / 3600
        let minutes = (remainingSeconds % 3600) / 60
        let seconds = remainingSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    deinit { deactivate() }
}


// MARK: - MenuBarController

class MenuBarController: NSObject {
    
    private var statusItem: NSStatusItem!
    private let sleepManager = SleepManager()
    
    private let timerOptions: [(String, Int)] = [
        ("10 Minutes", 10),
        ("30 Minutes", 30),
        ("1 Hour", 60),
        ("2 Hours", 120),
        ("4 Hours", 240),
        ("8 Hours", 480),
    ]
    
    func setup() {
        // Create status item with fixed length to ensure visibility
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Set initial appearance - use text title as primary, image as secondary
        updateAppearance()
        
        // Build the menu
        rebuildMenu()
        
        // Setup timer callbacks
        sleepManager.onTimerTick = { [weak self] in
            DispatchQueue.main.async {
                self?.updateAppearance()
                self?.rebuildMenu()
            }
        }
        sleepManager.onTimerEnd = { [weak self] in
            DispatchQueue.main.async {
                self?.updateAppearance()
                self?.rebuildMenu()
                NSSound.beep()
            }
        }
    }
    
    private func updateAppearance() {
        guard let button = statusItem.button else { return }
        
        if sleepManager.isActive {
            // Try SF Symbol first, fall back to emoji text
            if let img = NSImage(systemSymbolName: "cup.and.saucer.fill", accessibilityDescription: "Awake - Active") {
                let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
                button.image = img.withSymbolConfiguration(config)
                button.image?.isTemplate = true
                if sleepManager.isTimerMode {
                    button.title = " \(sleepManager.formattedRemainingTime())"
                } else {
                    button.title = ""
                }
            } else {
                button.image = nil
                if sleepManager.isTimerMode {
                    button.title = "☕ \(sleepManager.formattedRemainingTime())"
                } else {
                    button.title = "☕"
                }
            }
        } else {
            if let img = NSImage(systemSymbolName: "cup.and.saucer", accessibilityDescription: "Awake - Inactive") {
                let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
                button.image = img.withSymbolConfiguration(config)
                button.image?.isTemplate = true
                button.title = ""
            } else {
                button.image = nil
                button.title = "💤"
            }
        }
        
        button.toolTip = sleepManager.isActive ? "Awake - Keeping Mac awake" : "Awake - Mac can sleep"
    }
    
    private func rebuildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        
        // Status header
        let statusText = sleepManager.isActive ? "Status: Active" : "Status: Inactive"
        let statusItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        if sleepManager.isActive {
            statusItem.attributedTitle = NSAttributedString(
                string: statusText,
                attributes: [.foregroundColor: NSColor.systemGreen, .font: NSFont.menuFont(ofSize: 13)]
            )
        }
        menu.addItem(statusItem)
        
        // Timer remaining
        if sleepManager.isActive && sleepManager.isTimerMode {
            let timerText = "  ⏱ \(sleepManager.formattedRemainingTime()) remaining"
            let timerItem = NSMenuItem(title: timerText, action: nil, keyEquivalent: "")
            timerItem.isEnabled = false
            menu.addItem(timerItem)
        } else if sleepManager.isActive {
            let timerItem = NSMenuItem(title: "  ⏱ Indefinitely", action: nil, keyEquivalent: "")
            timerItem.isEnabled = false
            menu.addItem(timerItem)
        }
        
        // Current mode
        if sleepManager.isActive {
            let modeText = "  Mode: \(sleepManager.mode.rawValue)"
            let modeItem = NSMenuItem(title: modeText, action: nil, keyEquivalent: "")
            modeItem.isEnabled = false
            menu.addItem(modeItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Toggle
        if sleepManager.isActive {
            let deactivateItem = NSMenuItem(title: "Deactivate", action: #selector(deactivate), keyEquivalent: "d")
            deactivateItem.target = self
            menu.addItem(deactivateItem)
        } else {
            let activateItem = NSMenuItem(title: "Activate Indefinitely", action: #selector(activateIndefinitely), keyEquivalent: "a")
            activateItem.target = self
            menu.addItem(activateItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Timer options
        let timerHeader = NSMenuItem(title: "Activate for...", action: nil, keyEquivalent: "")
        timerHeader.isEnabled = false
        menu.addItem(timerHeader)
        
        for (label, minutes) in timerOptions {
            let item = NSMenuItem(title: "  \(label)", action: #selector(activateWithTimer(_:)), keyEquivalent: "")
            item.target = self
            item.tag = minutes
            menu.addItem(item)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Mode selection
        let modeHeader = NSMenuItem(title: "Sleep Prevention Mode", action: nil, keyEquivalent: "")
        modeHeader.isEnabled = false
        menu.addItem(modeHeader)
        
        let displayModeItem = NSMenuItem(title: "  Display & System", action: #selector(setModeDisplayAndSystem), keyEquivalent: "")
        displayModeItem.target = self
        displayModeItem.state = sleepManager.mode == .displayAndSystem ? .on : .off
        menu.addItem(displayModeItem)
        
        let systemModeItem = NSMenuItem(title: "  System Only", action: #selector(setModeSystemOnly), keyEquivalent: "")
        systemModeItem.target = self
        systemModeItem.state = sleepManager.mode == .systemOnly ? .on : .off
        menu.addItem(systemModeItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // About
        let aboutItem = NSMenuItem(title: "About Awake", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        self.statusItem.menu = menu
    }
    
    // MARK: - Actions
    
    @objc private func activateIndefinitely() {
        sleepManager.activate(mode: sleepManager.mode)
        updateAppearance()
        rebuildMenu()
    }
    
    @objc private func deactivate() {
        sleepManager.deactivate()
        updateAppearance()
        rebuildMenu()
    }
    
    @objc private func activateWithTimer(_ sender: NSMenuItem) {
        sleepManager.activateWithTimer(minutes: sender.tag, mode: sleepManager.mode)
        updateAppearance()
        rebuildMenu()
    }
    
    @objc private func setModeDisplayAndSystem() {
        let wasActive = sleepManager.isActive
        let wasTimer = sleepManager.isTimerMode
        let remaining = sleepManager.remainingSeconds
        
        sleepManager.deactivate()
        if wasActive {
            if wasTimer && remaining > 0 {
                sleepManager.activateWithTimer(minutes: max(1, remaining / 60), mode: .displayAndSystem)
            } else {
                sleepManager.activate(mode: .displayAndSystem)
            }
        }
        updateAppearance()
        rebuildMenu()
    }
    
    @objc private func setModeSystemOnly() {
        let wasActive = sleepManager.isActive
        let wasTimer = sleepManager.isTimerMode
        let remaining = sleepManager.remainingSeconds
        
        sleepManager.deactivate()
        if wasActive {
            if wasTimer && remaining > 0 {
                sleepManager.activateWithTimer(minutes: max(1, remaining / 60), mode: .systemOnly)
            } else {
                sleepManager.activate(mode: .systemOnly)
            }
        }
        updateAppearance()
        rebuildMenu()
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Awake ☕"
        alert.informativeText = """
        Version 1.0
        
        A simple menu bar utility that keeps your Mac awake.
        
        Uses IOKit Power Assertions to prevent sleep — the same mechanism as macOS's built-in caffeinate command.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
    
    @objc private func quitApp() {
        sleepManager.deactivate()
        NSApp.terminate(nil)
    }
}


// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {
    let menuBarController = MenuBarController()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController.setup()
    }
}


// MARK: - Main Entry Point

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()

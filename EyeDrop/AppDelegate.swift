//
//  AppDelegate.swift
//  EyeDrop
//
//  Created by Mattijs on 11/01/2017.
//  Copyright © 2017 Mattijs. All rights reserved.
//

import Cocoa
import Darwin

private enum MenuItemTags: Int {
    case MinutesRemaining
    case IntervalItem
    case DarknessMenu
    case DarknessMenuOption
    
    var tag: Int { return rawValue }
}

public enum DarknessOption: Int {
    case High = 0
    case Medium = 1
    case Low = 2
    
    public var alpha: CGFloat {
        switch self {
        case .High: return 1.0
        case .Medium: return 0.75
        case .Low: return 0.5
        }
    }
}

private enum StatusImage {
    case Active
    case Delayed
    case Normal
    case Paused
    
    var image: NSImage {
        if #available(OSX 10.10, *) {
            switch self {
            case .Active: return #imageLiteral(resourceName: "StatusBarActive")
            case .Delayed: return #imageLiteral(resourceName: "StatusBarDelayed")
            case .Normal: return #imageLiteral(resourceName: "StatusBarNormal")
            case .Paused: return #imageLiteral(resourceName: "StatusBarPaused")
            }
        } else {
            // using image assets not possible / working under 10.9
            // therefore falling back to fixed images
            switch self {
            case .Active: return NSImage(named: "eyedrop_active")!
            case .Delayed: return NSImage(named: "eyedrop_delayed")!
            case .Normal: return NSImage(named: "eyedrop_normal")!
            case .Paused: return NSImage(named: "eyedrop_pause")!
            }
        }
    }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, OverlayViewDelegate {

    var timeRemainingUponPaused = TimeInterval(-1)
    var isPaused = false
    var previousScreenIsLocked = false
    var overlayTimer = Timer()
    var displayedOverlays = [NSWindow]()

    let statusItem = NSStatusBar.system().statusItem(withLength: NSSquareStatusItemLength)
    
    lazy var minutesRemainingMenuItem: NSMenuItem = {
        // Minutes Remaining Item
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        item.tag = MenuItemTags.MinutesRemaining.tag
        return item
    }()

    var normalMenu: NSMenu!
    var pausedMenu: NSMenu!
    var transparencyMenu: NSMenu!
    
//    var lockName = "Y29lcy5zcWN1Yi5FeWVEcm9wbS5hcHBlcy5zcWN1Yi5FeWVEcm9wbGUuc2NyZXMuc3FjdWIuRXllRHJvcGVlbkllcy5zcWN1Yi5FeWVEcm9wc0xvY2VzLnNxY3ViLkV5ZURyb3BrZWQ="
    
//    var unlockName = "Y2VzLnNxY3ViLkV5ZURyb3BvbS5hcGVzLnNxY3ViLkV5ZURyb3BwbGUuc2NyZWVzLnNxY3ViLkV5ZURyb3BlbklzVW5lcy5zcWN1Yi5FeWVEcm9wbG9ja2Vk"
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        AppSettings.registerDefaults()
        
//        lockName = String(data: Data(base64Encoded: lockName)!, encoding: .utf8)!.replacingOccurrences(of: Bundle.main.bundleIdentifier!, with: "")
//        
//        unlockName = String(data: Data(base64Encoded: unlockName)!, encoding: .utf8)!.replacingOccurrences(of: Bundle.main.bundleIdentifier!, with: "")
        
        normalMenu = createNormalStatusBarMenu()
        normalMenu.delegate = self
        statusItem.highlightMode = true
        statusItem.menu = normalMenu
        updateMenuButtonImage(.Active)
        
        pausedMenu = createPausedStatusBarMenu()
        pausedMenu.delegate = self
        
        transparencyMenu = normalMenu.item(withTag: MenuItemTags.DarknessMenu.tag)!.submenu!
        
//        DistributedNotificationCenter.default().addObserver(self, selector: #selector(screenLocked), name: NSNotification.Name.init(rawValue: lockName), object: nil)
//        DistributedNotificationCenter.default().addObserver(self, selector: #selector(screenUnlocked), name: NSNotification.Name.init(rawValue: unlockName), object: nil)

        NSWorkspace.shared().notificationCenter.addObserver(self, selector: #selector(workspaceWillSleep), name: NSNotification.Name.NSWorkspaceWillSleep, object: nil)
        NSWorkspace.shared().notificationCenter.addObserver(self, selector: #selector(workspaceDidWake), name: NSNotification.Name.NSWorkspaceDidWake, object: nil)
        

        NSWorkspace.shared().notificationCenter.addObserver(self, selector: #selector(screensDidSleep), name: NSNotification.Name.NSWorkspaceScreensDidSleep, object: nil)
        NSWorkspace.shared().notificationCenter.addObserver(self, selector: #selector(screensDidWake), name: NSNotification.Name.NSWorkspaceScreensDidWake, object: nil)
        
        selectMenuItem(menu: normalMenu, itemTag: MenuItemTags.IntervalItem.tag, matchingValue: TimeInterval(AppSettings.interval.integer))
        selectMenuItem(menu: transparencyMenu, itemTag: MenuItemTags.DarknessMenuOption.tag, matchingValue: DarknessOption(rawValue: AppSettings.darknessOption.integer)!)

        Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(checkScreenLockState), userInfo: nil, repeats: true)
        
        resetInterval()
    }
    
    @objc private func checkScreenLockState() {
        let screenIsLocked = isScreenLocked()
        if previousScreenIsLocked != screenIsLocked {
            previousScreenIsLocked = screenIsLocked
            if screenIsLocked {
                self.screenLocked()
            } else {
                self.screenUnlocked()
            }
        }
    }
    
    private func isScreenLocked() -> Bool {
        let dict = CGSessionCopyCurrentDictionary() as? NSDictionary
        return dict?["CGS" + "Session" + "Screen" + "Is" + "Locked"] as? Bool ?? false
    }
    
    @objc
    private func screenLocked() {
        reset()
    }
    
    @objc
    private func screenUnlocked() {
        resume()
    }
    
    @objc
    private func screensDidSleep() {
        reset()
    }
    
    @objc
    private func screensDidWake() {
        resume()
    }

    @objc
    private func workspaceWillSleep() {
        reset()
    }
    
    @objc
    private func workspaceDidWake() {
        resume()
    }
    
    private func reset() {
        closeOverlays()
        cancelInterval()
    }
    
    private func resume() {
        if isPaused {
            // currently paused,
            // reset the time remaining so that when resumed the regular interval will be used
            timeRemainingUponPaused = TimeInterval(AppSettings.interval.integer)
        } else {
            resetInterval()
        }
    }
    
    private func createNormalStatusBarMenu() -> NSMenu {
        let menu = NSMenu()
        
        let minutesStepOptions = [10, 20, 30, 60]
        
        menu.addItem(minutesRemainingMenuItem)
        
        // -- separator
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: NSLocalizedString("Pause", tableName: "menu", comment: "'Pause' the interval"), action: #selector(pauseIntervalTapped(sender:)), keyEquivalent: "p"))

        // -- separator
        menu.addItem(NSMenuItem.separator())
        
        // Interval Items
        for minutes in minutesStepOptions {
            let interval = TimeInterval(minutes * 60)
            let itemTitle = title(forInterval: interval)
            let item = NSMenuItem(title: itemTitle, action: #selector(changeIntervalTapped(sender:)), keyEquivalent: "")
            item.representedObject = interval
            item.tag = MenuItemTags.IntervalItem.tag
            menu.addItem(item)
        }
        
        // -- separator
        menu.addItem(NSMenuItem.separator())
        
//        // Darkness menu
        let darknessMenuTitle = NSLocalizedString("Darkness", tableName: "menu", comment: "The menu item tile which contains a submenu with gradations of darkness")
        let darknessMenuItem = NSMenuItem(title: darknessMenuTitle, action: nil, keyEquivalent: "T")
        darknessMenuItem.submenu = createDarknessStatusBarMenu()
        darknessMenuItem.tag = MenuItemTags.DarknessMenu.tag
        menu.addItem(darknessMenuItem)
        
        // -- separator
        menu.addItem(NSMenuItem.separator())
        
        // Quit Item
        menu.addItem(createQuitMenuItem())
        
        return menu
    }
    
    private func createDarknessStatusBarMenu() -> NSMenu {
        let menu = NSMenu()
        
        let darknessOptions: [DarknessOption] = [.High, .Medium, .Low]
        
        // Interval Items
        for darknessOption in darknessOptions {
            let itemTitle = title(forDarknessOption: darknessOption)
            let item = NSMenuItem(title: itemTitle, action: #selector(changeDarknessTapped(sender:)), keyEquivalent: "")
            item.representedObject = darknessOption
            item.tag = MenuItemTags.DarknessMenuOption.tag
            menu.addItem(item)
        }
        
        return menu
    }
    
    private func createPausedStatusBarMenu() -> NSMenu {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: NSLocalizedString("Resume", tableName: "menu", comment: "'Resume' the interval"), action: #selector(resumeIntervalTapped(sender:)), keyEquivalent: "r"))

        // -- separator
        menu.addItem(NSMenuItem.separator())
        
        // Quit Item
        menu.addItem(createQuitMenuItem())
        
        return menu
    }
    
    private func createQuitMenuItem() -> NSMenuItem {
        let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? ""
        let title = String(format: NSLocalizedString("Quit %@", tableName: "menu", comment: "Quit <appname>"), appName)
        return NSMenuItem(title: title, action: #selector(terminate(sender:)), keyEquivalent: "q")
    }
    
    private func title(forRemainingInterval interval: TimeInterval) -> String {
        let minutes = max(-1, Int(interval / 60))
        return String.localizedStringWithFormat(NSLocalizedString("%d Minutes Remaining", tableName: "menu", comment: "Menu title that displays the amount of minutes remaining until next blank screen / blackout."), minutes)
    }
    
    private func title(forInterval interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        return String.localizedStringWithFormat(NSLocalizedString("%d Minutes", tableName: "menu", comment: "Menu title for the interval in minutes between blank screens"), minutes)
    }
    
    private func title(forDarknessOption option: DarknessOption) -> String {
        switch option {
        case .High: return NSLocalizedString("High", tableName: "menu", value: "Wow", comment: "'High' gradation of darkness")
        case .Medium: return NSLocalizedString("Medium", tableName: "menu", value: "Much", comment: "'Medium' gradation of darkness")
        case .Low: return NSLocalizedString("Low", tableName: "menu", value: "So", comment: "'Low' gradation of darkness")
        }
    }
    
    @objc
    private func changeDarknessTapped(sender: AnyObject) {
        if let item = sender as? NSMenuItem, let darknessOption = item.representedObject as? DarknessOption {
            updateToTransparencyPercentage(darknessOption)
        }
    }
    
    @objc
    private func changeIntervalTapped(sender: AnyObject) {
        if let item = sender as? NSMenuItem, let interval = item.representedObject as? TimeInterval {
            updateToInterval(interval)
        }
    }
    
    @objc
    private func pauseIntervalTapped(sender: AnyObject) {
        pauseInterval()
    }
    
    @objc
    private func resumeIntervalTapped(sender: AnyObject) {
        resumeInterval()
    }
    
    private func createOverlays() -> [NSWindow] {
        let screens = NSScreen.screens() ?? []
        var overlays = [NSWindow]()
        
        // for safety clamp alpha to be at least 0.5
        let alpha = max(0.5, DarknessOption(rawValue: AppSettings.darknessOption.integer)!.alpha)
        
        for i in 0..<screens.count {
            let frame = screens[i].frame
            let overlay = NSWindow(contentRect: frame, styleMask: NSWindowStyleMask.borderless, backing: NSBackingStoreType.buffered, defer: false)
            let view = OverlayView(delegate: self)
            view.wantsLayer = true
            view.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.0).cgColor
            overlay.contentView = view
            overlay.isOpaque = false
            overlay.hasShadow = false
            overlay.isReleasedWhenClosed = false
            overlay.level = Int(CGWindowLevelForKey(.popUpMenuWindow))
            
            overlay.backgroundColor = NSColor.black.withAlphaComponent(CGFloat(alpha))
            
            overlays.append(overlay)
        }
        return overlays
    }
    
    private func displayOverlay(timeout: TimeInterval) {
        closeOverlays(overlays: self.displayedOverlays)
        
        let overlays = createOverlays()
        
        // display overlays fully transparent
        overlays.forEach { overlay in
            overlay.alphaValue = 0
            overlay.orderFrontRegardless()
        }
        
        // add overlays to list of currently displayed overlays
        self.displayedOverlays.append(contentsOf: overlays)
        
        // fade in overlays
        NSAnimationContext.runAnimationGroup({ (context) -> Void in
            context.duration = 1.0
            overlays.forEach { $0.animator().alphaValue = 1 }
        }, completionHandler: {
            // schedule timer for removing the overlays after timeout
            Timer.scheduledTimer(timeInterval: timeout, target: self, selector: #selector(self.overlayDisplayTimeOut(timer:)), userInfo: nil, repeats: false)
        })
    }
    
    private func closeOverlays() {
        closeOverlays(overlays: self.displayedOverlays)
    }
    
    private func closeOverlays(overlays: [NSWindow]) {
        for overlay in overlays {
            closeOverlay(overlay: overlay)
        }
    }
    
    private func closeOverlay(overlay: NSWindow) {
        // fade out overlays
        NSAnimationContext.runAnimationGroup({ (context) -> Void in
            context.duration = 1.0
            overlay.animator().alphaValue = 0
        }, completionHandler: {
            // close overay once fully faded-out
            overlay.close()
            // and remove it from the list of currently displayed overlays
            if let index = self.displayedOverlays.index(of: overlay) {
                self.displayedOverlays.remove(at: index)
            }
        })
    }
    
    func overlayViewClicked(overlayView: OverlayView) {
        closeOverlays()
    }
    
    @objc
    private func overlayTimerTimedOut(timer: Timer) {
        // timeout = interval minutes as 1:1 seconds
        // example = interval = 600s, timeout = 10s
        let timeout = timer.timeInterval / 60
        displayOverlay(timeout: timeout)
    }
    
    @objc
    private func overlayDisplayTimeOut(timer: Timer) {
        closeOverlays()
    }
    
    private func selectMenuItem<T: Any>(menu: NSMenu, itemTag tag: Int, matchingValue value: T) where T: Equatable {
        for items in menu.items {
            if items.tag == tag {
                guard let itemValue = items.representedObject as? T else { continue }
                items.state = itemValue == value ? NSOnState : NSOffState
            }
        }
    }
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        let timeRemaining = overlayTimer.fireDate.timeIntervalSinceNow
        minutesRemainingMenuItem.title = title(forRemainingInterval: timeRemaining)
    }

    func updateToTransparencyPercentage(_ darknessOption: DarknessOption) {
        AppSettings.darknessOption.set(darknessOption.rawValue)
        selectMenuItem(menu: transparencyMenu, itemTag: MenuItemTags.DarknessMenuOption.tag, matchingValue: darknessOption)
    }
    
    func updateToInterval(_ interval: TimeInterval) {
        AppSettings.interval.set(interval)
        resetInterval(to: interval)
        selectMenuItem(menu: normalMenu, itemTag: MenuItemTags.IntervalItem.tag, matchingValue: interval)
    }
    
    func cancelInterval() {
        overlayTimer.invalidate()
    }
    
    func resetInterval() {
        resetInterval(to: TimeInterval(AppSettings.interval.integer))
    }
    
    func resetInterval(to interval: TimeInterval, initialInterval: TimeInterval? = nil) {
        cancelInterval()
        
        var fireDate: Date!
        if let initialInterval = initialInterval {
            fireDate = Date().addingTimeInterval(initialInterval)
        } else {
            fireDate = Date().addingTimeInterval(interval)
        }
        
        overlayTimer = Timer(fireAt: fireDate, interval: interval, target: self, selector: #selector(overlayTimerTimedOut(timer:)), userInfo: nil, repeats: true)
        RunLoop.current.add(overlayTimer, forMode: RunLoopMode.defaultRunLoopMode)
        
        isPaused = false
        statusItem.menu = normalMenu
        updateMenuButtonImage(.Active)
    }

    private func pauseInterval() {
        // save pause state
        isPaused = true
        timeRemainingUponPaused = overlayTimer.fireDate.timeIntervalSinceNow
        
        // show menu as paused
        statusItem.menu = pausedMenu
        updateMenuButtonImage(.Paused)
        
        // stop the interval timer
        cancelInterval()
    }
    
    fileprivate func updateMenuButtonImage(_ statusImage: StatusImage) {
        if #available(OSX 10.10, *) {
            statusItem.button?.image = statusImage.image
        } else {
            statusItem.image = statusImage.image
        }
    }
    
    private func resumeInterval() {
        resetInterval(to: TimeInterval(AppSettings.interval.integer), initialInterval: timeRemainingUponPaused)
    }
    
    @objc
    private func terminate(sender: AnyObject) {
        NSApplication.shared().terminate(sender)
    }
}


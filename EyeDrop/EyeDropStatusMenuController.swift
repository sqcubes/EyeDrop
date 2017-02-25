//
//  EyeDropStatusMenuController.swift
//  EyeDrop
//
//  Created by Mattijs on 29/01/2017.
//  Copyright © 2017 Mattijs. All rights reserved.
//

import Foundation
import Cocoa

protocol EyeDropStatusMenuControllerDelegate {
    func menuPauseIntervalTapped()
    func menuResumeIntervalTapped()
    func menuChangeIntervalTapped(interval: TimeInterval)
    func menuChangeDarknessOptionTapped(darknessOption: DarknessOption)
    func menuHighlightsDarknessOption(darknessOption: DarknessOption?)
    func menuToggleBlurTapped()
    func menuQuitApplicationTapped()
    func menuRunAfterLoginTapped()
    func menuShouldUpdateState()
}

private enum MenuItemTags: Int {
    case MinutesRemaining
    case IntervalItem
    case DarknessMenu
    case DarknessMenuOption
    case DarknessMenuBlur
    case RunAfterLogin
    
    var tag: Int { return rawValue }
}

fileprivate extension EyeDropState {
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

class EyeDropStatusMenuController: NSObject {
    var delegate: EyeDropStatusMenuControllerDelegate?
    
    private var statusItem: NSStatusItem?
    fileprivate let normalMenu = NSMenu()
    private let pausedMenu = NSMenu()
    fileprivate let darknessMenu = NSMenu()
    
    private lazy var minutesRemainingMenuItem: NSMenuItem = {
        // Minutes Remaining Item
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        item.tag = MenuItemTags.MinutesRemaining.tag
        return item
    }()
    
    // tracks the highlighted darkenss menu item option
    fileprivate var highlightedDarknessOption: DarknessOption? = nil {
        didSet {
            if oldValue != highlightedDarknessOption {
                delegate?.menuHighlightsDarknessOption(darknessOption: highlightedDarknessOption)
            }
        }
    }
    
    override init() {
        super.init()
        
        // create 'transparency' menu
        populateDarknessStatusBarMenu(menu: darknessMenu)
        
        // create 'normal' menu
        populateNormalStatusBarMenu(menu: normalMenu, darknessMenu: darknessMenu)
        normalMenu.delegate = self
        
        // create 'paused' menu
        populatePausedStatusBarMenu(menu: pausedMenu)
        pausedMenu.delegate = self
    }
    
    func show(currentState: EyeDropState) {
        // create status bar item
        statusItem = NSStatusBar.system().statusItem(withLength: NSSquareStatusItemLength)
        statusItem!.highlightMode = true
        statusItem!.menu = normalMenu
        
        update(forState: currentState)
    }
    
    private func populateNormalStatusBarMenu(menu: NSMenu, darknessMenu: NSMenu) {
        let minutesStepOptions = [10, 20, 30, 60]
        
        // Minutes remaining
        minutesRemainingMenuItem.target = self
        menu.addItem(minutesRemainingMenuItem)
        
        // --
        menu.addItem(NSMenuItem.separator())
        
        // -- Pause
        let pauseItem = NSMenuItem(title: NSLocalizedString("Pause", tableName: "menu", comment: "'Pause' the interval"), action: #selector(pauseIntervalTapped(sender:)), keyEquivalent: "p")
        pauseItem.target = self
        menu.addItem(pauseItem)
        
        // --
        menu.addItem(NSMenuItem.separator())
        
        // Interval options
        for minutes in minutesStepOptions {
            let interval = TimeInterval(minutes * 60)
            let itemTitle = title(forInterval: interval)
            let item = NSMenuItem(title: itemTitle, action: #selector(changeIntervalTapped(sender:)), keyEquivalent: "")
            item.target = self
            item.representedObject = interval
            item.tag = MenuItemTags.IntervalItem.tag
            menu.addItem(item)
        }
        
        // --
        menu.addItem(NSMenuItem.separator())
        
        // Darkness options submenu
        let darknessMenuTitle = NSLocalizedString("Darkness", tableName: "menu", comment: "The menu item title which contains a submenu with gradations of darkness")
        let darknessMenuItem = NSMenuItem(title: darknessMenuTitle, action: nil, keyEquivalent: "T")
        darknessMenuItem.submenu = darknessMenu
        darknessMenuItem.target = self
        darknessMenuItem.tag = MenuItemTags.DarknessMenu.tag
        menu.addItem(darknessMenuItem)
        
        // -- Run after Login
        let runAfterLoginItem = NSMenuItem(title: NSLocalizedString("Run after Login", tableName: "menu", comment: ""), action: #selector(runAfterLoginTapped(sender:)), keyEquivalent: "")
        runAfterLoginItem.target = self
        runAfterLoginItem.tag = MenuItemTags.RunAfterLogin.tag
        menu.addItem(runAfterLoginItem)
        
        // -- separator
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = createQuitMenuItem()
        quitItem.target = self
        menu.addItem(quitItem)
    }
    
    private func populateDarknessStatusBarMenu(menu: NSMenu) {
        menu.delegate = self
        
        // ordered options
        let darknessOptions: [DarknessOption] = [.High, .Medium, .Low]
        
        // Darkness menu options
        for darknessOption in darknessOptions {
            let itemTitle = title(forDarknessOption: darknessOption)
            let item = NSMenuItem(title: itemTitle, action: #selector(changeDarknessTapped(sender:)), keyEquivalent: "")
            item.representedObject = darknessOption
            item.target = self
            item.tag = MenuItemTags.DarknessMenuOption.tag
            menu.addItem(item)
        }
        
        if OverlayView.isBackgroundBlurSupported {
            // -- separator
            menu.addItem(NSMenuItem.separator())
            
            // Blur
            let toggleBlurItem = NSMenuItem(title: NSLocalizedString("Blur", tableName: "menu", comment: "The menu item that indicates whether or not blur is enabled"), action: #selector(toggleBlurTapped(sender:)), keyEquivalent: "")
            toggleBlurItem.tag = MenuItemTags.DarknessMenuBlur.tag
            toggleBlurItem.target = self
            menu.addItem(toggleBlurItem)
        }
    }
    
    private func populatePausedStatusBarMenu(menu: NSMenu) {
        // Resume
        let resumeItem = NSMenuItem(title: NSLocalizedString("Resume", tableName: "menu", comment: "'Resume' the interval"), action: #selector(resumeIntervalTapped(sender:)), keyEquivalent: "r")
        resumeItem.target = self
        menu.addItem(resumeItem)
        
        // --
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = createQuitMenuItem()
        quitItem.target = self
        menu.addItem(quitItem)
    }
    
    private func createQuitMenuItem() -> NSMenuItem {
        let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? ""
        let title = String(format: NSLocalizedString("Quit %@", tableName: "menu", comment: "Quit <appname>"), appName)
        return NSMenuItem(title: title, action: #selector(quitApplicationTapped(sender:)), keyEquivalent: "q")
    }
    
    func update(forState state: EyeDropState) {
        if #available(OSX 10.10, *) {
            statusItem?.button?.image = state.image
        } else {
            statusItem?.image = state.image
        }
        
        if state == .Paused {
            statusItem?.menu = pausedMenu
        } else {
            statusItem?.menu = normalMenu
        }
    }
    
    func update(forRemainingInterval remainingInterval: TimeInterval) {
        minutesRemainingMenuItem.title = title(forRemainingInterval: remainingInterval)
    }
    
    func update(forDarknessOption darknessOption: DarknessOption) {
        selectMenuItem(menu: darknessMenu, itemTag: .DarknessMenuOption, matchingValue: darknessOption)
    }
    
    func update(forBlurEnabled blurEnabled: Bool) {
        selectMenuItem(menu: darknessMenu, itemTag: .DarknessMenuBlur, selected: blurEnabled)
    }
    
    func update(forRunAfterLogin runAfterLogin: Bool) {
        selectMenuItem(menu: normalMenu, itemTag: .RunAfterLogin, selected: runAfterLogin)
    }
    
    func update(forInterval interval: TimeInterval) {
        selectMenuItem(menu: normalMenu, itemTag: .IntervalItem, matchingValue: interval)
    }
    
    private func selectMenuItem<T: Any>(menu: NSMenu, itemTag: MenuItemTags, matchingValue value: T) where T: Equatable {
        for items in menu.items {
            if items.tag == itemTag.tag {
                guard let itemValue = items.representedObject as? T else { continue }
                items.state = itemValue == value ? NSOnState : NSOffState
            }
        }
    }
    
    private func selectMenuItem(menu: NSMenu, itemTag: MenuItemTags, selected: Bool) {
        for items in menu.items {
            if items.tag == itemTag.tag {
                items.state = selected ? NSOnState : NSOffState
            }
        }
    }
    
    private func title(forRemainingInterval interval: TimeInterval) -> String {
        let minutes = max(0, Int(interval / 60))
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
            delegate?.menuChangeDarknessOptionTapped(darknessOption: darknessOption)
        }
    }
    
    @objc
    private func toggleBlurTapped(sender: AnyObject) {
        delegate?.menuToggleBlurTapped()
    }
    
    @objc
    private func changeIntervalTapped(sender: AnyObject) {
        if let item = sender as? NSMenuItem, let interval = item.representedObject as? TimeInterval {
            delegate?.menuChangeIntervalTapped(interval: interval)
        }
    }
    
    @objc
    private func resumeIntervalTapped(sender: AnyObject) {
        delegate?.menuResumeIntervalTapped()
    }

    @objc
    private func pauseIntervalTapped(sender: AnyObject) {
        delegate?.menuPauseIntervalTapped()
    }
    
    @objc
    private func runAfterLoginTapped(sender: AnyObject) {
        delegate?.menuRunAfterLoginTapped()
    }
    
    @objc
    private func quitApplicationTapped(sender: AnyObject) {
        delegate?.menuQuitApplicationTapped()
    }
}

extension EyeDropStatusMenuController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        // a state update is only needed for the normal menu
        // as it contains the minutes remaining item
        if menu == normalMenu {
            delegate?.menuShouldUpdateState()
        }
    }
    
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.tag == MenuItemTags.DarknessMenuBlur.tag {
            return OverlayView.isBlurAvailable
        }
        return true
    }
    
    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        if menu == darknessMenu {
            highlightedDarknessOption = item?.representedObject as? DarknessOption
        }
    }
    
    func menuDidClose(_ menu: NSMenu) {
        if menu == darknessMenu {
            highlightedDarknessOption = nil
        }
    }
}

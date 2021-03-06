//
//  OverlayController.swift
//  EyeDrop
//
//  Created by Mattijs on 29/01/2017.
//  Copyright © 2017 Mattijs. All rights reserved.
//

import Foundation
import Cocoa

class OverlayController {    
    var displayedOverlays = [NSWindow]()
    var isDisplayingOverlay: Bool = false
    var animationSpeed: TimeInterval = 1.0
    var hideLogo: Bool = false
    var hideProgress: Bool = false
    var blur: Bool = true
    var windowLevel: CGWindowLevelKey = .maximumWindow
    
    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillResignActive(_:)), name: NSApplication.willResignActiveNotification, object: nil)
    }
    
    @objc
    private func applicationWillResignActive(_ notification: NSNotification) {
        if (isDisplayingOverlay) {
            // Keep EyeDrop activated while displaying overlay, this way the screen can respond to ESC / double-clicks to dismiss
            // and it also prevents underlaying applications from receiving accidental taps / key presses.
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    private func createOverlays(darkness: DarknessOption) -> [NSWindow] {
        let screens = NSScreen.screens
        var overlays = [NSWindow]()
        
        for i in 0..<screens.count {
            let frame = screens[i].frame
            let overlayWindow = BorderlessWindow(contentRect: frame, styleMask: NSWindow.StyleMask.borderless, backing: NSWindow.BackingStoreType.buffered, defer: false)
            overlayWindow.isOpaque = false
            overlayWindow.hasShadow = false
            overlayWindow.ignoresMouseEvents = false
            overlayWindow.isReleasedWhenClosed = false
            overlayWindow.collectionBehavior = [.canJoinAllSpaces, .transient, ]
            overlayWindow.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(windowLevel)))
            overlayWindow.backgroundColor = NSColor.clear
            
            let overlayView = OverlayView(delegate: self)
            overlayView.hideLogo = hideLogo
            overlayView.blur = blur
            overlayView.hideProgress = hideProgress
            overlayView.darkness = darkness
            overlayWindow.contentView = overlayView
            overlayWindow.initialFirstResponder = overlayView
        
            overlays.append(overlayWindow)
        }
        return overlays
    }
    
    public func preview(darkness: DarknessOption) {
        show(duration: TimeInterval.infinity, darkness: darkness, activateApp: false)
    }
    
    public func show(duration: TimeInterval, darkness: DarknessOption) {
        show(duration: duration, darkness: darkness, activateApp: true)
    }
    
    private func show(duration: TimeInterval, darkness: DarknessOption, activateApp: Bool) {
        if isDisplayingOverlay {
            animate(darkness: darkness)
            return
        }
        // hide existing overlays
        hide()
        
        isDisplayingOverlay = true
        
        let overlays = createOverlays(darkness: darkness)
        
        // initially init overlays fully transparent
        overlays.forEach { overlay in
            overlay.alphaValue = 0
            // move to front
            overlay.orderFrontRegardless()
            overlay.makeKey()
        }
        
        // add overlays to list of currently displayed overlays
        self.displayedOverlays.append(contentsOf: overlays)
        
        // Activate the app so that the window can respond to the ESC keypress or double-clicks
        // to cancel the appearance (if enabled by settings).
        // Activating EyeDrop also prevents the underlaying app from accidental receiving clicks / keypresses
        // while the overlay is shown.
        if activateApp {
            NSApp.activate(ignoringOtherApps: true)
        }
        
        // fade in overlays
        NSAnimationContext.runAnimationGroup({ (context) -> Void in
            context.duration = animationSpeed
            overlays.forEach { $0.animator().alphaValue = 1.0 }
        }, completionHandler: {
            // schedule timer for removing the overlays after timeout
            Timer.scheduledTimer(timeInterval: duration, target: self, selector: #selector(self.overlayDisplayTimeOut(timer:)), userInfo: nil, repeats: false)
            
            // begin progress bar
            overlays.forEach {
                ($0.contentView as? OverlayView)?.beginProgress(duration: duration)
            }
        })
    }
    
    /**
     Animates only the darkness of the window (e.g. background color)
     */
    private func animate(darkness: DarknessOption) {
        for overlay in displayedOverlays {
            (overlay.contentView as? OverlayView)?.setDarkness(darkness: darkness, animated: true, duration: animationSpeed)
        }
    }
    
    func hide() {
        isDisplayingOverlay = false
        
        // .hide will activate the previous app but it also hides the overlay. But we can unhide it using
        // .unhideWithoutActivation. This way the previous application is ready to
        // receive keyboard / mouse events while fading out the overlay(s).
        NSApp.hide(nil)
        NSApp.unhideWithoutActivation()
    
        for overlay in displayedOverlays {
            // re-enable mouse events to be received by the previous application
            overlay.ignoresMouseEvents = true
            
            hide(overlay: overlay)
        }
    }
    
    /**
     Hides one specific overlay by fading out the window's alpha. Once the fade out transition
     is complete the window will be closed and removed from `displayedOverlays`
     */
    private func hide(overlay: NSWindow) {
        // fade out overlays
        NSAnimationContext.runAnimationGroup({ (context) -> Void in
            context.duration = animationSpeed
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
    
    @objc
    private func overlayDisplayTimeOut(timer: Timer) {
        hide()
    }
}

extension OverlayController: OverlayViewDelegate {
    func overlayViewCancelled(overlayView: OverlayView) {
        if AppSettings.cancelable.bool {
            hide()
        }
    }
}

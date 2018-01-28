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
    
    private func createOverlays(darkness: DarknessOption) -> [NSWindow] {
        let screens = NSScreen.screens
        var overlays = [NSWindow]()
        
        for i in 0..<screens.count {
            let frame = screens[i].frame
            let overlayWindow = NSWindow(contentRect: frame, styleMask: NSWindow.StyleMask.borderless, backing: NSWindow.BackingStoreType.buffered, defer: false)
            overlayWindow.isOpaque = false
            overlayWindow.hasShadow = false
            overlayWindow.isReleasedWhenClosed = false
            overlayWindow.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(windowLevel)))
            overlayWindow.backgroundColor = NSColor.clear
            
            let overlayView = OverlayView(delegate: self)
            overlayView.hideLogo = hideLogo
            overlayView.blur = blur
            overlayView.hideProgress = hideProgress
            overlayView.darkness = darkness
            overlayWindow.contentView = overlayView
        
            overlays.append(overlayWindow)
        }
        return overlays
    }
    
    public func show(duration: TimeInterval, darkness: DarknessOption) {
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
            overlay.orderFrontRegardless()
        }
        
        // add overlays to list of currently displayed overlays
        self.displayedOverlays.append(contentsOf: overlays)
        
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
        
        for overlay in displayedOverlays {
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
    func overlayViewClicked(overlayView: OverlayView) {
        hide()
    }
}

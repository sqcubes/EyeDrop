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
    
    public func displayOverlay(timeout: TimeInterval) {
        closeOverlays(overlays: self.displayedOverlays)
        
        let overlays = createOverlays()
        
        // initially init overlays fully transparent
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
    
    func closeOverlays() {
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
    
    @objc
    private func overlayDisplayTimeOut(timer: Timer) {
        closeOverlays()
    }
}

extension OverlayController: OverlayViewDelegate {
    func overlayViewClicked(overlayView: OverlayView) {
        closeOverlays()
    }
}

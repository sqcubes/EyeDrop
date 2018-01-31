//
//  FullscreenDetectorWindow.swift
//  EyeDrop
//
//  Created by Mattijs on 28/01/2018.
//  Copyright © 2018 Mattijs. All rights reserved.
//

import Foundation
import Cocoa

public class FullscreenDetector {
    public static var `default` = FullscreenDetector()
    public static let otherApplicationDidEnterFullScreen = NSNotification.Name(rawValue: "es.sqcub.EyeDrop.otherApplicationDidEnterFullScreen")
    public static let otherApplicationDidLeaveFullScreen = NSNotification.Name(rawValue: "es.sqcub.EyeDrop.otherApplicationDidLeaveFullScreen")
    private init() { }
    
    public fileprivate (set) var fullScreenAppIsActive = false {
        didSet {
            guard fullScreenAppIsActive != oldValue else { return }
            if fullScreenAppIsActive {
                didEnterFullScreen()
            } else {
                didLeaveFullScreen()
            }
        }
    }
    
    private func didEnterFullScreen() {
        NotificationCenter.default.post(name: FullscreenDetector.otherApplicationDidEnterFullScreen, object: nil)
    }
    
    private func didLeaveFullScreen() {
        NotificationCenter.default.post(name: FullscreenDetector.otherApplicationDidLeaveFullScreen, object: nil)
    }
}

class FullscreenDetectorWindow: NSWindow {
    
    init() {
        let styleMask = NSWindow.StyleMask.titled.union(.closable).union(.miniaturizable).union(.resizable)
        super.init(contentRect: NSRect.zero, styleMask: styleMask, backing: .buffered, defer: false)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidFinishLaunching(_:)), name: NSApplication.didFinishLaunchingNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(activeSpaceDidChange(_:)), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        
        if Bundle.main.infoDictionary?["LSUIElement"]! as? Bool ?? false {
            print("Warning, fullscreen detection does not work when LSUIElement is set to YES")
        }
    }
    
    @objc
    private func applicationDidFinishLaunching(_ notification: NSNotification) {
        updateFullScreenStatus()
    }
    
    @objc
    private func activeSpaceDidChange(_ notification: NSNotification) {
        updateFullScreenStatus()
    }
    
    private func updateFullScreenStatus() {
        FullscreenDetector.default.fullScreenAppIsActive = !self.isOnActiveSpace
    }
    
    override var canBecomeKey: Bool {
        return false
    }

    override var collectionBehavior: NSWindow.CollectionBehavior {
        get { return NSWindow.CollectionBehavior.fullScreenAuxiliary.union(.canJoinAllSpaces) }
        set { }
    }
    
    override var ignoresMouseEvents: Bool {
        get { return true }
        set { }
    }
    
    override var level: NSWindow.Level {
        get { return .screenSaver }
        set { }
    }
    
    override var alphaValue: CGFloat {
        get { return 0.5 }
        set { }
    }
}

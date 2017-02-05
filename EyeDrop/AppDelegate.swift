//
//  AppDelegate.swift
//  EyeDrop
//
//  Created by Mattijs on 11/01/2017.
//  Copyright © 2017 Mattijs. All rights reserved.
//

import Cocoa
import Darwin

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    fileprivate let eyeDropController = EyeDropController()
    fileprivate let statusMenuController = EyeDropStatusMenuController()
    fileprivate let previewOverlayController = OverlayController()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        AppSettings.registerDefaults()
        
        eyeDropController.delegate = self
        statusMenuController.delegate = self
        
        previewOverlayController.windowLevel = .mainMenuWindow
        previewOverlayController.animationSpeed = 0.3
        
        eyeDropController.start()
        statusMenuController.show(currentState: eyeDropController.state)
    }
}


extension AppDelegate: EyeDropStatusMenuControllerDelegate {
    func menuShouldUpdateState() {
        statusMenuController.update(forRemainingInterval: eyeDropController.remainingInterval)
        statusMenuController.update(forState: eyeDropController.state)
        statusMenuController.update(forInterval: eyeDropController.interval)
        statusMenuController.update(forDarknessOption: eyeDropController.darkness)
    }
    
    func menuPauseIntervalTapped() {
        eyeDropController.pause()
    }
    
    func menuResumeIntervalTapped() {
        eyeDropController.resume()
    }
    
    func menuChangeIntervalTapped(interval: TimeInterval) {
        eyeDropController.interval = interval
    }
    
    func menuChangeDarknessOptionTapped(darknessOption: DarknessOption) {
        eyeDropController.darkness = darknessOption
    }
    
    func menuQuitApplicationTapped() {
        NSApplication.shared().terminate(nil)
    }
}

extension AppDelegate: EyeDropControllerDelegate {
    func eyeDropController(eyeDrop: EyeDropController, didUpdateState state: EyeDropState) {
        statusMenuController.update(forState: state)
    }
    func eyeDropController(eyeDrop: EyeDropController, didUpdateInterval interval: TimeInterval) {
        statusMenuController.update(forInterval: interval)
    }
    func eyeDropController(eyeDrop: EyeDropController, didUpdateDarkness darkness: DarknessOption) {
        statusMenuController.update(forDarknessOption: darkness)
    }
    func menuHighlightsDarknessOption(darknessOption: DarknessOption?) {
        if let darknessOption = darknessOption {
            previewOverlayController.show(duration: TimeInterval.infinity, darkness: darknessOption)
        } else {
            previewOverlayController.hide()
        }
    }
}

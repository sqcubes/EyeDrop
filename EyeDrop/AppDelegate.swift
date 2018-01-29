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
        
        // using .accessory instead of .prohibited, otherwise:
        // - use of NSApp.hide & NSApp.unhideWithoutActivation cancels fade-out animation
        // - we cannot use NSApp.activate to be able to catch ESC presses
        NSApp.setActivationPolicy(.accessory) // https://github.com/shinypb/FullScreenDetector

        eyeDropController.delegate = self
        statusMenuController.delegate = self
        
        previewOverlayController.windowLevel = .mainMenuWindow
        previewOverlayController.hideLogo = false
        previewOverlayController.hideProgress = true
        previewOverlayController.animationSpeed = 0.3
        previewOverlayController.blur = eyeDropController.blur
        
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
        statusMenuController.update(forBlurEnabled: eyeDropController.blur)
        statusMenuController.update(forRunAfterLogin: eyeDropController.runAfterLogin)
        statusMenuController.update(forCancelable: eyeDropController.cancelable)
        statusMenuController.update(forPauseInFullScreen: eyeDropController.pauseInFullScreen)
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
    
    func menuToggleBlurTapped() {
        eyeDropController.blur = !eyeDropController.blur
        previewOverlayController.blur = eyeDropController.blur
    }
    
    func menuQuitApplicationTapped() {
        NSApplication.shared.terminate(nil)
    }
    
    func menuRunAfterLoginTapped() {
        eyeDropController.runAfterLogin = !eyeDropController.runAfterLogin
    }
    
    func menuCancelableTapped() {
        eyeDropController.cancelable = !eyeDropController.cancelable
    }
    
    func menuPauseInFullScreenTapped() {
        eyeDropController.pauseInFullScreen = !eyeDropController.pauseInFullScreen
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
    
    func eyeDropController(eyeDrop: EyeDropController, didUpdateBlurEnabled blurEnabled: Bool) {
        statusMenuController.update(forBlurEnabled: blurEnabled)
    }
    
    func eyeDropController(eyeDrop: EyeDropController, didUpdateRunAtLogin runAtLogin: Bool) {
        statusMenuController.update(forRunAfterLogin: runAtLogin)
    }
    
    func eyeDropController(eyeDrop: EyeDropController, didUpdateCancelable cancelable: Bool) {
        statusMenuController.update(forCancelable: cancelable)
    }

    func eyeDropController(eyeDrop: EyeDropController, didUpdatePauseInFullScreen pauseInFullScreen: Bool) {
        statusMenuController.update(forPauseInFullScreen: pauseInFullScreen)
    }
    
    func menuHighlightsDarknessOption(darknessOption: DarknessOption?) {
        if let darknessOption = darknessOption {
            previewOverlayController.show(duration: TimeInterval.infinity, darkness: darknessOption, activateApp: false)
        } else {
            previewOverlayController.hide()
        }
    }
}

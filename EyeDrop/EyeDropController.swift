//
//  EyeDropController.swift
//  EyeDrop
//
//  Created by Mattijs on 29/01/2017.
//  Copyright © 2017 Mattijs. All rights reserved.
//

import Foundation
import Cocoa

protocol EyeDropControllerDelegate {
    func eyeDropController(eyeDrop: EyeDropController, didUpdateState state: EyeDropState)
    func eyeDropController(eyeDrop: EyeDropController, didUpdateInterval interval: TimeInterval)
    func eyeDropController(eyeDrop: EyeDropController, didUpdateDarkness darkness: DarknessOption)

}

class EyeDropController {
    var delegate: EyeDropControllerDelegate?
    private var overlayTimer: Timer?
    private var remainingIntervalUponPaused = TimeInterval(-1)
    private let overlayController = OverlayController()
    private var previousScreenIsLocked = false
    
    private(set) var state: EyeDropState = .Active {
        didSet{
            if oldValue != state {
                delegate?.eyeDropController(eyeDrop: self, didUpdateState: state)
            }
        }
    }
    
    var remainingInterval: TimeInterval {
        return overlayTimer?.fireDate.timeIntervalSinceNow ?? 0
    }
    
    var interval: TimeInterval {
        get { return TimeInterval(AppSettings.interval.integer) }
        set {
            let changed = interval != newValue
            if (changed) {
                AppSettings.interval.set(newValue)
                resetInterval(to: interval)
                delegate?.eyeDropController(eyeDrop: self, didUpdateInterval: newValue)
            }
        }
    }
    
    var darkness: DarknessOption {
        get { return DarknessOption(rawValue: AppSettings.darknessOption.integer) ?? .Medium }
        set {
            let changed = darkness != newValue
            if (changed) {
                AppSettings.darknessOption.set(newValue.rawValue)
                delegate?.eyeDropController(eyeDrop: self, didUpdateDarkness: newValue)
            }
        }
    }
    
    func start() {
        NSWorkspace.shared().notificationCenter.addObserver(self, selector: #selector(workspaceWillSleep), name: NSNotification.Name.NSWorkspaceWillSleep, object: nil)
        NSWorkspace.shared().notificationCenter.addObserver(self, selector: #selector(workspaceDidWake), name: NSNotification.Name.NSWorkspaceDidWake, object: nil)
        
        
        NSWorkspace.shared().notificationCenter.addObserver(self, selector: #selector(screensDidSleep), name: NSNotification.Name.NSWorkspaceScreensDidSleep, object: nil)
        NSWorkspace.shared().notificationCenter.addObserver(self, selector: #selector(screensDidWake), name: NSNotification.Name.NSWorkspaceScreensDidWake, object: nil)
        
        Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(checkScreenLockState), userInfo: nil, repeats: true)
        
        // begin interval
        resetInterval()
    }
    
    @objc
    private func overlayTimerTimedOut(timer: Timer) {
        // timeout = interval minutes as 1:1 seconds
        // example = interval = 600s, timeout = 10s
        let timeout = timer.timeInterval / 60
        overlayController.show(duration: timeout, darkness: darkness)
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
        suspend()
    }
    
    @objc
    private func screenUnlocked() {
        resumeFromSuspendedState()
    }
    
    @objc
    private func screensDidSleep() {
        suspend()
    }
    
    @objc
    private func screensDidWake() {
        resumeFromSuspendedState()
    }
    
    @objc
    private func workspaceWillSleep() {
        suspend()
    }
    
    @objc
    private func workspaceDidWake() {
        resumeFromSuspendedState()
    }

    
    private func suspend() {
        overlayController.hide()
        cancelInterval()
    }
    
    private func resumeFromSuspendedState() {
        if state == .Paused {
            // currently paused,
            // reset the time remaining so that when resumed the regular interval will be used
            remainingIntervalUponPaused = interval
        } else {
            resetInterval()
        }
    }
    
    private func cancelInterval() {
        overlayTimer?.invalidate()
    }
    
    private func resetInterval() {
        resetInterval(to: interval)
    }
    
    private func resetInterval(to interval: TimeInterval, initialInterval: TimeInterval? = nil) {
        // abort existing timer
        cancelInterval()
        
        // determine next fire date
        var fireDate: Date!
        if let initialInterval = initialInterval {
            fireDate = Date().addingTimeInterval(initialInterval)
        } else {
            fireDate = Date().addingTimeInterval(interval)
        }
        
        // create and start new interval
        overlayTimer = Timer(fireAt: fireDate, interval: interval, target: self, selector: #selector(overlayTimerTimedOut(timer:)), userInfo: nil, repeats: true)
        RunLoop.current.add(overlayTimer!, forMode: RunLoopMode.defaultRunLoopMode)
        
        state = .Active
    }
    
    func pause() {
        state = .Paused
        remainingIntervalUponPaused = remainingInterval
        cancelInterval()
    }
    
    func resume() {
        resetInterval(to: interval, initialInterval: remainingIntervalUponPaused)
    }
}
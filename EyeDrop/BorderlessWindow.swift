//
//  BorderlessWindow.swift
//  EyeDrop
//
//  Created by Mattijs on 28/01/2018.
//  Copyright © 2018 Mattijs. All rights reserved.
//

import Cocoa

// https://stackoverflow.com/questions/11622255/keydown-not-being-called/11638926
class BorderlessWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}

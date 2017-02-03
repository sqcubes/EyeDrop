//
//  OverlayView.swift
//  EyeDrop
//
//  Created by Mattijs on 25/01/2017.
//  Copyright © 2017 Mattijs. All rights reserved.
//

import Cocoa

protocol OverlayViewDelegate {
    func overlayViewClicked(overlayView: OverlayView)
}

class OverlayView: NSView {
    var delegate: OverlayViewDelegate?
    
    init(delegate: OverlayViewDelegate) {
        self.delegate = delegate
        super.init(frame: NSRect.zero)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        if event.clickCount == 2 {
            delegate?.overlayViewClicked(overlayView: self)
        }
    }
}


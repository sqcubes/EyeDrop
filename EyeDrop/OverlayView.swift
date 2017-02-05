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
    private let logoImageView = NSImageView()
    var hideLogo: Bool = false {
        didSet {
            logoImageView.isHidden = hideLogo
        }
    }
    
    init(delegate: OverlayViewDelegate) {
        self.delegate = delegate
        super.init(frame: NSRect.zero)
        
        if let logoImage = NSImage(named: "Watermark") {
            logoImageView.image = logoImage
            logoImageView.alphaValue = 0.10
            logoImageView.frame = CGRect(x: 0, y: 0, width: logoImage.size.width, height: logoImage.size.height)
            logoImageView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(logoImageView)
            
            let views = ["logo": logoImageView]
            addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:[logo]-25-|", options: [], metrics: nil, views: views))
            addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:[logo]-20-|", options: [], metrics: nil, views: views))
        }
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


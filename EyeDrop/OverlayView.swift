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

extension DarknessOption {
    var alpha: CGFloat {
        switch self {
        case .High: return 1.0
        case .Medium: return 0.75
        case .Low: return 0.5
        }
    }
    
    var color: NSColor {
        return NSColor.black.withAlphaComponent(alpha)
    }
}

class OverlayView: NSView {
    var delegate: OverlayViewDelegate?
    private var blurView: NSView?
    private let darknessView = NSView()
    private let logoImageView = NSImageView()
    
    var hideLogo: Bool = false {
        didSet {
            logoImageView.isHidden = hideLogo
        }
    }
    
    var blur: Bool = false {
        didSet {
            if blur {
                addBlurViewIfNeeded()   
            } else {
                blurView?.removeFromSuperview()
            }
        }
    }
    
    var darkness: DarknessOption = .Medium {
        didSet {
            darknessView.layer?.backgroundColor = darkness.color.cgColor
        }
    }
    
    init(delegate: OverlayViewDelegate) {
        self.delegate = delegate
        super.init(frame: NSRect.zero)
        wantsLayer = true
        
        addDarknessViewIfNeeded()
        addLogoViewIfNeeded()
        
        // apply default darkness
        setDarkness(darkness: darkness, animated: false)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    func setDarkness(darkness: DarknessOption, animated: Bool, duration: TimeInterval = 0) {
        if animated {
            let toColor = darkness.color.cgColor
            let fromColor = darknessView.layer?.backgroundColor ?? toColor
            let darknessAnimation = CABasicAnimation(keyPath: "backgroundColor")
            darknessAnimation.fromValue = fromColor
            darknessAnimation.toValue = toColor
            darknessAnimation.duration = duration
            darknessView.layer?.add(darknessAnimation, forKey: "darkness")
        }
        
        self.darkness = darkness
    }
    
    private func addBlurViewIfNeeded() {
        // return when blur is unavailable or already added
        guard #available(OSX 10.10, *), OverlayView.isBlurAvailable, blurView?.superview == nil else { return }
    
        let visualEffectsView = NSVisualEffectView()
        visualEffectsView.translatesAutoresizingMaskIntoConstraints = false
        visualEffectsView.material = NSVisualEffectMaterial.dark
        visualEffectsView.blendingMode = NSVisualEffectBlendingMode.behindWindow
        visualEffectsView.state = NSVisualEffectState.active
        
        addSubview(visualEffectsView, positioned: NSWindowOrderingMode.below, relativeTo: subviews.first)
        let views = ["blur": visualEffectsView]
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-0-[blur]-0-|", options: [], metrics: nil, views: views))
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-0-[blur]-0-|", options: [], metrics: nil, views: views))
        
        self.blurView = visualEffectsView
    }
    
    /***
     Adding a dedicated background view will make sure the proper darkness
     is applied on top of the blur view in case blur is available and used
     */
    private func addDarknessViewIfNeeded() {
        guard darknessView.superview == nil else { return }
        
        let views = ["backgroundView": darknessView]
        darknessView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(darknessView, positioned: .above, relativeTo: blurView)
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-0-[backgroundView]-0-|", options: [], metrics: nil, views: views))
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-0-[backgroundView]-0-|", options: [], metrics: nil, views: views))
    }
    
    private func addLogoViewIfNeeded() {
        guard let logoImage = NSImage(named: "Watermark"), logoImageView.superview == nil else { return }
        
        logoImageView.image = logoImage
        logoImageView.alphaValue = 0.1
        logoImageView.frame = CGRect(x: 0, y: 0, width: logoImage.size.width, height: logoImage.size.height)
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(logoImageView, positioned: .above, relativeTo: darknessView)
        let views = ["logo": logoImageView]
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:[logo]-25-|", options: [], metrics: nil, views: views))
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:[logo]-20-|", options: [], metrics: nil, views: views))
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        if event.clickCount == 2 {
            delegate?.overlayViewClicked(overlayView: self)
        }
    }
    
    /**
     Determines whether or not the current platform supports background blur. it basically
     checks if the operating system is macOS Yosemite (10.10) or higher
     */
    static var isBackgroundBlurSupported: Bool {
        guard #available(OSX 10.10, *) else { return false }
        return true
    }
    
    /**
     Determines whether or not the background blur is available. The feature is not available on 
     macOS =<10.9 or when user activated the 'Reduce transparency' Accessibility option.
     */
    static var isBlurAvailable: Bool {
        guard #available(OSX 10.10, *) else { return false }
        return !NSWorkspace.shared().accessibilityDisplayShouldReduceTransparency
    }
}


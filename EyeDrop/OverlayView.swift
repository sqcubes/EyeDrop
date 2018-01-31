//
//  OverlayView.swift
//  EyeDrop
//
//  Created by Mattijs on 25/01/2017.
//  Copyright © 2017 Mattijs. All rights reserved.
//

import Cocoa

protocol OverlayViewDelegate {
    func overlayViewCancelled(overlayView: OverlayView)
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
    private let progressView = NSView()
    private let logoImageView = NSImageView()
    
    private var progressViewZeroWidthConstraint: NSLayoutConstraint?
    
    var hideLogo: Bool = false {
        didSet {
            logoImageView.isHidden = hideLogo
        }
    }
    
    var hideProgress: Bool = false {
        didSet {
            progressView.isHidden = hideProgress
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
        addProgressBarIfNeeded()
        
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
    
    func beginProgress(duration: TimeInterval) {
        NSAnimationContext.runAnimationGroup({ [weak self] (context) -> Void in
            context.duration = duration
            context.allowsImplicitAnimation = true
            context.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
            self?.progressViewZeroWidthConstraint?.priority = NSLayoutConstraint.Priority(rawValue: 750)
            self?.layoutSubtreeIfNeeded()
        }, completionHandler: nil)
    }
    
    private func addBlurViewIfNeeded() {
        // return when blur is unavailable or already added
        guard #available(OSX 10.10, *), OverlayView.isBlurAvailable, blurView?.superview == nil else { return }
    
        let visualEffectsView = NSVisualEffectView()
        visualEffectsView.translatesAutoresizingMaskIntoConstraints = false
        visualEffectsView.material = NSVisualEffectView.Material.dark
        visualEffectsView.blendingMode = NSVisualEffectView.BlendingMode.behindWindow
        visualEffectsView.state = NSVisualEffectView.State.active
        
        addSubview(visualEffectsView, positioned: NSWindow.OrderingMode.below, relativeTo: subviews.first)
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
        darknessView.wantsLayer = true
        
        addSubview(darknessView, positioned: .above, relativeTo: blurView)
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-0-[backgroundView]-0-|", options: [], metrics: nil, views: views))
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-0-[backgroundView]-0-|", options: [], metrics: nil, views: views))
    }
    
    private func addLogoViewIfNeeded() {
        guard let logoImage = NSImage(named: NSImage.Name(rawValue: "Watermark")), logoImageView.superview == nil else { return }
        
        logoImageView.image = logoImage
        logoImageView.alphaValue = 0.1
        logoImageView.frame = CGRect(x: 0, y: 0, width: logoImage.size.width, height: logoImage.size.height)
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(logoImageView, positioned: .above, relativeTo: darknessView)
        let views = ["logo": logoImageView]
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:[logo]-25-|", options: [], metrics: nil, views: views))
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:[logo]-20-|", options: [], metrics: nil, views: views))
    }
    
    private func addProgressBarIfNeeded() {
        guard progressView.superview == nil else { return }
        
        progressView.wantsLayer = true
        progressView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.6).cgColor
        progressView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(progressView, positioned: .above, relativeTo: darknessView)
        
        let views = ["progressView": progressView]
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-0-[progressView(2)]", options: [], metrics: nil, views: views))
        
        let fullWidthConstraint = NSLayoutConstraint(item: progressView, attribute: NSLayoutConstraint.Attribute.width, relatedBy: NSLayoutConstraint.Relation.equal, toItem: self, attribute: NSLayoutConstraint.Attribute.width, multiplier: 1.0, constant: 0)
        fullWidthConstraint.priority = NSLayoutConstraint.Priority(rawValue: 500)
        let zeroWidthConstraint = NSLayoutConstraint(item: progressView, attribute: NSLayoutConstraint.Attribute.width, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1.0, constant: 0)
        zeroWidthConstraint.priority = NSLayoutConstraint.Priority(rawValue: 250)
        let centerHorizontallyConstraint = NSLayoutConstraint(item: progressView, attribute: NSLayoutConstraint.Attribute.centerX, relatedBy: NSLayoutConstraint.Relation.equal, toItem: self, attribute: NSLayoutConstraint.Attribute.centerX, multiplier: 1.0, constant: 0.0)
        
        self.progressViewZeroWidthConstraint = zeroWidthConstraint
        
        addConstraints([centerHorizontallyConstraint, fullWidthConstraint, zeroWidthConstraint])
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        if event.clickCount == 2 {
            delegate?.overlayViewCancelled(overlayView: self)
        }
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func cancelOperation(_ sender: Any?) {
        delegate?.overlayViewCancelled(overlayView: self)
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
        return !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
    }
}


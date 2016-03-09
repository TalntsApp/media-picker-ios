//
//  RecordButton.swift
//  Talnts
//
//  Created by Mikhail Stepkin on 24.09.15.
//  Copyright (c) 2015 Ramotion. All rights reserved.
//

import UIKit

import Signals

//@IBDesignable
class RecordButton: UIView {
    
    private var onTap: (() -> Void)?
    
    @IBInspectable
    var recording: Bool = false {
        didSet {
            self.setNeedsDisplayInRect(bounds)
        }
    }
    
    @IBInspectable
    var progress: CGFloat = 0.0 {
        didSet {
            self.setNeedsDisplayInRect(bounds)
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    private func setup() {
        self.tapGestureRecognizer = UITapGestureRecognizer(target: self, action: Selector("tapHandler"))
        self.addGestureRecognizer(tapGestureRecognizer)
        
        ignite(self).listen(self) {
            self.recording = !self.recording
        }
    }
    
    private var tapGestureRecognizer: UITapGestureRecognizer!
    func tapHandler() {
        onTap?()
    }
    
    override func drawRect(rect: CGRect) {
        let bounds = self.bounds
        
        let ctx = UIGraphicsGetCurrentContext()
        
        // Clear background
        UIColor.clearColor().set()
        CGContextClearRect(ctx, bounds)
        
        UIColor.whiteColor().set()
        CGContextFillEllipseInRect(ctx, bounds)
        
        // Setting main color
        self.tintColor.set()
        
        // Drawing path
        let path: UIBezierPath
        if recording {
            let pathRect = CGRectInset(bounds, bounds.width/3, bounds.height/3)
            let radius = (pathRect.width + pathRect.height)/18
            path = UIBezierPath(roundedRect: pathRect, cornerRadius: radius)
        }
        else {
            let width = (bounds.width + bounds.height)/48
            let pathRect = CGRectInset(bounds, width, width)
            path = UIBezierPath(ovalInRect: pathRect)
        }
        
        CGContextAddPath(ctx, path.CGPath)
        CGContextFillPath(ctx)
    
        if recording {
            let percentage = progress/100
            let angle = CGFloat(2 * M_PI) * percentage - CGFloat(M_PI_2)
            let width = (bounds.width + bounds.height)/48
            
            CGContextSetLineWidth(ctx, width)
            CGContextAddArc(ctx, bounds.midX, bounds.midY, (bounds.width + bounds.height)/4 - width/2, -CGFloat(M_PI_2), angle, 0)
            CGContextStrokePath(ctx)
        }
    }
    
}

func ignite(recordButton: RecordButton) -> Signal<()> {
    let signal: Signal<()> = Signal<()>()
    
    recordButton.onTap = signal.fire
    
    return signal
}

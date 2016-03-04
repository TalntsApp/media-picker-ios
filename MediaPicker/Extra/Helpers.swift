import Foundation
import AVFoundation

import Signals

extension Signal {
    
    func reduce<U>(start: U, f: (U, T) -> U) -> Signal<U> {
        let reduced: Signal<U> = Signal<U>()
        reduced.fire(start)
        
        var acc: U = start
        self.listenPast(self) { t in
            acc = f(acc, t)
            reduced.fire(acc)
        }
        
        return reduced
    }
    
}

/// Implementing type can provide image in `UIImage` asynchronously
public protocol ImageSource {
    
    /// Called when `UIImage` is provided
    var onImageReady: (UIImage -> Void)? { get set }
    /// Called when action was cancelled
    var onClose: (() -> Void)? { get set }
    
}

/// Implementing type can provide video in `AVURLAsset` asynchronously
public protocol VideoSource {
    
    /// Called when `AVURLAsset` with video is provided
    var onVideoReady: (AVURLAsset -> Void)? { get set }
    /// Called when action was cancelled
    var onClose: (() -> Void)? { get set }
    
}

class Animate {
    typealias Action = () -> Void
    
    var duration: NSTimeInterval
    var options:  UIViewAnimationOptions
    
    init (duration:NSTimeInterval, options: UIViewAnimationOptions) {
        self.duration = duration
        self.options  = options
    }
    
    var before: Action?
    func before(before: Action) -> Animate {
        self.before = before
        return self
    }
    
    var animation: Action?
    func animation(animation: Action) -> Animate {
        self.animation = animation
        return self
    }
    
    var after: Action?
    func after(after: Action) -> Animate {
        self.after = after
        return self
    }
    
    var then: Animate?
    func then(then: Animate) -> Animate {
        self.then = then
        return self
    }
    
    func fire() {
        before?()
        UIView.animateWithDuration(duration,
            delay: 0.0,
            usingSpringWithDamping: 0.75,
            initialSpringVelocity:  0.5,
            options: options,
            animations: { [weak self] in
                self?.animation?()
            }, completion: { finished in
                if (finished) {
                    self.after?()
                    self.then?.fire()
                }
        })
    }
}

infix operator >*> {
associativity left
precedence 162
}

func >*>(lhs: Animate, rhs: Animate) -> Animate {
    return lhs.then(rhs)
}

func >*>(lhs: Animate, rhs: ()) -> () {
    lhs.fire()
}

@warn_unused_result
func addMotionEffects(views: [UIView]) -> Animate {
    return views.addMotionEffects()
}

extension SequenceType where Generator.Element: UIView {
    @warn_unused_result
    func addMotionEffects() -> Animate {
        return Animate(duration: 0.3, options: UIViewAnimationOptions.CurveEaseInOut).animation { self.forEach { view -> () in
            let horizontalEffect = UIInterpolatingMotionEffect(keyPath: "center.x", type: .TiltAlongHorizontalAxis)
            horizontalEffect.minimumRelativeValue = -13
            horizontalEffect.maximumRelativeValue =  13
            
            let verticalEffect = UIInterpolatingMotionEffect(keyPath: "center.y", type: .TiltAlongVerticalAxis)
            verticalEffect.minimumRelativeValue = -13
            verticalEffect.maximumRelativeValue =  13
            
            let group = UIMotionEffectGroup()
            group.motionEffects = [horizontalEffect, verticalEffect]
            
            view.addMotionEffect(group)
            }}
    }
}

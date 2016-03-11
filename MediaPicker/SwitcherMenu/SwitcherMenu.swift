//
//  SwitcherMenu.swift
//  Talnts
//
//  Created by Mikhail Stepkin on 07.08.15.
//  Copyright (c) 2015 Ramotion. All rights reserved.
//

import UIKit

import Runes

import Cartography

public class SwitcherMenu: UIViewController {
    
    public var onTap: [MediaSourceType: () -> Void] = [:]
    
    private(set) public var items: [MediaSourceType: UIButton] = [:]
    private(set) public var buttons: [UIButton] = []
    
    public init(items: Set<MediaSourceType>, selectedColor: UIColor) {
        super.init(nibName: "SwitcherMenu", bundle: nil)
        
        self.items = items.reduce([:], combine: { (var acc, item) -> [MediaSourceType: UIButton] in
            let uiButton: UIButton = (UIButton(type: UIButtonType.Custom))
            
            uiButton.setTitle(item.title, forState: .Normal)
            uiButton.setTitleColor(UIColor.whiteColor(), forState: .Normal)
            uiButton.setTitleColor(selectedColor, forState: .Selected)
            uiButton.setTitleColor(selectedColor, forState: .Highlighted)
            
            acc[item] = uiButton
            return acc
        })
        
        self.buttons = self.items.sorted({$0.0 <= $1.0}).map({ (_, btn) in btn })
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        let buttonsArray = items.sorted({ $0.0 < $1.0 })
        let (keys, values) = unzip(buttonsArray)
        
        values.forEach(view.addSubview)
        
        _ = keys.reduce([:], combine: { (var acc, button) -> [String: UIButton] in
            acc["\(button)"] = self.items[button]
            return acc
        })
        
        buttonsArray.forEach { tuple -> Void in
            let (key, value) = tuple
            
            switch keys.borderPositon(key) {
            case .Min:
                constrain(value, value.superview!) { button, superview in
                    button.leading == superview.leading + 20
                    button.bottom  == superview.bottom
                }
            case .Mid:
                constrain(value, value.superview!) { button, superview in
                    button.bottom == superview.bottom
                }
            case .Max:
                constrain(value, value.superview!) { button, superview in
                    button.trailing == superview.trailing - 20
                    button.bottom == superview.bottom
                }
                
            case .Both:
                constrain(value, value.superview!) { button, superview in
                    button.leading == superview.leading + 20
                    button.trailing == superview.trailing - 20
                    button.bottom == superview.bottom
                }
            }
        }
        
        values.pairEnum { (prev: UIButton, curr: UIButton) -> ConstraintGroup in
            return constrain(prev, curr) { left, right in
                left.trailing == right.leading
                left.height   == right.height
                left.width    == right.width
            }
        }
        
        items[.Gallery]?.selected = true
        
        keys.forEach {[weak self] (key: MediaSourceType) -> Void in
            if let `self` = self {
                let signal = self.items[key]?.onTouchDown
                
                // Selection
                signal?.listen(self) {[weak self] in
                    keys.forEach {
                        self?.items[$0]?.selected = ($0 == key)
                    }
                }
                
                // Tap action
                signal?.listen(self) {[weak self] in
                    self?.onTap[key]?()
                }
            }
        }
    }
    
}

public enum MediaSourceType: CustomStringConvertible, Comparable {
    case Gallery
    case Photo
    case Video
    
    public var description: String {
        switch self {
        case .Gallery:
            return "Gallery"
        case .Photo:
            return "Photo"
        case .Video:
            return "Video"
        }
    }
    
    public var title: String {
        switch self {
        case .Gallery:
            return NSLocalizedString("Gallery", comment: "Gallery")
        case .Photo:
            return NSLocalizedString("Photo", comment: "Photo")
        case .Video:
            return NSLocalizedString("Video", comment: "Video")
        }
    }
}

public func ==(lhs: MediaSourceType, rhs: MediaSourceType) -> Bool {
    switch (lhs, rhs) {
    case (.Gallery, .Gallery), (.Photo, .Photo), (.Video, .Video):
        return true
    default:
        return false
    }
}

public func <(lhs: MediaSourceType, rhs: MediaSourceType) -> Bool {
    switch (lhs, rhs) {
    case (.Gallery, .Photo), (.Gallery, .Video), (.Photo, .Video):
        return true
    default:
        return false
    }
}

enum Bounds {
    case Both
    
    case Min
    case Mid
    case Max
}

extension SequenceType where Generator.Element: Comparable {
    typealias T = Generator.Element
    
    func extreme(comparator: (T, T) -> T) -> T? {
        var generator = self.generate()
        if let initial = generator.next() {
            return self.reduce(initial) { (acc: T, cur: T) -> T in
                return comparator(acc, cur)
            }
        }
        else {
            return nil
        }
    }
    
    var minValue: T? {
        return extreme(min)
    }
    
    var maxValue: T? {
        return extreme(max)
    }
    
    func borderPositon(element: T) -> Bounds {
        let minimal = self.minValue
        let maximal = self.maxValue
        
        if element == minimal && element == maximal {
            return .Both
        }
        else if element == minimal {
            return .Min
        }
        else if element == maximal {
            return .Max
        }
        else {
            return .Mid
        }
    }
}

extension SequenceType {
    func pairEnum<U>(enumerator: (Generator.Element, Generator.Element) -> U) -> [U] {
        var generator = self.generate()
        
        var result:[U] = []
        if var previous = generator.next() {
            while let current = generator.next() {
                result.append(enumerator(previous, current))
                previous = current
            }
        }
        
        return result
    }
}

func unzip<T, U>(tuples: [(T, U)]) -> ([T], [U]) {
    return tuples.reduce(([], [])) { (acc, cur) -> ([T], [U]) in
        let (ts, us) = acc
        let (t, u)   = cur
        
        return (ts + [t], us + [u])
    }
}

func unzip<T, U>(dictionary: [T: U]) -> ([T], [U]) {
    return unzip(Array(dictionary))
}

extension Dictionary {
    
    func sorted(isOrderedBefore: ((Key, Value), (Key, Value)) -> Bool) -> [(Key, Value)] {
        let sorted = Array(self).sort(isOrderedBefore)
        return sorted
    }
    
}

class InertView: UIView {
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        //        print(self.superview)
        self.superview?.touchesBegan(touches, withEvent: event)
    }
    
}

class InertImageView: UIImageView {
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        //        print(self.superview)
        self.superview?.touchesBegan(touches, withEvent: event)
    }
    
}
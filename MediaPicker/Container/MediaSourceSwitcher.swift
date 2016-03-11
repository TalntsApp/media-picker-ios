//
//  ImageSourceSwitcher.swift
//  Talnts
//
//  Created by Mikhail Stepkin on 06.08.15.
//  Copyright (c) 2015 Ramotion. All rights reserved.
//

import UIKit
import AVFoundation
import TalntsUI
import SwipeBack
import Runes

class MediaSourceSwitcher: UIPageViewController, UIPageViewControllerDelegate, UIPageViewControllerDataSource, ImageSource, VideoSource, HideHamburger {
    
    var onImageReady: (UIImage -> Void)?
    var onVideoReady: (AVURLAsset -> Void)?
    var onClose: (() -> Void)?
    
    private var imageSources: [ImageSourceType: UIViewController] = [:]
    private var sourcesArray: [UIViewController] {
        return imageSources.sorted({$0.0 < $1.0}).map { (_, vc) in
            vc
        }
    }
    
    private var switcherMenu: SwitcherMenu?
    convenience init(maskType: ImageSelection.MaskType) {
        self.init(transitionStyle: .Scroll, navigationOrientation: .Horizontal, options: [:])
        
        imageSources[.Gallery] = ImageSelection(maskType: maskType)
        
        if CameraVC.authorizationStatus == .Authorized {
            imageSources[.Photo] = CameraVC(cameraType: .Photo)
            imageSources[.Video] = CameraVC(cameraType: .Video)
        }
        
        self.switcherMenu = SwitcherMenu(items: Set(Array(imageSources.keys)))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        Array(imageSources).forEach { (type, controller) -> Void in
            if var source = controller as? ImageSource {
                source.onImageReady = self.onImageReady
                source.onClose = {[weak self] in self?.onClose?()}
            }
            
            if var source = controller as? VideoSource {
                source.onVideoReady = self.onVideoReady
                source.onClose = {[weak self] in self?.onClose?()}
            }
        }
        
        self.dataSource = self
        self.delegate   = self
        
        switcherMenu?.onTap[.Gallery] = {[weak self] in self?.onImageTap()}
        switcherMenu?.onTap[.Photo]   = {[weak self] in self?.onPhotoTap()}
        switcherMenu?.onTap[.Video]   = {[weak self] in self?.onVideoTap()}
        
        self.addChildViewController <^> switcherMenu
        
        let menu = switcherMenu?.view
        menu?.frame = CGRect(x: 0, y: self.view.bounds.height - 40, width: self.view.bounds.width, height: 40)
        menu?.autoresizingMask = UIViewAutoresizing.FlexibleHeight
        self.view.addSubview <^> menu
    }
    
    override func viewDidLayoutSubviews() {
        switcherMenu?.view?.frame = CGRect(x: 0, y: self.view.bounds.height - 40, width: self.view.bounds.width, height: 40)
    }
    
    private func onImageTap() {

        let imageVC = self.imageSources[.Gallery]!
        
        objc_sync_enter(self)
        self.setViewControllers([imageVC], direction: .Reverse, animated: false, completion: nil)
        objc_sync_exit(self)
    }
    
    private func onPhotoTap() {

        let photoVC = self.imageSources[.Photo]!
        let photoIndex = self.sourcesArray.indexOf(photoVC)
        
        let direction: UIPageViewControllerNavigationDirection
        if
            let vc = self.viewControllers?.first,
            let vcIndex = self.sourcesArray.indexOf(vc)
        {
            if photoIndex < vcIndex {
                direction = .Reverse
            }
            else {
                direction = .Forward
            }
        }
        else {
            direction = .Reverse
        }
        
        objc_sync_enter(self)
        self.setViewControllers([photoVC], direction: direction, animated: false, completion: nil)
        objc_sync_exit(self)
    }
    
    private func onVideoTap() {
        let videoVC = self.imageSources[.Video]!
        
        objc_sync_enter(self)
        self.setViewControllers([videoVC], direction: .Forward, animated: false, completion: nil)
        objc_sync_exit(self)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.swipeBackEnabled = false
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationController?.navigationBarType = NavigationBarType.BlackFlat(height:44)
        
        let imageSource = imageSources[.Gallery] as! ImageSelection
        self.setViewControllers([imageSource], direction: .Forward, animated: false, completion: nil)
        switcherMenu?.items.forEach { type, button -> Void in button.selected = (type == .Gallery) }
    }
    
    override func viewWillDisappear(animated: Bool) {
        self.navigationController?.swipeBackEnabled = true
    }
    
    // Data Source
    func pageViewController(pageViewController: UIPageViewController, viewControllerBeforeViewController viewController: UIViewController) -> UIViewController? {
        if let index = (sourcesArray as [UIViewController]).indexOf(viewController) {
            let prev = index - 1
            return valueAtIndex(sourcesArray, prev)
        }
        return nil
    }
    
    func pageViewController(pageViewController: UIPageViewController, viewControllerAfterViewController viewController: UIViewController) -> UIViewController? {
        if let index = (sourcesArray as [UIViewController]).indexOf(viewController) {
            let next = index + 1
            return valueAtIndex(sourcesArray, next)
        }
        return nil
    }
    
    func pageViewController(pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if completed {
            asyncWith(self, priority: .Main) { [weak self] in
                if
                    let `self` = self,
                    let viewController: UIViewController = self.viewControllers?.first,
                    let index = (self.sourcesArray as [UIViewController]).indexOf(viewController),
                    let buttons = self.switcherMenu?.buttons
                    where index != NSNotFound
                {
                    let zip = Zip2Sequence(buttons, self.sourcesArray)
                    
                    for (idx, (button, _)) in zip.enumerate() {
                        let isSelected = (idx == index)
                        button.selected = isSelected
                    }
                }
            }
        }
    }
    
    func hideHamburger() -> Bool {
        return true
    }
}

protocol ImageSource {
    
    var onImageReady: (UIImage -> Void)? { get set }
    var onClose: (() -> Void)? { get set }
    
}

protocol VideoSource {
    
    var onVideoReady: (AVURLAsset -> Void)? { get set }
    var onClose: (() -> Void)? { get set }

}
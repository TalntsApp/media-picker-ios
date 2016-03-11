import UIKit
import MediaPlayer
import AVFoundation
import Photos

import Runes
import Argo

import BABCropperView

/**
 MediaPicker
 ----
 
 Control that allows you to pick media from gallery.
 */
public class MediaPicker: UIViewController, ImageSource, VideoSource {
    
    /// Image from gallery was selected
    public var onImageReady: (UIImage -> Void)?
    /// Video from gallery was selected
    public var onVideoReady: (AVURLAsset -> Void)?
    /// Selection was cancelled
    public var onClose: (() -> Void)?
    
    private weak var selectedAsset: PHAsset?
    @IBOutlet var largePreviewConstraint: NSLayoutConstraint!
    @IBOutlet var largePreview: BABCropperView!
    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    @IBOutlet var videoPreview: UIView?
    @IBOutlet var videoPlayControl: PlayControlView?
    
    @IBOutlet var upButtonConstraint: NSLayoutConstraint!
    @IBOutlet var upButton: UIButton!
    @IBOutlet var upButtonIcon: UIImageView!
    
    @IBOutlet var collectionHost: UIView!
    
    
    private enum PreviewState: CustomStringConvertible {
        case AllWayUp
        case FreeScroll
        
        mutating func flip() {
            switch self {
            case .FreeScroll:
                self = .AllWayUp
            case .AllWayUp:
                self = .FreeScroll
            }
        }
        
        var description: String {
            switch self {
            case .AllWayUp:
                return "AllWayUp"
            case .FreeScroll:
                return "FreeScroll"
            }
        }
    }
    
    private var previewState = PreviewState.FreeScroll {
        didSet {
            if previewState != oldValue {
                updatePreview()
            }
        }
    }
    
    func updatePreview() {
        if let imageCollection = self.imageCollection {
            let topPosition: CGFloat
            let iconTransform: CGAffineTransform
            
            switch self.previewState {
            case .AllWayUp:
                topPosition = -self.largePreview.frame.height
                iconTransform = CGAffineTransformMakeScale(1.0, -1.0)
            case .FreeScroll:
                topPosition = 0
                iconTransform = CGAffineTransformIdentity
            }
            
            Animate(duration: 0.6, options: UIViewAnimationOptions.CurveEaseInOut)
                .animation {
                    self.largePreviewConstraint.constant = topPosition
                    self.upButtonIcon.transform = iconTransform
                    
                    self.largePreview.layoutIfNeeded()
                    self.upButton.layoutIfNeeded()
                    imageCollection.layoutIfNeeded()
                }
                .fire()
        }
    }
    
    public enum MaskType {
        case Rectangle
        case Circle
    }
    private(set) public var maskType: MaskType = .Rectangle
    
    private(set) var photosOnly: Bool = false
    public convenience init(maskType: MaskType = .Rectangle, photosOnly: Bool = false) {
        let bundle = NSBundle(forClass: self.dynamicType)
        self.init(nibName: "MediaPicker", bundle: bundle)
        self.photosOnly = photosOnly
        
        self.maskType = maskType
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        setupForm()
        
        self.edgesForExtendedLayout = UIRectEdge.None
    }
    
    func hideHamburger() -> Bool {
        return true
    }
    
    override public func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        let title: String = photosOnly ? "Choose photo" : "Choose photo or video"
        navigationController?.topViewController?.navigationItem.title = title
        
        setupBackButton()
        setupNextButton()
        
        if let selectedPath = self.imageCollection?.indexPathsForSelectedItems()?.first
        {
            let asset = self.imageList.assets[selectedPath.section].assets[selectedPath.item]
            self.handleSelection(selectedPath, asset)
        }
    }
    
    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        setupCropper()
        
        imageList.viewDidLayoutSubviews()
    }
    
    private func setupCropper() {
        self.largePreview.cropDisplayScale = 1.0
        self.largePreview.cropSize = CGSize(width: 1242, height: 1242)
    }
    
    private lazy var imageList:MediaList = MediaList(photosOnly: self.photosOnly)
    private var imageCollection: UICollectionView?
    func setupForm() {
        self.largePreview.clipsToBounds = true
        self.largePreview.cropsImageToCircle = (self.maskType == .Circle)
        self.largePreview.leavesUnfilledRegionsTransparent = true
        
        self.addChildViewController(imageList)
        
        imageCollection = imageList.collectionView
        imageCollection?.frame = self.collectionHost.bounds
        imageCollection?.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        
        self.collectionHost.addSubview <^> imageCollection
        
        imageList.selectionSignal.listen(self) {[weak self] (indexPath, asset) in
            if let `self` = self {
                self.handleSelection(indexPath, asset)
            }
        }
        
        imageList.scrollSignal.listen(self) {[weak self] offset in
            if let `self` = self {
                self.handleScroll(offset)
            }
        }
        
        upButton.onTouchDown.listen(self) { [weak self] in
            if let `self` = self {
                self.previewState.flip()
                self.updatePreview()
            }
        }
    }
    
    private func handleSelection(indexPath: NSIndexPath, _ asset: PHAsset) {
        self.selectedAsset = asset
        
        self.activityIndicator.hidden = false
        self.activityIndicator.startAnimating()
        self.largePreview.image = nil
        asset.talntsImage.listen(self) { [weak self] image in
            if let `self` = self {
                Animate(duration: 0.6, options: .CurveEaseInOut)
                    .before {
                        self.largePreview.image = image
                    }
                    .animation {
                        self.largePreviewConstraint.constant = 0
                    }
                    .after {
                        self.activityIndicator.stopAnimating()
                        self.previewState = .FreeScroll
                    }
                    .fire()
            }
        }
        
        self.largePreview.synced { [weak self] in
            if let `self` = self {
                self.videoPreview?.removeFromSuperview()
                self.videoPreview = nil
                self.videoPlayControl?.removeFromSuperview()
                self.videoPlayControl = nil
                
                if asset.mediaType == .Video {
                    asset.urlAsset.listen(self) { [weak self] asset in
                        self?.setupVideoPreview <*> asset
                        self?.activityIndicator.stopAnimating()
                    }
                }
            }
        }
    }
    
    private func handleScroll(offset: CGFloat) {
        if self.previewState == .FreeScroll {
            self.largePreviewConstraint?.constant = offset
            
            let verticalTransform = (offset/self.largePreview.frame.height + 1/2) * 2
            
            self.upButton.synced {
                Animate(duration: 0.6, options: .CurveEaseOut)
                    .animation { [weak self] in
                        self?.upButtonIcon.transform = CGAffineTransformMakeScale(1.0, clip(low: -1.0, high: 1.0)(value: verticalTransform))
                    }
                    .fire()
            }
        }
        
        switch self.previewState {
        case .AllWayUp where offset.isZero:
            Animate(duration: 0.6, options: .CurveEaseOut)
                .animation { [weak self] in
                    self?.previewState = .FreeScroll
                }
                .fire()
        case .FreeScroll where -offset >= self.largePreview.frame.height:
            self.previewState = .AllWayUp
        default:
            break
        }
    }
    
    private func setupVideoPreview(asset: AVURLAsset) {
    }
    
    private var statusBarHidden: Bool = UIApplication.sharedApplication().statusBarHidden
    @objc(videoWentFullscreen:)
    private func videoWentFullscreen(notification: NSNotification) {
        statusBarHidden = UIApplication.sharedApplication().statusBarHidden
    }
    
    @objc(videoReturnedFromFullscreen:)
    private func videoReturnedFromFullscreen(notification: NSNotification) {
        UIApplication.sharedApplication().statusBarHidden = statusBarHidden
    }
    
    @objc(videoPlaybackStateChanged:)
    private func videoPlaybackStateChanged(notification: NSNotification) {
        if let player = notification.object as? MPMoviePlayerController {
            switch player.playbackState {
            case .Paused:
                videoPlayControl?.playControlState = .Play
            case .Playing:
                videoPlayControl?.playControlState = .Pause
            default:
                videoPlayControl?.playControlState = .Wait
            }
        }
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    private func setupBackButton() {
        
        let backImage = UIImage(named:"close-icon")
        let img = UIImageView(image: backImage)
        img.frame.size.width = img.frame.size.width
        img.frame.size.height = img.frame.size.height
        
        let btn = UIButton(frame: img.frame)
        btn.setImage(backImage, forState: UIControlState.Normal)
        btn.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Normal)
        btn.onTouchDown.listen(self) {[weak self] in self?.back()}
        
        navigationController?.topViewController?.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: btn)
    }
    
    func back() {
        self.onClose?()
    }
    
    private func setupNextButton() {
        
        let btn = UIButton(type: .System)
        btn.bounds = CGRectMake(0, 0, 32, 20)
        btn.setTitle("Next", forState: UIControlState.Normal)
        btn.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Normal)
        btn.sizeToFit()
        btn.onTouchDown.listen(self) {[weak self] in self?.next()}
        
        navigationController?.topViewController?.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: btn)
    }
    
    func next() {
        if let asset = selectedAsset {
            switch asset.mediaType {
            case .Image:
                asyncWith(self.largePreview, priority: .High) { [weak self, largePreview = self.largePreview] in
                    self?.setupCropper()
                    largePreview.cropsImageToCircle = false
                    largePreview.renderCroppedImage { [weak self] (image, rect) in
                        self?.onImageReady <*> image
                    }
                }
            case .Video:
                asset.urlAsset.listen(self) { [weak self] urlAsset in
                    if
                        let urlAsset = urlAsset,
                        let `self` = self
                    {
                        let outputFileURL = urlAsset.URL
                        
//                        let videoVC = VideoCropViewController(videoURL: outputFileURL)
//                        videoVC.onVideoReady = { [weak self] asset -> Void in
//                            if let `self` = self {
//                                self.onVideoReady?(asset)
//                            }
//                        }
//                        videoVC.onClose = { [weak self] in
//                            self?.navigationController?.popViewControllerAnimated(true)
//                        }
//                        self.navigationController?.pushViewController(videoVC, animated: true)
                    }
                }
            default:
                break
            }
        }
    }
    
}

func clip<T: Comparable>(low low: T, high: T)(value: T) -> T {
    return max(low, min(high, value))
}

func *(lhs: CGFloat, rhs: CGSize) -> CGSize {
    return CGSize(width: lhs * rhs.width, height: lhs * rhs.height)
}

func *(lhs: CGSize, rhs: CGFloat) -> CGSize {
    return rhs * lhs
}

extension UIView {
    var viewController: UIViewController? {
        var nextResponder: UIResponder? = self
        
        repeat {
            nextResponder = nextResponder?.nextResponder()
            
            if let viewController = nextResponder as? UIViewController {
                return viewController
            }
        } while (nextResponder != nil)
        
        return nil
    }
}

class PlayControlView: UIButton {
    enum State {
        case Wait
        case Pause
        case Play
    }
    
    var playControlState: State = .Pause
}
import UIKit
import MediaPlayer
import AVFoundation
import Photos

import Runes
import Argo

import BABCropperView

public class ImageSelection: UIView, ImageSource, VideoSource {
    
    var onImageReady: (UIImage -> Void)?
    var onVideoReady: (AVURLAsset -> Void)?
    var onClose: (() -> Void)?
    
    private weak var selectedAsset: PHAsset?
    
    @IBOutlet var view: UIView?
    
    @IBOutlet var largePreviewConstraint: NSLayoutConstraint!
    @IBOutlet var largePreview: BABCropperView!
    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    
    @IBOutlet var upButtonConstraint: NSLayoutConstraint!
    @IBOutlet var upButton: UIButton!
    @IBOutlet var upButtonIcon: UIImageView!
    
    @IBOutlet var collectionHost: UIView!
    
    @IBOutlet var videoPreview: UIView?
    @IBOutlet var videoPlayControl: PlayControlView?
    
    @IBInspectable var photosOnly: Bool = false
    
    override public func awakeFromNib() {
        super.awakeFromNib()
        
        let bundle = NSBundle(forClass: ImageSelection.self)
        if let _ = bundle.loadNibNamed("ImageSelection", owner: self, options: nil) {
            self.view?.frame = self.bounds
            self.addSubview <^> self.view
            
            setup()
        }
    }
    
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
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        setupCropper()
    }
    
    private func setupCropper() {
        self.largePreview.cropDisplayScale = 1.0
        self.largePreview.cropSize = CGSize(width: 1242, height: 1242)
    }
    
    private lazy var imageList:ImageList = ImageList(photosOnly: self.photosOnly)
    private var imageCollection: UICollectionView?
    
    func setup() {
        self.viewController?.addChildViewController(imageList)
        
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
            self.upButton.synced {
                Animate(duration: 0.6, options: .CurveEaseOut)
                    .animation { [weak self] in
                        if let `self` = self {
                            self.largePreviewConstraint?.constant = offset
                            
                            let verticalTransform = round((offset/self.largePreview.frame.height + 1/2) * 2)
                            self.upButtonIcon.transform = CGAffineTransformMakeScale(1.0, clip(low: -1.0, high: 1.0)(value: verticalTransform))
                        }
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
        let videoPreview = UIView(frame: self.largePreview.bounds)
        videoPreview.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        videoPreview.backgroundColor = UIColor.clearColor()
        self.largePreview.addSubview(videoPreview)
        
        self.videoPreview = videoPreview
        
        //        videoPreview.remoteURL = asset.URL.absoluteString
        
        let statusBarHidden = UIApplication.sharedApplication().statusBarHidden
        let movieController = MPMoviePlayerViewController(contentURL: asset.URL)
        
        let player = movieController.view
        
        videoPreview.contentMode = .ScaleAspectFill
        player.contentMode = .ScaleAspectFill
        
        player.frame = videoPreview.bounds
        player.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        
        player.removeFromSuperview()
        videoPreview.addSubview(player)
        videoPreview.bringSubviewToFront(player)
        
        if
            let vc = player.viewController as? MPMoviePlayerViewController,
            let mp = vc.moviePlayer
        {
            //            mp.controlStyle = .None
            mp.shouldAutoplay = false
            UIApplication.sharedApplication().statusBarHidden = statusBarHidden
            
            //            let playControlView = PlayControlView(frame: player.bounds)
            //            playControlView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
            //            player.addSubview(playControlView)
            //
            //            playControlView.onTouchDown.listen(self) { [weak playControlView] in
            //                if let state = playControlView?.playControlState {
            //                    switch state {
            //                    case .Pause:
            //                        mp.pause()
            //                    case .Play:
            //                        mp.play()
            //                    default:
            //                        break
            //                    }
            //                }
            //            }
            //            playControlView.playControlState = .Play
            //                playControlView.enableTouch = true
            //            self.videoPlayControl = playControlView
            //
            //            NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("videoPlaybackStateChanged:"), name: MPMoviePlayerPlaybackStateDidChangeNotification, object: mp)
            //            NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("videoWentFullscreen:"), name: MPMoviePlayerWillEnterFullscreenNotification, object: mp)
            //            NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("videoReturnedFromFullscreen:"), name: MPMoviePlayerDidExitFullscreenNotification, object: mp)
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
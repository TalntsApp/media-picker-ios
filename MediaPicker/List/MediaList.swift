import UIKit
import AVFoundation

import Photos

import Runes
import Argo

import Signals

/**
 MediaList
 ----
 
 List view controller of media from gallery
*/
public class MediaList: UICollectionViewController, PHPhotoLibraryChangeObserver {
    
    static var authorizationStatus: PHAuthorizationStatus {
        return PHPhotoLibrary.authorizationStatus()
    }
    
    static func requestAuthorization(closure: Bool -> Void) {
        switch self.authorizationStatus {
        case .Authorized:
            async(.Main) { () -> Void in
                closure(true)
            }
        default:
            PHPhotoLibrary.requestAuthorization({ status -> Void in
                async(.Main) {
                    closure(status == .Authorized)
                }
            })
        }
    }
    
    var assets: [AssetsSection] = [] {
        didSet {
            if oldValue != assets {
                if let collectionView = self.collectionView {
                    asyncWith(collectionView, priority: .Main) { [weak self] in
                        collectionView.reloadData()
                        
                        if
                            let asset = self?.assets.first?.assets.first
                            where asset != oldValue.first?.assets.first
                        {
                            let indexPath = NSIndexPath(forItem: 0, inSection: 0)
                            self?.selectionHandle(indexPath, asset)
                            collectionView.selectItemAtIndexPath(indexPath, animated: true, scrollPosition: .CenteredVertically)
                        }
                    }
                }
            }
        }
    }
    
    private(set) var photosOnly: Bool = false
    /**
     Designated initializer
     
     - parameter photosOnly: Set to `true` if you want just photos in the list, without videos. Default: `false`.
    */
    public init(photosOnly: Bool = false) {
        let bundle = NSBundle(forClass: MediaList.self)
        super.init(nibName: "MediaList", bundle: bundle)
        self.photosOnly = photosOnly
    }
    
    /// Just calls super's implementation
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName:nibNameOrNil, bundle:nibBundleOrNil)
    }
    
    /// Just calls super's implementation
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    /// Setups list cells and reusable views
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        setupAssetsUpdate()
        setupLayout()
        
        self.collectionView?.registerCell(AssetsCell)
        self.collectionView?.registerReusableView(MediaListTitleView)
        
        self.edgesForExtendedLayout = UIRectEdge.None
    }
    
    private func setupLayout() {
        if
            let layout = self.collectionViewLayout as? UICollectionViewFlowLayout,
            let collectionWidth = self.collectionView?.frame.width
        {
            let width = min(collectionWidth, self.view.frame.width, self.view.frame.height)
            Animate(duration: 30, options: UIViewAnimationOptions.CurveEaseOut)
                .animation {
                    let itemsNumber: CGFloat = 4
                    let interNumber: CGFloat = max(itemsNumber - 1, 1.0)
                    let distance:CGFloat = 1.0/interNumber
                    let itemWidth = min(150, floor((width - itemsNumber * distance)/itemsNumber))
                    layout.itemSize = CGSize(width: itemWidth, height: itemWidth)
                    layout.minimumInteritemSpacing = distance
                    layout.minimumLineSpacing      = 2 * distance
                    
                    layout.headerReferenceSize     = CGSize(width: width, height: 44)
                }
                .fire()
        }
    }
    
    /// Updates cell size
    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if
            let collectionView = self.collectionView,
            let layout = self.collectionView?.collectionViewLayout as? UICollectionViewFlowLayout
        {
            let itemHeight  = layout.itemSize.height
            
            var inset = collectionView.contentInset
            inset.bottom = collectionView.bounds.height - itemHeight
            
            if collectionView.contentInset != inset {
                collectionView.contentInset = inset
            }
            
            if collectionView.numberOfSections() > 0
                &&
                collectionView.numberOfItemsInSection(0) > 0
                &&
                collectionView.indexPathsForSelectedItems()?.first == nil
            {
                collectionView.selectItemAtIndexPath(NSIndexPath(forItem: 0, inSection: 0), animated: false, scrollPosition: .None)
            }
        }
    }
    
    /// Updates list upon attachment to superview
    override public func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        coordinator.animateAlongsideTransition(nil) { [weak self] _ in
            if
                let `self` = self,
                let collectionView = self.collectionView
            {
                collectionView.synced {
                    self.setupLayout()
                    collectionView.reloadData()
                }
            }
        }
    }
    
    private var assetsSignal: Signal<[AssetsSection]>?
    private func setupAssetsUpdate() {
        MediaList.requestAuthorization { success in
            if success {
                self.assetsSignal = getAssets(self.photosOnly).reduce([]) { (acc, val) in
                    return acc + [val]
                }
                
                self.assetsSignal?.listen(self) {[weak self] asset -> Void in
                    self?.assets = asset
                }
            }
        }
    }
    
    /// Updates list on gallery change
    public func photoLibraryDidChange(changeInstance: PHChange) {
        self.setupAssetsUpdate()
    }
    
    /// - Returns: The number of folders in gallery
    override public func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return self.assets.count
    }
    
    /// - Returns: The number of objects in folder
    override public func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.assets[section].assets.count
    }
    
    /// - Returns: `MediaListTitleView` for folder title
    override public func collectionView(
        collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        atIndexPath indexPath: NSIndexPath
        ) -> UICollectionReusableView {
            let titleView = collectionView.dequeueReusableSupplementaryViewOfKind(
                kind,
                withReuseIdentifier: MediaListTitleView.defaultIdentifier,
                forIndexPath: indexPath
                ) as! MediaListTitleView
            return titleView
    }
    
    /// Setups title in `MediaListTitleView`
    override public func collectionView(
        collectionView: UICollectionView,
        willDisplaySupplementaryView view: UICollectionReusableView,
        forElementKind elementKind: String,
        atIndexPath indexPath: NSIndexPath
        ) {
            let titleView = view as! MediaListTitleView
            let name = self.assets[indexPath.section].name

            titleView.titleLabel.text = name
    }
    
    /// - Returns: Cell for media item
    override public func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(AssetsCell.defaultIdentifier, forIndexPath: indexPath) as! AssetsCell
        return cell
    }
    
    /// Setups cell info
    override public func collectionView(collectionView: UICollectionView, willDisplayCell cell: UICollectionViewCell, forItemAtIndexPath indexPath: NSIndexPath) {
        let assetsCell = cell as! AssetsCell
        let asset = self.assets[indexPath.section].assets[indexPath.item]
        
        assetsCell.setupPreview(asset)
    }
    
    /// Handles media item selection
    override public func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        let asset = self.assets[indexPath.section].assets[indexPath.item]
        collectionView.scrollToItemAtIndexPath(indexPath, atScrollPosition: .Top, animated: false)
        selectionHandle(indexPath, asset)
    }
    
    /// - Returns: `true`
    override public func collectionView(collectionView: UICollectionView, shouldShowMenuForItemAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    let selectionSignal: Signal<(NSIndexPath, PHAsset)> = Signal()
    private func selectionHandle(indexPath: NSIndexPath, _ asset: PHAsset) {
        async(.Main) { [weak self] in
            self?.collectionView?.selectItemAtIndexPath(indexPath, animated: false, scrollPosition: .CenteredVertically)
            if let selectionSignal = self?.selectionSignal
            {
                selectionSignal.fire(indexPath, asset)
            }
        }
    }
    
    let scrollSignal: Signal<CGFloat> = Signal()
    /// Reacts on list scrolling and emit value of `scrollSignal`
    override public func scrollViewDidScroll(scrollView: UIScrollView) {
        asyncWith(scrollView, priority: .Main) { [weak self] in
            let offset = -scrollView.contentOffset.y
            self?.scrollSignal.fire(offset)
        }
    }
}

// UICollectionView extensions

extension UICollectionView {
    
    func registerCell<CellType: RegisterableCollectionViewCell>(
        cellType: CellType.Type = CellType.self,
        identifier: String = CellType.self.defaultIdentifier
        ) -> CellType.Type {
            cellType.self.registerAtCollectionView(self, identifier: identifier)
            return cellType
    }
    
    func registerReusableView<ViewType: RegisterableReusableView>(
        viewType: ViewType.Type = ViewType.self,
        kind: ReusableViewKind = .Header,
        identifier: String = ViewType.self.defaultIdentifier
        ) -> ViewType.Type {
            viewType.self.registerAtCollectionView(self, kind: kind, identifier: identifier)
            return viewType
    }
    
}

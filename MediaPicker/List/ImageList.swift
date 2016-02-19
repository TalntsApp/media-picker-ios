//
//  ImageList.swift
//  Talnts
//
//  Created by Mikhail Stepkin on 30.07.15.
//  Copyright (c) 2015 Ramotion. All rights reserved.
//

import MobileCoreServices

import UIKit
import AVFoundation

import Photos

import Runes
import Argo

import Signals

class ImageList: UICollectionViewController, PHPhotoLibraryChangeObserver {
    
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
                        }
                    }
                }
            }
        }
    }
    
    private(set) var photosOnly: Bool = false
    convenience init(photosOnly: Bool = false) {
        let bundle = NSBundle(forClass: ImageList.self)
        self.init(nibName: "ImageList", bundle: bundle)
        self.photosOnly = photosOnly
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName:nibNameOrNil, bundle:nibBundleOrNil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupAssetsUpdate()
        setupLayout()
        
        self.collectionView?.registerCell(AssetsCell)
        self.collectionView?.registerReusableView(ImageListTitleView)
        
        self.edgesForExtendedLayout = UIRectEdge.None
    }
    
    private func setupLayout() {
        if
            let layout = self.collectionViewLayout as? UICollectionViewFlowLayout,
            let collectionWidth = self.collectionView?.frame.width
        {
            let itemsNumber: CGFloat = 4
            let interNumber: CGFloat = max(itemsNumber - 1, 1.0)
            let distance:CGFloat = 1.0/interNumber
            let itemWidth = floor((collectionWidth - itemsNumber * distance)/itemsNumber)
            layout.itemSize = CGSize(width: itemWidth, height: itemWidth)
            layout.minimumInteritemSpacing = distance
            layout.minimumLineSpacing      = 2 * distance
            
            layout.headerReferenceSize     = CGSize(width: collectionWidth, height: 44)
        }
    }
    
    override func viewDidLayoutSubviews() {
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
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        setupLayout()
    }
    
    private var assetsSignal: Signal<[AssetsSection]>?
    private func setupAssetsUpdate() {
        ImageList.requestAuthorization { success in
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
    
    func photoLibraryDidChange(changeInstance: PHChange) {
        self.setupAssetsUpdate()
    }
    
    override func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return self.assets.count
    }
    
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.assets[section].assets.count
    }
    
    override func collectionView(
        collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        atIndexPath indexPath: NSIndexPath
        ) -> UICollectionReusableView {
        let titleView = collectionView.dequeueReusableSupplementaryViewOfKind(
            kind,
            withReuseIdentifier: ImageListTitleView.defaultIdentifier,
            forIndexPath: indexPath
            ) as! ImageListTitleView
        return titleView
    }
    
    override func collectionView(
        collectionView: UICollectionView,
        willDisplaySupplementaryView view: UICollectionReusableView,
        forElementKind elementKind: String,
        atIndexPath indexPath: NSIndexPath
        ) {
        let titleView = view as! ImageListTitleView
        let name = self.assets[indexPath.section].name
        
        titleView.titleLabel.text = name
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(AssetsCell.defaultIdentifier, forIndexPath: indexPath) as! AssetsCell
        return cell
    }
    
    override func collectionView(collectionView: UICollectionView, willDisplayCell cell: UICollectionViewCell, forItemAtIndexPath indexPath: NSIndexPath) {
        let assetsCell = cell as! AssetsCell
        let asset = self.assets[indexPath.section].assets[indexPath.item]
        
        assetsCell.setupPreview(asset)
    }
    
    override func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        let asset = self.assets[indexPath.section].assets[indexPath.item]
        collectionView.scrollToItemAtIndexPath(indexPath, atScrollPosition: .Top, animated: false)
        selectionHandle(indexPath, asset)
    }
    
    override func collectionView(collectionView: UICollectionView, shouldShowMenuForItemAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    let selectionSignal: Signal<(NSIndexPath, PHAsset)> = Signal()
    private func selectionHandle(indexPath: NSIndexPath, _ asset: PHAsset) {
        async(.Main) { [weak self] in
            if let selectionSignal = self?.selectionSignal
            {
                selectionSignal.fire(indexPath, asset)
            }
        }
    }
    
    let scrollSignal: Signal<CGFloat> = Signal()
    override func scrollViewDidScroll(scrollView: UIScrollView) {
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

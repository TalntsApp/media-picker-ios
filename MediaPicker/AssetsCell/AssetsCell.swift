//
//  AssetsCell.swift
//  Talnts
//
//  Created by Mikhail Stepkin on 31.07.15.
//  Copyright (c) 2015 Ramotion. All rights reserved.
//

import UIKit
import Photos

private let durationDateFormatter: NSDateFormatter = MkDurationDateFormatter()
func MkDurationDateFormatter() -> NSDateFormatter {
    let durationDateFormatter = NSDateFormatter()
    durationDateFormatter.timeZone = NSTimeZone(forSecondsFromGMT: 0)
    durationDateFormatter.dateFormat = NSDateFormatter.dateFormatFromTemplate("HH:mm:ss", options: 0, locale: nil)
    
    return durationDateFormatter
}

class AssetsCell: UICollectionViewCell, RegisterableCollectionViewCell {
    
    static let defaultIdentifier: String = "AssetsCell"
    static let nibName: String? = "AssetsCell"
    
    @IBOutlet weak var imageView: UIImageView?
    @IBOutlet weak var assetTypeIcon: UIImageView?
    @IBOutlet weak var durationLabel: UILabel?
    @IBOutlet weak var selectionOverlay: UIView?
    
    override var selected: Bool {
        willSet {
            self.selectionOverlay?.hidden = !newValue
        }
    }
    
    private var asset: PHAsset?
    func setupPreview(asset: PHAsset) {
        self.asset = asset
        asset.talntsThumbnail(self.frame.size).listen(self) { [weak self] image -> Void in
            self?.imageView?.image = image
        }
        
        let iconName: String?
        self.durationLabel?.hidden = true
        
        switch asset.mediaType {
        case .Video:
            iconName = "highlights_videoIcon"
            
            self.durationLabel?.hidden = false
            let duration = NSDate(timeIntervalSinceReferenceDate: asset.duration)
            self.durationLabel?.text = durationDateFormatter.stringFromDate(duration)
        default:
            iconName = nil
        }
        
        if let iconName = iconName {
            self.assetTypeIcon?.image = UIImage(named: iconName)
        }
        else {
            self.assetTypeIcon?.image = nil
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if
            let imageViewSize = self.imageView?.frame.size,
            let imageSize = self.imageView?.image?.size
            where (imageSize.width < imageViewSize.width || imageSize.height < imageViewSize.height)
                ||
                (imageSize.width % imageViewSize.width != 0 || imageSize.height % imageViewSize.height != 0)
        {
            if self.imageView?.image?.size != self.imageView?.frame.size {
                asset?.talntsThumbnail(self.frame.size).listen(self) { [weak self] image -> Void in
                    self?.imageView?.image = image
                }
            }
        }
    }
    
    override func prepareForReuse() {
        self.selected = false
        self.asset = nil
    }
    
}

protocol RegisterableCollectionViewCell: class {
    static var defaultIdentifier: String { get }
    static var nibName: String? { get }
    
    static func registerAtCollectionView(collectionView: UICollectionView, identifier: String)
}

extension RegisterableCollectionViewCell {
    static func registerAtCollectionView(collectionView: UICollectionView, identifier: String = Self.defaultIdentifier) {
        if let nibName = Self.nibName {
            let bundle = NSBundle(forClass: Self.self)
            let nib = UINib(nibName: nibName, bundle: bundle)
            
            collectionView.registerNib(nib, forCellWithReuseIdentifier: identifier)
        } else {
            collectionView.registerClass(Self.self, forCellWithReuseIdentifier: identifier)
        }
    }
}

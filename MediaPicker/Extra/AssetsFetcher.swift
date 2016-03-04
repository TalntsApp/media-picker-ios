import Photos

import Signals

// MARK: Assets
struct AssetsSection: Equatable {
    let name: String?
    let assets: [PHAsset]
}

func ==(lhs: AssetsSection, rhs: AssetsSection) -> Bool {
    return lhs.name == rhs.name && lhs.assets == rhs.assets
}

func getAssets(photosOnly: Bool) -> Signal<AssetsSection> {
    let signal:Signal<AssetsSection> = Signal()
    
    let options = PHFetchOptions()
    options.includeHiddenAssets = false
    options.includeAllBurstAssets = false
    
    let photoStreamResult = PHAssetCollection.fetchAssetCollectionsWithType(.SmartAlbum, subtype: .SmartAlbumUserLibrary, options: options)
    let favoritesResult   = PHAssetCollection.fetchAssetCollectionsWithType(.SmartAlbum, subtype: .SmartAlbumFavorites, options: options)
    let videoResult       = PHAssetCollection.fetchAssetCollectionsWithType(.SmartAlbum, subtype: .SmartAlbumVideos, options: options)
    let albumResult       = PHAssetCollection.fetchAssetCollectionsWithType(.Album, subtype: .Any, options: options)
    
    [photoStreamResult, favoritesResult, videoResult, albumResult].forEach { result in
        result.forEach {
            if let assetCollection = $0 as? PHAssetCollection {
                let assets = enumerateAssets(assetCollection, photosOnly: photosOnly)
                if assets.count > 0 {
                    async(.Main) {
                        if result == photoStreamResult {
                            signal.fire(AssetsSection(name: assetCollection.localizedTitle, assets: assets.sort({ $0.modificationDate > $1.modificationDate })))
                        }
                        else {
                            signal.fire(AssetsSection(name: assetCollection.localizedTitle, assets: assets))
                        }
                    }
                }
            }
        }
    }
    
    return signal
}

private func enumerateAssets(assetCollection: PHAssetCollection, photosOnly: Bool) -> [PHAsset] {
    let allowedTypes: Set<PHAssetMediaType>
    if photosOnly {
        allowedTypes = [.Image]
    }
    else {
        allowedTypes = [.Image, .Video]
    }
    
    let assetsResult = PHAsset.fetchAssetsInAssetCollection(assetCollection, options: nil)
    let assets: [PHAsset] = assetsResult.map({ $0 as! PHAsset }).filter({ allowedTypes.contains($0.mediaType) })
    return assets
}

extension NSDate: Comparable {}

/** 
    Compares time intervals since `reference date` of two dates.
    
    - returns: `true` if first one is closer to `reference date`, otherwise `false`
*/
public func <(lhs: NSDate, rhs: NSDate) -> Bool {
    return lhs.timeIntervalSinceReferenceDate < rhs.timeIntervalSinceReferenceDate
}

/**
 Compares time intervals since `reference date` of two dates.
 
 - returns: `true` if second one is closer to `reference date`, otherwise `false`
 */
public func >(lhs: NSDate, rhs: NSDate) -> Bool {
    return lhs.timeIntervalSinceReferenceDate > rhs.timeIntervalSinceReferenceDate
}

extension PHFetchResult: CollectionType {
    
    /**
     Conformity to `SequenceType` protocol
     
     - returns: `PHFetchResult` objects generator
    */
    public func generate() -> PHFetchResultGenerator {
        return Generator(fetchResult: self)
    }
    
    /// Index of first object in `PHFetchResult`
    public var startIndex: Int {
        return 0
    }
    
    /// Index of last object in `PHFetchResult`
    public var endIndex: Int {
        return self.count
    }
    
    public subscript (bounds: Range<Int>) -> [AnyObject] {
        let range = NSMakeRange(bounds.startIndex, bounds.count)
        let indexSet = NSIndexSet(indexesInRange: range)
        return self.objectsAtIndexes(indexSet)
    }
    
}

/// `PHFetchResult` objects generator
public struct PHFetchResultGenerator: GeneratorType {
    private let fetchResult: PHFetchResult
    init(fetchResult: PHFetchResult) {
        self.fetchResult  = fetchResult
        self.currentIndex = fetchResult.startIndex
    }
    
    private var currentIndex: Int
    /**
     `GeneratorType` method
     
     - returns: Next object from `PHFetchResult`
    */
    public mutating func next() -> AnyObject? {
        if currentIndex < fetchResult.endIndex {
            let object = fetchResult[currentIndex]
            currentIndex++
            return object
        }
        else {
            return nil
        }
    }
}

extension PHAsset {
    
    private var scale: CGFloat {
        let scale = UIScreen.screens().reduce(1.0, combine: { (maxScale, screen) -> CGFloat in
            let scale = screen.scale
            return max(maxScale, scale)
        })
        return scale
    }
    
    func talntsThumbnail(size: CGSize, deliveryMode: PHImageRequestOptionsDeliveryMode = .Opportunistic, adjustScale: Bool = true) -> Signal<UIImage?> {
        let signal: Signal<UIImage?> = Signal()
        
        let options = PHImageRequestOptions()
        options.deliveryMode = deliveryMode
        options.resizeMode   = .Exact
        options.synchronous  = false
        
        let adjustedSize: CGSize
        if adjustScale {
            adjustedSize = CGSize(width: size.width * scale, height: size.height * scale)
        }
        else {
            adjustedSize = size
        }
        
        PHImageManager.defaultManager().requestImageForAsset(
            self,
            targetSize: adjustedSize,
            contentMode: PHImageContentMode.AspectFill,
            options: options
            ) { (image, info) -> Void in
                async(.Main) {
                    signal.fire(image)
                }
        }
        
        return signal
    }
    
    var talntsImage: Signal<UIImage?> {
        let size = CGSize(width: CGFloat(self.pixelWidth), height: CGFloat(self.pixelHeight))
        return self.talntsThumbnail(size, deliveryMode: .HighQualityFormat, adjustScale: false)
    }
    
    var urlAsset: Signal<AVURLAsset?> {
        let signal: Signal<AVURLAsset?> = Signal()
        
        let options = PHVideoRequestOptions()
        options.deliveryMode = .HighQualityFormat
        PHImageManager.defaultManager().requestAVAssetForVideo(
            self, options:
            options
            ) { (asset, mix, info) -> Void in
                if let asset = asset as? AVURLAsset {
                    async(.Main) {
                        signal.fire(asset)
                    }
                }
        }
        
        return signal
    }
    
}
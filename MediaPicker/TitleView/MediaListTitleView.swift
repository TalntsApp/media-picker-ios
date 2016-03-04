import UIKit

class MediaListTitleView: UICollectionReusableView, RegisterableReusableView {
    
    static let defaultIdentifier: String = "MediaListTitleView"
    static let nibName: String? = "MediaListTitleView"
    
    @IBOutlet var titleLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        self.titleLabel.text = nil
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.titleLabel.text = nil
    }
    
}

protocol RegisterableReusableView: class {
    static var defaultIdentifier: String { get }
    static var nibName: String? { get }
    
    static func registerAtCollectionView(collectionView: UICollectionView, kind: ReusableViewKind, identifier: String)
}

extension RegisterableReusableView {
    static func registerAtCollectionView(collectionView: UICollectionView, kind: ReusableViewKind, identifier: String = Self.defaultIdentifier) {
        if let nibName = Self.nibName {
            let bundle = NSBundle(forClass: Self.self)
            let nib = UINib(nibName: nibName, bundle: bundle)
            
            collectionView.registerNib(nib, forSupplementaryViewOfKind: kind.rawValue, withReuseIdentifier: identifier)
        } else {
            collectionView.registerClass(Self.self, forSupplementaryViewOfKind: kind.rawValue, withReuseIdentifier: identifier)
        }
    }
}

enum ReusableViewKind {
    case Header
    case Footer
    
    init?(rawValue: String) {
        switch rawValue {
        case UICollectionElementKindSectionHeader:
            self = .Header
        case UICollectionElementKindSectionFooter:
            self = .Footer
        default:
            return nil
        }
    }
    
    var rawValue: String {
        switch self {
        case .Header:
            return UICollectionElementKindSectionHeader
        case .Footer:
            return UICollectionElementKindSectionFooter
        }
    }
}
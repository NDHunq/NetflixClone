//
//  TitleCollectionViewCell.swift
//  NetflixClone
//
//  Created by Nguyen Duy Hung on 27/3/26.
//
import UIKit
import SDWebImage

class TitleCollectionViewCell: UICollectionViewCell {
    static let identifier = "TitleCollectionViewCell"
    @IBOutlet weak var posterImageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Những config không làm được trong XIB thì làm ở đây
        posterImageView.clipsToBounds = true
    }
    
    public func configure(with model: String) {
        guard let url = URL(string: "https://image.tmdb.org/t/p/w500/\(model)") else { return }
        posterImageView.sd_setImage(with: url, completed: nil)
    }
}

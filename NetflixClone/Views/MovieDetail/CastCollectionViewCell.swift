//
//  CastCollectionViewCell.swift
//  NetflixClone
//
//  Created by NDHunq on 13/4/26.
//

import UIKit
import SDWebImage

class CastCollectionViewCell: UICollectionViewCell {
    
    static let identifier = "CastCollectionViewCell"

    @IBOutlet weak var castNameLabel: UILabel!
    @IBOutlet weak var castImageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        castImageView.layer.cornerRadius = 50
    }
    
func configure(profilePath: String?, castName: String) {
    let placeholder = UIImage(named: "avt_placeholder")
    if let path = profilePath {
        let url = URL(string: "https://image.tmdb.org/t/p/w500\(path)")
        castImageView.sd_setImage(with: url, placeholderImage: placeholder)
    } else {
        castImageView.image = placeholder
    }
    castNameLabel.text = castName
}


}

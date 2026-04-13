//
//  MovieOverviewCell.swift
//  NetflixClone
//
//  Created by NDHunq on 12/4/26.
//

import UIKit

class MovieOverviewTableViewCell: UITableViewCell {
    
    static let identifier = "MovieOverviewTableViewCell"
    @IBOutlet weak var headerLabel: UILabel!
    @IBOutlet weak var overviewLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
        backgroundColor = .clear
    }
    
    func configure(with overview: String?) {
        overviewLabel.text = overview ?? "No overview available."
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
}

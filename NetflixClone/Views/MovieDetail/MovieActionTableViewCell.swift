//
//  MovieActionCell.swift
//  NetflixClone
//
//  Created by NDHunq on 12/4/26.
//

import UIKit

protocol MovieActionCellDelegate: AnyObject {
    func movieActionCellDidTapPlayTrailer(_ cell: MovieActionTableViewCell)
    func movieActionCellDidTapDownload(_ cell: MovieActionTableViewCell)
}

class MovieActionTableViewCell: UITableViewCell {
    
    static let identifier = "MovieActionTableViewCell"
    weak var delegate: MovieActionCellDelegate?
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var downloadButton: UIButton!
    
    @IBAction func playTrailerTapped(_ sender: Any) {
        delegate?.movieActionCellDidTapPlayTrailer(self)
    }
    
    @IBAction func downloadTapped(_ sender: Any) {
        delegate?.movieActionCellDidTapDownload(self)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }
    
    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear
        
        playButton.layer.cornerRadius = 8
        playButton.clipsToBounds = true
        
        downloadButton.layer.cornerRadius = 8
        downloadButton.clipsToBounds = true
    }
    
    func configure(hasTrailer: Bool) {
        playButton.isEnabled = hasTrailer
        playButton.alpha = hasTrailer ? 1.0 : 0.5
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
}

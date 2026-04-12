//
//  MovieBackdropCell.swift
//  NetflixClone
//
//  Created by NDHunq on 12/4/26.
//

import UIKit
import SDWebImage

class MovieBackdropCell: UITableViewCell {
    
    static let identifier = "MovieBackdropCell"
    
    @IBOutlet weak var backdropImageView: UIImageView!
    @IBOutlet weak var gradientView: UIView!
    @IBOutlet weak var posterImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var metaLabel: UILabel!
    @IBOutlet weak var genreLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Gradient cần update frame khi cell thay đổi kích thước
        gradientView.layer.sublayers?
            .first(where: { $0 is CAGradientLayer })?
            .frame = gradientView.bounds
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // Poster corner radius (không set được trong XIB)
        posterImageView.layer.cornerRadius = 8
        posterImageView.clipsToBounds = true
        
        // Background trong suốt
        backgroundColor = .clear
        selectionStyle = .none
        
        // Gradient overlay
        addGradient()
    }
    
    private func addGradient() {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.systemBackground.cgColor
        ]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.frame = gradientView.bounds
        gradientView.layer.addSublayer(gradientLayer)
    }
    
    func configure(with detail: MovieDetail) {
        // Title
        titleLabel.text = detail.title ?? detail.original_title ?? "Unknown"
        
        // Backdrop
        if let backdropPath = detail.backdrop_path {
            let url = URL(string: "https://image.tmdb.org/t/p/w780\(backdropPath)")
            backdropImageView.sd_setImage(with: url)
        }
        
        // Poster
        if let posterPath = detail.poster_path {
            let url = URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")
            posterImageView.sd_setImage(with: url)
        }
        
        // Meta: ⭐ 8.4 · 2h19m · 2024
        var metaParts: [String] = []
        if let vote = detail.vote_average {
            metaParts.append("⭐ \(String(format: "%.1f", vote))")
        }
        if let runtime = detail.runtime, runtime > 0 {
            let hours = runtime / 60
            let minutes = runtime % 60
            metaParts.append(hours > 0 ? "\(hours)h\(minutes)m" : "\(minutes)m")
        }
        if let releaseDate = detail.release_date, releaseDate.count >= 4 {
            metaParts.append(String(releaseDate.prefix(4)))
        }
        metaLabel.text = metaParts.joined(separator: " · ")
        
        // Genres
        if let genres = detail.genres {
            genreLabel.text = genres.map(\.name).joined(separator: ", ")
        } else {
            genreLabel.text = nil
        }
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
    }
    
}

//
//  MovieCastCell.swift
//  NetflixClone
//
//  Created by NDHunq on 12/4/26.
//

import UIKit

class MovieCastCell: UITableViewCell {
    
    static let identifier = "MovieCastCell"
    @IBOutlet weak var headerLabel: UILabel!
    @IBOutlet weak var castLabel: UILabel!
    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
        backgroundColor = .clear
    }
    
    func configure(with cast: [CastMember]) {
        // Lấy tối đa 10 diễn viên, sắp xếp theo thứ tự xuất hiện
        let topCast = cast
            .sorted { ($0.order ?? 999) < ($1.order ?? 999) }
            .prefix(10)
        
        // Format: "Actor Name as Character"
        let castText = topCast
            .map { member in
                if let character = member.character, !character.isEmpty {
                    return "\(member.name) as \(character)"
                }
                return member.name
            }
            .joined(separator: "\n")
        
        castLabel.text = castText.isEmpty ? "No cast information available." : castText
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Configure the view for the selected state
    }
    
}

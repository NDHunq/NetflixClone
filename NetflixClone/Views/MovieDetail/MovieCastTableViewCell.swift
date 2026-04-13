//
//  MovieCastCell.swift
//  NetflixClone
//
//  Created by NDHunq on 12/4/26.
//

import UIKit

class MovieCastTableViewCell: UITableViewCell {
    
    static let identifier = "MovieCastTableViewCell"
    @IBOutlet weak var headerLabel: UILabel!
    @IBOutlet weak var castsCollectionView: UICollectionView!
    private var castList:[CastMember] = [CastMember]()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
        backgroundColor = .clear
        let nib = UINib(nibName: "CastCollectionViewCell", bundle: nil)
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 100, height: 180)
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 18
        castsCollectionView.collectionViewLayout = layout
        castsCollectionView.register(nib, forCellWithReuseIdentifier: CastCollectionViewCell.identifier)
        
        castsCollectionView.delegate = self
        castsCollectionView.dataSource = self
    }
    
    func configure(with cast: [CastMember]) {
        castList = cast
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
    }
}

extension MovieCastTableViewCell: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        castList.count
    }
    
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CastCollectionViewCell.identifier, for: indexPath) as! CastCollectionViewCell

        let cast = castList[indexPath.row]
        cell.configure(profilePath: cast.profile_path, castName: cast.name)

        return cell
    }
}


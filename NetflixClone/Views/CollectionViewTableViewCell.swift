//
//  CollectionViewTableViewCell.swift
//  NetflixClone
//
//  Created by Nguyen Duy Hung on 24/3/26.
//

import UIKit

protocol CollectionViewTableViewCellDelegate: AnyObject {
    func collectionViewTableViewCellDidTapCell(_ cell: CollectionViewTableViewCell, movieId: Int)
}

class CollectionViewTableViewCell: UITableViewCell{
  
    static let indentifier = "CollectionViewTableViewCell"
    private var titles: [Title] = [Title]()
    weak var delegate: CollectionViewTableViewCellDelegate?
    
    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 140, height: 200)
        layout.scrollDirection = .horizontal
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        let nib = UINib(nibName: "TitleCollectionViewCell", bundle: nil)
        collectionView.register(nib, forCellWithReuseIdentifier: TitleCollectionViewCell.identifier)
        return collectionView
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.backgroundColor = .systemPink
        contentView.addSubview(collectionView)
        collectionView.delegate = self
        collectionView.dataSource = self
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        collectionView.frame = contentView.bounds
    }
    
    public func configure(with titles: [Title]) {
        self.titles = titles
        DispatchQueue.main.async { [weak self] in
            self?.collectionView.reloadData()
        }
        
    }
        
}

extension CollectionViewTableViewCell: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return titles.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TitleCollectionViewCell.identifier, for: indexPath) as! TitleCollectionViewCell

        // Some TV items can have nil poster_path; keep returning a valid dequeued cell.
        if let model = titles[indexPath.row].poster_path {
            cell.configure(with: model)
        }

        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            collectionView.deselectItem(at: indexPath, animated: true)
            
            let title = titles[indexPath.row]
            let movieId = title.id
            
            print("[CollectionCell] Tapped: \(title.original_title ?? title.original_name ?? "Unknown") (id: \(movieId))")
            
            delegate?.collectionViewTableViewCellDidTapCell(self, movieId: movieId)
        }
    
}

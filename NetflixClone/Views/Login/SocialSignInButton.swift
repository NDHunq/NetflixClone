//
//  SocialSignInButton.swift
//  NetflixClone
//
//  Created by NDHunq on 14/4/26.
//

import UIKit

class SocialSignInButton: UIView {
    
    @IBOutlet weak var button: UIButton!
    var onTap: (() -> Void)?
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadFromXib()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadFromXib()
    }
    
    private func loadFromXib() {
        let nib = UINib(nibName: "SocialSignInButton", bundle: nil)
        guard let contentView = nib.instantiate(withOwner: self, options: nil).first as? UIView else { return }
        contentView.frame = bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(contentView)
    }
    
    
    func configure(title: String, titleColor: UIColor, backgroundColor: UIColor) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(titleColor, for: .normal)
        button.backgroundColor = backgroundColor
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        button.layer.cornerRadius = button.bounds.width / 2
        button.clipsToBounds = true
    }
    
    @IBAction func buttonTapped(_ sender: UIButton) {
        onTap?()
    }
}

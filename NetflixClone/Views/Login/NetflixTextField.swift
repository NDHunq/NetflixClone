//
//  NetflixTextField.swift
//  NetflixClone
//
//  Created by NDHunq on 14/4/26.
//

import UIKit

class NetflixTextField: UIView {
    
    
    @IBOutlet weak var textField: UITextField!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadFromXib()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadFromXib()
    }
    
    private func loadFromXib() {
        let nib = UINib(nibName: "NetflixTextField", bundle: nil)
        guard let contentView = nib.instantiate(withOwner: self, options: nil).first as? UIView else { return }
        contentView.frame = bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(contentView)
        applyStyle()
    }
    
    
    private func applyStyle() {
        layer.borderColor = UIColor(red: 229/255, green: 9/255, blue: 20/255, alpha: 1).cgColor
        layer.borderWidth = 1.5
        layer.cornerRadius = 8
        clipsToBounds = true
        
        textField.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        textField.textColor = .white
        textField.tintColor = .white
        
        let padding = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 1))
        textField.leftView = padding
        textField.leftViewMode = .always
    }
    
    
    func configure(placeholder: String, isSecure: Bool = false, keyboardType: UIKeyboardType = .default) {
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor.lightGray]
        )
        textField.isSecureTextEntry = isSecure
        textField.keyboardType = keyboardType
    }
    
    var text: String? {
        return textField.text
    }
    
    func setDelegate(_ delegate: UITextFieldDelegate) {
        textField.delegate = delegate
    }
    
    func setReturnKeyType(_ type: UIReturnKeyType) {
        textField.returnKeyType = type
    }
}

//
//  LoginViewController.swift
//  NetflixClone
//
//  Created by NDHunq on 14/4/26.
//

import UIKit

class LoginViewController: UIViewController {

    
    @IBOutlet weak var facebookButton: UIButton!
    @IBOutlet weak var googleButton: UIButton!
    @IBOutlet weak var bottomLabel: UILabel!
    @IBOutlet weak var signInButton: UIButton!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var overlayView: UIView!
    @IBOutlet weak var backgroundImageView: UIImageView!
    
    // MARK: - Gradient
    private var gradientLayer: CAGradientLayer?

    override func viewDidLoad() {
         super.viewDidLoad()
         setupUI()
         setupFullScreenBackground()
     }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Cập nhật frame gradient mỗi khi layout thay đổi (xoay màn hình, safe area...)
        gradientLayer?.frame = overlayView.bounds
    }

     // MARK: - Setup

     /// Đảm bảo backgroundImageView phủ toàn màn hình kể cả safe area
     private func setupFullScreenBackground() {
         guard let bgView = backgroundImageView else { return }
         bgView.translatesAutoresizingMaskIntoConstraints = false
         // Xóa constraint cũ (từ XIB) rồi pin vào view gốc (không phải safeArea)
         NSLayoutConstraint.deactivate(bgView.constraints)
         NSLayoutConstraint.activate([
             bgView.topAnchor.constraint(equalTo: view.topAnchor),
             bgView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
             bgView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
             bgView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
         ])
     }

     private func setupUI() {
         view.backgroundColor = .black

         // Gradient nửa dưới: trong suốt → đen đặc
         setupGradientOverlay()
         // TextFields
         styleTextField(emailTextField, placeholder: "Email")
         emailTextField.keyboardType = .emailAddress
         emailTextField.returnKeyType = .next
         emailTextField.delegate = self

         styleTextField(passwordTextField, placeholder: "Password")
         passwordTextField.isSecureTextEntry = true
         passwordTextField.returnKeyType = .done
         passwordTextField.delegate = self

         // Buttons
         styleSignInButton()
         styleCircleButton(googleButton,
                           title: "G",
                           textColor: UIColor(red: 66/255, green: 133/255, blue: 244/255, alpha: 1),
                           bgColor: .white)
         styleCircleButton(facebookButton,
                           title: "f",
                           textColor: .white,
                           bgColor: UIColor(red: 66/255, green: 103/255, blue: 178/255, alpha: 1))

         // Bottom label: "Sign up now" màu đỏ
         styleBottomLabel()

         // Dismiss keyboard khi tap ra ngoài
         let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
         view.addGestureRecognizer(tap)
     }

     // MARK: - Gradient Overlay

     private func setupGradientOverlay() {
         // overlayView trong XIB được đặt constraint top = 50% chiều cao màn hình
         // gradient chạy từ trong suốt (trên) → đen (dưới)
         overlayView.backgroundColor = .clear   // nền trong suốt, chỉ dùng gradient

         let gradient = CAGradientLayer()
         gradient.colors = [
             UIColor.clear.cgColor,                              // Đầu gradient: trong suốt
             UIColor.black.withAlphaComponent(0.6).cgColor,     // Giữa: bắt đầu đủc
             UIColor.black.cgColor                              // Cuối: đen đặc
         ]
         gradient.locations = [0.0, 0.5, 1.0]   // Rõ dần từ 0% → 50% → 100%
         gradient.startPoint = CGPoint(x: 0.5, y: 0.0) // Bắt đầu từ top của overlayView
         gradient.endPoint   = CGPoint(x: 0.5, y: 1.0) // Kết thúc ở bottom
         gradient.frame = overlayView.bounds            // frame được cập nhật lại trong viewDidLayoutSubviews

         overlayView.layer.insertSublayer(gradient, at: 0)
         gradientLayer = gradient
     }


     private func styleTextField(_ textField: UITextField, placeholder: String) {
         textField.backgroundColor = UIColor.black.withAlphaComponent(0.3)
         textField.textColor = .white
         textField.tintColor = .white
         textField.layer.borderColor = UIColor(red: 229/255, green: 9/255, blue: 20/255, alpha: 1).cgColor
         textField.layer.borderWidth = 1.5
         textField.layer.cornerRadius = 8
         textField.clipsToBounds = true

         // Padding bên trái
         let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 1))
         textField.leftView = paddingView
         textField.leftViewMode = .always

         // Placeholder màu xám
         textField.attributedPlaceholder = NSAttributedString(
             string: placeholder,
             attributes: [.foregroundColor: UIColor.lightGray]
         )
     }

     private func styleSignInButton() {
         signInButton.setTitle("Sign in", for: .normal)
         signInButton.setTitleColor(.white, for: .normal)
         signInButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
         signInButton.backgroundColor = UIColor(red: 229/255, green: 9/255, blue: 20/255, alpha: 1)
         signInButton.layer.cornerRadius = 8
         signInButton.clipsToBounds = true
     }

     private func styleCircleButton(_ button: UIButton, title: String, textColor: UIColor, bgColor: UIColor) {
         button.setTitle(title, for: .normal)
         button.setTitleColor(textColor, for: .normal)
         button.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
         button.backgroundColor = bgColor
         button.layer.cornerRadius = 24   // width = height = 48 → tròn hoàn hảo
         button.clipsToBounds = true
     }

     private func styleBottomLabel() {
         let fullText = "Is it first time for you? Sign up now"
         let attributed = NSMutableAttributedString(
             string: fullText,
             attributes: [
                 .foregroundColor: UIColor.white,
                 .font: UIFont.systemFont(ofSize: 14)
             ]
         )
         if let range = fullText.range(of: "Sign up now") {
             let nsRange = NSRange(range, in: fullText)
             attributed.addAttributes([
                 .foregroundColor: UIColor(red: 229/255, green: 9/255, blue: 20/255, alpha: 1),
                 .font: UIFont.systemFont(ofSize: 14, weight: .semibold)
             ], range: nsRange)
         }
         bottomLabel.attributedText = attributed
         bottomLabel.textAlignment = .center
         bottomLabel.isUserInteractionEnabled = true
         let tap = UITapGestureRecognizer(target: self, action: #selector(signUpTapped))
         bottomLabel.addGestureRecognizer(tap)
     }

     // MARK: - IBActions

     @IBAction func signInTapped(_ sender: UIButton) {
         guard let email = emailTextField.text, !email.isEmpty,
               let password = passwordTextField.text, !password.isEmpty else {
             showAlert(message: "Vui lòng nhập email và password.")
             return
         }
         // TODO: Gọi API đăng nhập thật ở đây
         navigateToMainApp()
     }

     @IBAction func googleSignInTapped(_ sender: UIButton) {
         // TODO: Tích hợp Google Sign-In SDK
         print("Google Sign In tapped")
     }

     @IBAction func facebookSignInTapped(_ sender: UIButton) {
         // TODO: Tích hợp Facebook Login SDK
         print("Facebook Sign In tapped")
     }

     @objc private func signUpTapped() {
         // TODO: Điều hướng đến màn hình đăng ký
         print("Sign Up tapped")
     }

     @objc private func dismissKeyboard() {
         view.endEditing(true)
     }

     // MARK: - Navigation

     private func navigateToMainApp() {
         guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first else { return }

         UIView.transition(with: window, duration: 0.4, options: .transitionCrossDissolve) {
             window.rootViewController = MainTabBarViewController()
         }
     }

     // MARK: - Helper

     private func showAlert(message: String) {
         let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
         alert.addAction(UIAlertAction(title: "OK", style: .default))
         present(alert, animated: true)
     }
 }

 // MARK: - UITextFieldDelegate

 extension LoginViewController: UITextFieldDelegate {
     func textFieldShouldReturn(_ textField: UITextField) -> Bool {
         if textField == emailTextField {
             passwordTextField.becomeFirstResponder()
         } else {
             textField.resignFirstResponder()
         }
         return true
     }
 }

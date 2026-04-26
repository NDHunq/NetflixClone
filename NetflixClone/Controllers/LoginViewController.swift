//
//  LoginViewController.swift
//  NetflixClone
//
//  Created by NDHunq on 14/4/26.
//

import UIKit

class LoginViewController: UIViewController {
    
    private struct LoginRequestBody: Encodable {
        let phone_number: String
        let password: String
    }
    
    private struct LoginAPIResponse: Decodable {
        let access_token: String
        let user: LoginUser
    }
    
    private struct LoginUser: Decodable {
        let id: Int
        let phone_number: String
        let full_name: String
        let created_at: String?
    }
    
    private struct ErrorResponse: Decodable {
        let detail: String?
        let error: String?
        let message: String?
    }
    
    private let loginEndpoint = "http://127.0.0.1:5001/auth/login"
        
    @IBOutlet weak var backgroundImageView: UIImageView?
    @IBOutlet weak var overlayView: UIView?
    @IBOutlet weak var netflixLogoLabel: UILabel?
    
    @IBOutlet weak var emailFieldView: NetflixTextField?
    @IBOutlet weak var passwordFieldView: NetflixTextField?
    
    @IBOutlet weak var emailTextField: UITextField?
    @IBOutlet weak var passwordTextField: UITextField?
    
    @IBOutlet weak var signInButton: UIButton?
    @IBOutlet weak var bottomLabel: UILabel?
    @IBOutlet weak var superAppSignInButton: UIButton?
    
    private var gradientLayer: CAGradientLayer?
    
    let ssoClientId = "serviceapp.demo"
    let ssoRedirectUri = "netflixclone://callback"
        
    override func viewDidLoad() {
        super.viewDidLoad()
        setupFullScreenBackground()
        setupUI()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer?.frame = overlayView?.bounds ?? .zero
    }
    
    private func setupFullScreenBackground() {
        guard let bgView = backgroundImageView else { return }
        bgView.translatesAutoresizingMaskIntoConstraints = false
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
        
        setupGradientOverlay()
        
        netflixLogoLabel?.text = "NETFLIX"
        netflixLogoLabel?.textColor = UIColor(red: 229/255, green: 9/255, blue: 20/255, alpha: 1)
        netflixLogoLabel?.font = .systemFont(ofSize: 42, weight: .black)
        
        if let emailFieldView = emailFieldView, let passwordFieldView = passwordFieldView {
            emailFieldView.configure(placeholder: "Phone number", keyboardType: .numberPad)
            emailFieldView.setReturnKeyType(.next)
            emailFieldView.setDelegate(self)
            
            passwordFieldView.configure(placeholder: "Password", isSecure: true)
            passwordFieldView.setReturnKeyType(.done)
            passwordFieldView.setDelegate(self)
        } else {
            styleLegacyTextField(emailTextField, placeholder: "Phone number", keyboardType: .numberPad, isSecure: false, returnKey: .next)
            styleLegacyTextField(passwordTextField, placeholder: "Password", keyboardType: .default, isSecure: true, returnKey: .done)
            emailTextField?.delegate = self
            passwordTextField?.delegate = self
        }
        
        signInButton?.layer.cornerRadius = 8
        signInButton?.clipsToBounds = true
        
        setupBottomLabel()
        setupSSOButton()
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
    }
        
    private func setupGradientOverlay() {
        guard let overlayView = overlayView else { return }
        overlayView.backgroundColor = .clear
        
        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.6).cgColor,
            UIColor.black.cgColor
        ]
        gradient.locations = [0.0, 0.5, 1.0]
        gradient.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradient.endPoint   = CGPoint(x: 0.5, y: 1.0)
        gradient.frame = overlayView.bounds
        
        overlayView.layer.insertSublayer(gradient, at: 0)
        gradientLayer = gradient
    }
        
    private func setupBottomLabel() {
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
        bottomLabel?.attributedText = attributed
        bottomLabel?.textAlignment = .center
        bottomLabel?.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(signUpTapped))
        bottomLabel?.addGestureRecognizer(tap)
    }
        
    private func setupSSOButton() {
        guard let superAppSignInButton = superAppSignInButton else { return }
        superAppSignInButton.setTitle("Super App", for: .normal)
        superAppSignInButton.titleLabel?.tintColor = .white
        superAppSignInButton.layer.cornerRadius = 6
        superAppSignInButton.clipsToBounds = true
        superAppSignInButton.backgroundColor = UIColor(red: 0/255.0, green: 139/255.0, blue: 91/255.0, alpha: 1.0)
        
        superAppSignInButton.addAction(UIAction { [weak self] _ in
            self?.handleSuperAppSSO()
        }, for: .touchUpInside)
    }
        
    @IBAction func signInTapped(_ sender: UIButton) {
        let phoneNumber = (emailFieldView?.text ?? emailTextField?.text)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = (passwordFieldView?.text ?? passwordTextField?.text)?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let phoneNumber, !phoneNumber.isEmpty,
              let password, !password.isEmpty else {
            showAlert(message: "Vui lòng nhập số điện thoại và password.")
            return
        }
        
        signInButton?.isEnabled = false
        performDirectLogin(phoneNumber: phoneNumber, password: password)
    }
    
    @objc private func signUpTapped() {
        print("Sign Up tapped")
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    private func handleSuperAppSSO() {
        // 1. Sinh bộ khóa PKCE
        let codeVerifier = PKCEHelper.generateCodeVerifier()
        let codeChallenge = PKCEHelper.generateCodeChallenge(verifier: codeVerifier)
        
        // 2. Sinh state chống CSRF
        let state = UUID().uuidString
        
        // 3. Lưu verifier & state để dùng khi nhận callback
        UserDefaults.standard.set(codeVerifier, forKey: "SSO_Verifier")
        UserDefaults.standard.set(state, forKey: "SSO_State")
        
        // 4. Gắn Deep Link
        var comp = URLComponents(string: "superapp://authorize")
        comp?.queryItems = [
            URLQueryItem(name: "client_id", value: ssoClientId),
            URLQueryItem(name: "redirect_uri", value: ssoRedirectUri),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state)
        ]
        
        guard let finalURL = comp?.url else { return }
        print("[SSO] Opening Super App: \(finalURL)")
        
        // 5. Mở Super App
        if UIApplication.shared.canOpenURL(finalURL) {
            UIApplication.shared.open(finalURL, options: [:]) { success in
                if success {
                    print("[SSO] Super App opened successfully")
                } else {
                    print("[SSO] Failed to open Super App")
                }
            }
        } else {
            showAlert(message: "Super App chưa được cài đặt. Vui lòng cài đặt Super App trước.")
        }
    }
    
    
    private func navigateToMainApp() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        UIView.transition(with: window, duration: 0.4, options: .transitionCrossDissolve) {
            window.rootViewController = MainTabBarViewController()
        }
    }
    
    private func performDirectLogin(phoneNumber: String, password: String) {
        guard let url = URL(string: loginEndpoint) else {
            signInButton?.isEnabled = true
            showAlert(message: "Login endpoint không hợp lệ.")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            request.httpBody = try JSONEncoder().encode(
                LoginRequestBody(phone_number: phoneNumber, password: password)
            )
        } catch {
            signInButton?.isEnabled = true
            showAlert(message: "Không thể tạo request body.")
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.signInButton?.isEnabled = true
            }
            
            if let error {
                DispatchQueue.main.async {
                    self?.showAlert(message: "Không gọi được API đăng nhập: \(error.localizedDescription)")
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    self?.showAlert(message: "Không nhận được phản hồi hợp lệ từ server.")
                }
                return
            }
            
            guard let data else {
                DispatchQueue.main.async {
                    self?.showAlert(message: "Server trả về dữ liệu rỗng.")
                }
                return
            }
            
            if (200...299).contains(httpResponse.statusCode) {
                do {
                    let decoded = try JSONDecoder().decode(LoginAPIResponse.self, from: data)
                    UserDefaults.standard.set(decoded.access_token, forKey: "auth_token")
                    UserDefaults.standard.set(decoded.user.phone_number, forKey: "user_phone_number")
                    UserDefaults.standard.set(decoded.user.full_name, forKey: "user_full_name")
                    
                    DispatchQueue.main.async {
                        self?.navigateToMainApp()
                    }
                } catch {
                    DispatchQueue.main.async {
                        self?.showAlert(message: "Parse login response thất bại.")
                    }
                }
                return
            }
            
            let serverMessage: String
            if let decodedError = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                serverMessage = decodedError.detail ?? decodedError.error ?? decodedError.message ?? "Đăng nhập thất bại."
            } else if let rawText = String(data: data, encoding: .utf8), !rawText.isEmpty {
                serverMessage = rawText
            } else {
                serverMessage = "Đăng nhập thất bại (HTTP \(httpResponse.statusCode))."
            }
            
            DispatchQueue.main.async {
                self?.showAlert(message: serverMessage)
            }
        }.resume()
    }
    
    private func styleLegacyTextField(
        _ textField: UITextField?,
        placeholder: String,
        keyboardType: UIKeyboardType,
        isSecure: Bool,
        returnKey: UIReturnKeyType
    ) {
        textField?.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor.lightGray]
        )
        textField?.textColor = .white
        textField?.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        textField?.keyboardType = keyboardType
        textField?.isSecureTextEntry = isSecure
        textField?.returnKeyType = returnKey
        textField?.layer.borderColor = UIColor(red: 229/255, green: 9/255, blue: 20/255, alpha: 1).cgColor
        textField?.layer.borderWidth = 1.5
        textField?.layer.cornerRadius = 8
        textField?.clipsToBounds = true
        
        let padding = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 1))
        textField?.leftView = padding
        textField?.leftViewMode = .always
    }
    
    private func styleLegacyCircleButton(
        _ button: UIButton?,
        title: String,
        titleColor: UIColor,
        backgroundColor: UIColor
    ) {
        button?.setTitle(title, for: .normal)
        button?.setTitleColor(titleColor, for: .normal)
        button?.backgroundColor = backgroundColor
        button?.layoutIfNeeded()
        if let width = button?.bounds.width, width > 0 {
            button?.layer.cornerRadius = width / 2
            button?.clipsToBounds = true
        }
    }
    
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension LoginViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let emailFieldView = emailFieldView,
           let passwordFieldView = passwordFieldView,
           textField == emailFieldView.textField {
            passwordFieldView.textField.becomeFirstResponder()
        } else if textField == emailTextField {
            passwordTextField?.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        return true
    }
}

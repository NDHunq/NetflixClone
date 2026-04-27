//
//  ProfileViewController.swift
//  NetflixClone
//
//  Created by Nguyen Duy Hung on 24/3/26.
//

import UIKit

class ProfileViewController: UIViewController {

    private let infoTextView: UITextView = {
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textColor = .label
        textView.backgroundColor = .secondarySystemBackground
        textView.layer.cornerRadius = 12
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
        return textView
    }()

    private let signOutButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Sign Out", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 229/255, green: 9/255, blue: 20/255, alpha: 1)
        button.layer.cornerRadius = 8
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Profile"
        setupViews()
        renderProfileDebugInfo()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Refresh each time so testers can verify account switching quickly.
        renderProfileDebugInfo()
    }

    private func setupViews() {
        view.addSubview(infoTextView)
        view.addSubview(signOutButton)

        signOutButton.addTarget(self, action: #selector(handleSignOutTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            infoTextView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            infoTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            infoTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            signOutButton.topAnchor.constraint(equalTo: infoTextView.bottomAnchor, constant: 16),
            signOutButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            signOutButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            signOutButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            signOutButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    private func renderProfileDebugInfo() {
        // Fetch fresh user data from backend instead of UserDefaults
        APICaller.shared.getUserProfile { [weak self] result in
            DispatchQueue.main.async {
                let defaults = UserDefaults.standard
                
                switch result {
                case .success(let userResponse):
                    let lines = [
                        "Netflix SSO User Profile",
                        "------------------------",
                        "id: \(userResponse.id)",
                        "phone_number: \(userResponse.phone_number ?? "-")",
                        "full_name: \(userResponse.full_name ?? "-")",
                        "created_at: \(userResponse.created_at ?? "-")",
                        "",
                        "Session Tokens",
                        "--------------",
                        "access_token_head: \(self?.short(defaults.string(forKey: "AccessToken")) ?? "-")",
                        "expires_in_seconds: \(defaults.object(forKey: "TokenExpiresInSeconds") as? Int ?? -1)",
                    ]
                    
                    self?.infoTextView.text = lines.joined(separator: "\n")
                    print("[SSO][Netflix][ProfileUI] status=render user_id=\(userResponse.id) phone_head=\(self?.short(userResponse.phone_number) ?? "-")")
                    
                case .failure(let error):
                    let lines = [
                        "Netflix SSO Profile",
                        "-------------------",
                        "Error loading user data:",
                        "\(error.localizedDescription)",
                    ]
                    self?.infoTextView.text = lines.joined(separator: "\n")
                    print("[SSO][Netflix][ProfileUI] status=error reason=\(error.localizedDescription)")
                }
            }
        }
    }

    private func display(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "-" }
        return value
    }

    private func displayInt(_ value: Int?) -> String {
        guard let value else { return "-" }
        return String(value)
    }

    private func short(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "-" }
        if value.count <= 16 { return value }
        return String(value.prefix(16)) + "..."
    }

    @objc private func handleSignOutTapped() {
        let alert = UIAlertController(
            title: "Sign Out",
            message: "Are you sure you want to sign out?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Sign Out", style: .destructive) { [weak self] _ in
            self?.performSignOut()
        })
        
        present(alert, animated: true)
    }
    
    private func performSignOut() {
        let defaults = UserDefaults.standard
        // Only these keys are stored now
        let keys = [
            "AccessToken",
            "TokenExpiresInSeconds",
            "SSO_LocalUserId",
            "SSO_Verifier",
            "SSO_State"
        ]
        keys.forEach { defaults.removeObject(forKey: $0) }
        
        print("[SSO][Netflix][Profile] status=logout cleared_keys=\(keys.count)")

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        
        let loginVC = LoginViewController(nibName: "LoginViewController", bundle: nil)
        UIView.transition(with: window, duration: 0.4, options: .transitionCrossDissolve) {
            window.rootViewController = loginVC
        }
    }
}

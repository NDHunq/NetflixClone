//
//  ProfileViewController.swift
//  NetflixClone
//
//  Created by Nguyen Duy Hung on 24/3/26.
//

import UIKit

class ProfileViewController: UIViewController {

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 20
        return stack
    }()

    private let profileCardView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 16
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.systemGray5.cgColor
        return view
    }()

    private let profileCardStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 14
        return stack
    }()

    private let phoneValueLabel = ProfileViewController.makeValueLabel()
    private let fullNameValueLabel = ProfileViewController.makeValueLabel()
    private let profileNameValueLabel = ProfileViewController.makeValueLabel()

    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private let errorLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .systemRed
        label.numberOfLines = 0
        label.isHidden = true
        return label
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
        loadProfile()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadProfile()
    }

    private func setupViews() {
        view.addSubview(contentStack)
        view.addSubview(signOutButton)

        signOutButton.addTarget(self, action: #selector(handleSignOutTapped), for: .touchUpInside)

        contentStack.addArrangedSubview(profileCardView)
        contentStack.addArrangedSubview(errorLabel)
        contentStack.addArrangedSubview(loadingIndicator)

        profileCardView.addSubview(profileCardStack)
        profileCardStack.addArrangedSubview(makeInfoRow(title: "Phone Number", valueLabel: phoneValueLabel))
        profileCardStack.addArrangedSubview(makeInfoRow(title: "Full Name", valueLabel: fullNameValueLabel))
        profileCardStack.addArrangedSubview(makeInfoRow(title: "Profile Name", valueLabel: profileNameValueLabel))

        NSLayoutConstraint.activate([
            profileCardStack.topAnchor.constraint(equalTo: profileCardView.topAnchor, constant: 18),
            profileCardStack.leadingAnchor.constraint(equalTo: profileCardView.leadingAnchor, constant: 16),
            profileCardStack.trailingAnchor.constraint(equalTo: profileCardView.trailingAnchor, constant: -16),
            profileCardStack.bottomAnchor.constraint(equalTo: profileCardView.bottomAnchor, constant: -18)
        ])

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: signOutButton.topAnchor, constant: -20),
            
            signOutButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            signOutButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            signOutButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            signOutButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    private func loadProfile() {
        setLoading(true)
        errorLabel.isHidden = true

        APICaller.shared.getUserProfile { [weak self] result in
            DispatchQueue.main.async {
                self?.setLoading(false)

                switch result {
                case .success(let userResponse):
                    self?.phoneValueLabel.text = self?.display(userResponse.phone_number)
                    self?.fullNameValueLabel.text = self?.display(userResponse.full_name)
                    self?.profileNameValueLabel.text = self?.display(userResponse.profile_name)
                    print("[SSO][Netflix][ProfileUI] status=render user_id=\(userResponse.id)")

                case .failure(let error):
                    self?.phoneValueLabel.text = "-"
                    self?.fullNameValueLabel.text = "-"
                    self?.profileNameValueLabel.text = "-"
                    self?.errorLabel.text = "Không tải được thông tin profile. \(error.localizedDescription)"
                    self?.errorLabel.isHidden = false
                    print("[SSO][Netflix][ProfileUI] status=error reason=\(error.localizedDescription)")
                }
            }
        }
    }

    private func setLoading(_ isLoading: Bool) {
        if isLoading {
            loadingIndicator.startAnimating()
        } else {
            loadingIndicator.stopAnimating()
        }
    }

    private func display(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "-" }
        return value
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

    private func makeInfoRow(title: String, valueLabel: UILabel) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 4

        let titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .secondaryLabel
        titleLabel.text = title.uppercased()

        valueLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        container.addArrangedSubview(titleLabel)
        container.addArrangedSubview(valueLabel)
        return container
    }

    private static func makeValueLabel() -> UILabel {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        label.numberOfLines = 0
        label.text = "-"
        return label
    }
}

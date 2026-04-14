//
//  SplashViewController.swift
//  NetflixClone
//
//  Created by NDHunq on 14/4/26.
//

import UIKit
import SDWebImage

class SplashViewController: UIViewController {

    private let splashDuration: TimeInterval = 3.0

    private var animationImageView: SDAnimatedImageView!
    private var hasNavigated = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupGIFAnimation()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startSplashTimer()
    }

    private func setupGIFAnimation() {
        guard let gifURL = Bundle.main.url(forResource: "netflixFullLogo", withExtension: "gif"),
              let gifData = try? Data(contentsOf: gifURL),
              let animatedImage = SDAnimatedImage(data: gifData) else {
            navigateToLogin()
            return
        }

        animationImageView = SDAnimatedImageView()
        animationImageView.image = animatedImage
        animationImageView.contentMode = .scaleAspectFit
        animationImageView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(animationImageView)

        NSLayoutConstraint.activate([
            animationImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            animationImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            animationImageView.widthAnchor.constraint(equalToConstant: 200),
            animationImageView.heightAnchor.constraint(equalToConstant: 200)
        ])

        animationImageView.startAnimating()
    }


    private func startSplashTimer() {
        DispatchQueue.main.asyncAfter(deadline: .now() + splashDuration) { [weak self] in
            self?.navigateToLogin()
        }
    }

    private func navigateToLogin() {
        guard !hasNavigated else { return }
        hasNavigated = true

        let loginVC = LoginViewController(nibName: "LoginViewController", bundle: nil)
        loginVC.modalPresentationStyle = .fullScreen
        loginVC.modalTransitionStyle = .crossDissolve
        present(loginVC, animated: true)
    }
}

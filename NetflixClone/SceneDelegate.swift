//
//  SceneDelegate.swift
//  NetflixClone
//
//  Created by Nguyen Duy Hung on 23/3/26.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    private func short(_ value: String, head: Int = 8) -> String {
        String(value.prefix(head))
    }


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        window = UIWindow(frame: windowScene.coordinateSpace.bounds)
        window?.windowScene = windowScene
        let splashVC = SplashViewController(nibName: "SplashViewController", bundle: nil)
        window?.rootViewController = splashVC
        window?.makeKeyAndVisible()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCallbackNotification(_:)),
            name: .ssoCallbackURLReceived,
            object: nil
        )
        
        // Kiểm tra deep link callback khi cold start
        if let urlContext = connectionOptions.urlContexts.first {
            print("[SSO] Received cold callback URL: \(urlContext.url.absoluteString)")
            handleCallbackURL(urlContext.url)
        }
    }

    @objc private func handleCallbackNotification(_ notification: Notification) {
        guard let url = notification.object as? URL else { return }
        print("[SSO] SceneDelegate received callback via AppDelegate bridge: \(url.absoluteString)")
        handleCallbackURL(url)
    }

    // Bắt callback khi warm start
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        if let url = URLContexts.first?.url {
            print("[SSO] Received warm callback URL: \(url.absoluteString)")
            handleCallbackURL(url)
        }
    }
    
    // Xử lý callback từ Super App
    private func handleCallbackURL(_ url: URL) {
        print("[SSO] handleCallbackURL entered: \(url.absoluteString)")
        guard url.scheme == "netflixclone", url.host == "callback" else { return }
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let queryItems = components.queryItems else { return }
        
        var callbackParams = [String: String]()
        queryItems.forEach { callbackParams[$0.name] = $0.value }

        print("[SSO][Netflix][Callback] params=\(callbackParams.keys.sorted())")
        
        if let err = callbackParams["error"] {
            print("[SSO] Lỗi từ Super App: \(err)")
            return
        }
        
        guard let code = callbackParams["code"], 
              let state = callbackParams["state"] else {
            print("[SSO] Missing code or state")
                        print("[SSO][Netflix][Callback] status=failed reason=missing_code_or_state")
            return
        }

                print("[SSO][Netflix][Callback] status=parsed code_head=\(short(code)) state=\(state)")
        
        let savedState = UserDefaults.standard.string(forKey: "SSO_State") ?? ""
        print("[SSO][Netflix][Callback] state_received=\(state) state_saved=\(savedState)")
        if state != savedState {
            print("[SSO] State không khớp - có thể bị CSRF attack")
            print("[SSO][Netflix][Callback] status=failed reason=state_mismatch")
            return
        }
        
        exchangeCodeForJWT(code: code)
    }
    
    private func exchangeCodeForJWT(code: String) {
        print("[SSO] exchangeCodeForJWT started with code: \(code)")
        guard let verifier = UserDefaults.standard.string(forKey: "SSO_Verifier") else {
            print("[SSO] Không tìm thấy verifier")
            return
        }
        
        let clientId = "serviceapp.demo"
        let redirectUri = "netflixclone://callback"
        
        let tokenRequest = OIDCTokenRequest(
            client_id: clientId,
            code: code,
            redirect_uri: redirectUri,
            code_verifier: verifier
        )

        print("[SSO][Netflix][Token] status=request client_id=\(clientId) code_head=\(short(code)) verifier_len=\(verifier.count) redirect_uri=\(redirectUri)")
        
        APICaller.shared.exchangeCodeForToken(request: tokenRequest) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let tokenResponse):
                    print("[SSO] Token exchange successful")
                    print("[SSO] Upstream ID Token: \(tokenResponse.upstream_id_token)")
                    print("[SSO][Netflix][Token] status=success app_access_token_head=\(self.short(tokenResponse.app_access_token))")
                    print("[SSO][Netflix][Token] mapped local_user_id=\(tokenResponse.user.id) profile_id=\(tokenResponse.identity.profile_id) provider=\(tokenResponse.identity.provider)")
                    
                    if let payloadDict = self.decodeJWTPayload(jwt: tokenResponse.upstream_id_token) {
                        print("[SSO] Decoded payload: \(payloadDict)")
                    }
                    
                    // Netflix app session token ONLY (no PII, no upstream tokens)
                    UserDefaults.standard.set(tokenResponse.app_access_token, forKey: "AccessToken")
                    UserDefaults.standard.set(tokenResponse.app_expires_in_seconds, forKey: "TokenExpiresInSeconds")
                    UserDefaults.standard.set(tokenResponse.user.id, forKey: "SSO_LocalUserId")

                    print("[SSO][Netflix][Session] status=saved keys=AccessToken,TokenExpiresInSeconds,SSO_LocalUserId")
                    
                    UserDefaults.standard.removeObject(forKey: "SSO_Verifier")
                    UserDefaults.standard.removeObject(forKey: "SSO_State")

                    print("[SSO][Netflix][Session] status=cleanup removed=SSO_Verifier,SSO_State")
                    
                    self.navigateToHome()
                    
                case .failure(let error):
                    print("[SSO] Token exchange failed: \(error.localizedDescription)")
                    print("[SSO][Netflix][Token] status=failed error=\(error.localizedDescription)")
                }
            }
        }
    }
    
    private func decodeJWTPayload(jwt: String) -> [String: Any]? {
        let segments = jwt.components(separatedBy: ".")
        guard segments.count > 1 else { return nil }
        
        var base64 = segments[1]
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        
        guard let data = Data(base64Encoded: base64) else { return nil }
        
        do {
            let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            return dict
        } catch {
            print("[SSO] Decode JWT error: \(error)")
            return nil
        }
    }
    
    private func navigateToHome() {
        guard let window = window else { return }
        UIView.transition(with: window, duration: 0.4, options: .transitionCrossDissolve) {
            window.rootViewController = MainTabBarViewController()
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }


}


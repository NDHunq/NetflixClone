//
//  OIDCModels.swift
//  NetflixClone
//
//  Created by Nguyen Duy Hung on 25/4/26.
//

import Foundation

struct OIDCTokenRequest: Codable {
    let grant_type: String
    let client_id: String
    let code: String
    let redirect_uri: String
    let code_verifier: String
    
    enum CodingKeys: String, CodingKey {
        case grant_type
        case client_id
        case code
        case redirect_uri
        case code_verifier
    }
    
    init(client_id: String, code: String, redirect_uri: String, code_verifier: String) {
        self.grant_type = "authorization_code"
        self.client_id = client_id
        self.code = code
        self.redirect_uri = redirect_uri
        self.code_verifier = code_verifier
    }
}

struct OIDCTokenResponse: Codable {
    let app_access_token: String
    let app_token_type: String
    let app_expires_in_seconds: Int
    let user: SSOUserResponse
    let identity: SSOIdentityResponse
    let upstream_access_token: String
    let upstream_id_token: String
    let upstream_token_type: String
    let upstream_expires_in: Int
}

struct SSOUserResponse: Codable {
    let id: Int
    let phone_number: String
    let full_name: String
    let created_at: String?
}

struct SSOIdentityResponse: Codable {
    let provider: String
    let subject: String
    let profile_id: String
    let audience: String?
    let full_name: String?
    let gender: String?
    let local_user_id: Int
    let last_login_at: String?
}

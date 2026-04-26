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
    let access_token: String
    let id_token: String
    let token_type: String
    let expires_in: Int
}

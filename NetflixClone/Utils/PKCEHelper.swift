//
//  PKCEHelper.swift
//  NetflixClone
//
//  Created by Nguyen Duy Hung on 25/4/26.
//

import Foundation
import CommonCrypto

struct PKCEHelper {
    
    static func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        let result = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        guard result == errSecSuccess else { return "" }
        
        let data = Data(buffer)
        return data.base64URLEncodedString()
    }
    
    static func generateCodeChallenge(verifier: String) -> String {
        guard let data = verifier.data(using: .ascii) else { return "" }
        
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(data.count), &digest)
        }
        
        let hashData = Data(digest)
        return hashData.base64URLEncodedString()
    }
}

//format Base64 thành Base64URL
extension Data {
    func base64URLEncodedString() -> String {
        let base64 = self.base64EncodedString()
        return base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

//
//  NetworkManager.swift
//  NetflixClone
//
//  Created by hd on 6/4/26.
//

import Foundation
import Alamofire

class NetworkManager {
    static let shared = NetworkManager()
    private let session: Session
    
    private init(){
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 7
        config.waitsForConnectivity = true
        
        self.session = Session(configuration: config)
    }
    
    func request<T: Decodable>(
        endpoint: APIEndpoint,
        responseType: T.Type,
        completion: @escaping (Result<T, NetworkError>) -> Void
    ){
        let url = endpoint.fullURL
#if DEBUG
        print("[NetworkManager] → \(endpoint.method.rawValue.uppercased()) \(url)")
        if let params = endpoint.parameters, !params.isEmpty {
            print("   Params: \(params)")
        }
#endif
        
        session.request(
            url,
            method: endpoint.method,
            parameters: endpoint.parameters,
            encoding: URLEncoding.default,
            headers: endpoint.headers
        )
        .validate(statusCode: 200..<300)       // Tự động fail nếu HTTP status không phải 2xx
        .responseDecodable(of: responseType) { response in
            
            // Log response
#if DEBUG
            let statusCode = response.response?.statusCode ?? 0
            print("   ← [\(statusCode)] \(url)")
#endif
            
            switch response.result {
            case .success(let decodedData):
                completion(.success(decodedData))
                
            case .failure(let afError):
                let networkError = NetworkManager.mapError(afError, response: response)
#if DEBUG
                print("   ❌ Error: \(networkError.localizedDescription)")
#endif
                completion(.failure(networkError))
            }
        }
    }
    
    private static func mapError<T>(_ afError: AFError, response: DataResponse<T, AFError>) -> NetworkError {
        if let statusCode = response.response?.statusCode {
            switch statusCode {
            case 401: return .unauthorized
            case 404: return .notFound
            case 429: return .rateLimited
            case 500...599: return .serverError
            default: break
            }
        }
        
        if afError.isSessionTaskError {
            return .noInternet
        }
        
        if afError.isResponseSerializationError {
            return .decodingFailed
        }
        
        return .unknown(afError.localizedDescription)
    }
}

enum NetworkError: Error {
    case noInternet
    case unauthorized
    case notFound
    case rateLimited
    case serverError
    case decodingFailed
    case invalidURL
    case unknown(String)
    
    var localizedDescription: String {
        switch self {
        case .noInternet:       return "Không có kết nối mạng. Vui lòng kiểm tra wifi/data."
        case .unauthorized:     return "API key không hợp lệ hoặc đã hết hạn."
        case .notFound:         return "Không tìm thấy dữ liệu yêu cầu."
        case .rateLimited:      return "Quá nhiều yêu cầu. Vui lòng thử lại sau."
        case .serverError:      return "Lỗi máy chủ. Vui lòng thử lại sau."
        case .decodingFailed:   return "Lỗi xử lý dữ liệu từ server."
        case .invalidURL:       return "URL không hợp lệ."
        case .unknown(let msg): return "Lỗi không xác định: \(msg)"
        }
    }
}

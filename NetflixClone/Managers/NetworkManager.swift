//
//  NetworkManager.swift
//  NetflixClone
//
//  Created by hd on 6/4/26.
//

import Foundation
import Alamofire

class NetworkInterceptor: RequestInterceptor {
    let retryLimit = 3
    let retryDelay: TimeInterval = 2

    func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
        guard request.retryCount < retryLimit else {
            completion(.doNotRetry)
            return
        }
        
        if let afError = error as? AFError {
            switch afError {
            case .sessionTaskFailed(let sessionError):
                // Network timeout, connection lost
                if (sessionError as NSError).code == NSURLErrorTimedOut ||
                    (sessionError as NSError).code == NSURLErrorNetworkConnectionLost {
                    print("****Retrying request: \(request.request?.url?.absoluteString ?? "unknown URL") (Attempt \(request.retryCount + 1))")
                    completion(.retryWithDelay(retryDelay))
                    return
                }
                
            case .responseValidationFailed(let reason):
                // 5xx server errors
                if case .unacceptableStatusCode(let statusCode) = reason, statusCode >= 500 {
                    print("****Retrying request: \(request.request?.url?.absoluteString ?? "unknown URL") (Attempt \(request.retryCount + 1))")
                    completion(.retryWithDelay(retryDelay))
                    return
                }
                
            default:
                break
            }
        }
        completion(.doNotRetry)
    }
}

class NetworkManager {
    static let shared = NetworkManager()
    private let session: Session
    
    private init(){
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 7
        config.waitsForConnectivity = true
        
        self.session = Session(configuration: config, interceptor: NetworkInterceptor())
    }
    
    func request<T: Decodable>(
        endpoint: APIEndpoint,
        responseType: T.Type,
        completion: @escaping (Result<T, NetworkError>) -> Void
    ){
        let url = endpoint.fullURL
        print("[NetworkManager] → \(endpoint.method.rawValue.uppercased()) \(url)")
        if let params = endpoint.parameters, !params.isEmpty {
            print("   Params: \(params)")
        }
        
        session.request(
            url,
            method: endpoint.method,
            parameters: endpoint.parameters,
            encoding: URLEncoding.default,
            headers: endpoint.headers
        )
        .validate(statusCode: 200..<300)
        .responseDecodable(of: responseType) { response in
            let statusCode = response.response?.statusCode ?? 0
            print("   ← [\(statusCode)] \(url)")
            
            switch response.result {
            case .success(let decodedData):
                completion(.success(decodedData))
                
            case .failure(let afError):
                let networkError = NetworkManager.mapError(afError, response: response)
                print("   ❌ Error: \(networkError.localizedDescription)")
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

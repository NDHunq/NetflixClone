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

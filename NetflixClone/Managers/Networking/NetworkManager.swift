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
        config.timeoutIntervalForRequest = 3
        config.timeoutIntervalForResource = 5
        self.session = Session(configuration: config, interceptor: NetworkInterceptor())
    }
    
    func request<T: Decodable>(
        endpoint: APIEndpoint,
        method: HTTPMethod,
        body: Parameters? = nil,
        responseType: T.Type,
        completion: @escaping (Result<T, NetworkError>) -> Void
    ) {
        do {
            let finalURL = try buildURL(from: endpoint.fullURL, queryParams: endpoint.parameters, method: method)
            
            let encoding: ParameterEncoding
            let requestParams: Parameters?
            
            switch method {
            case .post, .put, .patch:
                encoding = JSONEncoding.default
                requestParams = body
            default:
                encoding = URLEncoding.default
                requestParams = endpoint.parameters
            }
            
            print("→ [\(method.rawValue)] \(finalURL.absoluteString)")
            
            session.request(
                finalURL,
                method: method,
                parameters: requestParams,
                encoding: encoding,
                headers: endpoint.headers
            )
            .validate(statusCode: 200..<300)
            .responseDecodable(of: responseType) { response in
                switch response.result {
                case .success(let decodedData):
                    completion(.success(decodedData))
                case .failure(let afError):
                    let networkError = NetworkManager.mapError(afError, response: response)
                    print("   ❌ Error: \(networkError.localizedDescription)")
                    completion(.failure(networkError))
                }
            }
        } catch {
            print("❌ Error: Invalid URL")
            completion(.failure(.invalidURL))
        }
    }
    
    private func buildURL(from urlString: String, queryParams: Parameters?, method: HTTPMethod) throws -> URL {
        guard var components = URLComponents(string: urlString) else {
            throw URLError(.badURL)
        }
        
        if (method == .post || method == .put || method == .patch),
           let params = queryParams, !params.isEmpty {
            components.queryItems = params.map { URLQueryItem(name: $0.key, value: "\($0.value)") }
        }
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        return url
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

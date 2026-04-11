//
//  NetworkInterceptor.swift
//  NetflixClone
//
//  Created by NDHunq on 11/4/26.
//

import Foundation
import Alamofire

final class NetworkInterceptor: RequestInterceptor {
    private let retryLimit = 3
    private let retryDelay: TimeInterval = 2
    
    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        let method = urlRequest.httpMethod ?? "UNKNOWN"
        let url = urlRequest.url?.absoluteString ?? "unknown URL"
        print("[Interceptor][Adapt] \(method) \(url)")
        completion(.success(urlRequest))
    }

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
                    print("[Interceptor][Retry] \(request.request?.httpMethod ?? "UNKNOWN") \(request.request?.url?.absoluteString ?? "unknown URL") (Attempt \(request.retryCount + 1))")
                    completion(.retryWithDelay(retryDelay))
                    return
                }
                
            case .responseValidationFailed(let reason):
                // 5xx server errors
                if case .unacceptableStatusCode(let statusCode) = reason, statusCode >= 500 {
                    print("[Interceptor][Retry] \(request.request?.httpMethod ?? "UNKNOWN") \(request.request?.url?.absoluteString ?? "unknown URL") (Attempt \(request.retryCount + 1), status: \(statusCode))")
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

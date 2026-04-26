//
//  APICaller.swift
//  NetflixClone
//
//  Created by Nguyen Duy Hung on 27/3/26.
//

import Foundation
import Alamofire

class APICaller {
    
    static let shared = APICaller()
    private init() {}

    private func short(_ value: String, head: Int = 8) -> String {
        String(value.prefix(head))
    }
        
    func getHomeTrendingMovies(completion: @escaping (Result<[Title], NetworkError>) -> Void) {
        NetworkManager.shared.request(
            endpoint: .trendingMovies,
            method: .get,
            responseType: TrendingTitleResponse.self
        ) { result in
            completion(result.map(\.results))
        }
    }
    
    func getHomeTrendingTVs(completion: @escaping (Result<[Title], NetworkError>) -> Void) {
        NetworkManager.shared.request(
            endpoint: .trendingTV,
            method: .get,
            responseType: TrendingTitleResponse.self
        ) { result in
            completion(result.map(\.results))
        }
    }
    
    func getHomePopularMovies(completion: @escaping (Result<[Title], NetworkError>) -> Void) {
        NetworkManager.shared.request(
            endpoint: .popularMovies,
            method: .get,
            responseType: TrendingTitleResponse.self
        ) { result in
            completion(result.map(\.results))
        }
    }
    
    func getHomeUpcomingMovies(completion: @escaping (Result<[Title], NetworkError>) -> Void) {
        NetworkManager.shared.request(
            endpoint: .upcomingMovies,
            method: .get,
            responseType: TrendingTitleResponse.self
        ) { result in
            completion(result.map(\.results))
        }
    }
    
    func getHomeTopRated(completion: @escaping (Result<[Title], NetworkError>) -> Void) {
        NetworkManager.shared.request(
            endpoint: .topRatedMovies,
            method: .get,
            responseType: TrendingTitleResponse.self
        ) { result in
            completion(result.map(\.results))
        }
    }
    
    func getMovieDetail(movieId: Int, completion: @escaping (Result<MovieDetail, NetworkError>) -> Void) {
            NetworkManager.shared.request(
                endpoint: .movieDetail(movieId: movieId),
                method: .get,
                responseType: MovieDetail.self
            ) { result in
                completion(result)
            }
        }
        
        func getMovieCredits(movieId: Int, completion: @escaping (Result<[CastMember], NetworkError>) -> Void) {
            NetworkManager.shared.request(
                endpoint: .movieCredits(movieId: movieId),
                method: .get,
                responseType: MovieCreditsResponse.self
            ) { result in
                completion(result.map(\.cast))
            }
        }
        
        func getMovieVideos(movieId: Int, completion: @escaping (Result<[MovieVideo], NetworkError>) -> Void) {
            NetworkManager.shared.request(
                endpoint: .movieVideos(movieId: movieId),
                method: .get,
                responseType: MovieVideosResponse.self
            ) { result in
                completion(result.map(\.results))
            }
        }
        
    /// Đổi code & code_verifier lấy JWT token qua Netflix BE
    func exchangeCodeForToken(request: OIDCTokenRequest, 
                              completion: @escaping (Result<OIDCTokenResponse, NetworkError>) -> Void) {
        // Netflix Clone Backend (Service App BE) sẽ proxy sang Super App BE
        let tokenEndpoint = "http://127.0.0.1:5001/auth/oidc/token"

        print("[SSO][Netflix][API][Token] status=request endpoint=\(tokenEndpoint) client_id=\(request.client_id) code_head=\(short(request.code)) verifier_len=\(request.code_verifier.count)")
        
        guard let url = URL(string: tokenEndpoint) else {
            completion(.failure(.invalidURL))
            return
        }
        
        let params: [String: Any] = [
            "grant_type": request.grant_type,
            "client_id": request.client_id,
            "code": request.code,
            "redirect_uri": request.redirect_uri,
            "code_verifier": request.code_verifier
        ]
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: params)
        } catch {
            completion(.failure(.invalidURL))
            return
        }
        
        URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                print("[SSO] Error: \(error.localizedDescription)")
                print("[SSO][Netflix][API][Token] status=failed reason=network error=\(error.localizedDescription)")
                completion(.failure(.noInternet))
                return
            }

            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                let bodyString = String(data: data ?? Data(), encoding: .utf8) ?? ""
                print("[SSO] Token exchange HTTP \(httpResponse.statusCode): \(bodyString)")
                print("[SSO][Netflix][API][Token] status=failed reason=http status=\(httpResponse.statusCode)")
                completion(.failure(.unknown("HTTP \(httpResponse.statusCode)")))
                return
            }
            
            guard let data = data else {
                completion(.failure(.invalidURL))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let tokenResponse = try decoder.decode(OIDCTokenResponse.self, from: data)
                print("[SSO][Netflix][API][Token] status=success access_token_head=\(self.short(tokenResponse.access_token))")
                completion(.success(tokenResponse))
            } catch {
                let bodyString = String(data: data, encoding: .utf8) ?? ""
                print("[SSO] Decode error: \(error). Body: \(bodyString)")
                print("[SSO][Netflix][API][Token] status=failed reason=decode")
                completion(.failure(.decodingFailed))
            }
        }.resume()
    }
}

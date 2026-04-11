//
//  APICaller.swift
//  NetflixClone
//
//  Created by Nguyen Duy Hung on 27/3/26.
//

import Foundation

class APICaller {
    
    static let shared = APICaller()
    private init() {}
    
    // MARK: - Home APIs
    
    func getHomeTrendingMovies(completion: @escaping (Result<[Title], NetworkError>) -> Void) {
        NetworkManager.shared.request(
            endpoint: .trendingMovies,
            responseType: TrendingTitleResponse.self
        ) { result in
            completion(result.map(\.results))
        }
    }
    
    func getHomeTrendingTVs(completion: @escaping (Result<[Title], NetworkError>) -> Void) {
        NetworkManager.shared.request(
            endpoint: .trendingTV,
            responseType: TrendingTitleResponse.self
        ) { result in
            completion(result.map(\.results))
        }
    }
    
    func getHomePopularMovies(completion: @escaping (Result<[Title], NetworkError>) -> Void) {
        NetworkManager.shared.request(
            endpoint: .popularMovies,
            responseType: TrendingTitleResponse.self
        ) { result in
            completion(result.map(\.results))
        }
    }
    
    func getHomeUpcomingMovies(completion: @escaping (Result<[Title], NetworkError>) -> Void) {
        NetworkManager.shared.request(
            endpoint: .upcomingMovies,
            responseType: TrendingTitleResponse.self
        ) { result in
            completion(result.map(\.results))
        }
    }
    
    func getHomeTopRated(completion: @escaping (Result<[Title], NetworkError>) -> Void) {
        NetworkManager.shared.request(
            endpoint: .topRatedMovies,
            responseType: TrendingTitleResponse.self
        ) { result in
            completion(result.map(\.results))
        }
    }
}

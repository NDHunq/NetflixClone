//
//  Untitled.swift
//  NetflixClone
//
//  Created by Nguyen Duy Hung on 27/3/26.
//

import Foundation
import Alamofire

struct Constants {
    static let API_KEY = "ac90e227bedf46c08087b19100afc0f1"
    static let baseURL = "https://api.themoviedb.org"
}

enum APIError: Error {
    case failedToGetData
}

class APICaller {
    
    static let shared = APICaller()
    private init() {}
    
    // MARK: - Home APIs
    
    func getHomeTrendingMovies(completion: @escaping (Result<[Title], Error>) -> Void) {
        NetworkManager.shared.request(
            endpoint: .trendingMovies,
            responseType: TrendingTitleResponse.self
        ) { result in
            completion(result.map(\.results).mapError { $0 as Error })
        }
    }
    
    func getHomeTrendingTVs(completion: @escaping (Result<[Title], Error>) -> Void) {
        NetworkManager.shared.request(
            endpoint: .trendingTV,
            responseType: TrendingTitleResponse.self
        ) { result in
            completion(result.map(\.results).mapError { $0 as Error })
        }
    }
    
    func getHomePopularMovies(completion: @escaping (Result<[Title], Error>) -> Void) {
        NetworkManager.shared.request(
            endpoint: .popularMovies,
            responseType: TrendingTitleResponse.self
        ) { result in
            completion(result.map(\.results).mapError { $0 as Error })
        }
    }
    
    func getHomeUpcomingMovies(completion: @escaping (Result<[Title], Error>) -> Void) {
        NetworkManager.shared.request(
            endpoint: .upcomingMovies,
            responseType: TrendingTitleResponse.self
        ) { result in
            completion(result.map(\.results).mapError { $0 as Error })
        }
    }
    
    func getHomeTopRated(completion: @escaping (Result<[Title], Error>) -> Void) {
        NetworkManager.shared.request(
            endpoint: .topRatedMovies,
            responseType: TrendingTitleResponse.self
        ) { result in
            completion(result.map(\.results).mapError { $0 as Error })
        }
    }
    
    // MARK: - Upcoming
    
    func getUpcomingMovies(completion: @escaping (Result<[Title], Error>) -> Void) {
        NetworkManager.shared.request(
            endpoint: .upcomingMovies,
            responseType: TrendingTitleResponse.self
        ) { result in
            completion(result.map(\.results).mapError { $0 as Error })
        }
    }
}

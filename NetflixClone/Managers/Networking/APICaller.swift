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
}

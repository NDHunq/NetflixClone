//
//  APIEndpoint.swift
//  NetflixClone
//
//  Created by hd on 6/4/26.
//

import Foundation
import Alamofire

private enum APIConstants {
    static let apiKey   = "ac90e227bedf46c08087b19100afc0f1"
    static let baseURL  = "https://api.themoviedb.org/3"
    static let language = "en-US"
}

enum APIEndpoint {
    
    // Trending
    case trendingMovies                     // GET /trending/movie/day
    case trendingTV                         // GET /trending/tv/day
    
    // Movies
    case popularMovies                      // GET /movie/popular
    case upcomingMovies                     // GET /movie/upcoming
    case topRatedMovies                     // GET /movie/top_rated
    
    // Search
    case searchMovies(query: String)        // GET /search/movie?query=...
}

extension APIEndpoint {
    
    var path: String {
        switch self {
        case .trendingMovies:           return "/trending/movie/day"
        case .trendingTV:               return "/trending/tv/day"
        case .popularMovies:            return "/movie/popular"
        case .upcomingMovies:           return "/movie/upcoming"
        case .topRatedMovies:           return "/movie/top_rated"
        case .searchMovies:             return "/search/movie"
        }
    }
    
    var method: HTTPMethod {
        return .get
    }
    
    var fullURL: String {
        return APIConstants.baseURL + path
    }
    
    var parameters: Parameters? {
        var params: Parameters = [
            "api_key": APIConstants.apiKey,
            "language": APIConstants.language
        ]
        
        switch self {
        case .searchMovies(let query):
            params["query"] = query
            params["page"] = 1
        case .popularMovies, .upcomingMovies, .topRatedMovies:
            params["page"] = 1
        default:
            break
        }
        
        return params
    }
    
    var headers: HTTPHeaders {
        return [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
    }
}

//
//  MovieDetail.swift
//  NetflixClone
//
//  Created by NDHunq on 12/4/26.
//

import Foundation

struct MovieDetail: Codable {
    let id: Int
    let title: String?
    let original_title: String?
    let overview: String?
    let poster_path: String?
    let backdrop_path: String?
    let release_date: String?
    let runtime: Int?
    let vote_average: Double?
    let vote_count: Int?
    let status: String?
    let tagline: String?
    let budget: Int?
    let revenue: Int?
    let genres: [Genre]?
    let production_companies: [ProductionCompany]?
}

struct Genre: Codable {
    let id: Int
    let name: String
}

struct ProductionCompany: Codable {
    let id: Int
    let name: String
    let logo_path: String?
}

// MARK: - Movie Credits Response
// API: GET /movie/{movie_id}/credits
struct MovieCreditsResponse: Codable {
    let id: Int
    let cast: [CastMember]
}

struct CastMember: Codable {
    let id: Int
    let name: String
    let character: String?
    let profile_path: String?
    let order: Int?
}

// MARK: - Movie Videos Response
// API: GET /movie/{movie_id}/videos
struct MovieVideosResponse: Codable {
    let id: Int
    let results: [MovieVideo]
}

struct MovieVideo: Codable {
    let name: String?
    let key: String            // YouTube video ID
    let site: String?          // "YouTube"
    let type: String?          // "Trailer", "Teaser", "Featurette"
    let official: Bool?
}

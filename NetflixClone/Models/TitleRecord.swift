//
//  TitleRecord.swift
//  NetflixClone
//
//  Created by hd on 3/4/26.
//

import Foundation
import GRDB



struct TitleRecord: Codable, FetchableRecord, MutablePersistableRecord {

    var id: Int
    var media_type: String?
    var original_name: String?
    var original_title: String?
    var poster_path: String?
    var overview: String?
    var vote_count: Int?
    var release_date: String?
    var vote_average: Double?
    var section: String
    var saved_at: Date?

    static let databaseTableName = "title"

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let mediaType = Column(CodingKeys.media_type)
        static let originalName = Column(CodingKeys.original_name)
        static let originalTitle = Column(CodingKeys.original_title)
        static let posterPath = Column(CodingKeys.poster_path)
        static let overview = Column(CodingKeys.overview)
        static let voteCount = Column(CodingKeys.vote_count)
        static let releaseDate = Column(CodingKeys.release_date)
        static let voteAverage = Column(CodingKeys.vote_average)
        static let section = Column(CodingKeys.section)
        static let savedAt = Column(CodingKeys.saved_at)
    }

    init(from title: Title, section: String) {
        self.id = title.id
        self.media_type = title.media_type
        self.original_name = title.original_name
        self.original_title = title.original_title
        self.poster_path = title.poster_path
        self.overview = title.overview
        self.vote_count = title.vote_count
        self.release_date = title.release_date
        self.vote_average = title.vote_average
        self.section = section
        self.saved_at = Date()
    }

    func toTitle() -> Title {
        return Title(
            id: id,
            media_type: media_type,
            original_name: original_name,
            original_title: original_title,
            poster_path: poster_path,
            overview: overview,
            vote_count: vote_count,
            release_date: release_date,
            vote_average: vote_average
        )
    }
}

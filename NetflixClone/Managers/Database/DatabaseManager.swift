//
//  DatabaseManager.swift
//  NetflixClone
//
//  Created by hd on 3/4/26.
//

import Foundation
import GRDB

class DatabaseManager {

    static let shared = DatabaseManager()
    private var dbQueue: DatabaseQueue?
    private let passphrase = "NetflixClone@SecretKey2026"

    private init() {
        do {
            try setupDatabase()
        } catch {
            print("[DatabaseManager] Database setup failed: \(error)")
        }
    }

    private func setupDatabase() throws {
        let fileManager = FileManager.default
        let documentsURL = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dbURL = documentsURL.appendingPathComponent("NetflixClone.sqlite")

        print("[DatabaseManager] Database path: \(dbURL.path)")

        var config = Configuration()
        config.prepareDatabase { db in
            try db.usePassphrase(self.passphrase)
        }

        dbQueue = try DatabaseQueue(path: dbURL.path, configuration: config)

        try runMigrations()

        print("[DatabaseManager] Database ready (SQLCipher)")
    }


    private func runMigrations() throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_createTitles") { db in
            try db.create(table: "title", ifNotExists: true) { t in
                t.column("id", .integer).primaryKey()
                t.column("media_type", .text)
                t.column("original_name", .text)
                t.column("original_title", .text)
                t.column("poster_path", .text)
                t.column("overview", .text)
                t.column("vote_count", .integer)
                t.column("release_date", .text)
                t.column("vote_average", .double)
                t.column("section", .text).notNull()
                t.column("saved_at", .datetime)
                    .defaults(to: Date())
                t.uniqueKey(["id", "section"])
            }
        }
        
        migrator.registerMigration("v2_addIndexes") { db in
            try db.create(index: "idx_title_section",
                          on: "title",
                          columns: ["section"],
                          ifNotExists: true)

            try db.create(index: "idx_title_section_saved_at",
                          on: "title",
                          columns: ["section", "saved_at"],
                          ifNotExists: true)
        }
        
        migrator.registerMigration("v3_createUpcomingTitles") { db in
            try db.create(table: "upcoming_title", ifNotExists: true) { t in
                t.column("id", .integer).primaryKey()
                t.column("media_type", .text)
                t.column("original_name", .text)
                t.column("original_title", .text)
                t.column("poster_path", .text)
                t.column("overview", .text)
                t.column("vote_count", .integer)
                t.column("release_date", .text)
                t.column("vote_average", .double)
                t.column("saved_at", .datetime)
                    .defaults(to: Date())
            }
        }

        try migrator.migrate(dbQueue!)
    }
}

extension DatabaseManager {
    func saveTitles(_ titles: [Title], section: String) {
        guard let dbQueue = dbQueue else { return }

        do {
            try dbQueue.write { db in
                for title in titles {
                    var record = TitleRecord(from: title, section: section)
                    try record.save(db)
                }
            }
            print("[DatabaseManager] Đã lưu \(titles.count) phim vào section '\(section)'")
        } catch {
            print("[DatabaseManager] Lỗi lưu titles: \(error)")
        }
    }

    func fetchTitles(section: String) -> [Title] {
        guard let dbQueue = dbQueue else { return [] }

        do {
            return try dbQueue.read { db in
                let records = try TitleRecord
                    .filter(TitleRecord.Columns.section == section)
                    .order(TitleRecord.Columns.savedAt.desc)
                    .fetchAll(db)

                return records.map { $0.toTitle() }
            }
        } catch {
            print("[DatabaseManager] Lỗi fetch titles: \(error)")
            return []
        }
    }
    
    // MARK: - Upcoming Titles
    
    func saveUpcomingTitles(_ titles: [Title]) {
        guard let dbQueue = dbQueue else { return }

        do {
            try dbQueue.write { db in
                for title in titles {
                    var record = UpcomingTitleRecord(from: title)
                    try record.save(db)
                }
            }
            print("[DatabaseManager] Đã lưu \(titles.count) phim vào bảng 'upcoming_title'")
        } catch {
            print("[DatabaseManager] Lỗi lưu upcoming titles: \(error)")
        }
    }

    func fetchUpcomingTitles(limit: Int, offset: Int) -> [Title] {
        guard let dbQueue = dbQueue else { return [] }

        do {
            return try dbQueue.read { db in
                let records = try UpcomingTitleRecord
                    .order(UpcomingTitleRecord.Columns.savedAt.desc)
                    .limit(limit, offset: offset)
                    .fetchAll(db)

                return records.map { $0.toTitle() }
            }
        } catch {
            print("[DatabaseManager] Lỗi fetch upcoming titles paginated: \(error)")
            return []
        }
    }

    func fetchUpcomingTitlesByQuery(limit: Int, offset: Int) -> [Title] {
        guard let dbQueue = dbQueue else { return [] }

        do {
            return try dbQueue.read { db in
                let sql = "SELECT * FROM upcoming_title ORDER BY saved_at DESC LIMIT ? OFFSET ?"
                let records = try UpcomingTitleRecord.fetchAll(db, sql: sql, arguments: [limit, offset])

                return records.map { $0.toTitle() }
            }
        } catch {
            print("[DatabaseManager] Lỗi fetch upcoming titles paginated: \(error)")
            return []
        }
    }

    func searchTitlesByQuery(withKeyword keyword: String) -> [Title] {
        guard let dbQueue = dbQueue else { return [] }

        do {
            return try dbQueue.read { db in
                let sql = """
                    SELECT * FROM title 
                    WHERE original_title LIKE ? OR original_name LIKE ? 
                    ORDER BY saved_at DESC
                """
                let pattern = "%\(keyword)%"
                
                let records = try TitleRecord.fetchAll(
                    db,
                    sql: sql,
                    arguments: [pattern, pattern]
                )

                return records.map { $0.toTitle() }
            }
        } catch {
            print("[DatabaseManager] Lỗi search titles bằng SQL: \(error)")
            return []
        }
    }
}

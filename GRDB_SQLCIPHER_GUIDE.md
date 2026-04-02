# 📖 Hướng dẫn tích hợp GRDB + SQLCipher vào NetflixClone

> **Mục đích:** Sử dụng [GRDB.swift](https://github.com/groue/GRDB.swift) kết hợp [SQLCipher](https://www.zetetic.net/sqlcipher/) để lưu trữ dữ liệu phim được fetch từ API vào database local với mã hoá.
>
> **Phạm vi demo:** Khi app chạy → gọi API → lưu phim vào SQLite (được mã hoá bởi SQLCipher).

---

## Mục lục

1. [Tổng quan GRDB & SQLCipher](#1-tổng-quan)
2. [Cài đặt bằng CocoaPods](#2-cài-đặt-bằng-cocoapods)
3. [Tạo DatabaseManager](#3-tạo-databasemanager)
4. [Conform model Title cho GRDB](#4-conform-model-title)
5. [Tích hợp vào HomeViewController](#5-tích-hợp-vào-homeviewcontroller)
6. [Đọc dữ liệu đã lưu (tuỳ chọn)](#6-đọc-dữ-liệu-đã-lưu)
7. [Sử dụng DB Browser for SQLite](#7-db-browser-for-sqlite)
8. [Lỗi thường gặp & Xử lý](#8-lỗi-thường-gặp)

---

## 1. Tổng quan

### GRDB.swift là gì?

**GRDB.swift** là một thư viện Swift để làm việc với SQLite. Thay vì phải viết raw SQL và dùng con trỏ `OpaquePointer` như SQLite3 thuần, GRDB cho phép:

- Map struct Swift ↔ bảng SQL tự động thông qua protocol `Codable`
- API type-safe, dễ đọc
- Quản lý migration (thay đổi schema database qua các version)
- Thread-safe sẵn (không cần tự tạo `DispatchQueue` serial)

### SQLCipher là gì?

**SQLCipher** là một bản mở rộng của SQLite hỗ trợ **mã hoá toàn bộ database file** bằng AES-256. Khi tích hợp:

- File `.sqlite` trên thiết bị sẽ bị mã hoá hoàn toàn
- Không thể đọc bằng các tool SQLite thông thường nếu không có passphrase
- Bảo vệ dữ liệu người dùng nếu thiết bị bị jailbreak hoặc backup bị truy cập trái phép

### So sánh với cách làm cũ (SQLite3 thuần)

| | SQLite3 thuần | GRDB + SQLCipher |
|---|---|---|
| **Import** | `import SQLite3` | `import GRDB` |
| **Kiểu con trỏ** | `OpaquePointer?` | `DatabaseQueue` (type-safe) |
| **Tạo bảng** | Viết raw SQL string | Dùng `db.create(table:)` API |
| **Insert/Select** | `sqlite3_prepare_v2`, `bind`, `step`, `finalize` | `try record.insert(db)`, `Record.fetchAll(db)` |
| **Optional handling** | Phải check `SQLITE_NULL` thủ công | Tự động qua `Codable` |
| **Thread safety** | Tự quản lý `DispatchQueue` | GRDB quản lý sẵn |
| **Mã hoá** | ❌ Không có | ✅ SQLCipher tích hợp |
| **Migration** | Tự viết logic | `DatabaseMigrator` built-in |

---

## 2. Cài đặt bằng CocoaPods

### 2.1 Cài CocoaPods (nếu chưa có)

```bash
# Kiểm tra đã cài chưa
pod --version

# Nếu chưa có, cài bằng gem:
sudo gem install cocoapods
```

### 2.2 Khởi tạo Podfile

```bash
cd /đường/dẫn/tới/NetflixClone
pod init
```

Lệnh `pod init` sẽ tạo file `Podfile` ở thư mục gốc project.

### 2.3 Chỉnh sửa Podfile

Mở file `Podfile` và sửa thành:

```ruby
platform :ios, '15.0'

target 'NetflixClone' do
  use_frameworks!

  # GRDB với SQLCipher — sử dụng subspec SQLCipher
  pod 'GRDB.swift/SQLCipher'

  # SQLCipher — thư viện mã hoá SQLite
  pod 'SQLCipher', '~> 4.0'
end
```

> ⚠️ **Quan trọng:** KHÔNG thêm `pod 'GRDB.swift'` (không có `/SQLCipher`).
> Chỉ dùng MỘT trong hai: `GRDB.swift` hoặc `GRDB.swift/SQLCipher`. Nếu có cả hai sẽ gây conflict.

### 2.4 Cài đặt

```bash
pod install
```

Sau khi cài xong:
- **Đóng** file `NetflixClone.xcodeproj`
- **Mở** file `NetflixClone.xcworkspace` (file mới được tạo ra)
- Từ giờ **LUÔN** dùng `.xcworkspace` thay vì `.xcodeproj`

### 2.5 Verify

Build project (⌘B). Nếu build thành công, thêm dòng test vào bất kỳ file Swift nào:

```swift
import GRDB  // ← nếu không báo lỗi = đã cài đúng
```

---

## 3. Tạo DatabaseManager

Tạo file mới: `NetflixClone/Managers/DatabaseManager.swift`

```swift
//
//  DatabaseManager.swift
//  NetflixClone
//

import Foundation
import GRDB

class DatabaseManager {

    // MARK: - Singleton
    static let shared = DatabaseManager()

    // MARK: - Properties
    /// DatabaseQueue quản lý việc đọc/ghi thread-safe
    private var dbQueue: DatabaseQueue?

    /// Passphrase để mã hoá database — trong thực tế nên lưu trong Keychain
    private let passphrase = "NetflixClone@SecretKey2026"

    // MARK: - Init
    private init() {
        do {
            try setupDatabase()
        } catch {
            print("❌ Database setup failed: \(error)")
        }
    }

    // MARK: - Setup

    /// Mở database và tạo bảng
    private func setupDatabase() throws {

        // 1. Đường dẫn file database
        let fileManager = FileManager.default
        let documentsURL = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dbURL = documentsURL.appendingPathComponent("NetflixClone.sqlite")

        // In đường dẫn ra console để dùng DB Browser xem database
        print("📂 Database path: \(dbURL.path)")

        // 2. Cấu hình với SQLCipher passphrase
        var config = Configuration()
        config.prepareDatabase { db in
            try db.usePassphrase(self.passphrase)
        }

        // 3. Mở (hoặc tạo mới) database
        dbQueue = try DatabaseQueue(path: dbURL.path, configuration: config)

        // 4. Chạy migration để tạo bảng
        try runMigrations()

        print("✅ Database đã sẵn sàng (mã hoá SQLCipher)")
    }

    // MARK: - Migrations

    /// Tạo và cập nhật schema database
    private func runMigrations() throws {
        var migrator = DatabaseMigrator()

        // Migration v1: tạo bảng titles
        migrator.registerMigration("v1_createTitles") { db in
            try db.create(table: "title", ifNotExists: true) { t in
                t.column("id", .integer).primaryKey()      // ID từ API, không auto-increment
                t.column("media_type", .text)               // "movie" hoặc "tv"
                t.column("original_name", .text)            // Tên gốc (cho TV)
                t.column("original_title", .text)           // Tên gốc (cho Movie)
                t.column("poster_path", .text)              // Đường dẫn poster
                t.column("overview", .text)                 // Mô tả
                t.column("vote_count", .integer)            // Số lượt vote
                t.column("release_date", .text)             // Ngày phát hành
                t.column("vote_average", .double)           // Điểm trung bình
                t.column("section", .text).notNull()        // Section: "trending_movies", "trending_tv", ...
                t.column("saved_at", .datetime)             // Thời điểm lưu
                    .defaults(to: Date())

                // Unique constraint: mỗi phim chỉ xuất hiện 1 lần trong mỗi section
                t.uniqueKey(["id", "section"])
            }
        }

        // Có thể thêm migration v2, v3... ở đây khi cần thay đổi schema
        // migrator.registerMigration("v2_addColumn") { db in
        //     try db.alter(table: "title") { t in
        //         t.add(column: "newColumn", .text)
        //     }
        // }

        try migrator.migrate(dbQueue!)
    }
}

// MARK: - CRUD Operations

extension DatabaseManager {

    // MARK: Save (Insert hoặc Update)

    /// Lưu danh sách phim vào database theo section
    /// - Parameters:
    ///   - titles: Mảng `Title` từ API
    ///   - section: Tên section (VD: "trending_movies", "popular", ...)
    func saveTitles(_ titles: [Title], section: String) {
        guard let dbQueue = dbQueue else { return }

        do {
            try dbQueue.write { db in
                for title in titles {
                    // Tạo TitleRecord từ Title + section
                    var record = TitleRecord(from: title, section: section)

                    // INSERT OR REPLACE — nếu trùng (id, section) thì ghi đè
                    try record.save(db)
                }
            }
            print("✅ Đã lưu \(titles.count) phim vào section '\(section)'")
        } catch {
            print("❌ Lỗi lưu titles: \(error)")
        }
    }

    // MARK: Fetch

    /// Đọc tất cả phim đã lưu trong một section
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
            print("❌ Lỗi fetch titles: \(error)")
            return []
        }
    }

    /// Đọc tất cả phim trong database (tất cả section)
    func fetchAllTitles() -> [TitleRecord] {
        guard let dbQueue = dbQueue else { return [] }

        do {
            return try dbQueue.read { db in
                try TitleRecord.fetchAll(db)
            }
        } catch {
            print("❌ Lỗi fetch all: \(error)")
            return []
        }
    }

    /// Đếm tổng số record trong database
    func countAll() -> Int {
        guard let dbQueue = dbQueue else { return 0 }

        do {
            return try dbQueue.read { db in
                try TitleRecord.fetchCount(db)
            }
        } catch {
            return 0
        }
    }

    // MARK: Delete

    /// Xoá tất cả phim trong một section
    func deleteTitles(section: String) {
        guard let dbQueue = dbQueue else { return }

        do {
            try dbQueue.write { db in
                _ = try TitleRecord
                    .filter(TitleRecord.Columns.section == section)
                    .deleteAll(db)
            }
        } catch {
            print("❌ Lỗi xoá: \(error)")
        }
    }

    /// Xoá toàn bộ database
    func deleteAll() {
        guard let dbQueue = dbQueue else { return }

        do {
            try dbQueue.write { db in
                _ = try TitleRecord.deleteAll(db)
            }
            print("🗑️ Đã xoá toàn bộ database")
        } catch {
            print("❌ Lỗi xoá all: \(error)")
        }
    }
}
```

**Giải thích:**

| Khái niệm | Ý nghĩa |
|---|---|
| `DatabaseQueue` | Quản lý kết nối database, tự xử lý thread safety |
| `config.prepareDatabase` | Chạy mỗi khi mở kết nối — dùng để set passphrase |
| `usePassphrase()` | Hàm SQLCipher — mã hoá/giải mã database bằng passphrase |
| `DatabaseMigrator` | Quản lý version schema — chỉ chạy migration chưa chạy |
| `dbQueue.write { }` | Block ghi — GRDB đảm bảo chỉ 1 thread ghi tại 1 thời điểm |
| `dbQueue.read { }` | Block đọc — cho phép nhiều thread đọc đồng thời |

---

## 4. Conform model Title

### 4.1 Tạo TitleRecord

Do model `Title` hiện tại đang dùng cho cả JSON decoding (API) lẫn nhiều chỗ khác, ta tạo một struct riêng `TitleRecord` chuyên cho database để không ảnh hưởng code hiện có.

Tạo file mới: `NetflixClone/Models/TitleRecord.swift`

```swift
//
//  TitleRecord.swift
//  NetflixClone
//

import Foundation
import GRDB

/// Database record cho bảng "title"
/// Tách riêng khỏi Title struct để không ảnh hưởng JSON decoding từ API
struct TitleRecord: Codable, FetchableRecord, MutablePersistableRecord {

    // MARK: - Properties (mapping 1-1 với columns trong database)

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

    // MARK: - Table name

    /// Tên bảng trong database — GRDB dùng tên này để map
    static let databaseTableName = "title"

    // MARK: - Column definitions (dùng cho type-safe query)

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

    // MARK: - Conversion helpers

    /// Tạo TitleRecord từ Title (API model) + section name
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

    /// Chuyển TitleRecord về Title (để dùng với UI hiện tại)
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
```

**Giải thích các protocol:**

| Protocol | Vai trò |
|---|---|
| `Codable` | Cho phép GRDB tự động map property ↔ column (dựa trên tên trùng nhau) |
| `FetchableRecord` | Cho phép đọc record từ database (`fetchAll`, `fetchOne`, ...) |
| `MutablePersistableRecord` | Cho phép ghi record vào database (`insert`, `save`, `update`, `delete`) |

> **Tại sao dùng `MutablePersistableRecord` thay vì `PersistableRecord`?**
> Vì `MutablePersistableRecord` cho phép thay đổi record sau khi insert (ví dụ: cập nhật auto-generated ID). Trong trường hợp này ta dùng ID từ API nên không bắt buộc, nhưng dùng `Mutable` linh hoạt hơn khi mở rộng sau này.

### 4.2 Tại sao tách TitleRecord thay vì sửa Title?

- **Title** đang conform `Codable` cho JSON decoding từ API. Nếu thêm property `section`, `saved_at` vào Title thì JSON decoding sẽ bị ảnh hưởng.
- Giữ **Title** nguyên vẹn = không cần sửa bất kỳ code API/UI nào đã có.
- **TitleRecord** chỉ dùng nội bộ cho database, có thêm `section` và `saved_at`.

---

## 5. Tích hợp vào HomeViewController

### 5.1 Ý tưởng

Mỗi khi API trả về danh sách phim, ta lưu luôn vào database. Chỉ cần thêm **1 dòng** sau mỗi lần fetch thành công:

```swift
DatabaseManager.shared.saveTitles(titles, section: "tên_section")
```

### 5.2 Code cụ thể

Sửa `HomeViewController.swift`, trong hàm `cellForRowAt`:

```swift
func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard let cell = tableView.dequeueReusableCell(
        withIdentifier: CollectionViewTableViewCell.indentifier,
        for: indexPath
    ) as? CollectionViewTableViewCell else {
        return UITableViewCell()
    }

    switch indexPath.section {
    case Sections.TrendingMovies.rawValue:
        APICaller.shared.getTrendingMovies { result in
            switch result {
            case .success(let titles):
                cell.configure(with: titles)
                // ✅ Lưu vào database
                DatabaseManager.shared.saveTitles(titles, section: "trending_movies")
            case .failure(let error):
                print(error.localizedDescription)
            }
        }

    case Sections.TrendingTV.rawValue:
        APICaller.shared.getTrendingTVs { result in
            switch result {
            case .success(let titles):
                cell.configure(with: titles)
                // ✅ Lưu vào database
                DatabaseManager.shared.saveTitles(titles, section: "trending_tv")
            case .failure(let error):
                print(error.localizedDescription)
            }
        }

    case Sections.Popular.rawValue:
        APICaller.shared.getPopularMovies { result in
            switch result {
            case .success(let titles):
                cell.configure(with: titles)
                // ✅ Lưu vào database
                DatabaseManager.shared.saveTitles(titles, section: "popular")
            case .failure(let error):
                print(error.localizedDescription)
            }
        }

    case Sections.UpcomingMovies.rawValue:
        APICaller.shared.getUpcomingMovies { result in
            switch result {
            case .success(let titles):
                cell.configure(with: titles)
                // ✅ Lưu vào database
                DatabaseManager.shared.saveTitles(titles, section: "upcoming")
            case .failure(let error):
                print(error.localizedDescription)
            }
        }

    case Sections.TopRated.rawValue:
        APICaller.shared.getTopRated { result in
            switch result {
            case .success(let titles):
                cell.configure(with: titles)
                // ✅ Lưu vào database
                DatabaseManager.shared.saveTitles(titles, section: "top_rated")
            case .failure(let error):
                print(error.localizedDescription)
            }
        }

    default:
        return UITableViewCell()
    }

    return cell
}
```

### 5.3 Verify trong console

Sau khi chạy app, console sẽ hiển thị:

```
📂 Database path: /Users/.../Documents/NetflixClone.sqlite
✅ Database đã sẵn sàng (mã hoá SQLCipher)
✅ Đã lưu 20 phim vào section 'trending_movies'
✅ Đã lưu 20 phim vào section 'trending_tv'
✅ Đã lưu 20 phim vào section 'popular'
✅ Đã lưu 20 phim vào section 'upcoming'
✅ Đã lưu 20 phim vào section 'top_rated'
```

---

## 6. Đọc dữ liệu đã lưu

Phần này tuỳ chọn — demo cách đọc lại dữ liệu từ database.

### 6.1 Đọc phim theo section

```swift
// Lấy tất cả phim trending movies đã lưu
let trendingMovies = DatabaseManager.shared.fetchTitles(section: "trending_movies")
print("Có \(trendingMovies.count) trending movies trong DB")

for title in trendingMovies {
    print("  - \(title.original_title ?? title.original_name ?? "N/A")")
}
```

### 6.2 Đếm tổng số phim

```swift
let total = DatabaseManager.shared.countAll()
print("Tổng cộng \(total) record trong database")
```

### 6.3 Ví dụ: Load từ DB khi không có mạng (offline fallback)

```swift
case Sections.TrendingMovies.rawValue:
    APICaller.shared.getTrendingMovies { result in
        switch result {
        case .success(let titles):
            cell.configure(with: titles)
            DatabaseManager.shared.saveTitles(titles, section: "trending_movies")
        case .failure(let error):
            print(error.localizedDescription)
            // ✅ Fallback: đọc từ database khi API fail
            let cached = DatabaseManager.shared.fetchTitles(section: "trending_movies")
            if !cached.isEmpty {
                cell.configure(with: cached)
                print("📱 Loaded \(cached.count) phim từ cache")
            }
        }
    }
```

---

## 7. DB Browser for SQLite

### 7.1 Giới thiệu

**DB Browser for SQLite** là app miễn phí giúp xem và chỉnh sửa database SQLite bằng giao diện đồ hoạ. Rất hữu ích khi debug — xem dữ liệu đã lưu đúng chưa.

### 7.2 Cài đặt

#### Cách 1: Tải từ website (Khuyến nghị — bản có hỗ trợ SQLCipher)

1. Vào [https://sqlitebrowser.org/dl/](https://sqlitebrowser.org/dl/)
2. Tải bản cho macOS
3. Chọn bản **"DB Browser for SQLite"** — bản tiêu chuẩn đã hỗ trợ mở file SQLCipher

#### Cách 2: Cài bằng Homebrew

```bash
# Bản tiêu chuẩn
brew install --cask db-browser-for-sqlite
```

> ⚠️ **Lưu ý:** Đảm bảo bản bạn cài **có hỗ trợ SQLCipher**. Khi mở file encrypted, app phải hiện dialog yêu cầu nhập password. Nếu không hiện → bạn đang dùng bản không hỗ trợ SQLCipher.

### 7.3 Mở database của app (chạy trên Simulator)

#### Bước 1: Lấy đường dẫn database

Khi app chạy trên Simulator, console sẽ in ra:

```
📂 Database path: /Users/hd/Library/Developer/CoreSimulator/Devices/XXXX/data/Containers/Data/Application/YYYY/Documents/NetflixClone.sqlite
```

Copy đường dẫn này.

#### Bước 2: Mở trong DB Browser

1. Mở **DB Browser for SQLite**
2. Click **"Open Database"** (hoặc ⌘O)
3. Paste đường dẫn vào thanh Go To Folder (⌘⇧G trong Finder dialog)
4. Chọn file `NetflixClone.sqlite`

#### Bước 3: Nhập passphrase SQLCipher

Khi mở file encrypted, DB Browser sẽ hiện dialog:

```
┌─────────────────────────────────────────┐
│  Enter passphrase for the database      │
│                                         │
│  Password: [NetflixClone@SecretKey2026] │
│                                         │
│  Encryption:  SQLCipher 4 defaults ▼    │
│                                         │
│         [Cancel]    [OK]                │
└─────────────────────────────────────────┘
```

- Nhập passphrase: **`NetflixClone@SecretKey2026`** (giống trong `DatabaseManager.swift`)
- Encryption settings: chọn **"SQLCipher 4 defaults"**
- Click **OK**

#### Bước 4: Xem dữ liệu

Sau khi mở thành công:

1. Tab **"Database Structure"** — xem schema bảng `title`
2. Tab **"Browse Data"** — xem dữ liệu trong bảng
   - Chọn table `title` từ dropdown
   - Sẽ thấy các record phim đã lưu với các cột: id, media_type, original_name, ...
3. Tab **"Execute SQL"** — chạy SQL query trực tiếp

```sql
-- Xem 10 phim trending movies
SELECT * FROM title WHERE section = 'trending_movies' LIMIT 10;

-- Đếm phim theo section
SELECT section, COUNT(*) as total FROM title GROUP BY section;

-- Tìm phim theo tên
SELECT original_title, vote_average FROM title
WHERE original_title LIKE '%Spider%';
```

### 7.4 Mẹo sử dụng DB Browser

| Mẹo | Chi tiết |
|---|---|
| **Bookmark đường dẫn** | Finder → Go to Folder (⌘⇧G) → paste path → Add to sidebar |
| **Auto-refresh** | DB Browser không tự refresh — nhấn ⌘R hoặc đóng mở lại file sau khi app ghi dữ liệu |
| **Export CSV** | File → Export → Table as CSV — tiện khi cần gửi data cho người khác |
| **Xem SQL tạo bảng** | Tab Database Structure → click bảng → xem SQL ở dưới |
| **Đóng app trước khi mở DB** | Nếu app đang chạy và DB Browser báo lỗi, hãy stop Simulator trước |

### 7.5 Shortcut hữu ích trong DB Browser

| Phím tắt | Chức năng |
|---|---|
| ⌘O | Mở database |
| ⌘R | Refresh / Load lại |
| ⌘E | Mở tab Execute SQL |
| ⌘W | Đóng database |
| ⌘⇧S | Lưu thay đổi |

---

## 8. Lỗi thường gặp

### 8.1 Build errors

| Lỗi | Nguyên nhân | Cách sửa |
|---|---|---|
| `No such module 'GRDB'` | Chưa `pod install` hoặc đang mở `.xcodeproj` | Chạy `pod install`, mở `.xcworkspace` |
| `Multiple commands produce...` | Conflict giữa GRDB và GRDB/SQLCipher | Chỉ giữ `pod 'GRDB.swift/SQLCipher'` trong Podfile |
| Linker error `_sqlite3_...` | SQLCipher conflict với system SQLite | Clean build (⌘⇧K), xoá DerivedData, `pod install` lại |

### 8.2 Runtime errors

| Lỗi | Nguyên nhân | Cách sửa |
|---|---|---|
| `SQLite error 26: file is not a database` | Passphrase sai hoặc database tạo không có mã hoá rồi thêm mã hoá sau | Xoá file `.sqlite` cũ, để app tạo lại |
| `UNIQUE constraint failed` | Insert bản ghi trùng primary key | Dùng `save()` thay vì `insert()` — save = insert or update |
| `No such table: title` | Migration chưa chạy | Kiểm tra `runMigrations()` có được gọi trong `setupDatabase()` |

### 8.3 DB Browser issues

| Vấn đề | Giải pháp |
|---|---|
| Không hiện dialog nhập password | Cài bản DB Browser có hỗ trợ SQLCipher |
| Nhập đúng password nhưng vẫn lỗi | Thử đổi encryption settings sang "SQLCipher 3 defaults" hoặc "Custom" |
| File trống / không có data | Chạy app trước rồi mới mở DB Browser — dữ liệu chỉ có sau khi app fetch API |

### 8.4 Thread safety

GRDB's `DatabaseQueue` **đã tự xử lý thread safety**. Bạn KHÔNG cần tạo `DispatchQueue` riêng như khi dùng SQLite3 thuần. Chỉ cần gọi:

- `dbQueue.write { }` — cho các thao tác ghi (insert, update, delete)
- `dbQueue.read { }` — cho các thao tác đọc (select, fetch)

GRDB sẽ serialize các thao tác ghi và cho phép đọc đồng thời khi không có ghi.

---

## Tổng kết — Checklist thực hành

```
[ ] 1. Cài CocoaPods (nếu chưa có)
[ ] 2. Tạo Podfile với GRDB.swift/SQLCipher + SQLCipher
[ ] 3. Chạy `pod install`, mở .xcworkspace
[ ] 4. Tạo file Models/TitleRecord.swift
[ ] 5. Tạo file Managers/DatabaseManager.swift
[ ] 6. Sửa HomeViewController — thêm saveTitles() sau mỗi API call
[ ] 7. Build & Run — kiểm tra console log
[ ] 8. Copy database path → mở bằng DB Browser → nhập passphrase → xem dữ liệu
```

> **Tip cuối:** Nếu muốn test nhanh mà chưa muốn sửa HomeViewController, chỉ cần thêm đoạn này vào `viewDidLoad()` của bất kỳ ViewController nào:
>
> ```swift
> // Test nhanh: lưu 1 bộ phim giả vào DB
> let testTitle = Title(id: 9999, media_type: "movie", original_name: nil,
>                       original_title: "Test Movie", poster_path: nil,
>                       overview: "This is a test", vote_count: 100,
>                       release_date: "2026-01-01", vote_average: 8.5)
> DatabaseManager.shared.saveTitles([testTitle], section: "test")
> print("Total records: \(DatabaseManager.shared.countAll())")
> ```

# 📖 Hướng dẫn áp dụng SQLite vào NetflixClone

> **Mục đích:** Học cách dùng SQLite trong iOS để lưu trữ dữ liệu local.
> Áp dụng thực tế: lưu phim đã download, cache dữ liệu API, lịch sử tìm kiếm.

---

## Mục lục

1. [SQLite là gì?](#1-sqlite-là-gì)
2. [Cách dùng SQLite trong iOS](#2-cách-dùng-sqlite-trong-ios)
3. [Thiết kế database cho project](#3-thiết-kế-database)
4. [BƯỚC 1 — Tạo DatabaseManager](#4-bước-1--tạo-databasemanager)
5. [BƯỚC 2 — CRUD cho bảng downloads](#5-bước-2--crud-cho-bảng-downloads)
6. [BƯỚC 3 — Cache API responses](#6-bước-3--cache-api-responses)
7. [BƯỚC 4 — Tích hợp vào ViewController](#7-bước-4--tích-hợp-vào-viewcontroller)
8. [BƯỚC 5 — Lịch sử tìm kiếm](#8-bước-5--lịch-sử-tìm-kiếm)
9. [Kiến thức SQL cần nắm](#9-kiến-thức-sql-cần-nắm)
10. [Lỗi thường gặp & Debug](#10-lỗi-thường-gặp)

---

## 1. SQLite là gì?

### 1.1 Định nghĩa

**SQLite** là database nhẹ, chạy trực tiếp trên thiết bị (không cần server). iOS đã tích hợp sẵn
thư viện SQLite — chỉ cần `import SQLite3` là dùng được.

### 1.2 So sánh các cách lưu dữ liệu trong iOS

| Cách | Phù hợp cho | Độ phức tạp |
|---|---|---|
| **UserDefaults** | Settings, flags đơn giản | Thấp |
| **File JSON/Plist** | Dữ liệu nhỏ, ít query | Thấp |
| **SQLite** | Dữ liệu có cấu trúc, cần query | Trung bình |
| **Core Data** | ORM wrapper trên SQLite | Cao |
| **Realm** | Thư viện bên thứ 3 | Trung bình |

**Tại sao học SQLite thuần?** Vì Core Data bên dưới cũng dùng SQLite. Hiểu SQLite = hiểu nền tảng.

### 1.3 File database nằm ở đâu?

```
App Sandbox/
├── Documents/        ← database của user (backup iCloud)
├── Library/Caches/   ← cache (có thể bị xóa khi hết bộ nhớ)
└── tmp/              ← tạm thời
```

Trong project này: `Documents/NetflixClone.sqlite`

---

## 2. Cách dùng SQLite trong iOS

### 2.1 Import và kiểu dữ liệu

```swift
import SQLite3  // ← có sẵn, không cần cài thêm

// Kiểu chính: OpaquePointer — con trỏ đại diện cho database/statement
var db: OpaquePointer?       // database connection
var stmt: OpaquePointer?     // prepared statement
```

### 2.2 Vòng đời cơ bản

```
Mở database (sqlite3_open)
    ↓
Tạo bảng (sqlite3_exec với CREATE TABLE)
    ↓
Chuẩn bị câu lệnh (sqlite3_prepare_v2)
    ↓
Gắn giá trị (sqlite3_bind_text, sqlite3_bind_int, ...)
    ↓
Thực thi (sqlite3_step)
    ↓
Đọc kết quả (sqlite3_column_text, sqlite3_column_int, ...)
    ↓
Giải phóng (sqlite3_finalize)
    ↓
Đóng database (sqlite3_close)
```

### 2.3 Các hàm SQLite3 quan trọng

| Hàm | Mục đích | Trả về |
|---|---|---|
| `sqlite3_open(path, &db)` | Mở/tạo database | `SQLITE_OK` nếu thành công |
| `sqlite3_exec(db, sql, ...)` | Chạy SQL đơn giản (CREATE, DROP) | `SQLITE_OK` |
| `sqlite3_prepare_v2(db, sql, -1, &stmt, nil)` | Chuẩn bị statement có tham số | `SQLITE_OK` |
| `sqlite3_bind_text(stmt, 1, value, -1, SQLITE_TRANSIENT)` | Gắn giá trị String vào `?` thứ 1 | — |
| `sqlite3_bind_int(stmt, 2, value)` | Gắn giá trị Int vào `?` thứ 2 | — |
| `sqlite3_bind_double(stmt, 3, value)` | Gắn giá trị Double vào `?` thứ 3 | — |
| `sqlite3_step(stmt)` | Thực thi / đọc dòng tiếp theo | `SQLITE_DONE` hoặc `SQLITE_ROW` |
| `sqlite3_column_text(stmt, 0)` | Đọc cột thứ 0 (String) | `UnsafePointer<UInt8>?` |
| `sqlite3_column_int(stmt, 1)` | Đọc cột thứ 1 (Int) | `Int32` |
| `sqlite3_finalize(stmt)` | Giải phóng statement | — |
| `sqlite3_close(db)` | Đóng database | — |

**Lưu ý `SQLITE_TRANSIENT`:** Nói SQLite "copy giá trị này ngay", an toàn khi dùng với String Swift.
Khai báo: `let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)`

---

## 3. Thiết kế database

### 3.1 Áp dụng cho project NetflixClone

Dựa trên model `Title` hiện có và các tính năng cần thiết:

```sql
-- Bảng 1: Phim đã download (tính năng Downloads tab)
CREATE TABLE IF NOT EXISTS downloads (
    id INTEGER PRIMARY KEY,
    media_type TEXT,
    original_name TEXT,
    original_title TEXT,
    poster_path TEXT,
    overview TEXT,
    vote_count INTEGER,
    release_date TEXT,
    vote_average REAL,
    downloaded_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Bảng 2: Cache dữ liệu API (offline mode)
CREATE TABLE IF NOT EXISTS cached_titles (
    id INTEGER PRIMARY KEY,
    media_type TEXT,
    original_name TEXT,
    original_title TEXT,
    poster_path TEXT,
    overview TEXT,
    vote_count INTEGER,
    release_date TEXT,
    vote_average REAL,
    section TEXT NOT NULL,        -- 'trending_movies', 'trending_tv', ...
    cached_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Bảng 3: Lịch sử tìm kiếm
CREATE TABLE IF NOT EXISTS search_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    query TEXT NOT NULL,
    searched_at TEXT DEFAULT CURRENT_TIMESTAMP
);
```

### 3.2 Mapping giữa Title struct và SQL

| Swift property | SQL column | SQL type | Ghi chú |
|---|---|---|---|
| `id: Int` | `id` | `INTEGER PRIMARY KEY` | Không tự tăng vì dùng ID từ API |
| `media_type: String?` | `media_type` | `TEXT` | Nullable |
| `original_name: String?` | `original_name` | `TEXT` | Nullable |
| `original_title: String?` | `original_title` | `TEXT` | Nullable |
| `poster_path: String?` | `poster_path` | `TEXT` | Nullable |
| `overview: String?` | `overview` | `TEXT` | Nullable |
| `vote_count: Int?` | `vote_count` | `INTEGER` | Nullable |
| `release_date: String?` | `release_date` | `TEXT` | Nullable |
| `vote_average: Double?` | `vote_average` | `REAL` | Nullable |

---

## 4. BƯỚC 1 — Tạo DatabaseManager

### 4.1 Cấu trúc file mới

```
Managers/
├── APICaller.swift       ← đã có
└── DatabaseManager.swift ← TẠO MỚI
```

### 4.2 Code `DatabaseManager.swift`

```swift
//  DatabaseManager.swift
//  NetflixClone

import Foundation
import SQLite3

enum DatabaseError: Error {
    case openFailed
    case prepareFailed(String)
    case executionFailed(String)
    case unknown
}

class DatabaseManager {

    // MARK: - Singleton
    static let shared = DatabaseManager()

    // MARK: - Properties
    private var db: OpaquePointer?

    // Cần khai báo vì Swift không có sẵn
    private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    // MARK: - Init
    private init() {
        openDatabase()
        createTables()
    }

    // MARK: - Mở Database
    /// Database được lưu trong thư mục Documents của app
    private func openDatabase() {
        // 1. Tìm đường dẫn thư mục Documents
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask,
                 appropriateFor: nil, create: false)
            .appendingPathComponent("NetflixClone.sqlite")

        // 2. Mở database (tự tạo file nếu chưa có)
        if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
            print("❌ Không thể mở database: \(String(cString: sqlite3_errmsg(db)))")
        } else {
            print("✅ Database đã mở tại: \(fileURL.path)")
        }
    }

    // MARK: - Tạo bảng
    private func createTables() {
        let createDownloadsTable = """
        CREATE TABLE IF NOT EXISTS downloads (
            id INTEGER PRIMARY KEY,
            media_type TEXT,
            original_name TEXT,
            original_title TEXT,
            poster_path TEXT,
            overview TEXT,
            vote_count INTEGER,
            release_date TEXT,
            vote_average REAL,
            downloaded_at TEXT DEFAULT CURRENT_TIMESTAMP
        );
        """

        let createCacheTable = """
        CREATE TABLE IF NOT EXISTS cached_titles (
            id INTEGER,
            media_type TEXT,
            original_name TEXT,
            original_title TEXT,
            poster_path TEXT,
            overview TEXT,
            vote_count INTEGER,
            release_date TEXT,
            vote_average REAL,
            section TEXT NOT NULL,
            cached_at TEXT DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id, section)
        );
        """

        let createSearchHistory = """
        CREATE TABLE IF NOT EXISTS search_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            query TEXT NOT NULL UNIQUE,
            searched_at TEXT DEFAULT CURRENT_TIMESTAMP
        );
        """

        executeSQL(createDownloadsTable)
        executeSQL(createCacheTable)
        executeSQL(createSearchHistory)
    }

    // MARK: - Helper: chạy SQL đơn giản (không trả kết quả)
    private func executeSQL(_ sql: String) {
        var errorMessage: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, sql, nil, nil, &errorMessage) != SQLITE_OK {
            if let msg = errorMessage {
                print("❌ SQL Error: \(String(cString: msg))")
                sqlite3_free(errorMessage)
            }
        }
    }

    // MARK: - Đóng Database (gọi khi app terminate nếu cần)
    deinit {
        sqlite3_close(db)
    }
}
```

**Giải thích:**
- `static let shared` = Singleton pattern, chỉ có 1 instance duy nhất
- `sqlite3_open` = mở file database, tự tạo nếu chưa có
- `CREATE TABLE IF NOT EXISTS` = chỉ tạo bảng nếu chưa tồn tại, an toàn khi chạy nhiều lần
- `sqlite3_exec` = chạy SQL đơn giản, không cần bind tham số

---

## 5. BƯỚC 2 — CRUD cho bảng downloads

> **CRUD** = Create (thêm), Read (đọc), Update (cập nhật), Delete (xóa)

### 5.1 CREATE — Thêm phim vào downloads

Thêm vào `DatabaseManager.swift`:

```swift
// MARK: - Downloads CRUD

/// Thêm 1 phim vào danh sách đã download
func downloadTitle(_ title: Title) -> Bool {
    let sql = """
    INSERT OR REPLACE INTO downloads
    (id, media_type, original_name, original_title, poster_path,
     overview, vote_count, release_date, vote_average)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
    """

    var stmt: OpaquePointer?

    // Bước 1: Chuẩn bị statement
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
        print("❌ Prepare failed: \(String(cString: sqlite3_errmsg(db)))")
        return false
    }

    // Bước 2: Gắn giá trị vào các dấu ? (index bắt đầu từ 1)
    sqlite3_bind_int(stmt, 1, Int32(title.id))
    bindOptionalText(stmt, index: 2, value: title.media_type)
    bindOptionalText(stmt, index: 3, value: title.original_name)
    bindOptionalText(stmt, index: 4, value: title.original_title)
    bindOptionalText(stmt, index: 5, value: title.poster_path)
    bindOptionalText(stmt, index: 6, value: title.overview)
    bindOptionalInt(stmt, index: 7, value: title.vote_count)
    bindOptionalText(stmt, index: 8, value: title.release_date)
    bindOptionalDouble(stmt, index: 9, value: title.vote_average)

    // Bước 3: Thực thi
    let result = sqlite3_step(stmt) == SQLITE_DONE

    // Bước 4: Giải phóng (BẮT BUỘC! Nếu quên → memory leak)
    sqlite3_finalize(stmt)

    return result
}

// MARK: - Bind helpers cho Optional values

private func bindOptionalText(_ stmt: OpaquePointer?, index: Int32, value: String?) {
    if let value = value {
        sqlite3_bind_text(stmt, index, (value as NSString).utf8String, -1, SQLITE_TRANSIENT)
    } else {
        sqlite3_bind_null(stmt, index)
    }
}

private func bindOptionalInt(_ stmt: OpaquePointer?, index: Int32, value: Int?) {
    if let value = value {
        sqlite3_bind_int(stmt, index, Int32(value))
    } else {
        sqlite3_bind_null(stmt, index)
    }
}

private func bindOptionalDouble(_ stmt: OpaquePointer?, index: Int32, value: Double?) {
    if let value = value {
        sqlite3_bind_double(stmt, index, value)
    } else {
        sqlite3_bind_null(stmt, index)
    }
}
```

### 5.2 READ — Đọc danh sách đã download

```swift
/// Lấy tất cả phim đã download
func fetchDownloads() -> [Title] {
    let sql = "SELECT id, media_type, original_name, original_title, poster_path, overview, vote_count, release_date, vote_average FROM downloads ORDER BY downloaded_at DESC;"

    var stmt: OpaquePointer?
    var titles: [Title] = []

    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
        print("❌ Prepare failed")
        return []
    }

    // sqlite3_step trả SQLITE_ROW cho mỗi dòng kết quả
    while sqlite3_step(stmt) == SQLITE_ROW {
        let title = readTitleFromStatement(stmt)
        titles.append(title)
    }

    sqlite3_finalize(stmt)
    return titles
}

/// Kiểm tra phim đã download chưa
func isDownloaded(id: Int) -> Bool {
    let sql = "SELECT COUNT(*) FROM downloads WHERE id = ?;"
    var stmt: OpaquePointer?

    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
    sqlite3_bind_int(stmt, 1, Int32(id))

    var count: Int32 = 0
    if sqlite3_step(stmt) == SQLITE_ROW {
        count = sqlite3_column_int(stmt, 0)
    }
    sqlite3_finalize(stmt)
    return count > 0
}

// MARK: - Helper: đọc Title từ statement

private func readTitleFromStatement(_ stmt: OpaquePointer?) -> Title {
    let id = Int(sqlite3_column_int(stmt, 0))
    let media_type = columnText(stmt, index: 1)
    let original_name = columnText(stmt, index: 2)
    let original_title = columnText(stmt, index: 3)
    let poster_path = columnText(stmt, index: 4)
    let overview = columnText(stmt, index: 5)

    let vote_count: Int?
    if sqlite3_column_type(stmt, 6) != SQLITE_NULL {
        vote_count = Int(sqlite3_column_int(stmt, 6))
    } else {
        vote_count = nil
    }

    let release_date = columnText(stmt, index: 7)

    let vote_average: Double?
    if sqlite3_column_type(stmt, 8) != SQLITE_NULL {
        vote_average = sqlite3_column_double(stmt, 8)
    } else {
        vote_average = nil
    }

    return Title(id: id, media_type: media_type, original_name: original_name,
                 original_title: original_title, poster_path: poster_path,
                 overview: overview, vote_count: vote_count,
                 release_date: release_date, vote_average: vote_average)
}

private func columnText(_ stmt: OpaquePointer?, index: Int32) -> String? {
    guard sqlite3_column_type(stmt, index) != SQLITE_NULL,
          let cString = sqlite3_column_text(stmt, index) else { return nil }
    return String(cString: cString)
}
```

### 5.3 DELETE — Xóa phim khỏi downloads

```swift
/// Xóa 1 phim theo ID
func deleteDownload(id: Int) -> Bool {
    let sql = "DELETE FROM downloads WHERE id = ?;"
    var stmt: OpaquePointer?

    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
    sqlite3_bind_int(stmt, 1, Int32(id))

    let result = sqlite3_step(stmt) == SQLITE_DONE
    sqlite3_finalize(stmt)
    return result
}

/// Xóa tất cả downloads
func deleteAllDownloads() -> Bool {
    let sql = "DELETE FROM downloads;"
    var stmt: OpaquePointer?

    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
    let result = sqlite3_step(stmt) == SQLITE_DONE
    sqlite3_finalize(stmt)
    return result
}
```

---

## 6. BƯỚC 3 — Cache API responses

Mục đích: lưu dữ liệu API để hiển thị khi **không có mạng**.

```swift
// MARK: - Cache CRUD

/// Lưu danh sách Title vào cache theo section
func cacheTitles(_ titles: [Title], section: String) {
    // Xóa cache cũ của section này trước
    executeSQL("DELETE FROM cached_titles WHERE section = '\(section)';")

    for title in titles {
        let sql = """
        INSERT OR REPLACE INTO cached_titles
        (id, media_type, original_name, original_title, poster_path,
         overview, vote_count, release_date, vote_average, section)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { continue }

        sqlite3_bind_int(stmt, 1, Int32(title.id))
        bindOptionalText(stmt, index: 2, value: title.media_type)
        bindOptionalText(stmt, index: 3, value: title.original_name)
        bindOptionalText(stmt, index: 4, value: title.original_title)
        bindOptionalText(stmt, index: 5, value: title.poster_path)
        bindOptionalText(stmt, index: 6, value: title.overview)
        bindOptionalInt(stmt, index: 7, value: title.vote_count)
        bindOptionalText(stmt, index: 8, value: title.release_date)
        bindOptionalDouble(stmt, index: 9, value: title.vote_average)
        sqlite3_bind_text(stmt, 10, (section as NSString).utf8String, -1, SQLITE_TRANSIENT)

        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
    }
}

/// Lấy dữ liệu cache theo section
func fetchCachedTitles(section: String) -> [Title] {
    let sql = """
    SELECT id, media_type, original_name, original_title, poster_path,
           overview, vote_count, release_date, vote_average
    FROM cached_titles WHERE section = ? ORDER BY rowid;
    """
    var stmt: OpaquePointer?
    var titles: [Title] = []

    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
    sqlite3_bind_text(stmt, 1, (section as NSString).utf8String, -1, SQLITE_TRANSIENT)

    while sqlite3_step(stmt) == SQLITE_ROW {
        titles.append(readTitleFromStatement(stmt))
    }
    sqlite3_finalize(stmt)
    return titles
}
```

---

## 7. BƯỚC 4 — Tích hợp vào ViewController

### 7.1 HomeViewController — Cache kết quả API

Trong `cellForRowAt`, sau khi nhận kết quả từ API, lưu vào cache:

```swift
case Sections.TrendingMovies.rawValue:
    APICaller.shared.getTrendingMovies { result in
        switch result {
        case .success(let titles):
            cell.configure(with: titles)
            // ✅ MỚI: Cache kết quả
            DatabaseManager.shared.cacheTitles(titles, section: "trending_movies")
        case .failure(let error):
            print(error.localizedDescription)
            // ✅ MỚI: Load từ cache khi API fail
            let cached = DatabaseManager.shared.fetchCachedTitles(section: "trending_movies")
            if !cached.isEmpty { cell.configure(with: cached) }
        }
    }
```

### 7.2 DownloadsViewController — Hiển thị phim đã download

```swift
class DownloadsViewController: UIViewController {

    @IBOutlet weak var downloadsTable: UITableView!  // hoặc tạo bằng code
    private var titles: [Title] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Downloads"
        // setup tableView ...
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Load lại mỗi lần vào tab
        titles = DatabaseManager.shared.fetchDownloads()
        downloadsTable.reloadData()
    }
}
```

### 7.3 Thêm nút Download trên Cell

Trong CollectionView delegate, xử lý long press hoặc thêm context menu:

```swift
// Ví dụ: long press để download
func collectionView(_ collectionView: UICollectionView,
                    contextMenuConfigurationForItemAt indexPath: IndexPath,
                    point: CGPoint) -> UIContextMenuConfiguration? {
    let title = titles[indexPath.row]
    return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
        let downloadAction = UIAction(title: "Download",
                                       image: UIImage(systemName: "arrow.down.to.line")) { _ in
            let success = DatabaseManager.shared.downloadTitle(title)
            print(success ? "✅ Đã download" : "❌ Download thất bại")
        }
        return UIMenu(title: "", children: [downloadAction])
    }
}
```

---

## 8. BƯỚC 5 — Lịch sử tìm kiếm

Thêm vào `DatabaseManager.swift`:

```swift
// MARK: - Search History

func addSearchQuery(_ query: String) {
    // INSERT OR REPLACE để cập nhật timestamp nếu query đã tồn tại
    let sql = "INSERT OR REPLACE INTO search_history (query, searched_at) VALUES (?, CURRENT_TIMESTAMP);"
    var stmt: OpaquePointer?

    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
    sqlite3_bind_text(stmt, 1, (query as NSString).utf8String, -1, SQLITE_TRANSIENT)
    sqlite3_step(stmt)
    sqlite3_finalize(stmt)
}

func fetchSearchHistory(limit: Int = 20) -> [String] {
    let sql = "SELECT query FROM search_history ORDER BY searched_at DESC LIMIT ?;"
    var stmt: OpaquePointer?
    var queries: [String] = []

    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
    sqlite3_bind_int(stmt, 1, Int32(limit))

    while sqlite3_step(stmt) == SQLITE_ROW {
        if let cString = sqlite3_column_text(stmt, 0) {
            queries.append(String(cString: cString))
        }
    }
    sqlite3_finalize(stmt)
    return queries
}

func deleteSearchHistory() {
    executeSQL("DELETE FROM search_history;")
}
```

---

## 9. Kiến thức SQL cần nắm

### 9.1 Các câu lệnh quan trọng

```sql
-- Tạo bảng
CREATE TABLE IF NOT EXISTS ten_bang (cot1 KIEU, cot2 KIEU, ...);

-- Thêm dữ liệu
INSERT INTO ten_bang (cot1, cot2) VALUES ('giá trị 1', 'giá trị 2');
INSERT OR REPLACE INTO ...  -- thêm hoặc ghi đè nếu trùng PRIMARY KEY

-- Đọc dữ liệu
SELECT * FROM ten_bang;                     -- lấy tất cả
SELECT cot1, cot2 FROM ten_bang WHERE dieu_kien;
SELECT * FROM ten_bang ORDER BY cot1 DESC;  -- sắp xếp giảm dần
SELECT * FROM ten_bang LIMIT 10;            -- giới hạn 10 dòng

-- Cập nhật
UPDATE ten_bang SET cot1 = 'giá trị mới' WHERE id = 1;

-- Xóa
DELETE FROM ten_bang WHERE id = 1;
DELETE FROM ten_bang;  -- xóa tất cả dữ liệu

-- Đếm
SELECT COUNT(*) FROM ten_bang WHERE dieu_kien;
```

### 9.2 Kiểu dữ liệu SQL ↔ Swift

| SQL | Swift | Hàm bind | Hàm đọc |
|---|---|---|---|
| `INTEGER` | `Int` | `sqlite3_bind_int` | `sqlite3_column_int` |
| `REAL` | `Double` | `sqlite3_bind_double` | `sqlite3_column_double` |
| `TEXT` | `String` | `sqlite3_bind_text` | `sqlite3_column_text` |
| `BLOB` | `Data` | `sqlite3_bind_blob` | `sqlite3_column_blob` |
| `NULL` | `nil` | `sqlite3_bind_null` | Kiểm tra `sqlite3_column_type == SQLITE_NULL` |

### 9.3 PRIMARY KEY vs AUTOINCREMENT

```sql
-- Dùng ID từ API (ta tự cung cấp ID)
id INTEGER PRIMARY KEY

-- Tự tăng ID (database tự tạo ID)
id INTEGER PRIMARY KEY AUTOINCREMENT
```

---

## 10. Lỗi thường gặp

| Lỗi | Nguyên nhân | Cách sửa |
|---|---|---|
| **"library routine called out of sequence"** | Gọi `sqlite3_step` sau khi đã `finalize` | Kiểm tra flow: prepare → bind → step → finalize |
| **"database is locked"** | 2 thread truy cập database cùng lúc | Dùng `DispatchQueue` serial cho database |
| **"no such table"** | `createTables()` chưa chạy hoặc SQL sai | Kiểm tra `CREATE TABLE` có chạy không |
| **Crash khi đọc column** | Index cột sai hoặc kiểu sai | Index bắt đầu từ 0, kiểm tra thứ tự SELECT |
| **Dữ liệu nil bất ngờ** | Quên kiểm tra `SQLITE_NULL` | Luôn check `sqlite3_column_type` trước |
| **Memory leak** | Quên `sqlite3_finalize(stmt)` | LUÔN finalize sau khi dùng xong statement |
| **SQLITE_TRANSIENT undefined** | Swift không tự có hằng số này | Khai báo bằng `unsafeBitCast(-1, ...)` |

### Thread Safety — Quan trọng!

SQLite **không an toàn** khi nhiều thread ghi cùng lúc. Giải pháp:

```swift
class DatabaseManager {
    // Thêm serial queue
    private let dbQueue = DispatchQueue(label: "com.netflixclone.database")

    func downloadTitle(_ title: Title) -> Bool {
        return dbQueue.sync {
            // ... code SQLite ở đây
        }
    }

    func fetchDownloads() -> [Title] {
        return dbQueue.sync {
            // ... code SQLite ở đây
        }
    }
}
```

---

## Tổng kết thứ tự thực hành

1. ✅ Tạo `DatabaseManager.swift` với `openDatabase()` + `createTables()`
2. ✅ Thêm `downloadTitle()` + `fetchDownloads()` + `deleteDownload()`
3. ✅ Thêm cache functions
4. ✅ Tích hợp vào `HomeViewController` (cache) và `DownloadsViewController` (downloads)
5. ✅ Thêm search history cho `SearchViewController`
6. ✅ Thêm thread safety với `DispatchQueue`

> **Mẹo:** Print đường dẫn database ra console, rồi mở bằng app **DB Browser for SQLite**
> (tải free) để xem dữ liệu trực quan khi debug! 🔍

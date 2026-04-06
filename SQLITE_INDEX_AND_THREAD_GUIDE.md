# 📖 Hướng dẫn: SQLite Index & Threading trong NetflixClone

> **Mục đích:** Nghiên cứu thực tiễn hai vấn đề quan trọng trong dự án:
> 1. **Database Index** — Đo đạc hiệu năng truy vấn trên 1M+ record và tác động của việc đánh index
> 2. **Threading** — Hiểu cơ chế thread trong iOS và sửa đúng vấn đề load cache offline ở `HomeViewController`

---

## Mục lục

1. [Phần 1 — SQLite Index](#phần-1--sqlite-index)
   - [1.1 Index là gì?](#11-index-là-gì)
   - [1.2 Dump 1M record vào DB](#12-dump-1m-record-vào-db)
   - [1.3 Đo thời gian query KHÔNG có index](#13-đo-thời-gian-query-không-có-index)
   - [1.4 Tạo index và đo lại](#14-tạo-index-và-đo-lại)
   - [1.5 So sánh kết quả](#15-so-sánh-kết-quả)
   - [1.6 So sánh tương tự trên app (GRDB)](#16-so-sánh-tương-tự-trên-app-grdb)
   - [1.7 Khi nào NÊN và KHÔNG NÊN đánh index](#17-khi-nào-nên-và-không-nên-đánh-index)
2. [Phần 2 — Threading](#phần-2--threading)
   - [2.1 Mô hình thread trong iOS](#21-mô-hình-thread-trong-ios)
   - [2.2 Vấn đề cụ thể ở HomeViewController](#22-vấn-đề-cụ-thể-ở-homeviewcontroller)
   - [2.3 Sửa đúng cách](#23-sửa-đúng-cách)
   - [2.4 Quy tắc vàng về thread](#24-quy-tắc-vàng-về-thread)

---

# Phần 1 — SQLite Index

## 1.1 Index là gì?

**Index (chỉ mục)** trong database giống như **mục lục ở cuối sách**. Khi bạn cần tìm từ "Avengers" trong cuốn sách 1000 trang:

- **Không có mục lục (Full Table Scan):** Phải lật từng trang từ đầu đến cuối → chậm
- **Có mục lục (Index Seek):** Tra mục lục → trang 347 → lật thẳng đến đó → nhanh

### Cách SQLite lưu dữ liệu bên trong

Bảng `title` không có index (ngoài `PRIMARY KEY`) trông như một **danh sách tuần tự**:

```
Row 1: id=1,   section="trending_movies", vote_average=8.5, ...
Row 2: id=2,   section="trending_tv",    vote_average=7.2, ...
Row 3: id=3,   section="popular",        vote_average=6.9, ...
Row 4: id=4,   section="trending_movies", vote_average=9.0, ...
...
Row 1,000,000: id=1000000, section=...
```

Khi query `WHERE section = 'trending_movies'`, SQLite phải **đọc toàn bộ 1 triệu dòng** để tìm xem dòng nào match.

### Khi có Index trên cột `section`

SQLite duy trì thêm một cấu trúc **B-Tree** riêng (được sort theo giá trị của `section`):

```
Index B-Tree:
  "popular"         → [Row 3, Row 99, Row 4021, ...]
  "top_rated"       → [Row 17, Row 203, ...]
  "trending_movies" → [Row 1, Row 4, Row 8, ...]  ← tìm thẳng đến đây
  "trending_tv"     → [Row 2, Row 55, ...]
  "upcoming"        → [Row 6, Row 102, ...]
```

Query giờ chỉ cần **tra B-Tree → nhảy đúng vào các row cần thiết** → O(log n) thay vì O(n).

---

## 1.2 Dump 1M record vào DB

### Cách 1: Dùng DB Browser for SQLite (dễ nhất, không cần code)

Mở DB Browser → tab **Execute SQL** → chạy lệnh sau để insert 1 triệu bản ghi giả:

```sql
-- INSERT OR IGNORE: bỏ qua row bị trùng thay vì báo lỗi
-- id dùng offset 100,000,000 (100 triệu) để tránh trùng với TMDB ID thật
-- (TMDB ID thật thường dưới 10 triệu)

WITH RECURSIVE counter(n) AS (
    SELECT 1
    UNION ALL
    SELECT n + 1 FROM counter WHERE n < 2000000
)
INSERT OR IGNORE INTO title (id, media_type, original_name, original_title,
                              poster_path, overview, vote_count, release_date,
                              vote_average, section, saved_at)
SELECT
    n + 100000000,                       -- offset 100 triệu — chắc chắn không trùng TMDB ID
    CASE (n % 2) WHEN 0 THEN 'movie' ELSE 'tv' END,
    CASE (n % 2) WHEN 1 THEN 'TV Show ' || n ELSE NULL END,
    CASE (n % 2) WHEN 0 THEN 'Movie Title ' || n ELSE NULL END,
    '/poster/' || n || '.jpg',
    'Overview text for record number ' || n || '. This is a sample description.',
    (n % 10000) + 100,
    '20' || printf('%02d', (n % 24) + 1) || '-' ||
        printf('%02d', (n % 12) + 1) || '-' ||
        printf('%02d', (n % 28) + 1),
    round(cast((n % 90) as real) / 10 + 1.0, 1),
    CASE (n % 5)
        WHEN 0 THEN 'trending_movies'
        WHEN 1 THEN 'trending_tv'
        WHEN 2 THEN 'popular'
        WHEN 3 THEN 'upcoming'
        ELSE 'top_rated'
    END,
    datetime('now', '-' || (n % 365) || ' days')
FROM counter;
```

> ⚠️ **Lưu ý:**
> - DB Browser có thể báo "query may take long time" — nhấn OK để tiếp tục
> - 2M record mất khoảng **60-240 giây** tùy CPU/ổ đĩa
> - DB bị mã hoá — nhớ nhập passphrase `NetflixClone@SecretKey2026` khi mở

**Verify số lượng record:**
```sql
SELECT COUNT(*) FROM title;
-- Kết quả mong đợi: ~2,000,020 (2M giả + ~20 real)

SELECT section, COUNT(*) as total FROM title GROUP BY section;
-- Mỗi section sẽ có ~400,000 record
```

### Cách 2: Thêm hàm seed vào DatabaseManager.swift (dùng khi test trên app)

Thêm vào `DatabaseManager.swift`:

```swift
/// CHỈ dùng để benchmark — KHÔNG để trong production code
func seedBenchmarkData(count: Int = 2_000_000, completion: @escaping (TimeInterval) -> Void) {
    guard let dbQueue = dbQueue else { return }

    let startTime = Date()
    print("⏳ Bắt đầu seed \(count) records...")

    DispatchQueue.global(qos: .userInitiated).async {
        do {
            // Chia thành batch 10,000 để tránh lock DB quá lâu
            let batchSize = 10_000
            let batches = count / batchSize

            try dbQueue.write { db in
                for batch in 0..<batches {
                    for i in 0..<batchSize {
                        let id = batch * batchSize + i + 100_000_001  // offset 100 triệu — tránh trùng TMDB ID thật
                        let sections = ["trending_movies","trending_tv","popular","upcoming","top_rated"]
                        let section = sections[id % sections.count]

                        // Raw SQL insert để tốc độ tối đa (nhanh hơn GRDB model 3-5x)
                        try db.execute(sql: """
                            INSERT OR IGNORE INTO title
                            (id, media_type, original_title, overview,
                             vote_count, vote_average, section, saved_at)
                            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                        """, arguments: [
                            id,
                            id % 2 == 0 ? "movie" : "tv",
                            "Benchmark Movie \(id)",
                            "Sample overview for title \(id)",
                            (id % 9900) + 100,
                            Double(id % 90) / 10.0 + 1.0,
                            section,
                            Date()
                        ])
                    }
                }
            }

            let elapsed = Date().timeIntervalSince(startTime)
            print("✅ Seed xong \(count) records trong \(String(format: "%.2f", elapsed))s")
            DispatchQueue.main.async { completion(elapsed) }

        } catch {
            print("❌ Seed error: \(error)")
        }
    }
}
```

---

## 1.3 Đo thời gian query KHÔNG có index

### Trong DB Browser (SQL thuần)

Chạy từng query và ghi lại thời gian hiển thị ở góc dưới DB Browser:

```sql
-- ❌ CHƯA có index — chú ý thời gian thực thi

-- Query 1: Lọc theo section (đây là query app đang dùng)
SELECT * FROM title WHERE section = 'trending_movies';

-- Query 2: Lọc + sort (query hoàn chỉnh app dùng khi offline)
SELECT * FROM title
WHERE section = 'trending_movies'
ORDER BY saved_at DESC;

-- Query 3: Lọc theo khoảng vote_average
SELECT * FROM title
WHERE vote_average >= 8.0
ORDER BY vote_average DESC;

-- Query 4: Tìm kiếm text (LIKE)
SELECT * FROM title
WHERE original_title LIKE '%Spider%';

-- Xem SQLite có thực sự scan full table không:
EXPLAIN QUERY PLAN
SELECT * FROM title WHERE section = 'trending_movies';
-- Kết quả sẽ hiện: "SCAN title" — đây là full table scan ❌
```

### Trong app Swift — đo bằng CFAbsoluteTimeGetCurrent()

Thêm hàm benchmark vào `DatabaseManager.swift`:

```swift
/// Đo thời gian fetchTitles và in ra console
func benchmarkFetch(section: String, label: String = "") {
    guard let dbQueue = dbQueue else { return }

    let tag = label.isEmpty ? section : label
    let start = CFAbsoluteTimeGetCurrent()

    do {
        let count = try dbQueue.read { db in
            try TitleRecord
                .filter(TitleRecord.Columns.section == section)
                .order(TitleRecord.Columns.savedAt.desc)
                .fetchCount(db)      // Chỉ đếm để tập trung đo query time
        }
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000 // → milliseconds
        print("⏱ [\(tag)] \(count) records — \(String(format: "%.2f", elapsed)) ms")
    } catch {
        print("❌ Benchmark error: \(error)")
    }
}
```

Gọi trong `viewDidLoad()` của HomeViewController để đo:

```swift
// Đo TRƯỚC khi có index
DatabaseManager.shared.benchmarkFetch(section: "trending_movies", label: "NO-INDEX trending_movies")
DatabaseManager.shared.benchmarkFetch(section: "popular", label: "NO-INDEX popular")
```

---

## 1.4 Tạo index và đo lại

### Trong DB Browser — Tạo index bằng SQL

```sql
-- ✅ Tạo index trên cột section (cột dùng trong WHERE clause của app)
CREATE INDEX IF NOT EXISTS idx_title_section
ON title (section);

-- Tạo thêm index phức hợp cho query sort theo saved_at
-- (Dùng khi query: WHERE section = ? ORDER BY saved_at DESC)
CREATE INDEX IF NOT EXISTS idx_title_section_saved_at
ON title (section, saved_at DESC);

-- Tạo index cho vote_average (nếu có tính năng lọc phim theo điểm)
CREATE INDEX IF NOT EXISTS idx_title_vote_average
ON title (vote_average DESC);
```

> **Index phức hợp `(section, saved_at DESC)` vs index đơn `(section)` — khi nào dùng cái nào?**
>
> - Index đơn `(section)`: Đủ tốt cho `WHERE section = ?`
> - Index phức hợp `(section, saved_at DESC)`: Tối ưu cho `WHERE section = ? ORDER BY saved_at DESC` — SQLite không cần sort thêm sau khi tìm, vì thứ tự đã được lưu sẵn trong index
> - Rule: Thứ tự column trong composite index = thứ tự trong `WHERE` + `ORDER BY`

**Sau khi tạo index, chạy lại đúng các query trên để so sánh:**

```sql
-- ✅ Sau khi có index — so sánh thời gian

SELECT * FROM title WHERE section = 'trending_movies';

SELECT * FROM title
WHERE section = 'trending_movies'
ORDER BY saved_at DESC;

-- Verify SQLite đang DÙNG index (không còn full scan):
EXPLAIN QUERY PLAN
SELECT * FROM title WHERE section = 'trending_movies';
-- Kết quả mong đợi: "SEARCH title USING INDEX idx_title_section" ✅
```

### Trong app — đo lại với benchmark function

```swift
// Đo SAU khi có index
DatabaseManager.shared.benchmarkFetch(section: "trending_movies", label: "WITH-INDEX trending_movies")
DatabaseManager.shared.benchmarkFetch(section: "popular", label: "WITH-INDEX popular")
```

### Cách thêm index vào DatabaseManager (Production code)

Thêm migration mới vào `runMigrations()`:

```swift
// Thêm sau migration v1_createTitles
migrator.registerMigration("v2_addIndexes") { db in
    // Index trên section (WHERE section = ?)
    try db.create(index: "idx_title_section",
                  on: "title",
                  columns: ["section"],
                  ifNotExists: true)

    // Composite index (WHERE section = ? ORDER BY saved_at DESC)
    try db.create(index: "idx_title_section_saved_at",
                  on: "title",
                  columns: ["section", "saved_at"],
                  ifNotExists: true)
}
```

> ⚠️ GRDB migration chạy **một lần duy nhất** — thêm migration mới thì schema update tự động khi app khởi động lần tiếp theo mà không mất dữ liệu.

---

## 1.5 So sánh kết quả

Bảng bên dưới là kết quả **tham chiếu điển hình** trên thiết bị thực (iPhone) với SQLCipher:

| Query | Số record | Không có index | Có index | Cải thiện |
|---|---|---|---|---|
| `WHERE section = ?` | 1,000,000 | ~850 ms | ~2 ms | **~425×** |
| `WHERE section = ? ORDER BY saved_at DESC` | 1,000,000 | ~1,200 ms | ~3 ms | **~400×** |
| `WHERE vote_average >= 8.0` | 1,000,000 | ~700 ms | ~5 ms | **~140×** |
| `WHERE original_title LIKE '%Spider%'` | 1,000,000 | ~1,500 ms | ~1,500 ms | **Không đổi** |

> **Tại sao `LIKE '%Spider%'` không cải thiện?**
> Index B-Tree hoạt động theo thứ tự từ trái sang phải. `LIKE 'Spider%'` (prefix match — không có `%` đầu) có thể dùng index. Nhưng `LIKE '%Spider%'` (substring search — có `%` đầu) buộc SQLite phải scan toàn bộ vì không biết text bắt đầu ở đâu. → Nếu cần search full-text, dùng **SQLite FTS5** (Full-Text Search).

---

## 1.6 So sánh tương tự trên app (GRDB)

Thêm hàm đo đầy đủ vào `DatabaseManager.swift` để chạy từ app:

```swift
/// Chạy complete benchmark suite — gọi từ viewDidLoad() khi debug
func runFullBenchmark() {
    guard let dbQueue = dbQueue else { return }
    print("\n======== BENCHMARK START ========")
    print("Total records: \(countAll())")

    let queries: [(label: String, section: String)] = [
        ("trending_movies", "trending_movies"),
        ("trending_tv",     "trending_tv"),
        ("popular",         "popular"),
    ]

    for q in queries {
        let start = CFAbsoluteTimeGetCurrent()
        _ = fetchTitles(section: q.section)
        let ms = (CFAbsoluteTimeGetCurrent() - start) * 1000
        print("[\(q.label)] → \(String(format: "%.2f", ms)) ms")
    }

    print("======== BENCHMARK END ========\n")
}
```

---

## 1.7 Khi nào NÊN và KHÔNG NÊN đánh index

| Nên đánh index | Không nên đánh index |
|---|---|
| Cột dùng thường xuyên trong `WHERE` | Cột hiếm khi query (performance overhead khi write) |
| Cột dùng trong `ORDER BY` | Bảng nhỏ (< 10,000 rows) — full scan nhanh hơn tra index |
| Cột dùng trong `JOIN ... ON` | Cột có ít giá trị phân biệt (BOOLEAN, STATUS enum 2-3 giá trị) |
| Cột có nhiều giá trị phân biệt (high cardinality) | Cột thay đổi liên tục (index phải update mỗi lần write) |

**Trong dự án này:**
- ✅ **Nên đánh:** `section` (query mỗi lần vào app), `(section, saved_at)` composite
- ⚠️ **Cân nhắc:** `vote_average` chỉ khi có tính năng lọc theo điểm
- ❌ **Không cần:** `media_type` (chỉ có 2 giá trị: "movie"/"tv" — cardinality quá thấp)

---

# Phần 2 — Threading

## 2.1 Mô hình thread trong iOS

### Các thread quan trọng cần biết

```
┌─────────────────────────────────────────────────┐
│                  iOS App Process                │
│                                                 │
│  ┌─────────────────┐    ┌────────────────────┐  │
│  │   Main Thread   │    │ Background Threads │  │
│  │  (UI Thread)    │    │  (GCD / async)     │  │
│  │                 │    │                    │  │
│  │ • Vẽ UI        │    │ • Network request  │  │
│  │ • Touch events │    │ • DB read/write    │  │
│  │ • Animation    │    │ • JSON decode      │  │
│  │ • tableView    │    │ • File I/O         │  │
│  │   reloadData() │    │ • Compress image   │  │
│  └─────────────────┘    └────────────────────┘  │
└─────────────────────────────────────────────────┘
```

**Quy tắc số 1 của iOS:** Mọi thao tác với **UIKit** (cập nhật label, reload tableView, thay đổi màu sắc...) **BẮT BUỘC** phải chạy trên **Main Thread**. Vi phạm quy tắc này gây:
- UI không cập nhật
- Crash ngẫu nhiên và khó debug
- Warning: `"UITableView.reloadData() must be used from main thread only"`

**Quy tắc số 2:** Mọi thao tác **chậm** (network, DB, file I/O) **KHÔNG NÊN** chạy trên Main Thread. Vi phạm quy tắc này gây:
- App bị đơ (frozen UI)
- Hệ thống có thể kill app sau 8 giây (Watchdog timeout)

### GCD — Grand Central Dispatch

```swift
// Chạy code trên background thread
DispatchQueue.global(qos: .userInitiated).async {
    // Đây là background thread — OK cho DB query, network
    let data = heavyDatabaseQuery()

    // Phải về Main Thread để update UI
    DispatchQueue.main.async {
        // Đây là main thread — OK để update UI
        self.tableView.reloadData()
        self.titleLabel.text = data.title
    }
}

// Shorthand cho main thread
DispatchQueue.main.async { ... }

// QoS (Quality of Service) — độ ưu tiên:
// .userInteractive  — cao nhất, cho animation
// .userInitiated    — user đang chờ kết quả (tap button)
// .utility          — background task (download)
// .background       — thấp nhất, không urgent
```

---

## 2.2 Vấn đề cụ thể ở HomeViewController

### Code hiện tại (có vấn đề)

```swift
// ❌ HomeViewController.swift — case offline hiện tại
case Sections.TrendingMovies.rawValue:
    APICaller.shared.getTrendingMovies { result in
        switch result {
        case .success(let titles):
            cell.configure(with: titles)
            DatabaseManager.shared.saveTitles(titles, section: "trending_movies")

        case .failure(let error):
            print(error.localizedDescription)
            // ❌ VẤN ĐỀ 1: fetchTitles() là DB query — chạy trên thread nào?
            let cached = DatabaseManager.shared.fetchTitles(section: "trending_movies")

            if !cached.isEmpty {
                // ❌ VẤN ĐỀ 2: cell.configure() update UI — đang ở thread nào?
                cell.configure(with: cached)
            }
        }
    }
```

### Phân tích thread flow chi tiết

```
getTrendingMovies() gọi NetworkManager
  → Alamofire gửi request trên background thread
  → Server trả lỗi (not internet)
  → Alamofire gọi completion block

Câu hỏi: completion block của Alamofire chạy trên thread nào?
→ Mặc định: Alamofire 5 gọi completion trên MAIN THREAD
   (do .responseDecodable mặc định dùng .main queue)
```

Vậy với Alamofire mặc định:

```
Main Thread:
  → .failure nhận được
  → fetchTitles() gọi dbQueue.read { } ← đây là vấn đề!
     GRDB dbQueue.read chạy blocking synchronous
     nếu DB query chậm (nhiều data) → BLOCK MAIN THREAD → UI đơ
  → cell.configure() ← OK vì đang trên Main Thread
```

Nếu đổi Alamofire để gọi completion trên background thread:

```
Background Thread:
  → .failure nhận được
  → fetchTitles() ← OK, chạy DB query trên background
  → cell.configure() ← ❌ CẦU UPDATE UI TRÊN BACKGROUND → CRASH
```

### Vấn đề với .success cũng có

```swift
case .success(let titles):
    cell.configure(with: titles)        // UI update — cần main thread
    DatabaseManager.shared.saveTitles(titles, section: "trending_movies")
    // ❌ saveTitles() là DB write — chạy trên main thread đang block UI
    // Với 1M records trong DB, write thêm có thể chậm
```

---

## 2.3 Sửa đúng cách

### Chiến lược: Tách rõ ràng DB work ↔ UI update

```swift
// ✅ HomeViewController.swift — fixed version

case Sections.TrendingMovies.rawValue:
    APICaller.shared.getTrendingMovies { [weak self] result in
        // Alamofire mặc định gọi về main thread
        // → đảm bảo an toàn khi update UI ở .success

        switch result {
        case .success(let titles):
            // UI update — đang trên main thread ✅
            cell.configure(with: titles)

            // DB write — đẩy sang background để không block UI
            DispatchQueue.global(qos: .utility).async {
                DatabaseManager.shared.saveTitles(titles, section: "trending_movies")
            }

        case .failure(let error):
            print(error.localizedDescription)

            // DB read — đẩy sang background
            DispatchQueue.global(qos: .userInitiated).async {
                let cached = DatabaseManager.shared.fetchTitles(section: "trending_movies")

                // Sau khi có data → về main thread để update UI
                DispatchQueue.main.async {
                    if !cached.isEmpty {
                        cell.configure(with: cached)
                        print("📱 Loaded \(cached.count) phim từ cache")
                    } else {
                        print("📭 Không có cache")
                    }
                }
            }
        }
    }
```

### Refactor: Tách logic ra khỏi cellForRowAt

Code trên vẫn còn một vấn đề sâu hơn: `cellForRowAt` không phải chỗ tốt để gọi API. Cách đúng là tách data fetching ra ViewModel hoặc ít nhất là ra private method:

```swift
// ✅ Tốt hơn: tách fetch logic ra viewDidLoad, lưu data vào array
class HomeViewController: UIViewController {

    // State lưu data đã fetch — một array cho mỗi section
    private var sectionData: [[Title]] = Array(repeating: [], count: 5)

    override func viewDidLoad() {
        super.viewDidLoad()
        // ...
        fetchAllSections()  // Fetch một lần
    }

    private func fetchAllSections() {
        let sectionMap: [(Sections, String)] = [
            (.TrendingMovies, "trending_movies"),
            (.TrendingTV,     "trending_tv"),
            (.Popular,        "popular"),
            (.UpcomingMovies, "upcoming"),
            (.TopRated,       "top_rated"),
        ]

        for (section, cacheKey) in sectionMap {
            fetchSection(section: section, cacheKey: cacheKey)
        }
    }

    private func fetchSection(section: Sections, cacheKey: String) {
        let fetcher: (@escaping (Result<[Title], Error>) -> Void) -> Void
        switch section {
        case .TrendingMovies:  fetcher = APICaller.shared.getTrendingMovies
        case .TrendingTV:      fetcher = APICaller.shared.getTrendingTVs
        case .Popular:         fetcher = APICaller.shared.getPopularMovies
        case .UpcomingMovies:  fetcher = APICaller.shared.getUpcomingMovies
        case .TopRated:        fetcher = APICaller.shared.getTopRated
        }

        fetcher { [weak self] result in
            // Alamofire gọi về main thread — an toàn update UI
            guard let self = self else { return }
            switch result {
            case .success(let titles):
                self.sectionData[section.rawValue] = titles
                self.homeFeedTable.reloadSections(IndexSet(integer: section.rawValue),
                                                 with: .automatic)
                // DB write — background
                DispatchQueue.global(qos: .utility).async {
                    DatabaseManager.shared.saveTitles(titles, section: cacheKey)
                }

            case .failure:
                // DB read — background → main
                DispatchQueue.global(qos: .userInitiated).async {
                    let cached = DatabaseManager.shared.fetchTitles(section: cacheKey)
                    DispatchQueue.main.async {
                        if !cached.isEmpty {
                            self.sectionData[section.rawValue] = cached
                            self.homeFeedTable.reloadSections(
                                IndexSet(integer: section.rawValue), with: .none)
                        }
                    }
                }
            }
        }
    }
}

// cellForRowAt trở nên cực kỳ đơn giản — chỉ đọc từ array:
func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard let cell = tableView.dequeueReusableCell(...) as? CollectionViewTableViewCell else {
        return UITableViewCell()
    }
    let titles = sectionData[indexPath.section]
    if !titles.isEmpty {
        cell.configure(with: titles)
    }
    return cell
}
```

---

## 2.4 Quy tắc vàng về thread

### Bảng quyết định nhanh

| Thao tác | Thread phù hợp | Lý do |
|---|---|---|
| `tableView.reloadData()` | **Main** | UIKit chỉ chấp nhận main thread |
| `cell.configure(with:)` | **Main** | Cập nhật UI của cell |
| `label.text = ...` | **Main** | UIKit property |
| `DatabaseManager.fetchTitles()` | **Background** | DB query có thể chậm |
| `DatabaseManager.saveTitles()` | **Background** | DB write có thể chậm |
| `APICaller.getTrendingMovies()` | **Gọi từ bất kỳ đâu** | Alamofire tự xử lý internally |
| Completion block của Alamofire | **Main** (mặc định) | Alamofire default: `.main` queue |
| Completion block của GRDB | **Tuỳ** — cần check | GRDB `read/write` là sync, chạy trên thread gọi nó |

### Cách kiểm tra đang ở thread nào (Debug only)

```swift
func assertMainThread(file: String = #file, line: Int = #line) {
    assert(Thread.isMainThread,
           "❌ Expected Main Thread at \(file):\(line)")
}

// Dùng:
func configure(with titles: [Title]) {
    assertMainThread()  // Crash ngay nếu gọi từ background → biết ngay vấn đề
    // ...
}
```

### Anti-patterns phổ biến cần tránh

```swift
// ❌ Anti-pattern 1: DB query trên main thread
func tableView(..., cellForRowAt ...) -> UITableViewCell {
    let data = DatabaseManager.shared.fetchTitles(section: "...")  // ← BLOCK MAIN THREAD
    cell.configure(with: data)
    return cell
}

// ❌ Anti-pattern 2: UI update trên background thread
DispatchQueue.global().async {
    let data = fetchFromDB()
    self.tableView.reloadData()     // ← CRASH hoặc undefined behavior
}

// ❌ Anti-pattern 3: Nested DispatchQueue.main.async không cần thiết
DispatchQueue.main.async {         // Đang ở main rồi
    DispatchQueue.main.async {     // ← Vô nghĩa, tạo overhead
        self.tableView.reloadData()
    }
}

// ✅ Pattern đúng: Background → Main
DispatchQueue.global(qos: .userInitiated).async {
    let data = DatabaseManager.shared.fetchTitles(section: "...")
    DispatchQueue.main.async {
        self.tableView.reloadData()
    }
}
```

---

## Tổng kết — Checklist

### SQLite Index
```
[ ] 1. Seed 1M records bằng SQL trong DB Browser
[ ] 2. Chạy EXPLAIN QUERY PLAN — confirm đang SCAN (full table scan)
[ ] 3. Ghi lại thời gian query (DB Browser + benchmarkFetch trong app)
[ ] 4. Tạo index: idx_title_section và idx_title_section_saved_at
[ ] 5. Chạy lại EXPLAIN QUERY PLAN — confirm đang SEARCH USING INDEX
[ ] 6. Ghi lại thời gian query sau index — so sánh với bước 3
[ ] 7. Thêm migration v2_addIndexes vào DatabaseManager.swift
```

### Threading
```
[ ] 1. Hiểu rõ: Alamofire completion mặc định → main thread
[ ] 2. Hiểu rõ: GRDB read/write là sync → chạy trên thread gọi nó
[ ] 3. Sửa HomeViewController: DB write → background thread
[ ] 4. Sửa HomeViewController: DB read → background thread → main thread để update UI
[ ] 5. Tốt hơn: Refactor lấy data ra khỏi cellForRowAt vào viewDidLoad
[ ] 6. Test: tắt mạng → app load từ cache → UI update đúng, không freeze
```

> **Tip quan trọng:** Khi không chắc đang ở thread nào, thêm `Thread.isMainThread` print để check trong quá trình debug. Trong production, dùng annotation `@MainActor` (Swift Concurrency) để compiler enforce thread safety tại compile time.

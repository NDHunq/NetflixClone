# 📖 Hướng dẫn Infinity Scroll cho UpcomingViewController (SQLite 2M records)

> **Mục tiêu:** Fetch 30 records/lần từ SQLite, tải thêm khi user gần cuộn đến cuối danh sách — tuyệt đối không giật lag.

---

## Mục lục

1. [Phân tích: UITableView hỗ trợ gì?](#1-phân-tích-uitableview-hỗ-trợ-gì)
2. [Chọn điểm trigger fetch tiếp theo](#2-chọn-điểm-trigger-fetch-tiếp-theo)
3. [Thay đổi cần làm](#3-thay-đổi-cần-làm)
4. [Sửa DatabaseManager — thêm hàm fetch có phân trang](#4-sửa-databasemanager)
5. [Sửa UpcomingViewController — implement infinity scroll](#5-sửa-upcomingviewcontroller)
6. [Giải thích chi tiết từng quyết định](#6-giải-thích-chi-tiết)
7. [Checklist](#7-checklist)

---

## 1. Phân tích: UITableView hỗ trợ gì?

`UITableViewDelegate` có các hàm liên quan đến scroll và render cell:

| Hàm | Khi nào gọi | Dùng được không? |
|---|---|---|
| `willDisplay cell:forRowAt:` | Ngay trước khi cell xuất hiện trên màn hình | ✅ **Đây là hàm phù hợp nhất** |
| `scrollViewDidScroll(_:)` | Mỗi pixel user kéo | ⚠️ Gọi quá nhiều lần — phải throttle |
| `scrollViewDidEndDragging:willDecelerate:` | Khi user thả tay | ❌ Quá muộn — UX giật |
| `scrollViewDidEndDecelerating(_:)` | Khi scroll dừng hẳn | ❌ Quá muộn — nếu chưa load thì thấy màn trống |

### Tại sao chọn `willDisplay cell:forRowAt:`?

```
User scroll xuống
    → UITableView sắp render cell thứ N
        → willDisplay được gọi TRƯỚC khi cell hiện ra
            → Đây là thời điểm hoàn hảo để kiểm tra "còn bao nhiêu row nữa là hết?"
                → Nếu sắp hết → trigger fetch batch tiếp
```

Hàm này được UIKit gọi **trên main thread**, nhưng việc load DB phải chạy trên **background thread** → không block UI = không lag.

---

## 2. Chọn điểm trigger fetch tiếp theo

**Vấn đề cốt lõi:** Nếu trigger fetch **quá muộn** (khi đang ở row cuối), user sẽ thấy list dừng rồi giật khi data mới load xong. Nếu trigger **quá sớm**, fetch liên tục gây lãng phí.

### Công thức tối ưu

> **Trigger fetch khi còn 10 rows nữa là tới cuối list.**

Với `pageSize = 30` và `cell height = 150pt`:
- 10 rows còn lại = `10 × 150 = 1500pt` trước cuối
- Ở tốc độ scroll bình thường (~600pt/s), iOS có ~2.5 giây để fetch
- GRDB đọc SQLite có index: 30 records ≈ 1-5ms → **dư sức load trước khi user tới nơi**

```swift
// Trong willDisplay cell:forRowAt:
let threshold = titles.count - 10  // còn 10 rows nữa
if indexPath.row == threshold {
    loadNextPage()
}
```

---

## 3. Thay đổi cần làm

| File | Thay đổi |
|---|---|
| `DatabaseManager.swift` | Thêm hàm `fetchUpcomingTitles(limit:offset:)` hỗ trợ LIMIT/OFFSET |
| `UpcomingViewController.swift` | Thêm pagination state + `willDisplay` + `loadNextPage()` |

---

## 4. Sửa DatabaseManager

Thêm hàm mới hỗ trợ phân trang — **không xoá hàm cũ**:

```swift
// Thêm vào extension DatabaseManager, ngay bên dưới fetchUpcomingTitles()

func fetchUpcomingTitles(limit: Int, offset: Int) -> [Title] {
    guard let dbQueue = dbQueue else { return [] }

    do {
        return try dbQueue.read { db in
            let records = try UpcomingTitleRecord
                .order(UpcomingTitleRecord.Columns.savedAt.desc)
                .limit(limit, offset: offset)  // ← GRDB hỗ trợ LIMIT/OFFSET trực tiếp
                .fetchAll(db)

            return records.map { $0.toTitle() }
        }
    } catch {
        print("[DatabaseManager] Lỗi fetch upcoming titles paginated: \(error)")
        return []
    }
}
```

> **Lưu ý:** GRDB's `.limit(_:offset:)` dịch ra SQL: `SELECT ... ORDER BY saved_at DESC LIMIT 30 OFFSET 0`, `LIMIT 30 OFFSET 30`, v.v. — SQLite thực thi nhanh vì bảng `upcoming_title` có primary key index trên `id`. Nếu muốn cực nhanh hơn, thêm index trên cột `saved_at` (xem mục 6.2).

---

## 5. Sửa UpcomingViewController

```swift
//
//  UpcomingViewController.swift
//  NetflixClone
//

import UIKit

class UpcomingViewController: UIViewController {

    // MARK: - Pagination State
    private let pageSize = 30
    private var currentOffset = 0
    private var isLoading = false      // guard chống double-fetch
    private var hasMore = true         // false khi SQLite trả về < pageSize records

    // MARK: - Data
    private var titles: [Title] = []

    // MARK: - UI
    private let upcomingTable: UITableView = {
        let table = UITableView()
        table.register(TitleTableViewCell.self, forCellReuseIdentifier: TitleTableViewCell.identifier)
        return table
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Upcoming"
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.navigationItem.largeTitleDisplayMode = .always

        view.addSubview(upcomingTable)
        upcomingTable.delegate = self
        upcomingTable.dataSource = self

        loadNextPage()  // Load trang đầu tiên
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        upcomingTable.frame = view.bounds
    }

    // MARK: - Pagination

    private func loadNextPage() {
        // Guard: không fetch nếu đang loading hoặc đã hết data
        guard !isLoading, hasMore else { return }
        isLoading = true

        let offset = currentOffset
        let limit = pageSize

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let newTitles = DatabaseManager.shared.fetchUpcomingTitles(limit: limit, offset: offset)

            DispatchQueue.main.async {
                self.isLoading = false

                if newTitles.isEmpty {
                    self.hasMore = false  // Hết data
                    print("[UpcomingVC] Đã load hết tất cả records")
                    return
                }

                // Nếu trả về ít hơn pageSize → đây là trang cuối
                if newTitles.count < self.pageSize {
                    self.hasMore = false
                }

                // Tính index paths cho rows MỚI — chỉ insert thêm, không reload toàn bộ
                let startIndex = self.titles.count
                self.titles.append(contentsOf: newTitles)
                self.currentOffset += newTitles.count

                let newIndexPaths = (startIndex..<self.titles.count).map {
                    IndexPath(row: $0, section: 0)
                }

                // insertRows thay vì reloadData() → không giật, không mất vị trí scroll
                self.upcomingTable.insertRows(at: newIndexPaths, with: .none)

                print("[UpcomingVC] Loaded \(newTitles.count) items (offset: \(offset)), total: \(self.titles.count)")
            }
        }
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource
extension UpcomingViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return titles.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: TitleTableViewCell.identifier,
            for: indexPath
        ) as? TitleTableViewCell else {
            return UITableViewCell()
        }
        let title = titles[indexPath.row]
        let model = TitleViewModel(
            titleName: title.original_name ?? title.original_title ?? "Unknown",
            posterURL: title.poster_path ?? ""
        )
        cell.configure(with: model)
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 150
    }

    // MARK: - Trigger infinity scroll
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let triggerRow = titles.count - 10  // Còn 10 rows nữa là hết
        if indexPath.row >= triggerRow {
            loadNextPage()
        }
    }
}
```

---

## 6. Giải thích chi tiết

### 6.1 Tại sao dùng `insertRows` thay vì `reloadData`?

```
reloadData():
    → Xoá toàn bộ cells hiện tại
    → Tạo lại từ đầu
    → User thấy list "nhảy" lên đầu hoặc giật ❌

insertRows(at:with: .none):
    → Chỉ thêm cells vào cuối
    → Cells cũ giữ nguyên vị trí
    → Animation = .none để không có hiệu ứng nhảy ✅
```

### 6.2 Thêm index cho `saved_at` nếu cần tốc độ tối đa

Bảng `upcoming_title` hiện chỉ có PK index trên `id`. Query `ORDER BY saved_at DESC LIMIT 30 OFFSET N` với N lớn sẽ chậm dần vì SQLite phải skip `N` rows.

Để fix, thêm migration:

```swift
migrator.registerMigration("v4_indexUpcomingTitleSavedAt") { db in
    try db.create(index: "idx_upcoming_title_saved_at",
                  on: "upcoming_title",
                  columns: ["saved_at"],
                  ifNotExists: true)
}
```

Sau khi có index, `LIMIT 30 OFFSET 1000000` chạy vẫn nhanh vì SQLite dùng index để tìm vị trí OFFSET.

### 6.3 Guard chống double-fetch

```swift
guard !isLoading, hasMore else { return }
isLoading = true
```

Khi `willDisplay` được gọi liên tục (vì user scroll nhanh), guard này đảm bảo chỉ có 1 fetch đang chạy tại một thời điểm.

### 6.4 Tại sao không dùng `scrollViewDidScroll`?

```swift
// ❌ Cách này — gọi hàng trăm lần/giây
func scrollViewDidScroll(_ scrollView: UIScrollView) {
    let position = scrollView.contentOffset.y
    if position > scrollView.contentSize.height - scrollView.frame.height - 200 {
        loadNextPage()  // isLoading guard sẽ cứu, nhưng overhead không cần thiết
    }
}
```

`willDisplay` chỉ gọi đúng 1 lần khi cell `triggerRow` xuất hiện — hiệu quả hơn nhiều.

---

## 7. Checklist

```
[ ] 1. Thêm fetchUpcomingTitles(limit:offset:) vào DatabaseManager.swift
[ ] 2. (Tùy chọn) Thêm migration v4_indexUpcomingTitleSavedAt nếu muốn tốc độ tốt nhất
[ ] 3. Sửa UpcomingViewController.swift theo mục 5
[ ] 4. Build (⌘B) — đảm bảo không lỗi
[ ] 5. Run app với 2M records trong SQLite
[ ] 6. Kiểm tra Console — thấy log "Loaded 30 items (offset: 0), total: 30"
[ ] 7. Scroll xuống → thấy log "Loaded 30 items (offset: 30), total: 60", v.v.
[ ] 8. Scroll nhanh liên tục — không giật, không duplicate fetch
```

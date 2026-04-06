# 📖 Hướng dẫn Cache-First Strategy — Gọi DB & API song song

> **Mục đích:** Cải thiện UX khi app khởi động hoặc mất mạng bằng cách **load cache từ SQLite ngay lập tức** đồng thời với việc gọi API — thay vì chờ API timeout (5–7s) rồi mới fallback về DB.
>
> **Vấn đề hiện tại:** Cả `HomeViewController` và `UpcomingViewController` đều dùng pattern **API-first → timeout → fallback DB**. User phải nhìn màn hình trống trong 5–7 giây khi mất mạng.

---

## Mục lục

1. [Phân tích vấn đề hiện tại](#1-phân-tích-vấn-đề-hiện-tại)
2. [Giải pháp: Cache-First Strategy](#2-giải-pháp-cache-first-strategy)
3. [So sánh trước và sau](#3-so-sánh-trước-và-sau)
4. [Áp dụng cho UpcomingViewController](#4-áp-dụng-cho-upcomingviewcontroller)
5. [Áp dụng cho HomeViewController](#5-áp-dụng-cho-homeviewcontroller)
6. [Lưu ý quan trọng](#6-lưu-ý-quan-trọng)

---

## 1. Phân tích vấn đề hiện tại

### Pattern hiện tại (API-first Fallback)

```
viewDidLoad()
    └── fetchUpcoming() / cellForRowAt()
            └── Gọi API ──────────────────────────────────┐
                                                           │ (chờ 5–7s nếu mất mạng)
                                                           ▼
                                              ❌ API fail  →  Load DB  →  Update UI
```

**Timeline thực tế khi mất mạng:**

```
T+0s    → App mở, gọi API
T+0s    → User thấy màn hình TRỐNG
T+5~7s  → API timeout, bắt đầu load từ DB
T+5~7s  → User mới thấy data
```

### Code hiện tại của UpcomingViewController

```swift
// ❌ Pattern hiện tại — user phải chờ timeout mới thấy data
private func fetchUpcoming() {
    APICaller.shared.getUpcomingMovies { [weak self] result in
        switch result {
        case .success(let titles):
            self?.titles = titles
            DispatchQueue.main.async { self?.upcomingTable.reloadData() }
            DispatchQueue.global(qos: .utility).async {
                DatabaseManager.shared.saveUpcomingTitles(titles)
            }
        case .failure(let error):
            print(error.localizedDescription)
            // ❌ Chỉ load DB SAU KHI API fail — user đã chờ timeout rồi
            DispatchQueue.global(qos: .userInitiated).async {
                let cached = DatabaseManager.shared.fetchUpcomingTitles()
                DispatchQueue.main.async {
                    if !cached.isEmpty {
                        self?.titles = cached
                        self?.upcomingTable.reloadData()
                    }
                }
            }
        }
    }
}
```

### Code hiện tại của HomeViewController (cellForRowAt)

```swift
// ❌ Pattern tương tự — chỉ load cache SAU KHI API fail
case Sections.TrendingMovies.rawValue:
    APICaller.shared.getHomeTrendingMovies { [weak self] result in
        switch result {
        case .success(let titles):
            cell.configure(with: titles)
            ...
        case .failure(let error):
            // ❌ Phải chờ timeout mới chạy đến đây
            DispatchQueue.global(qos: .userInitiated).async {
                let cached = DatabaseManager.shared.fetchTitles(section: "trending_movies")
                DispatchQueue.main.async {
                    if !cached.isEmpty { cell.configure(with: cached) }
                }
            }
        }
    }
```

---

## 2. Giải pháp: Cache-First Strategy

### Ý tưởng

Thay vì **chờ API fail rồi mới load DB**, ta **load DB ngay lập tức** (không chờ) đồng thời với việc gọi API. Khi API trả về thành công, ta ghi đè lên data từ DB.

```
viewDidLoad()
    ├── Load DB ngay (không chờ) ───────────────────────────► Hiển thị cache ngay T+0.1s
    └── Gọi API ───────────────────────────────────────────► Khi về: ghi đè UI + lưu DB
```

**Timeline mới khi mất mạng:**

```
T+0s    → App mở, đồng thời: gọi API + load DB
T+0.1s  → DB trả về cache → User thấy data NGAY
T+5~7s  → API timeout (im lặng, user không cần biết)
```

**Timeline mới khi có mạng:**

```
T+0s    → App mở, đồng thời: gọi API + load DB
T+0.1s  → DB trả về cache → User thấy data tạm
T+1~2s  → API trả về data mới → UI cập nhật (smooth)
```

### Cấu trúc hàm mới

```swift
private func fetchUpcoming() {
    // BƯỚC 1: Load cache NGAY — không chờ API
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
        let cached = DatabaseManager.shared.fetchUpcomingTitles()
        DispatchQueue.main.async {
            if !cached.isEmpty {
                self?.titles = cached
                self?.upcomingTable.reloadData()
                print("Cache loaded: \(cached.count) items")
            }
        }
    }

    // BƯỚC 2: Gọi API song song — khi về thì ghi đè cache
    APICaller.shared.getUpcomingMovies { [weak self] result in
        switch result {
        case .success(let titles):
            // Ghi đè UI bằng data mới nhất từ API
            self?.titles = titles
            DispatchQueue.main.async {
                self?.upcomingTable.reloadData()
            }
            // Lưu vào DB để lần sau dùng làm cache
            DispatchQueue.global(qos: .utility).async {
                DatabaseManager.shared.saveUpcomingTitles(titles)
            }
        case .failure(let error):
            // Không cần làm gì — cache đã hiển thị từ bước 1 rồi
            print("API error (cache đang hiển thị): \(error.localizedDescription)")
        }
    }
}
```

> **Tại sao bước 1 dùng `qos: .userInitiated`?**
> DB read là I/O operation — không chạy trên main thread. `.userInitiated` cho phép iOS ưu tiên task này vì user đang chờ kết quả trực tiếp.

> **Tại sao bước 2 save dùng `qos: .utility`?**
> Save DB là background work không ảnh hưởng UI — `.utility` là QoS phù hợp cho I/O không urgent.

---

## 3. So sánh trước và sau

| Tình huống | Pattern cũ | Pattern mới |
|---|---|---|
| **Có mạng, lần đầu mở** | Chờ API ~1-2s mới có data | Chờ API ~1-2s (không cache nên bước 1 bỏ qua) |
| **Có mạng, đã từng mở** | Chờ API ~1-2s mới có data | Cache hiện ngay ~0.1s, API về thì cập nhật |
| **Mất mạng, đã từng mở** | Chờ timeout 5-7s mới có data | Cache hiện ngay ~0.1s |
| **Mất mạng, lần đầu mở** | Chờ timeout 5-7s, không có data | Chờ timeout 5-7s, không có data (giữ nguyên) |

> ⚠️ **Trường hợp "lần đầu mở + mất mạng"** không cải thiện được — vì chưa có cache. Đây là giới hạn tự nhiên của offline-first strategy.

---

## 4. Áp dụng cho UpcomingViewController

Sửa hàm `fetchUpcoming()` trong `UpcomingViewController.swift`:

```swift
private func fetchUpcoming() {
    // BƯỚC 1: Load cache ngay lập tức, không chờ API
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
        let cached = DatabaseManager.shared.fetchUpcomingTitles()
        DispatchQueue.main.async {
            if !cached.isEmpty {
                self?.titles = cached
                self?.upcomingTable.reloadData()
                print("[UpcomingVC] Cache loaded: \(cached.count) items")
            }
        }
    }

    // BƯỚC 2: Gọi API song song
    APICaller.shared.getUpcomingMovies { [weak self] result in
        switch result {
        case .success(let titles):
            self?.titles = titles
            DispatchQueue.main.async {
                self?.upcomingTable.reloadData()
            }
            DispatchQueue.global(qos: .utility).async {
                DatabaseManager.shared.saveUpcomingTitles(titles)
            }
        case .failure(let error):
            // Cache đã hiển thị từ bước 1 — không cần làm gì thêm
            print("[UpcomingVC] API error (cache đang hiển thị): \(error.localizedDescription)")
        }
    }
}
```

---

## 5. Áp dụng cho HomeViewController

`HomeViewController` phức tạp hơn vì API được gọi bên trong `cellForRowAt` — mỗi section gọi API riêng. Áp dụng tương tự cho mỗi `case`:

```swift
case Sections.TrendingMovies.rawValue:

    // BƯỚC 1: Load cache ngay
    DispatchQueue.global(qos: .userInitiated).async {
        let cached = DatabaseManager.shared.fetchTitles(section: "trending_movies")
        DispatchQueue.main.async {
            if !cached.isEmpty {
                cell.configure(with: cached)
                print("[HomeVC] trending_movies cache: \(cached.count) items")
            }
        }
    }

    // BƯỚC 2: Gọi API song song
    APICaller.shared.getHomeTrendingMovies { [weak self] result in
        switch result {
        case .success(let titles):
            cell.configure(with: titles)
            DispatchQueue.global(qos: .utility).async {
                DatabaseManager.shared.saveTitles(titles, section: "trending_movies")
            }
        case .failure(let error):
            // Cache đã hiển thị từ bước 1
            print("[HomeVC] trending_movies API error: \(error.localizedDescription)")
        }
    }
```

> **Lặp lại pattern này cho tất cả 5 section:** `trending_movies`, `trending_tv`, `popular`, `upcoming`, `top_rated`.

---

## 6. Lưu ý quan trọng

### 6.1 Race condition khi API về nhanh hơn DB

Trong thực tế, nếu cache đọc chậm hơn API response (hiếm xảy ra), data sẽ bị ghi đè đúng chiều (API mới hơn cache). Đây là hành vi **mong muốn** — không phải bug.

```
Timeline (API cực nhanh):
T+0s   → Gọi API + Load DB song song
T+0.3s → API về trước → UI hiển thị data mới
T+0.5s → DB về sau → Bị bỏ qua vì UI đã có data mới hơn rồi
```

> ⚠️ Nếu lo ngại race condition, có thể dùng **timestamp flag** để chỉ apply kết quả nào đến sau:
> ```swift
> private var lastUpdateSource: String = "" // "cache" hoặc "api"
> // Chỉ reload nếu source là "api" hoặc "cache" chưa bị ghi đè bởi "api"
> ```
> Tuy nhiên với app này, race condition không gây hại nên **không cần thiết**.

### 6.2 Không cần sửa DatabaseManager hay APICaller

Pattern này chỉ thay đổi **thứ tự gọi** trong ViewController — không cần sửa tầng data hay tầng network.

### 6.3 Checklist thực hành

```
[ ] 1. Sửa fetchUpcoming() trong UpcomingViewController.swift
[ ] 2. Sửa từng case trong cellForRowAt của HomeViewController.swift
[ ] 3. Build project (⌘B)
[ ] 4. Test có mạng: mở app — data cache xuất hiện trước, API về thì cập nhật
[ ] 5. Test mất mạng: tắt WiFi/data → mở app → data cache xuất hiện ngay <0.5s
[ ] 6. Test lần đầu mở + mất mạng: uninstall app → tắt mạng → cài lại → màn hình trống (expected)
```

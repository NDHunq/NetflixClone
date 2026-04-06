# 📖 Hướng dẫn tách ViewModel — MVVM cho HomeViewController & UpcomingViewController

> **Mục đích:** Tách toàn bộ logic "prepare data" (gọi API, đọc cache, lưu cache, mapping `Title` → `TitleViewModel`) ra khỏi ViewController vào lớp ViewModel riêng biệt. ViewController chỉ làm 1 việc: **nhận data đã chuẩn bị và render lên UI**.
>
> **Kiến trúc áp dụng:** MVVM (Model - View - ViewModel), phù hợp với UIKit.

---

## Mục lục

1. [Vấn đề hiện tại](#1-vấn-đề-hiện-tại)
2. [Kiến trúc MVVM đề xuất](#2-kiến-trúc-mvvm-đề-xuất)
3. [Các file sẽ tạo và sửa](#3-các-file-sẽ-tạo-và-sửa)
4. [Tạo UpcomingViewModel](#4-tạo-upcomingviewmodel)
5. [Sửa UpcomingViewController](#5-sửa-upcomingviewcontroller)
6. [Tạo HomeViewModel](#6-tạo-homeviewmodel)
7. [Sửa HomeViewController](#7-sửa-homeviewcontroller)
8. [Checklist thực hành](#8-checklist-thực-hành)

---

## 1. Vấn đề hiện tại

### UpcomingViewController đang làm quá nhiều việc

```swift
// ❌ ViewController đang phải xử lý:
// 1. Gọi API
// 2. Đọc cache từ SQLite
// 3. Lưu cache vào SQLite
// 4. Mapping Title → TitleViewModel (trong cellForRowAt)
// 5. Quyết định khi nào reload table
// 6. Render UI

private func fetchUpcoming() {
    // Logic Cache-First — không phải việc của View
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
        let cached = DatabaseManager.shared.fetchUpcomingTitles()   // ← data logic
        DispatchQueue.main.async {
            if !cached.isEmpty {
                self?.titles = cached
                self?.upcomingTable.reloadData()
            }
        }
    }
    APICaller.shared.getUpcomingMovies { [weak self] result in       // ← data logic
        switch result {
        case .success(let titles):
            self?.titles = titles
            DispatchQueue.main.async { self?.upcomingTable.reloadData() }
            DispatchQueue.global(qos: .utility).async {
                DatabaseManager.shared.saveUpcomingTitles(titles)   // ← data logic
            }
        case .failure(let error):
            print(error.localizedDescription)
        }
    }
}

// Trong cellForRowAt — mapping cũng là data logic, không phải view logic
let model = TitleViewModel(
    titleName: title.original_name ?? title.original_title ?? "Unknown",  // ← data logic
    posterURL: title.poster_path ?? ""                                     // ← data logic
)
```

### HomeViewController còn tệ hơn

`cellForRowAt` đang gọi trực tiếp APICaller + DatabaseManager bên trong hàm render cell — vi phạm nặng Single Responsibility Principle. Khi table scroll và cell được dequeue lại → API có thể bị gọi lại nhiều lần.

---

## 2. Kiến trúc MVVM đề xuất

### Trước

```
UpcomingViewController
    ├── fetchUpcoming()       ← gọi API + đọc/ghi DB
    ├── cellForRowAt()        ← mapping Title → TitleViewModel
    └── upcomingTable         ← render UI

HomeViewController
    └── cellForRowAt()        ← gọi API + đọc/ghi DB + render cell
```

### Sau

```
UpcomingViewController        ← chỉ render UI
    └── UpcomingViewModel     ← toàn bộ data logic
            ├── fetchData()   ← cache-first: đọc DB + gọi API song song
            ├── saveToDB()    ← lưu kết quả API
            └── viewModels    ← [TitleViewModel] đã mapped, sẵn để bind lên UI

HomeViewController             ← chỉ render UI
    └── HomeViewModel          ← toàn bộ data logic
            ├── fetchSection() ← cache-first cho từng section
            └── titlesForSection(at:) ← [Title] đã load, dùng ở cellForRowAt
```

### Nguyên tắc giao tiếp ViewModel → ViewController

Trong UIKit (không có SwiftUI/Combine), ViewModel thông báo cho View bằng **closure callback**:

```swift
// ViewModel expose callback
var onDataUpdated: (() -> Void)?
var onError: ((String) -> Void)?

// ViewController bind
viewModel.onDataUpdated = { [weak self] in
    self?.tableView.reloadData()
}
```

---

## 3. Các file sẽ tạo và sửa

| File | Hành động | Mô tả |
|---|---|---|
| `ViewModels/UpcomingViewModel.swift` | **TẠO MỚI** | Toàn bộ data logic của Upcoming |
| `ViewModels/HomeViewModel.swift` | **TẠO MỚI** | Toàn bộ data logic của Home |
| `Controllers/UpcomingViewController.swift` | **SỬA LẠI** | Chỉ còn UI code, bind với UpcomingViewModel |
| `Controllers/HomeViewController.swift` | **SỬA LẠI** | Chỉ còn UI code, bind với HomeViewModel |
| `Models/TitleViewModel.swift` | **GIỮ NGUYÊN** | Vẫn dùng làm display model |

> ⚠️ **Tạo folder `ViewModels/`** trong Xcode bên cạnh `Controllers/`, `Models/`, `Views/`.

---

## 4. Tạo UpcomingViewModel

Tạo file mới: `NetflixClone/ViewModels/UpcomingViewModel.swift`

```swift
//
//  UpcomingViewModel.swift
//  NetflixClone
//

import Foundation

class UpcomingViewModel {

    // MARK: - Output — ViewController bind vào đây
    var onDataUpdated: (() -> Void)?
    var onError: ((String) -> Void)?

    // MARK: - Data — đã mapped sẵn thành TitleViewModel
    private(set) var viewModels: [TitleViewModel] = []

    // MARK: - Fetch Data (Cache-First)
    func fetchData() {
        // BƯỚC 1: Load cache NGAY - không chờ API
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let cached = DatabaseManager.shared.fetchUpcomingTitles()
            if !cached.isEmpty {
                let mapped = self?.map(titles: cached) ?? []
                DispatchQueue.main.async {
                    self?.viewModels = mapped
                    self?.onDataUpdated?()
                }
            }
        }

        // BƯỚC 2: Gọi API song song — khi về thì ghi đè
        APICaller.shared.getUpcomingMovies { [weak self] result in
            switch result {
            case .success(let titles):
                let mapped = self?.map(titles: titles) ?? []
                DispatchQueue.main.async {
                    self?.viewModels = mapped
                    self?.onDataUpdated?()
                }
                DispatchQueue.global(qos: .utility).async {
                    DatabaseManager.shared.saveUpcomingTitles(titles)
                }
            case .failure(let error):
                // Cache đã hiển thị từ bước 1 — chỉ cần log
                DispatchQueue.main.async {
                    self?.onError?(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Private Mapping
    private func map(titles: [Title]) -> [TitleViewModel] {
        return titles.map { title in
            TitleViewModel(
                titleName: title.original_name ?? title.original_title ?? "Unknown",
                posterURL: title.poster_path ?? ""
            )
        }
    }
}
```

**Điều ViewController nhận được:**
- `viewModel.viewModels` — `[TitleViewModel]` đã map xong, dùng trực tiếp trong `cellForRowAt`
- `viewModel.onDataUpdated` — gọi khi có data mới (từ cache hoặc API)
- `viewModel.onError` — gọi khi API lỗi và không có cache

---

## 5. Sửa UpcomingViewController

```swift
//
//  UpcomingViewController.swift
//  NetflixClone
//

import UIKit

class UpcomingViewController: UIViewController {

    // MARK: - ViewModel
    private let viewModel = UpcomingViewModel()

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

        bindViewModel()      // ← kết nối callbacks
        viewModel.fetchData() // ← trigger fetch
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        upcomingTable.frame = view.bounds
    }

    // MARK: - Bind
    private func bindViewModel() {
        viewModel.onDataUpdated = { [weak self] in
            self?.upcomingTable.reloadData()
        }
        viewModel.onError = { message in
            print("[UpcomingVC] \(message)")
        }
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource
extension UpcomingViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.viewModels.count  // ← dùng trực tiếp, không cần map
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: TitleTableViewCell.identifier,
            for: indexPath
        ) as? TitleTableViewCell else {
            return UITableViewCell()
        }
        cell.configure(with: viewModel.viewModels[indexPath.row])  // ← chỉ render, không map
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 150
    }
}
```

**So sánh:**

| | Trước | Sau |
|---|---|---|
| `fetchUpcoming()` | 30 dòng logic phức tạp | **Xoá hoàn toàn** |
| `cellForRowAt` | 10 dòng (dequeue + mapping + configure) | **5 dòng** (dequeue + configure) |
| ViewController biết về APICaller? | ✅ Có | ❌ Không |
| ViewController biết về DatabaseManager? | ✅ Có | ❌ Không |
| ViewController biết về Title model? | ✅ Có (dùng trong mapping) | ❌ Không |

---

## 6. Tạo HomeViewModel

Tạo file mới: `NetflixClone/ViewModels/HomeViewModel.swift`

Home phức tạp hơn vì có 5 section, mỗi section cần data riêng.

```swift
//
//  HomeViewModel.swift
//  NetflixClone
//

import Foundation

class HomeViewModel {

    // MARK: - Output
    var onSectionUpdated: ((Int) -> Void)?    // section index nào được update
    var onError: ((String) -> Void)?

    // MARK: - Data — mỗi section lưu [Title] riêng
    // HomeVC dùng cell.configure(with: [Title]) — không cần map sang TitleViewModel
    private(set) var sectionData: [[Title]] = Array(repeating: [], count: 5)

    // MARK: - Fetch tất cả sections (Cache-First cho từng section)
    func fetchAllSections() {
        fetchSection(.TrendingMovies, apiCall: APICaller.shared.getHomeTrendingMovies, cacheKey: "trending_movies")
        fetchSection(.TrendingTV,     apiCall: APICaller.shared.getHomeTrendingTVs,    cacheKey: "trending_tv")
        fetchSection(.Popular,        apiCall: APICaller.shared.getHomePopularMovies,  cacheKey: "popular")
        fetchSection(.UpcomingMovies, apiCall: APICaller.shared.getHomeUpcomingMovies, cacheKey: "upcoming")
        fetchSection(.TopRated,       apiCall: APICaller.shared.getHomeTopRated,       cacheKey: "top_rated")
    }

    // MARK: - Private
    private func fetchSection(
        _ section: Sections,
        apiCall: (@escaping (Result<[Title], Error>) -> Void) -> Void,
        cacheKey: String
    ) {
        let index = section.rawValue

        // BƯỚC 1: Load cache ngay
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let cached = DatabaseManager.shared.fetchTitles(section: cacheKey)
            if !cached.isEmpty {
                DispatchQueue.main.async {
                    self?.sectionData[index] = cached
                    self?.onSectionUpdated?(index)
                }
            }
        }

        // BƯỚC 2: Gọi API song song
        apiCall { [weak self] result in
            switch result {
            case .success(let titles):
                DispatchQueue.main.async {
                    self?.sectionData[index] = titles
                    self?.onSectionUpdated?(index)
                }
                DispatchQueue.global(qos: .utility).async {
                    DatabaseManager.shared.saveTitles(titles, section: cacheKey)
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self?.onError?("[HomeVM] \(cacheKey): \(error.localizedDescription)")
                }
            }
        }
    }
}
```

---

## 7. Sửa HomeViewController

```swift
//
//  HomeViewController.swift
//  NetflixClone
//

import UIKit

class HomeViewController: UIViewController {

    // MARK: - ViewModel
    private let viewModel = HomeViewModel()

    // MARK: - UI
    let sectionTiles: [String] = ["Trending Movies", "Trending TV", "Popular", "Upcoming Movies", "Top Rated"]

    private let homeFeedTable: UITableView = {
        let table = UITableView(frame: .zero, style: .grouped)
        table.register(CollectionViewTableViewCell.self, forCellReuseIdentifier: CollectionViewTableViewCell.indentifier)
        return table
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        URLCache.shared.removeAllCachedResponses()
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        view.addSubview(homeFeedTable)

        homeFeedTable.delegate = self
        homeFeedTable.dataSource = self

        configureNavBar()

        let headerView = HeroHeaderUIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 450))
        homeFeedTable.tableHeaderView = headerView

        bindViewModel()        // ← kết nối callbacks
        viewModel.fetchAllSections() // ← trigger fetch
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        homeFeedTable.frame = view.bounds
    }

    // MARK: - Bind
    private func bindViewModel() {
        viewModel.onSectionUpdated = { [weak self] sectionIndex in
            // Chỉ reload đúng row của section đó — hiệu quả hơn reloadData()
            let indexPath = IndexPath(row: 0, section: sectionIndex)
            self?.homeFeedTable.reloadRows(at: [indexPath], with: .none)
        }
        viewModel.onError = { message in
            print(message)
        }
    }

    // MARK: - Nav
    private func configureNavBar() {
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(image: UIImage(systemName: "person"), style: .done, target: self, action: nil),
            UIBarButtonItem(image: UIImage(systemName: "play.rectangle"), style: .done, target: self, action: nil)
        ]
        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.backgroundColor = .clear
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource
extension HomeViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        sectionTiles.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: CollectionViewTableViewCell.indentifier,
            for: indexPath
        ) as? CollectionViewTableViewCell else {
            return UITableViewCell()
        }
        // ← Chỉ render — không gọi API, không đọc DB
        let titles = viewModel.sectionData[indexPath.section]
        if !titles.isEmpty {
            cell.configure(with: titles)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 200
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sectionTiles[section]
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.textLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        header.textLabel?.frame = CGRect(x: header.bounds.origin.x + 20, y: header.bounds.origin.y, width: 100, height: header.bounds.height)
    }
}
```

**Lợi ích lớn nhất ở HomeViewController:**

> Trước đây `cellForRowAt` gọi API trực tiếp → mỗi lần scroll và cell bị dequeue lại → **API bị gọi lại**. Sau refactor, `cellForRowAt` chỉ đọc từ `viewModel.sectionData` (in-memory array) → **không bao giờ gọi API trong render cycle**.

---

## 8. Checklist thực hành

```
[ ] 1. Tạo folder ViewModels/ trong Xcode (New Group)
[ ] 2. Tạo file ViewModels/UpcomingViewModel.swift
[ ] 3. Tạo file ViewModels/HomeViewModel.swift
[ ] 4. Sửa UpcomingViewController.swift theo mục 5
[ ] 5. Sửa HomeViewController.swift theo mục 7
[ ] 6. Build project (⌘B) — đảm bảo không lỗi
[ ] 7. Run app — kiểm tra home + upcoming load bình thường
[ ] 8. Test offline — cache vẫn hiển thị ngay như trước
```

> **Lưu ý cấu trúc folder sau khi hoàn thành:**
> ```
> NetflixClone/
> ├── Controllers/
> │   ├── HomeViewController.swift      ← chỉ còn UI code
> │   └── UpcomingViewController.swift  ← chỉ còn UI code
> ├── ViewModels/                       ← MỚI
> │   ├── HomeViewModel.swift
> │   └── UpcomingViewModel.swift
> ├── Models/
> ├── Views/
> └── Managers/
> ```

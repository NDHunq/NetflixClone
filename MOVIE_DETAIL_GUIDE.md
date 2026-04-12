# 🎬 Hướng dẫn xây dựng tính năng Chi Tiết Phim (Movie Detail) với XIB

> **Mục đích:** Hướng dẫn từng bước chi tiết để thêm tính năng xem chi tiết phim khi nhấn vào poster phim trên Home screen.
> Tính năng này sử dụng **UITableView + nhiều Cell XIB** — mỗi section là 1 component riêng biệt, tái sử dụng được.
> Đây là pattern **rất phổ biến** trong các app thương mại (App Store, Netflix thật, Spotify...).

---

## Mục lục

1. [Tổng quan tính năng](#1-tổng-quan-tính-năng)
2. [API TMDB cần dùng](#2-api-tmdb-cần-dùng)
3. [Bản đồ file cần tạo / sửa](#3-bản-đồ-file-cần-tạo--sửa)
4. [BƯỚC 1 — Tạo Model cho Movie Detail](#4-bước-1--tạo-model-cho-movie-detail)
5. [BƯỚC 2 — Thêm API Endpoint](#5-bước-2--thêm-api-endpoint)
6. [BƯỚC 3 — Thêm hàm gọi API trong APICaller](#6-bước-3--thêm-hàm-gọi-api-trong-apicaller)
7. [BƯỚC 4 — Tạo MovieBackdropCell (XIB)](#7-bước-4--tạo-moviebackdropcell-xib)
8. [BƯỚC 5 — Tạo MovieActionCell (XIB)](#8-bước-5--tạo-movieactioncell-xib)
9. [BƯỚC 6 — Tạo MovieOverviewCell (XIB)](#9-bước-6--tạo-movieoverviewcell-xib)
10. [BƯỚC 7 — Tạo MovieCastCell (XIB)](#10-bước-7--tạo-moviecastcell-xib)
11. [BƯỚC 8 — Tạo MovieDetailViewController (XIB)](#11-bước-8--tạo-moviedetailviewcontroller-xib)
12. [BƯỚC 9 — Kết nối Navigation từ Home](#12-bước-9--kết-nối-navigation-từ-home)
13. [Tổng kết & Checklist](#13-tổng-kết--checklist)

---

## 1. Tổng quan tính năng

### 1.1. Luồng hoạt động

```
┌─────────────────────────────────────────────────────┐
│                    HomeVC                            │
│   ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐         │
│   │Poster│ │Poster│ │Poster│ │Poster│ │Poster│  ← Tap │
│   └──┬──┘ └─────┘ └─────┘ └─────┘ └─────┘         │
│      │                                              │
│      ▼  lấy movie.id                                │
│                                                     │
│  CollectionViewTableViewCell → delegate → HomeVC    │
│                                                     │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼  navigationController?.pushViewController
                       
┌─────────────────────────────────────────────────────┐
│         MovieDetailViewController (UITableView)     │
│  ┌──────────────────────────────────────────────┐   │
│  │  Section 0: MovieBackdropCell                │   │
│  │  ┌──────────────────────────────────────┐    │   │
│  │  │       Backdrop Image + Gradient      │    │   │
│  │  │  ┌──────┐  Title                     │    │   │
│  │  │  │Poster│  ⭐ 8.4 · 2h19m · 2024     │    │   │
│  │  │  │Image │  Drama, Thriller           │    │   │
│  │  │  └──────┘                            │    │   │
│  │  └──────────────────────────────────────┘    │   │
│  ├──────────────────────────────────────────────┤   │
│  │  Section 1: MovieActionCell                  │   │
│  │  ┌──────────────┐  ┌──────────────┐          │   │
│  │  │ ▶ Play       │  │ 📥 Download  │          │   │
│  │  └──────────────┘  └──────────────┘          │   │
│  ├──────────────────────────────────────────────┤   │
│  │  Section 2: MovieOverviewCell                │   │
│  │  Overview                                    │   │
│  │  "A ticking-time-bomb insomniac and a..."    │   │
│  ├──────────────────────────────────────────────┤   │
│  │  Section 3: MovieCastCell                    │   │
│  │  Cast                                        │   │
│  │  Edward Norton as Narrator                   │   │
│  │  Brad Pitt as Tyler Durden                   │   │
│  │  Helena Bonham Carter as Marla Singer        │   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

### 1.2. Tại sao dùng UITableView + nhiều Cell XIB?

| So sánh | 1 XIB chung | UITableView + nhiều Cell XIB ✅ |
|---|---|---|
| Tái sử dụng | ❌ Gắn chặt vào 1 màn hình | ✅ Mỗi cell dùng lại ở nơi khác |
| Thêm/bớt section | ❌ Phải sửa layout phức tạp | ✅ Thêm/bớt section trong code |
| Self-sizing height | ❌ Phải tính thủ công | ✅ Auto Layout tự tính |
| Thay đổi thứ tự | ❌ Sửa constraints lại | ✅ Đổi thứ tự enum |
| Quản lý code | ❌ 1 file Swift cồng kềnh | ✅ Mỗi cell có file riêng |
| Pattern thực tế | Ít dùng | ✅ App Store, Netflix, Spotify |

### 1.3. Kiến thức XIB sẽ học được

| Concept | Ở bước nào |
|---|---|
| Tạo UITableViewCell + XIB (Cocoa Touch Class) | Bước 4, 5, 6, 7 |
| Self-sizing UITableViewCell trong XIB | Bước 4 |
| IBOutlet kết nối XIB → Swift | Tất cả bước |
| IBAction trong XIB | Bước 5 |
| CAGradientLayer (code, không XIB) | Bước 4 |
| Tạo ViewController + XIB | Bước 8 |
| UINib register cell | Bước 8 |
| Delegate Pattern cho cell event | Bước 5, 9 |
| `nibName` init cho ViewController | Bước 9 |

---

## 2. API TMDB cần dùng

> **Lưu ý:** Tất cả API response bên dưới là **dữ liệu thật** — được gọi trực tiếp từ TMDB API 
> với `api_key` của project (`ac90e227bedf46c08087b19100afc0f1`), test với phim **Fight Club** (id=550).
> Bạn có thể tự verify bằng cách paste URL vào trình duyệt.

### 2.1. Movie Details API

```
GET https://api.themoviedb.org/3/movie/{movie_id}
```

**Query Parameters** (tự động được inject bởi `NetworkInterceptor`):
- `api_key` — đã có sẵn
- `language` — đã có sẵn (`en-US`)

**Verify URL:**
```
https://api.themoviedb.org/3/movie/550?api_key=ac90e227bedf46c08087b19100afc0f1&language=en-US
```

**Response mẫu thật** (đã lược bớt field không cần):

```json
{
  "id": 550,
  "title": "Fight Club",
  "original_title": "Fight Club",
  "overview": "A ticking-time-bomb insomniac and a slippery soap salesman channel primal male aggression into a shocking new form of therapy...",
  "poster_path": "/jSziioSwPVrOy9Yow3XhWIBDjq1.jpg",
  "backdrop_path": "/c6OLXfKAk5BKeR6broC8pYiCquX.jpg",
  "release_date": "1999-10-15",
  "runtime": 139,
  "vote_average": 8.438,
  "vote_count": 31763,
  "status": "Released",
  "tagline": "Mischief. Mayhem. Soap.",
  "budget": 63000000,
  "revenue": 100853753,
  "genres": [
    { "id": 18, "name": "Drama" },
    { "id": 53, "name": "Thriller" }
  ],
  "production_companies": [
    { "id": 711, "name": "Fox 2000 Pictures", "logo_path": "/tEiIH5QesdheJmDAqQwvtN60727.png" }
  ]
}
```

### 2.2. Movie Credits API

```
GET https://api.themoviedb.org/3/movie/{movie_id}/credits
```

**Verify URL:**
```
https://api.themoviedb.org/3/movie/550/credits?api_key=ac90e227bedf46c08087b19100afc0f1&language=en-US
```

**Response mẫu thật** (chỉ trích `cast`, response thật có 75 cast members):

```json
{
  "id": 550,
  "cast": [
    {
      "id": 819,
      "name": "Edward Norton",
      "character": "Narrator",
      "profile_path": "/8nytsqL59SFJTVYVrN72k6qkGgJ.jpg",
      "order": 0
    },
    {
      "id": 287,
      "name": "Brad Pitt",
      "character": "Tyler Durden",
      "profile_path": "/r9DzKQLNbh5QfXlrFGHoVNKER7X.jpg",
      "order": 1
    },
    {
      "id": 1283,
      "name": "Helena Bonham Carter",
      "character": "Marla Singer",
      "profile_path": "/hJMbNSPJ2PCahsP3rNEU39C8GWU.jpg",
      "order": 2
    }
  ]
}
```

### 2.3. Movie Videos API

```
GET https://api.themoviedb.org/3/movie/{movie_id}/videos
```

**Verify URL:**
```
https://api.themoviedb.org/3/movie/550/videos?api_key=ac90e227bedf46c08087b19100afc0f1&language=en-US
```

**Response mẫu thật:**

```json
{
  "id": 550,
  "results": [
    {
      "name": "20th Anniversary Trailer",
      "key": "dfeUzm6KF4g",
      "site": "YouTube",
      "type": "Trailer",
      "official": true
    },
    {
      "name": "#TBT Trailer",
      "key": "BdJKm16Co6M",
      "site": "YouTube",
      "type": "Trailer",
      "official": true
    }
  ]
}
```

> **Cách xem trailer:** Lọc video có `type == "Trailer"` và `site == "YouTube"`, rồi mở URL:
> `https://www.youtube.com/watch?v={key}` bằng `UIApplication.shared.open(url)`

### 2.4. Cách tạo URL ảnh từ path

```swift
// Poster (nhỏ hơn, dùng w500)
"https://image.tmdb.org/t/p/w500\(poster_path)"

// Backdrop (lớn hơn, dùng w780)
"https://image.tmdb.org/t/p/w780\(backdrop_path)"

// Profile (ảnh diễn viên, dùng w185)
"https://image.tmdb.org/t/p/w185\(profile_path)"
```

---

## 3. Bản đồ file cần tạo / sửa

```
NetflixClone/
├── Models/
│   └── MovieDetail.swift                        ← [MỚI] Model cho 3 API response
│
├── Managers/Networking/
│   ├── APIEndpoint.swift                        ← [SỬA] Thêm 3 endpoint mới
│   └── APICaller.swift                          ← [SỬA] Thêm 3 hàm gọi API
│
├── Controllers/
│   ├── HomeViewController.swift                 ← [SỬA] Thêm delegate + navigation
│   ├── MovieDetailViewController.swift          ← [MỚI] ViewController chính
│   └── MovieDetailViewController.xib            ← [MỚI] XIB cho VC (chỉ có TableView)
│
├── Views/
│   ├── CollectionViewTableViewCell.swift         ← [SỬA] Thêm delegate cho tap
│   │
│   ├── MovieBackdropCell.swift                  ← [MỚI] Cell: backdrop + poster + info
│   ├── MovieBackdropCell.xib                    ← [MỚI] XIB cho backdrop cell
│   │
│   ├── MovieActionCell.swift                    ← [MỚI] Cell: buttons
│   ├── MovieActionCell.xib                      ← [MỚI] XIB cho action cell
│   │
│   ├── MovieOverviewCell.swift                  ← [MỚI] Cell: overview text
│   ├── MovieOverviewCell.xib                    ← [MỚI] XIB cho overview cell
│   │
│   ├── MovieCastCell.swift                      ← [MỚI] Cell: cast list
│   └── MovieCastCell.xib                        ← [MỚI] XIB cho cast cell
```

**Thứ tự làm:** Model → Endpoint → APICaller → 4 Cell XIBs → ViewController XIB → Navigation

**Tổng:** 8 file mới + 3 file sửa = 11 file

---

## 4. BƯỚC 1 — Tạo Model cho Movie Detail

> **Mục tiêu:** Tạo các struct Codable để parse JSON response từ 3 API.

### 4.1. Tạo file `MovieDetail.swift`

1. Click phải vào folder **Models** trong Project Navigator
2. Chọn **New File...** → **Swift File** → đặt tên `MovieDetail` → Create
3. Đảm bảo target `NetflixClone` được tick ✅

### 4.2. Viết code

```swift
//
//  MovieDetail.swift
//  NetflixClone
//

import Foundation

// MARK: - Movie Details Response
// API: GET /movie/{movie_id}
struct MovieDetail: Codable {
    let id: Int
    let title: String?
    let original_title: String?
    let overview: String?
    let poster_path: String?
    let backdrop_path: String?
    let release_date: String?
    let runtime: Int?           // phút, ví dụ: 139
    let vote_average: Double?
    let vote_count: Int?
    let status: String?         // "Released", "Post Production", ...
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
```

### 4.3. Giải thích thiết kế

| Quyết định | Lý do |
|---|---|
| Dùng `let` thay `var` | Immutable — chỉ đọc data từ API, không sửa |
| Hầu hết là `Optional (?)` | API không chắc luôn trả về đủ field |
| Struct riêng cho `Genre`, `CastMember`... | Tách biệt, tái sử dụng, dễ đọc |
| `Codable` | Tương thích `responseDecodable` của Alamofire trong `NetworkManager` |

### 4.4. Build kiểm tra

`Cmd + B` — phải thành công, không lỗi.

---

## 5. BƯỚC 2 — Thêm API Endpoint

> **Mục tiêu:** Thêm 3 endpoint mới vào `APIEndpoint.swift`.

### 5.1. Mở file `Managers/Networking/APIEndpoint.swift`

### 5.2. Thêm case mới vào enum

Tìm `enum APIEndpoint {` và thêm **3 case mới** vào cuối (trước dấu `}`):

```swift
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
    
    // ✅ MỚI: Movie Detail
    case movieDetail(movieId: Int)          // GET /movie/{movie_id}
    case movieCredits(movieId: Int)         // GET /movie/{movie_id}/credits
    case movieVideos(movieId: Int)          // GET /movie/{movie_id}/videos
}
```

### 5.3. Thêm path trong extension

Trong `extension APIEndpoint`, thêm 3 case vào `var path`:

```swift
var path: String {
    switch self {
    case .trendingMovies:           return "/trending/movie/day"
    case .trendingTV:               return "/trending/tv/day"
    case .popularMovies:            return "/movie/popular"
    case .upcomingMovies:           return "/movie/upcoming"
    case .topRatedMovies:           return "/movie/top_rated"
    case .searchMovies:             return "/search/movie"
    
    // ✅ MỚI: path có chứa movieId dynamic
    case .movieDetail(let movieId):  return "/movie/\(movieId)"
    case .movieCredits(let movieId): return "/movie/\(movieId)/credits"
    case .movieVideos(let movieId):  return "/movie/\(movieId)/videos"
    }
}
```

### 5.4. Cập nhật `var parameters`

3 API mới **không cần thêm query param** (api_key và language đã được `NetworkInterceptor` tự thêm):

```swift
var parameters: Parameters? {
    switch self {
    case .searchMovies(let query):
        return ["query": query, "page": 1]
    case .popularMovies, .upcomingMovies, .topRatedMovies:
        return ["page": 1]
    // movieDetail, movieCredits, movieVideos đều rơi vào default → nil
    // api_key và language được NetworkInterceptor tự inject
    default:
        return nil
    }
}
```

### 5.5. Build kiểm tra

`Cmd + B` — phải thành công.

---

## 6. BƯỚC 3 — Thêm hàm gọi API trong APICaller

> **Mục tiêu:** Thêm 3 hàm mới để gọi detail, credits, videos.

### 6.1. Mở file `Managers/Networking/APICaller.swift`

### 6.2. Thêm 3 hàm vào cuối class (trước dấu `}` cuối)

```swift
class APICaller {
    
    static let shared = APICaller()
    private init() {}
    
    // MARK: - Home APIs
    // ... (giữ nguyên tất cả hàm đã có) ...
    
    // MARK: - Movie Detail APIs
    
    /// Lấy thông tin chi tiết của 1 bộ phim theo ID
    func getMovieDetail(movieId: Int, completion: @escaping (Result<MovieDetail, NetworkError>) -> Void) {
        NetworkManager.shared.request(
            endpoint: .movieDetail(movieId: movieId),
            method: .get,
            responseType: MovieDetail.self
        ) { result in
            completion(result)
        }
    }
    
    /// Lấy danh sách diễn viên của phim
    func getMovieCredits(movieId: Int, completion: @escaping (Result<[CastMember], NetworkError>) -> Void) {
        NetworkManager.shared.request(
            endpoint: .movieCredits(movieId: movieId),
            method: .get,
            responseType: MovieCreditsResponse.self
        ) { result in
            // result.map(\.cast) biến Result<MovieCreditsResponse, Error> → Result<[CastMember], Error>
            // Cùng pattern đã dùng ở getHomeTrendingMovies: result.map(\.results)
            completion(result.map(\.cast))
        }
    }
    
    /// Lấy danh sách video (trailer) của phim
    func getMovieVideos(movieId: Int, completion: @escaping (Result<[MovieVideo], NetworkError>) -> Void) {
        NetworkManager.shared.request(
            endpoint: .movieVideos(movieId: movieId),
            method: .get,
            responseType: MovieVideosResponse.self
        ) { result in
            completion(result.map(\.results))
        }
    }
}
```

### 6.3. Build kiểm tra

`Cmd + B` — phải thành công.

---

## 7. BƯỚC 4 — Tạo MovieBackdropCell (XIB)

> **Mục tiêu:** Tạo cell đầu tiên — hiển thị ảnh backdrop, poster, title, rating, genres.
> Đây là cell phức tạp nhất, sau khi làm xong cell này, các cell sau sẽ dễ hơn nhiều.

### 7.1. Tạo file trong Xcode

1. Click phải vào folder **Views** → **New File...**
2. Chọn template: **iOS → Cocoa Touch Class**
3. Điền:
   - **Class:** `MovieBackdropCell`
   - **Subclass of:** `UITableViewCell`
   - ✅ **Also create XIB file** ← tick vào!
   - **Language:** Swift
4. Nhấn **Next** → **Create**

> Xcode tạo 2 file: `MovieBackdropCell.swift` + `MovieBackdropCell.xib`
> Custom Class đã được set tự động trên root cell trong XIB.

### 7.2. Thiết kế trong XIB

Mở `MovieBackdropCell.xib`. Đầu tiên, set **kích thước preview** để dễ thiết kế:

1. Chọn **Cell** trên canvas → **Size Inspector** (icon thước kẻ, `Cmd + Option + 5`)
2. Row Height: **400** (chỉ là preview, runtime sẽ tự tính bằng Auto Layout)

#### Cấu trúc View Hierarchy

```
MovieBackdropCell (root)
└── Content View
    ├── backdropImageView (UIImageView)     ← full width, phía trên
    ├── gradientView (UIView)               ← chồng lên backdrop
    ├── posterImageView (UIImageView)        ← nhỏ, nằm đè lên backdrop
    ├── titleLabel (UILabel)                 ← bên phải poster
    ├── metaLabel (UILabel)                  ← ⭐ 8.4 · 2h19m · 2024
    └── genreLabel (UILabel)                 ← Drama, Thriller
```

#### A. Thêm Backdrop Image

1. Mở **Object Library** (`Cmd + Shift + L`) → kéo **UIImageView** vào Content View
2. **Constraints** (nút 📌 ở góc dưới phải):
   - Top = 0 (so với Content View, **bỏ tick** Constrain to margins)
   - Leading = 0
   - Trailing = 0
   - Height = **250** (fixed)
3. **Attributes Inspector** (`Cmd + Option + 4`):
   - Content Mode: **Aspect Fill**
   - ✅ Clip to Bounds
   - Background: **Dark Gray Color** (placeholder khi chưa có ảnh)

#### B. Thêm Gradient View

1. Kéo **UIView** vào Content View
2. **Constraints** — gắn vào **backdropImageView** (không phải Content View):
   - Cách làm: Ctrl + kéo từ gradientView → backdropImageView
   - Top = 0, Bottom = 0, Leading = 0, Trailing = 0
   - Hoặc: chọn gradientView, rồi Add Constraints với dropdown chọn backdropImageView
3. Attributes Inspector:
   - Background: **Clear Color**

> Gradient layer sẽ thêm bằng code trong `awakeFromNib()` vì `CAGradientLayer` không tạo được trong XIB.

#### C. Thêm Poster Image

1. Kéo **UIImageView** vào Content View
2. **Constraints**:
   - Top = **180** (so với **Content View** top) — poster sẽ nằm đè lên backdrop
   - Leading = **16**
   - Width = **120**
   - Height = **180**
3. Attributes Inspector:
   - Content Mode: **Aspect Fill**
   - ✅ Clip to Bounds
   - Background: **Dark Gray Color**

> Corner radius cho poster sẽ set bằng code.

#### D. Thêm Title Label

1. Kéo **UILabel** vào Content View
2. **Constraints**:
   - Top = **192** (so với Content View) — ngang tầm với posterImage + chút padding
   - Leading = 12 so với **posterImageView.trailing**
     (Ctrl + kéo từ titleLabel → posterImageView → chọn **Horizontal Spacing**, set constant = 12)
   - Trailing = -16 (so với Content View)
3. Attributes Inspector:
   - Text: `"Movie Title"` (placeholder)
   - Font: **System Bold, 20**
   - Color: **White**
   - Lines: **0** (cho phép nhiều dòng)

#### E. Thêm Meta Label

1. Kéo **UILabel** vào Content View
2. **Constraints**:
   - Top = 8 so với **titleLabel.bottom**
     (Ctrl + kéo từ metaLabel → titleLabel → Vertical Spacing = 8)
   - Leading = 12 so với posterImageView.trailing
   - Trailing = -16
3. Attributes Inspector:
   - Text: `"⭐ 8.4 · 2h19m · 2024"` (placeholder)
   - Font: **System, 14**
   - Color: **Secondary Label Color** (chọn trong Named Colors)

#### F. Thêm Genre Label

1. Kéo **UILabel** vào Content View
2. **Constraints**:
   - Top = 8 so với **metaLabel.bottom**
   - Leading = 12 so với posterImageView.trailing
   - Trailing = -16
3. Attributes Inspector:
   - Text: `"Drama, Thriller"` (placeholder)
   - Font: **System, 13**
   - Color: **Secondary Label Color**
   - Lines: **0**

#### G. Constraint Bottom — RẤT QUAN TRỌNG

Cell cần biết chiều cao → phải có constraint nối từ element cuối cùng xuống Content View bottom.

Cách xác định element nào ở dưới cùng: **posterImageView** (top=180, height=180, tổng = 360) 
thường sẽ thấp hơn genreLabel. Và ta muốn cell cao hơn poster bottom một chút.

1. Chọn **posterImageView**
2. Add constraint: **Bottom = 16** so với **Content View**
   (tức Content View bottom cách posterImage bottom 16 point)

> ⚠️ Nếu thiếu constraint bottom này, UITableView sẽ **không biết height** của cell
> và cell sẽ bị collapse hoặc hiện lỗi Auto Layout trong console.

### 7.3. Tạo IBOutlets

Mở **Assistant Editor** (`Ctrl + Option + Cmd + Enter`), đảm bảo `MovieBackdropCell.swift` hiện bên phải.

**Ctrl + kéo** từng element trên XIB sang file Swift:

| Element | Outlet Name | Type |
|---|---|---|
| Backdrop ImageView | `backdropImageView` | UIImageView |
| Gradient View | `gradientView` | UIView |
| Poster ImageView | `posterImageView` | UIImageView |
| Title Label | `titleLabel` | UILabel |
| Meta Label | `metaLabel` | UILabel |
| Genre Label | `genreLabel` | UILabel |

### 7.4. Viết code `MovieBackdropCell.swift`

```swift
//
//  MovieBackdropCell.swift
//  NetflixClone
//

import UIKit
import SDWebImage

class MovieBackdropCell: UITableViewCell {
    
    static let identifier = "MovieBackdropCell"
    
    // MARK: - IBOutlets
    @IBOutlet weak var backdropImageView: UIImageView!
    @IBOutlet weak var gradientView: UIView!
    @IBOutlet weak var posterImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var metaLabel: UILabel!
    @IBOutlet weak var genreLabel: UILabel!
    
    // MARK: - Lifecycle
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Gradient cần update frame khi cell thay đổi kích thước
        gradientView.layer.sublayers?
            .first(where: { $0 is CAGradientLayer })?
            .frame = gradientView.bounds
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // Poster corner radius (không set được trong XIB)
        posterImageView.layer.cornerRadius = 8
        posterImageView.clipsToBounds = true
        
        // Background trong suốt
        backgroundColor = .clear
        selectionStyle = .none
        
        // Gradient overlay
        addGradient()
    }
    
    private func addGradient() {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.systemBackground.cgColor
        ]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.frame = gradientView.bounds
        gradientView.layer.addSublayer(gradientLayer)
    }
    
    // MARK: - Configure (gọi từ ViewController)
    
    func configure(with detail: MovieDetail) {
        // Title
        titleLabel.text = detail.title ?? detail.original_title ?? "Unknown"
        
        // Backdrop
        if let backdropPath = detail.backdrop_path {
            let url = URL(string: "https://image.tmdb.org/t/p/w780\(backdropPath)")
            backdropImageView.sd_setImage(with: url)
        }
        
        // Poster
        if let posterPath = detail.poster_path {
            let url = URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")
            posterImageView.sd_setImage(with: url)
        }
        
        // Meta: ⭐ 8.4 · 2h19m · 2024
        var metaParts: [String] = []
        if let vote = detail.vote_average {
            metaParts.append("⭐ \(String(format: "%.1f", vote))")
        }
        if let runtime = detail.runtime, runtime > 0 {
            let hours = runtime / 60
            let minutes = runtime % 60
            metaParts.append(hours > 0 ? "\(hours)h\(minutes)m" : "\(minutes)m")
        }
        if let releaseDate = detail.release_date, releaseDate.count >= 4 {
            metaParts.append(String(releaseDate.prefix(4)))
        }
        metaLabel.text = metaParts.joined(separator: " · ")
        
        // Genres
        if let genres = detail.genres {
            genreLabel.text = genres.map(\.name).joined(separator: ", ")
        } else {
            genreLabel.text = nil
        }
    }
}
```

### 7.5. Những gì KHÔNG THỂ làm trong XIB (cần code)

| Thuộc tính | XIB? | Code? | Ở đâu |
|---|---|---|---|
| Content Mode (Aspect Fill) | ✅ | | Attributes Inspector |
| Clip to Bounds | ✅ | | Attributes Inspector |
| Corner Radius | ❌ | ✅ | `awakeFromNib()` |
| CAGradientLayer | ❌ | ✅ | `addGradient()` |
| Selection Style = none | ❌ | ✅ | `awakeFromNib()` |
| Load ảnh từ URL | ❌ | ✅ | `configure(with:)` |

---

## 8. BƯỚC 5 — Tạo MovieActionCell (XIB)

> **Mục tiêu:** Cell chứa 2 nút: Play Trailer và Download.
> Học thêm: IBAction trong XIB, Delegate cho button event.

### 8.1. Tạo file trong Xcode

1. Click phải folder **Views** → **New File...** → **Cocoa Touch Class**
2. Class: `MovieActionCell`, Subclass: `UITableViewCell`, ✅ Also create XIB file
3. Create

### 8.2. Tạo Delegate Protocol

Trước khi thiết kế XIB, ta cần protocol để thông báo cho ViewController khi nút được nhấn.

Lý do: Cell **không nên** tự xử lý navigation hoặc mở URL. Cell chỉ **báo** cho ViewController, 
ViewController **quyết định** làm gì → đúng Single Responsibility Principle.

### 8.3. Thiết kế trong XIB

Mở `MovieActionCell.xib`:

1. Chọn Cell → Size Inspector → Row Height: **80**

#### Cấu trúc

```
MovieActionCell (root)
└── Content View
    ├── playButton (UIButton)        ← bên trái
    └── downloadButton (UIButton)    ← bên phải
```

#### A. Thêm Play Button

1. Kéo **UIButton** vào Content View
2. **Constraints**:
   - Top = **16**
   - Leading = **16**
   - Bottom = **-16** (so với Content View)
   - Height = **44**
3. Thêm constraint Width liên quan tới Download Button (sẽ làm ở bước B)
4. Attributes Inspector:
   - Title: `"▶  Play Trailer"`
   - Style: **Default**
   - Background: **System Red** (chọn trong System Colors)
   - Tint: **White**
   - Font: **System Bold, 15**

#### B. Thêm Download Button

1. Kéo **UIButton** vào Content View
2. **Constraints**:
   - Top = **16**
   - Trailing = **-16**
   - Bottom = **-16**
   - Height = **44**
   - Leading = 12 so với **playButton.trailing**
     (Ctrl + kéo từ downloadButton → playButton → Horizontal Spacing = 12)
3. **Equal Widths** với playButton:
   - Ctrl + kéo từ downloadButton → playButton → chọn **Equal Widths**
   - Điều này đảm bảo 2 nút luôn cùng chiều rộng
4. Attributes Inspector:
   - Title: `"📥  Download"`
   - Background: **Dark Gray Color** (hoặc System Gray 5)
   - Tint: **White**
   - Font: **System Bold, 15**

### 8.4. Tạo IBOutlets và IBActions

Mở Assistant Editor, Ctrl + kéo:

**Outlets:**
| Element | Name | Type |
|---|---|---|
| Play Button | `playButton` | UIButton |
| Download Button | `downloadButton` | UIButton |

**Actions** (chọn Connection = **Action**, Event = Touch Up Inside):
| Element | Name |
|---|---|
| Play Button | `playTrailerTapped` |
| Download Button | `downloadTapped` |

### 8.5. Viết code `MovieActionCell.swift`

```swift
//
//  MovieActionCell.swift
//  NetflixClone
//

import UIKit

// Delegate để ViewController xử lý sự kiện
protocol MovieActionCellDelegate: AnyObject {
    func movieActionCellDidTapPlayTrailer(_ cell: MovieActionCell)
    func movieActionCellDidTapDownload(_ cell: MovieActionCell)
}

class MovieActionCell: UITableViewCell {
    
    static let identifier = "MovieActionCell"
    
    // MARK: - IBOutlets
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var downloadButton: UIButton!
    
    // MARK: - Properties
    weak var delegate: MovieActionCellDelegate?
    
    // MARK: - Lifecycle
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear
        
        // Corner radius cho buttons (không set được trong XIB)
        playButton.layer.cornerRadius = 8
        playButton.clipsToBounds = true
        
        downloadButton.layer.cornerRadius = 8
        downloadButton.clipsToBounds = true
    }
    
    // MARK: - Configure
    
    /// Cho phép enable/disable nút Play tùy có trailer hay không
    func configure(hasTrailer: Bool) {
        playButton.isEnabled = hasTrailer
        playButton.alpha = hasTrailer ? 1.0 : 0.5
    }
    
    // MARK: - IBActions
    
    @IBAction func playTrailerTapped(_ sender: UIButton) {
        delegate?.movieActionCellDidTapPlayTrailer(self)
    }
    
    @IBAction func downloadTapped(_ sender: UIButton) {
        delegate?.movieActionCellDidTapDownload(self)
    }
}
```

### 8.6. Tại sao dùng Delegate cho button?

```
❌ Anti-pattern:
   Cell tự mở YouTube URL → cell phải biết về trailerKey, UIApplication
   → vi phạm Single Responsibility, cell không tái sử dụng được

✅ Delegate pattern:
   Cell chỉ báo: "user nhấn Play"
   ViewController giữ trailerKey, quyết định mở YouTube hay làm gì khác
   → Cell sạch, tái sử dụng được ở bất cứ đâu
```

---

## 9. BƯỚC 6 — Tạo MovieOverviewCell (XIB)

> **Mục tiêu:** Cell hiển thị phần mô tả phim. Cell đơn giản nhất — chỉ có 2 UILabel.

### 9.1. Tạo file

1. Click phải folder **Views** → **New File...** → **Cocoa Touch Class**
2. Class: `MovieOverviewCell`, Subclass: `UITableViewCell`, ✅ Also create XIB file
3. Create

### 9.2. Thiết kế trong XIB

Mở `MovieOverviewCell.xib`:

#### Cấu trúc

```
MovieOverviewCell (root)
└── Content View
    ├── headerLabel (UILabel)      ← "Overview"
    └── overviewLabel (UILabel)    ← nội dung mô tả (multi-line)
```

#### A. Thêm Header Label

1. Kéo **UILabel** vào Content View
2. **Constraints**:
   - Top = **16**
   - Leading = **16**
   - Trailing = **-16**
3. Attributes Inspector:
   - Text: `"Overview"`
   - Font: **System Bold, 18**
   - Color: **White**

#### B. Thêm Overview Label

1. Kéo **UILabel** vào Content View
2. **Constraints**:
   - Top = 8 so với **headerLabel.bottom**
   - Leading = **16**
   - Trailing = **-16**
   - **Bottom = -16** (so với Content View) ← QUAN TRỌNG cho self-sizing!
3. Attributes Inspector:
   - Text: `"Movie overview will appear here..."` (placeholder)
   - Font: **System, 15**
   - Color: **Secondary Label Color**
   - **Lines: 0** ← cho phép wrap nhiều dòng

> ⚠️ **Lines = 0** và **constraint Bottom** là 2 điều kiện BẮT BUỘC để cell tự tính height.
> Nếu Lines = 1 (mặc định) → text bị cắt. Nếu thiếu Bottom constraint → height = 0.

### 9.3. Tạo IBOutlets

| Element | Name | Type |
|---|---|---|
| Header Label | `headerLabel` | UILabel |
| Overview Label | `overviewLabel` | UILabel |

### 9.4. Viết code `MovieOverviewCell.swift`

```swift
//
//  MovieOverviewCell.swift
//  NetflixClone
//

import UIKit

class MovieOverviewCell: UITableViewCell {
    
    static let identifier = "MovieOverviewCell"
    
    // MARK: - IBOutlets
    @IBOutlet weak var headerLabel: UILabel!
    @IBOutlet weak var overviewLabel: UILabel!
    
    // MARK: - Lifecycle
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
        backgroundColor = .clear
    }
    
    // MARK: - Configure
    
    func configure(with overview: String?) {
        overviewLabel.text = overview ?? "No overview available."
    }
}
```

> **Chú ý:** Cell này rất đơn giản — chỉ nhận 1 string và hiển thị.
> Đây là ví dụ về **component nhỏ, tập trung 1 nhiệm vụ**, dễ tái sử dụng.
> Ví dụ: sau này bạn có trang chi tiết TV Show, cũng cần hiển thị overview → dùng lại cell này.

---

## 10. BƯỚC 7 — Tạo MovieCastCell (XIB)

> **Mục tiêu:** Cell hiển thị danh sách diễn viên.

### 10.1. Tạo file

1. Click phải folder **Views** → **New File...** → **Cocoa Touch Class**
2. Class: `MovieCastCell`, Subclass: `UITableViewCell`, ✅ Also create XIB file
3. Create

### 10.2. Thiết kế trong XIB

Mở `MovieCastCell.xib`:

#### Cấu trúc

```
MovieCastCell (root)
└── Content View
    ├── headerLabel (UILabel)      ← "Cast"
    └── castLabel (UILabel)        ← danh sách diễn viên (multi-line)
```

#### A. Thêm Header Label

1. Kéo **UILabel** vào Content View
2. Constraints: Top=16, Leading=16, Trailing=-16
3. Font: **System Bold, 18**, Color: **White**, Text: `"Cast"`

#### B. Thêm Cast Label

1. Kéo **UILabel** vào Content View
2. **Constraints**:
   - Top = 8 so với headerLabel.bottom
   - Leading = 16, Trailing = -16
   - **Bottom = -16** (so với Content View) ← QUAN TRỌNG!
3. Attributes Inspector:
   - Font: **System, 14**
   - Color: **Secondary Label Color**
   - **Lines: 0**
   - Text: `"Actor as Character"` (placeholder)

### 10.3. Tạo IBOutlets

| Element | Name | Type |
|---|---|---|
| Header Label | `headerLabel` | UILabel |
| Cast Label | `castLabel` | UILabel |

### 10.4. Viết code `MovieCastCell.swift`

```swift
//
//  MovieCastCell.swift
//  NetflixClone
//

import UIKit

class MovieCastCell: UITableViewCell {
    
    static let identifier = "MovieCastCell"
    
    // MARK: - IBOutlets
    @IBOutlet weak var headerLabel: UILabel!
    @IBOutlet weak var castLabel: UILabel!
    
    // MARK: - Lifecycle
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
        backgroundColor = .clear
    }
    
    // MARK: - Configure
    
    func configure(with cast: [CastMember]) {
        // Lấy tối đa 10 diễn viên, sắp xếp theo thứ tự xuất hiện
        let topCast = cast
            .sorted { ($0.order ?? 999) < ($1.order ?? 999) }
            .prefix(10)
        
        // Format: "Actor Name as Character"
        let castText = topCast
            .map { member in
                if let character = member.character, !character.isEmpty {
                    return "\(member.name) as \(character)"
                }
                return member.name
            }
            .joined(separator: "\n")
        
        castLabel.text = castText.isEmpty ? "No cast information available." : castText
    }
}
```

---

## 11. BƯỚC 8 — Tạo MovieDetailViewController (XIB)

> **Mục tiêu:** Tạo ViewController chính, dùng UITableView để hiển thị 4 loại cell.
> Đây là nơi **tổng hợp** tất cả component đã tạo.

### 11.1. Tạo file

1. Click phải folder **Controllers** → **New File...** → **Cocoa Touch Class**
2. Điền:
   - Class: `MovieDetailViewController`
   - Subclass of: `UIViewController`
   - ✅ **Also create XIB file** ← tick!
   - Language: Swift
3. Create

> Xcode tạo: `MovieDetailViewController.swift` + `MovieDetailViewController.xib`
> File's Owner đã set tự động, `view` outlet đã kết nối.

### 11.2. Thiết kế XIB — Chỉ có mỗi UITableView

Mở `MovieDetailViewController.xib`:

1. Kéo **UITableView** vào root View
2. **Constraints**: Top=0, Bottom=0, Leading=0, Trailing=0 (so với Superview, **KHÔNG** phải Safe Area)

   > Dùng Superview thay Safe Area để TableView trải full màn hình — backdrop image sẽ chui under status bar, tạo hiệu ứng immersive giống Netflix thật.

3. Attributes Inspector:
   - Separator: **None** (background cells riêng thì không cần đường kẻ)
   - Background: **System Background Color**

4. Tạo **IBOutlet**: Ctrl + kéo TableView → file Swift:
   - Name: `tableView`, Type: UITableView

### 11.3. Viết code `MovieDetailViewController.swift`

```swift
//
//  MovieDetailViewController.swift
//  NetflixClone
//

import UIKit

// MARK: - Section enum — quản lý thứ tự hiển thị
private enum DetailSection: Int, CaseIterable {
    case backdrop = 0    // MovieBackdropCell
    case actions  = 1    // MovieActionCell
    case overview = 2    // MovieOverviewCell
    case cast     = 3    // MovieCastCell
}

class MovieDetailViewController: UIViewController {
    
    // MARK: - IBOutlets
    @IBOutlet weak var tableView: UITableView!
    
    // MARK: - Properties
    private var movieId: Int = 0
    private var movieDetail: MovieDetail?
    private var castMembers: [CastMember] = []
    private var trailerKey: String?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupTableView()
        fetchAllData()
    }
    
    // MARK: - Public
    
    /// Gọi từ HomeVC trước khi push
    func configure(with movieId: Int) {
        self.movieId = movieId
    }
    
    // MARK: - Setup
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        
        // Đăng ký 4 cell XIB bằng UINib
        tableView.register(
            UINib(nibName: "MovieBackdropCell", bundle: nil),
            forCellReuseIdentifier: MovieBackdropCell.identifier
        )
        tableView.register(
            UINib(nibName: "MovieActionCell", bundle: nil),
            forCellReuseIdentifier: MovieActionCell.identifier
        )
        tableView.register(
            UINib(nibName: "MovieOverviewCell", bundle: nil),
            forCellReuseIdentifier: MovieOverviewCell.identifier
        )
        tableView.register(
            UINib(nibName: "MovieCastCell", bundle: nil),
            forCellReuseIdentifier: MovieCastCell.identifier
        )
        
        // Self-sizing cells
        tableView.estimatedRowHeight = 100
        tableView.rowHeight = UITableView.automaticDimension
        
        // Ẩn separator
        tableView.separatorStyle = .none
        
        // Cho phép table view scroll under navigation bar
        tableView.contentInsetAdjustmentBehavior = .never
    }
    
    // MARK: - API Calls (3 API gọi song song)
    
    private func fetchAllData() {
        fetchMovieDetail()
        fetchMovieCredits()
        fetchMovieVideos()
    }
    
    private func fetchMovieDetail() {
        APICaller.shared.getMovieDetail(movieId: movieId) { [weak self] result in
            switch result {
            case .success(let detail):
                DispatchQueue.main.async {
                    self?.movieDetail = detail
                    self?.navigationItem.title = detail.title
                    // Reload backdrop + overview sections
                    self?.tableView.reloadSections(
                        IndexSet([DetailSection.backdrop.rawValue, DetailSection.overview.rawValue]),
                        with: .automatic
                    )
                }
            case .failure(let error):
                print("[MovieDetailVC] Detail error: \(error.localizedDescription)")
            }
        }
    }
    
    private func fetchMovieCredits() {
        APICaller.shared.getMovieCredits(movieId: movieId) { [weak self] result in
            switch result {
            case .success(let cast):
                DispatchQueue.main.async {
                    self?.castMembers = cast
                    self?.tableView.reloadSections(
                        IndexSet([DetailSection.cast.rawValue]),
                        with: .automatic
                    )
                }
            case .failure(let error):
                print("[MovieDetailVC] Credits error: \(error.localizedDescription)")
            }
        }
    }

    private func fetchMovieVideos() {
        APICaller.shared.getMovieVideos(movieId: movieId) { [weak self] result in
            switch result {
            case .success(let videos):
                // Lọc trailer YouTube đầu tiên
                let trailer = videos.first { $0.type == "Trailer" && $0.site == "YouTube" }
                DispatchQueue.main.async {
                    self?.trailerKey = trailer?.key
                    self?.tableView.reloadSections(
                        IndexSet([DetailSection.actions.rawValue]),
                        with: .automatic
                    )
                }
            case .failure(let error):
                print("[MovieDetailVC] Videos error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - UITableViewDataSource

extension MovieDetailViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return DetailSection.allCases.count  // 4 sections
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1  // mỗi section chỉ có 1 row
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = DetailSection(rawValue: indexPath.section) else {
            return UITableViewCell()
        }
        
        switch section {
        case .backdrop:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: MovieBackdropCell.identifier,
                for: indexPath
            ) as! MovieBackdropCell
            
            if let detail = movieDetail {
                cell.configure(with: detail)
            }
            return cell
            
        case .actions:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: MovieActionCell.identifier,
                for: indexPath
            ) as! MovieActionCell
            
            cell.delegate = self  // để nhận sự kiện tap button
            cell.configure(hasTrailer: trailerKey != nil)
            return cell
            
        case .overview:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: MovieOverviewCell.identifier,
                for: indexPath
            ) as! MovieOverviewCell
            
            cell.configure(with: movieDetail?.overview)
            return cell
            
        case .cast:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: MovieCastCell.identifier,
                for: indexPath
            ) as! MovieCastCell
            
            cell.configure(with: castMembers)
            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension MovieDetailViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - MovieActionCellDelegate

extension MovieDetailViewController: MovieActionCellDelegate {
    
    func movieActionCellDidTapPlayTrailer(_ cell: MovieActionCell) {
        guard let key = trailerKey,
              let url = URL(string: "https://www.youtube.com/watch?v=\(key)") else {
            print("[MovieDetailVC] No trailer available")
            return
        }
        UIApplication.shared.open(url)
    }
    
    func movieActionCellDidTapDownload(_ cell: MovieActionCell) {
        // TODO: Implement download feature
        print("[MovieDetailVC] Download tapped — chưa implement")
    }
}
```

### 11.4. Giải thích kiến trúc

```
┌────────────────────────────────────────────────────┐
│            MovieDetailViewController               │
│                                                    │
│  ┌──────────────────────────────────────────┐      │
│  │ DetailSection enum (CaseIterable)        │      │
│  │  .backdrop = 0                           │      │
│  │  .actions  = 1                           │      │
│  │  .overview = 2                           │      │
│  │  .cast     = 3                           │      │
│  └──────────────────────────────────────────┘      │
│                                                    │
│  numberOfSections → DetailSection.allCases.count   │
│  cellForRowAt     → switch section { ... }         │
│                                                    │
│  Muốn thêm section mới? Thêm case vào enum!       │
│  Muốn đổi thứ tự? Đổi rawValue trong enum!        │
│  Muốn ẩn section? numberOfRowsInSection return 0!  │
└────────────────────────────────────────────────────┘
```

**Tại sao dùng `CaseIterable`?**
- `DetailSection.allCases.count` → tự động đếm số section
- Nếu thêm/xóa case trong enum, `numberOfSections` tự cập nhật
- Không cần hardcode magic number

**Tại sao `reloadSections` thay vì `reloadData`?**
- `reloadData()` reload TOÀN BỘ table → giật, mất animation
- `reloadSections(_:with:)` chỉ reload section có data mới → mượt, có animation

**Tại sao `UITableView.automaticDimension`?**
- Cell tự tính height dựa vào constraints trong XIB
- Không cần implement `heightForRowAt` cho từng cell
- Nếu overview text dài → cell tự cao hơn

---

## 12. BƯỚC 9 — Kết nối Navigation từ Home

> **Mục tiêu:** Khi user tap poster phim ở Home → push sang MovieDetailViewController.

### 12.1. Tạo Delegate Protocol cho CollectionViewTableViewCell

Mở file **`Views/CollectionViewTableViewCell.swift`**.

Thêm protocol ở **đầu file** (trước `class CollectionViewTableViewCell`):

```swift
// Delegate để thông báo cho ViewController khi user tap vào 1 phim
protocol CollectionViewTableViewCellDelegate: AnyObject {
    func collectionViewTableViewCellDidTapCell(_ cell: CollectionViewTableViewCell, movieId: Int)
}
```

### 12.2. Thêm delegate property vào class

```swift
class CollectionViewTableViewCell: UITableViewCell {
    
    static let indentifier = "CollectionViewTableViewCell"
    private var titles: [Title] = [Title]()
    
    // ✅ MỚI: Delegate để báo cho ViewController
    weak var delegate: CollectionViewTableViewCellDelegate?
    
    // ... phần còn lại giữ nguyên ...
}
```

### 12.3. Implement didSelectItemAt

Trong extension `UICollectionViewDelegate` ở cuối file, thêm method:

```swift
extension CollectionViewTableViewCell: UICollectionViewDelegate, UICollectionViewDataSource {
    
    // ... các method đã có giữ nguyên: numberOfItemsInSection, cellForItemAt ...
    
    // ✅ MỚI: Xử lý tap vào poster
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        let title = titles[indexPath.row]
        let movieId = title.id
        
        print("[CollectionCell] Tapped: \(title.original_title ?? title.original_name ?? "Unknown") (id: \(movieId))")
        
        delegate?.collectionViewTableViewCellDidTapCell(self, movieId: movieId)
    }
}
```

### 12.4. Set delegate trong HomeViewController

Mở **`Controllers/HomeViewController.swift`**.

Trong `cellForRowAt`, thêm **1 dòng** ngay sau khi dequeue cell:

```swift
func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard let cell = tableView.dequeueReusableCell(withIdentifier: CollectionViewTableViewCell.indentifier, for: indexPath) as? CollectionViewTableViewCell else {
        return UITableViewCell()
    }
    
    // ✅ MỚI: Set delegate để nhận sự kiện tap
    cell.delegate = self
    
    switch indexPath.section {
    // ... giữ nguyên tất cả switch cases ...
    }
    return cell
}
```

### 12.5. Implement delegate trong HomeViewController

Thêm **extension mới** ở cuối file `HomeViewController.swift`:

```swift
// MARK: - CollectionViewTableViewCellDelegate
extension HomeViewController: CollectionViewTableViewCellDelegate {
    
    func collectionViewTableViewCellDidTapCell(_ cell: CollectionViewTableViewCell, movieId: Int) {
        // Khởi tạo VC từ XIB bằng nibName
        let detailVC = MovieDetailViewController(
            nibName: "MovieDetailViewController",
            bundle: nil
        )
        detailVC.configure(with: movieId)
        detailVC.hidesBottomBarWhenPushed = true 
        navigationController?.pushViewController(detailVC, animated: true)
    }
}
```

### 12.6. Giải thích luồng hoàn chỉnh

```
1. User tap poster
         ↓
2. UICollectionView gọi didSelectItemAt
         ↓
3. CollectionViewTableViewCell gọi delegate.didTapCell(movieId)
         ↓
4. HomeViewController nhận event
         ↓
5. HomeVC tạo MovieDetailViewController(nibName:)
         ↓
6. HomeVC gọi detailVC.configure(with: movieId)
         ↓
7. HomeVC push detailVC lên navigation stack
         ↓
8. MovieDetailVC.viewDidLoad() → setupTableView() → fetchAllData()
         ↓
9. 3 API gọi song song → callback → reloadSections()
         ↓
10. 4 cell XIB hiển thị data
```

### 12.7. Tại sao dùng `nibName` khi init ViewController?

```swift
// ❌ KHÔNG DÙNG: init mặc định → iOS sẽ KHÔNG load file XIB
let vc = MovieDetailViewController()

// ✅ DÙNG: chỉ định nibName → iOS load file XIB tương ứng
let vc = MovieDetailViewController(nibName: "MovieDetailViewController", bundle: nil)
```

Khi bạn tạo VC bằng **Cocoa Touch Class + tick XIB**, Xcode KHÔNG tự liên kết.
Bạn phải chỉ rõ `nibName` khi khởi tạo VC.

**Ngoại lệ:** Nếu tên file `.xib` **TRÙNG CHÍNH XÁC** với tên class, bạn có thể dùng `nibName: nil`:
```swift
// Cũng OK vì tên class == tên file XIB
let vc = MovieDetailViewController(nibName: nil, bundle: nil)
```
Nhưng viết rõ `nibName` sẽ **tường minh hơn**, dễ debug hơn.

---

## 13. Tổng kết & Checklist

### Checklist tự kiểm tra

**Model:**
- [ ] `MovieDetail.swift` — có `MovieDetail`, `Genre`, `ProductionCompany`, `MovieCreditsResponse`, `CastMember`, `MovieVideosResponse`, `MovieVideo`

**Networking:**
- [ ] `APIEndpoint.swift` — có 3 case mới: `.movieDetail`, `.movieCredits`, `.movieVideos` + path + parameters
- [ ] `APICaller.swift` — có 3 hàm: `getMovieDetail`, `getMovieCredits`, `getMovieVideos`

**Cell XIBs (4 cặp file):**
- [ ] `MovieBackdropCell.swift` + `.xib` — backdrop, poster, title, meta, genre
- [ ] `MovieActionCell.swift` + `.xib` — 2 buttons + delegate protocol
- [ ] `MovieOverviewCell.swift` + `.xib` — header + overview text
- [ ] `MovieCastCell.swift` + `.xib` — header + cast list

**ViewController:**
- [ ] `MovieDetailViewController.swift` + `.xib` — UITableView, 4 sections, fetch 3 API song song

**Navigation:**
- [ ] `CollectionViewTableViewCell.swift` — protocol + delegate + didSelectItemAt
- [ ] `HomeViewController.swift` — set delegate + implement + push VC

**Kiểm tra chạy:**
- [ ] `Cmd + B` — build thành công
- [ ] `Cmd + R` — chạy app
- [ ] Tap poster → mở trang chi tiết
- [ ] Backdrop image hiển thị
- [ ] Poster image hiển thị
- [ ] Title, rating, runtime, year hiển thị đúng
- [ ] Genre hiển thị
- [ ] Overview hiển thị đầy đủ, scroll được
- [ ] Cast hiển thị tối đa 10 người
- [ ] Nút Play Trailer → mở YouTube
- [ ] Nút Back (navigation) → quay lại Home

### Lỗi thường gặp & cách sửa

| Lỗi | Nguyên nhân | Cách sửa |
|---|---|---|
| Crash: `loaded nib but view outlet was not set` | VC XIB chưa kết nối `view` | Click phải File's Owner → kéo `view` → root View |
| Cell height = 0 hoặc bị collapse | Thiếu constraint bottom trong XIB | Thêm constraint bottom của element cuối → Content View |
| Ảnh không hiển thị | Quên `import SDWebImage` hoặc URL sai | Kiểm tra import + URL path |
| Crash: `unexpectedly found nil` ở IBOutlet | Outlet chưa kết nối | Mở XIB → click phải cell → kiểm tra connections |
| Tap poster không phản hồi | Quên `cell.delegate = self` | Thêm dòng này trong `cellForRowAt` ở HomeVC |
| Build error: `Cannot find type` | File chưa add vào target | File Inspector → tick target `NetflixClone` |
| `register(UINib(...))` crash | Tên nibName không khớp tên file .xib | Kiểm tra chính tả chính xác |
| Console: `Unable to simultaneously satisfy constraints` | Conflict constraints trong XIB | Mở XIB → Issue Navigator (⌘5) → fix warnings |

### So sánh kiến thức: Trước vs Sau

| Trước (chỉ biết code) | Sau (biết XIB + code) |
|---|---|
| `init(frame:)` / `init(style:)` | `awakeFromNib()` |
| `addSubview(...)` | Kéo thả trong XIB |
| `NSLayoutConstraint.activate(...)` | Pin constraints trong XIB |
| `let view = UIView()` | `@IBOutlet weak var view: UIView!` |
| Không có preview | Thấy ngay layout trong XIB |
| 1 file Swift dài | Swift (logic) + XIB (UI) tách biệt |
| `register(Class.self)` | `register(UINib(nibName:), ...)` |
| Khó tái sử dụng component | Mỗi XIB cell là 1 component độc lập |

---

> 💡 **Mẹo cuối:**
> - Khi gặp lỗi constraint, xem **Issue Navigator** (`Cmd + 5`) — Xcode chỉ rõ thiếu gì.
> - Khi IBOutlet bị đứt kết nối, click phải vào cell/File's Owner trong XIB → thấy dấu ⚠️ vàng.
> - Nếu muốn thêm section mới (ví dụ: Similar Movies), chỉ cần: tạo cell XIB + thêm case vào enum + register + switch case. Pattern mở rộng rất dễ!

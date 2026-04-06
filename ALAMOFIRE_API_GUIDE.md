# 📖 Hướng dẫn tích hợp Alamofire & tạo Base Network Layer

> **Mục đích:** Thay thế các `URLSession.shared.dataTask` lặp đi lặp lại trong `APICaller.swift` bằng một lớp network base chung sử dụng [Alamofire](https://github.com/Alamofire/Alamofire) — giúp code gọn hơn, dễ mở rộng và dễ bảo trì hơn.
>
> **Vấn đề hiện tại:** Mỗi hàm trong `APICaller.swift` đều lặp lại cùng một đoạn code: tạo URL → gọi `URLSession` → check error → decode JSON. Tổng cộng **5 hàm**, mỗi hàm ~15 dòng, gần như giống hệt nhau.

---

## Mục lục

1. [Phân tích vấn đề hiện tại](#1-phân-tích-vấn-đề-hiện-tại)
2. [Tổng quan kiến trúc mới](#2-tổng-quan-kiến-trúc-mới)
3. [Cài đặt Alamofire bằng CocoaPods](#3-cài-đặt-alamofire)
4. [Tạo NetworkManager (Base Layer)](#4-tạo-networkmanager)
5. [Tạo APIEndpoint (Enum các endpoint)](#5-tạo-apiendpoint)
6. [Refactor APICaller](#6-refactor-apicaller)
7. [Không cần sửa HomeViewController](#7-không-cần-sửa-homeviewcontroller)
8. [Mở rộng thêm endpoint mới](#8-mở-rộng-thêm-endpoint)
9. [Xử lý lỗi nâng cao](#9-xử-lý-lỗi-nâng-cao)
10. [Lỗi thường gặp & Xử lý](#10-lỗi-thường-gặp)

---

## 1. Phân tích vấn đề hiện tại

### Code bị lặp trong APICaller.swift

Nhìn vào `APICaller.swift` hiện tại, 5 hàm đều có cấu trúc giống hệt nhau:

```swift
// ❌ Pattern lặp lại ở MỌI hàm — chỉ khác nhau ở URL
func getTrendingMovies(completion: @escaping (Result<[Title], Error>) -> Void) {
    guard let url = URL(string: "\(Constants.baseURL)/3/trending/movie/day?api_key=\(Constants.API_KEY)") else {
        return  // ❌ Silent fail — không báo lỗi nếu URL invalid
    }
    let task = URLSession.shared.dataTask(with: url) { data, _, error in
        guard let data = data, error == nil else {
            completion(.failure(APIError.failedToGetData))  // ❌ Lỗi generic, không biết nguyên nhân
            return
        }
        do {
            let results = try JSONDecoder().decode(TrendingTitleResponse.self, from: data)
            completion(.success(results.results))
        } catch {
            completion(.failure(APIError.failedToGetData))  // ❌ Lỗi generic, nuốt mất decode error
        }
    }
    task.resume()
}
```

### Danh sách vấn đề cụ thể

| Vấn đề | Chi tiết |
|---|---|
| **Lặp code** | URLSession boilerplate lặp 5 lần — thêm endpoint mới phải copy-paste |
| **Không có logging** | Không log request/response — debug khó |
| **Lỗi generic** | `APIError.failedToGetData` cho mọi loại lỗi (network, decode, ...) |
| **Silent fail** | `guard let url = URL(...) else { return }` — không gọi completion khi URL lỗi |
| **Không retry** | Không có cơ chế tự retry khi timeout |
| **Khó test** | Dependency cứng vào `URLSession.shared` — không mock được |
| **Không có header chung** | Mỗi hàm phải tự thêm API key vào URL — không có `Authorization` header tập trung |

---

## 2. Tổng quan kiến trúc mới

### So sánh trước và sau

```
TRƯỚC:
HomeViewController
    └── APICaller (5 hàm, mỗi hàm = URLSession boilerplate)

SAU:
HomeViewController
    └── APICaller (5 hàm, mỗi hàm = 1 dòng gọi NetworkManager)
            └── NetworkManager (base layer dùng Alamofire)
                    └── APIEndpoint (enum định nghĩa các endpoint)
```

### Luồng request

```
APICaller.getTrendingMovies()
    → NetworkManager.request(endpoint: .trendingMovies, responseType: TrendingTitleResponse.self)
        → Alamofire.AF.request(url, method, headers, parameters)
            → Decode JSON → TrendingTitleResponse
                → Trả về [Title] về APICaller
                    → HomeViewController nhận kết quả
```

### Các file sẽ tạo/sửa

| File | Hành động | Mô tả |
|---|---|---|
| `Managers/NetworkManager.swift` | **TẠO MỚI** | Base layer — toàn bộ logic Alamofire ở đây |
| `Managers/APIEndpoint.swift` | **TẠO MỚI** | Enum định nghĩa tất cả endpoint: URL, method, params |
| `Managers/APICaller.swift` | **SỬA LẠI** | Chỉ còn gọi NetworkManager — không còn boilerplate |
| `Podfile` | **SỬA THÊM** | Thêm pod Alamofire |
| `HomeViewController.swift` | **KHÔNG SỬA** | Không cần thay đổi gì ✅ |

---

## 3. Cài đặt Alamofire

### 3.1 Sửa Podfile

Mở `Podfile` tại thư mục gốc project và thêm Alamofire:

```ruby
platform :ios, '15.0'

target 'NetflixClone' do
  use_frameworks!

  # Database (đã có từ trước)
  pod 'GRDB.swift/SQLCipher'
  pod 'SQLCipher', '~> 4.0'

  # Networking — thêm mới
  pod 'Alamofire', '~> 5.0'
end
```

> ⚠️ **Lưu ý version:** Dùng Alamofire 5.x (Swift concurrency-compatible). Không dùng 4.x vì đã deprecated.

### 3.2 Cài đặt

```bash
cd /Users/hd/Documents/GitHub/NetflixClone
pod install
```

### 3.3 Verify

Mở `.xcworkspace`, build project (⌘B). Thêm test import vào bất kỳ file nào:

```swift
import Alamofire  // ← Nếu không báo lỗi = cài đúng
```

---

## 4. Tạo NetworkManager

Tạo file mới: `NetflixClone/Managers/NetworkManager.swift`

```swift
//
//  NetworkManager.swift
//  NetflixClone
//
//  Base network layer dùng Alamofire.
//  Tất cả API call đều đi qua đây — không gọi Alamofire trực tiếp ở nơi khác.
//

import Foundation
import Alamofire

class NetworkManager {

    // MARK: - Singleton
    static let shared = NetworkManager()

    // MARK: - Session
    /// Dùng Alamofire Session thay vì AF global để dễ cấu hình và test
    private let session: Session

    // MARK: - Init
    private init() {
        // Cấu hình timeout
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30    // Timeout mỗi request: 30 giây
        config.timeoutIntervalForResource = 60   // Timeout tổng: 60 giây
        config.waitsForConnectivity = true       // Chờ có mạng thay vì fail ngay

        self.session = Session(configuration: config)
    }

    // MARK: - Generic Request

    /// Hàm request chung — tất cả API call đều gọi hàm này
    /// - Parameters:
    ///   - endpoint: Enum APIEndpoint định nghĩa URL, method, params
    ///   - responseType: Kiểu Decodable cần decode về (VD: TrendingTitleResponse.self)
    ///   - completion: Callback trả về Result<T, NetworkError>
    func request<T: Decodable>(
        endpoint: APIEndpoint,
        responseType: T.Type,
        completion: @escaping (Result<T, NetworkError>) -> Void
    ) {
        let url = endpoint.fullURL

        // Log request (chỉ hiện trong Debug build)
        #if DEBUG
        print("🌐 [NetworkManager] → \(endpoint.method.rawValue.uppercased()) \(url)")
        if let params = endpoint.parameters, !params.isEmpty {
            print("   Params: \(params)")
        }
        #endif

        session.request(
            url,
            method: endpoint.method,
            parameters: endpoint.parameters,
            encoding: URLEncoding.default,
            headers: endpoint.headers
        )
        .validate(statusCode: 200..<300)       // Tự động fail nếu HTTP status không phải 2xx
        .responseDecodable(of: responseType) { response in

            // Log response
            #if DEBUG
            let statusCode = response.response?.statusCode ?? 0
            print("   ← [\(statusCode)] \(url)")
            #endif

            switch response.result {
            case .success(let decodedData):
                completion(.success(decodedData))

            case .failure(let afError):
                let networkError = NetworkManager.mapError(afError, response: response)
                #if DEBUG
                print("   ❌ Error: \(networkError.localizedDescription)")
                #endif
                completion(.failure(networkError))
            }
        }
    }

    // MARK: - Error Mapping

    /// Chuyển AFError sang NetworkError — lỗi rõ ràng hơn cho caller xử lý
    private static func mapError<T>(_ afError: AFError, response: DataResponse<T, AFError>) -> NetworkError {
        if let statusCode = response.response?.statusCode {
            switch statusCode {
            case 401: return .unauthorized          // API key không hợp lệ
            case 404: return .notFound              // Endpoint không tồn tại
            case 429: return .rateLimited           // Quá nhiều request
            case 500...599: return .serverError     // Lỗi phía server
            default: break
            }
        }

        if afError.isSessionTaskError {
            return .noInternet                      // Không có mạng
        }

        if afError.isResponseSerializationError {
            return .decodingFailed                  // Decode JSON thất bại
        }

        return .unknown(afError.localizedDescription)
    }
}

// MARK: - NetworkError

/// Các loại lỗi network — chi tiết hơn APIError cũ chỉ có `failedToGetData`
enum NetworkError: Error {
    case noInternet                 // Không có kết nối mạng
    case unauthorized               // API key sai hoặc hết hạn
    case notFound                   // Endpoint không tồn tại (404)
    case rateLimited                // Quá nhiều request (429)
    case serverError                // Lỗi server 5xx
    case decodingFailed             // Không parse được JSON response
    case invalidURL                 // URL không hợp lệ
    case unknown(String)            // Lỗi khác — kèm description

    var localizedDescription: String {
        switch self {
        case .noInternet:       return "Không có kết nối mạng. Vui lòng kiểm tra wifi/data."
        case .unauthorized:     return "API key không hợp lệ hoặc đã hết hạn."
        case .notFound:         return "Không tìm thấy dữ liệu yêu cầu."
        case .rateLimited:      return "Quá nhiều yêu cầu. Vui lòng thử lại sau."
        case .serverError:      return "Lỗi máy chủ. Vui lòng thử lại sau."
        case .decodingFailed:   return "Lỗi xử lý dữ liệu từ server."
        case .invalidURL:       return "URL không hợp lệ."
        case .unknown(let msg): return "Lỗi không xác định: \(msg)"
        }
    }
}
```

**Giải thích các quyết định thiết kế:**

| Quyết định | Lý do |
|---|---|
| `Session` thay vì `AF` global | Dễ cấu hình timeout, interceptor, và có thể mock khi test |
| `validate(statusCode: 200..<300)` | Alamofire tự convert HTTP error thành Swift Error — không phải check thủ công |
| `responseDecodable` | Alamofire tự decode JSON trong background queue, không block main thread |
| `#if DEBUG` logging | Log chỉ xuất hiện khi dev — production sạch log |
| `NetworkError` enum | Phân loại lỗi rõ ràng để UI có thể hiển thị message phù hợp cho user |

---

## 5. Tạo APIEndpoint

Tạo file mới: `NetflixClone/Managers/APIEndpoint.swift`

```swift
//
//  APIEndpoint.swift
//  NetflixClone
//
//  Định nghĩa tất cả API endpoint tập trung tại một chỗ.
//  Khi cần thêm endpoint mới: chỉ thêm case vào enum này.
//

import Foundation
import Alamofire

// MARK: - API Constants

private enum APIConstants {
    static let apiKey   = "ac90e227bedf46c08087b19100afc0f1"
    static let baseURL  = "https://api.themoviedb.org/3"
    static let language = "en-US"
}

// MARK: - APIEndpoint

/// Enum tập trung toàn bộ endpoint của TMDB API
/// Thêm endpoint mới = thêm 1 case + implement computed properties bên dưới
enum APIEndpoint {

    // MARK: - Trending
    case trendingMovies                     // GET /trending/movie/day
    case trendingTV                         // GET /trending/tv/day

    // MARK: - Movies
    case popularMovies                      // GET /movie/popular
    case upcomingMovies                     // GET /movie/upcoming
    case topRatedMovies                     // GET /movie/top_rated

    // MARK: - Search (ví dụ mở rộng sau)
    case searchMovies(query: String)        // GET /search/movie?query=...
}

// MARK: - Endpoint Properties

extension APIEndpoint {

    /// Đường dẫn path của endpoint (không bao gồm baseURL)
    var path: String {
        switch self {
        case .trendingMovies:           return "/trending/movie/day"
        case .trendingTV:               return "/trending/tv/day"
        case .popularMovies:            return "/movie/popular"
        case .upcomingMovies:           return "/movie/upcoming"
        case .topRatedMovies:           return "/movie/top_rated"
        case .searchMovies:             return "/search/movie"
        }
    }

    /// HTTP method — mặc định GET cho tất cả TMDB endpoint
    var method: HTTPMethod {
        return .get
    }

    /// URL đầy đủ = baseURL + path
    var fullURL: String {
        return APIConstants.baseURL + path
    }

    /// Query parameters — API key và các param khác tự động thêm vào
    var parameters: Parameters? {
        // Parameters chung cho tất cả endpoint
        var params: Parameters = [
            "api_key": APIConstants.apiKey,
            "language": APIConstants.language
        ]

        // Parameters riêng theo từng endpoint
        switch self {
        case .searchMovies(let query):
            params["query"] = query
            params["page"] = 1
        case .popularMovies, .upcomingMovies, .topRatedMovies:
            params["page"] = 1
        default:
            break
        }

        return params
    }

    /// HTTP Headers — Bearer token, Content-Type, ...
    var headers: HTTPHeaders {
        return [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
        // Nếu dùng Bearer token thay vì API key:
        // "Authorization": "Bearer \(APIConstants.bearerToken)"
    }
}
```

**Tại sao dùng enum thay vì string URL?**

| | String URL (cũ) | APIEndpoint enum (mới) |
|---|---|---|
| **Thêm endpoint** | Copy-paste URL vào hàm mới | Thêm 1 `case` vào enum |
| **Sửa baseURL** | Phải sửa ở nhiều chỗ | Sửa 1 chỗ trong `APIConstants` |
| **Sửa API key** | Sửa ở `Constants.API_KEY` (OK nếu dùng struct) | Sửa 1 chỗ trong `APIConstants` |
| **Compile-time check** | Không — runtime mới biết URL sai | Có — compiler báo lỗi nếu quên implement case mới |
| **Xem tất cả endpoint** | Phải search codebase | Nhìn 1 enum là thấy hết |

---

## 6. Refactor APICaller

Sửa lại `NetflixClone/Managers/APICaller.swift` — **toàn bộ URLSession boilerplate được xoá**:

```swift
//
//  APICaller.swift
//  NetflixClone
//
//  Tầng API chuyên biệt — định nghĩa các hàm fetch dữ liệu nghiệp vụ.
//  Không chứa logic HTTP — tất cả delegate cho NetworkManager.
//

import Foundation

class APICaller {

    // MARK: - Singleton
    static let shared = APICaller()
    private init() {}

    // MARK: - Trending

    func getTrendingMovies(completion: @escaping (Result<[Title], Error>) -> Void) {
        NetworkManager.shared.request(
            endpoint: .trendingMovies,
            responseType: TrendingTitleResponse.self
        ) { result in
            // .map(\.results)  — lấy [Title] từ TrendingTitleResponse
            // .mapError { $0 as Error }  — ép kiểu NetworkError → Error (Swift không tự coerce generic)
            completion(result.map(\.results).mapError { $0 as Error })
        }
    }

    func getTrendingTVs(completion: @escaping (Result<[Title], Error>) -> Void) {
        NetworkManager.shared.request(
            endpoint: .trendingTV,
            responseType: TrendingTitleResponse.self
        ) { result in
            completion(result.map(\.results).mapError { $0 as Error })
        }
    }

    // MARK: - Movies

    func getPopularMovies(completion: @escaping (Result<[Title], Error>) -> Void) {
        NetworkManager.shared.request(
            endpoint: .popularMovies,
            responseType: TrendingTitleResponse.self
        ) { result in
            completion(result.map(\.results).mapError { $0 as Error })
        }
    }

    func getUpcomingMovies(completion: @escaping (Result<[Title], Error>) -> Void) {
        NetworkManager.shared.request(
            endpoint: .upcomingMovies,
            responseType: TrendingTitleResponse.self
        ) { result in
            completion(result.map(\.results).mapError { $0 as Error })
        }
    }

    func getTopRated(completion: @escaping (Result<[Title], Error>) -> Void) {
        NetworkManager.shared.request(
            endpoint: .topRatedMovies,
            responseType: TrendingTitleResponse.self
        ) { result in
            completion(result.map(\.results).mapError { $0 as Error })
        }
    }
}
```

### So sánh số dòng code

| | Trước | Sau |
|---|---|---|
| `APICaller.swift` | **117 dòng** (5 hàm × ~15 dòng boilerplate) | **~50 dòng** (5 hàm × ~5 dòng) |
| Thêm endpoint mới | Copy-paste 15 dòng | Thêm `case` vào enum + 5 dòng vào APICaller |
| Sửa timeout | Không làm được | Sửa 1 chỗ trong `NetworkManager.init()` |
| Debug request log | Không có | Tự động log mọi request (DEBUG only) |

> **Lưu ý về `.map(\.results).mapError { $0 as Error }`:**  
> - `.map(\.results)` = `.map { $0.results }` — lấy array `[Title]` từ trong wrapper `TrendingTitleResponse`.  
> - `.mapError { $0 as Error }` — cần thiết vì Swift **không tự coerce** generic type parameter. Dù `NetworkError: Error`, nhưng `Result<[Title], NetworkError>` và `Result<[Title], any Error>` là 2 type riêng biệt. Bước này ép kiểu tường minh để tương thích với signature của APICaller.

---

## 7. Không cần sửa HomeViewController

`HomeViewController.swift` **không cần thay đổi dòng nào** vì:

- `APICaller.shared.getTrendingMovies { result in ... }` — signature vẫn giữ nguyên
- `result` vẫn là `Result<[Title], Error>` — `.success`, `.failure` hoạt động y hệt trước

✅ **Backward compatible hoàn toàn.**

---

## 8. Mở rộng thêm endpoint

Ví dụ: muốn thêm tính năng **Search phim** sau này.

### Bước 1: Thêm case vào APIEndpoint.swift (đã có sẵn)

```swift
// Đã có trong enum APIEndpoint:
case searchMovies(query: String)
```

### Bước 2: Thêm hàm vào APICaller.swift

```swift
func searchMovies(with query: String, completion: @escaping (Result<[Title], Error>) -> Void) {
    NetworkManager.shared.request(
        endpoint: .searchMovies(query: query),
        responseType: TrendingTitleResponse.self
    ) { result in
        completion(result.map(\.results))
    }
}
```

### Bước 3: Gọi từ ViewController

```swift
APICaller.shared.searchMovies(with: "Spider-Man") { result in
    switch result {
    case .success(let titles):
        print("Tìm thấy \(titles.count) kết quả")
    case .failure(let error):
        print(error.localizedDescription)
    }
}
```

**Tổng cộng chỉ cần thêm ~5 dòng** — không phải copy-paste URLSession boilerplate như trước.

---

## 9. Xử lý lỗi nâng cao

### 9.1 Hiển thị lỗi cụ thể cho user

Với `NetworkError` enum mới, ViewController có thể hiển thị message phù hợp:

```swift
case .failure(let error):
    if let networkError = error as? NetworkError {
        switch networkError {
        case .noInternet:
            // Hiển thị offline banner
            self?.showOfflineBanner()
            // Fallback sang cache
            let cached = DatabaseManager.shared.fetchTitles(section: "trending_movies")
            if !cached.isEmpty { cell.configure(with: cached) }

        case .rateLimited:
            // Hiển thị alert "Quá nhiều request"
            self?.showAlert(message: networkError.localizedDescription)

        default:
            print(networkError.localizedDescription)
        }
    }
```

### 9.2 Retry tự động với Alamofire RequestRetrier

Nếu muốn tự động retry khi timeout, thêm `RetryPolicy` vào `NetworkManager.init()`:

```swift
// Thêm vào NetworkManager.init():
let retrier = RetryPolicy(retryLimit: 3, exponentialBackoffBase: 2)
self.session = Session(configuration: config, interceptor: retrier)
```

> Alamofire's `RetryPolicy` tự retry tối đa 3 lần với exponential backoff (1s, 2s, 4s) khi gặp network timeout.

### 9.3 Thêm Authorization header

Khi API cần Bearer token (thay vì API key trong URL):

```swift
// Trong APIEndpoint.headers:
var headers: HTTPHeaders {
    return [
        "Authorization": "Bearer \(TokenManager.shared.accessToken)",
        "Content-Type": "application/json"
    ]
}
```

---

## 10. Lỗi thường gặp

### 10.1 Build errors

| Lỗi | Nguyên nhân | Cách sửa |
|---|---|---|
| `No such module 'Alamofire'` | Chưa `pod install` hoặc đang mở `.xcodeproj` | Chạy `pod install`, mở `.xcworkspace` |
| `Cannot find type 'HTTPMethod'` | Quên `import Alamofire` trong `APIEndpoint.swift` | Thêm `import Alamofire` ở đầu file |
| `Value of type 'Result<T, NetworkError>' has no member 'map'` | `map` chỉ có trên `Result` từ Swift 5+ | Đảm bảo deployment target ≥ iOS 13 |
| Conflict giữa các pod | Alamofire và GRDB cùng link SQLite | Thường không xảy ra, nếu có thì `pod deintegrate && pod install` |

### 10.2 Runtime errors

| Lỗi | Nguyên nhân | Cách sửa |
|---|---|---|
| `AFError: response validation failed` | HTTP status 4xx/5xx | Kiểm tra API key còn hợp lệ không, log statusCode |
| `AFError: responseSerializationFailed` | JSON response không match model | In `response.data` để xem JSON thực tế |
| Request không được gọi | `session` bị deinit trước khi complete | Đảm bảo dùng singleton `NetworkManager.shared` |
| Kết quả trả về trên background thread | Alamofire gọi completion trên Main Queue theo mặc định | Không cần `DispatchQueue.main.async` ở APICaller, nhưng cần ở ViewController khi update UI |

### 10.3 Debug tips

```swift
// Xem raw JSON response khi có lỗi decode
session.request(url, ...)
    .responseData { response in
        if let data = response.data {
            print(String(data: data, encoding: .utf8) ?? "nil")
        }
    }
```

---

## Tổng kết — Checklist thực hành

```
[ ] 1. Thêm `pod 'Alamofire', '~> 5.0'` vào Podfile
[ ] 2. Chạy `pod install`, mở lại .xcworkspace
[ ] 3. Tạo file Managers/NetworkManager.swift (base layer)
[ ] 4. Tạo file Managers/APIEndpoint.swift (enum endpoints)
[ ] 5. Xoá toàn bộ nội dung APICaller.swift, viết lại theo hướng dẫn
[ ] 6. Build project (⌘B) — đảm bảo không lỗi
[ ] 7. Run app — kiểm tra console log thấy "🌐 [NetworkManager] → GET ..."
[ ] 8. Test offline: tắt mạng → app vẫn load data từ cache (DatabaseManager)
```

> **Tip:** Sau khi refactor xong, thêm endpoint mới cho bất kỳ TMDB endpoint nào chỉ mất ~5 phút:
> 1. Thêm `case` vào `APIEndpoint` enum
> 2. Implement `path` và `parameters` cho case đó
> 3. Thêm hàm ~5 dòng vào `APICaller`
> 4. Done ✅

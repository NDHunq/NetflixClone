//
//  NetworkError.swift
//  NetflixClone
//
//  Created by NDHunq on 11/4/26.
//

enum NetworkError: Error {
    case noInternet
    case unauthorized
    case notFound
    case rateLimited
    case serverError
    case decodingFailed
    case invalidURL
    case unknown(String)
    
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

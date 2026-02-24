import Foundation

/// URL Scheme 模型
struct URLScheme: Identifiable, Codable, Hashable {

    // MARK: - Properties

    let id: UUID
    let scheme: String
    var displayName: String

    // MARK: - Computed Properties

    /// 显示用的 scheme 字符串（如 "https://"）
    var schemeString: String {
        return "\(scheme)://"
    }

    // MARK: - Initialization

    init(id: UUID = UUID(), scheme: String, displayName: String) {
        self.id = id
        self.scheme = scheme.lowercased()
        self.displayName = displayName
    }
}

// MARK: - CustomStringConvertible

extension URLScheme: CustomStringConvertible {
    var description: String {
        return "\(displayName) (\(schemeString))"
    }
}

// MARK: - Comparable

extension URLScheme: Comparable {
    static func < (lhs: URLScheme, rhs: URLScheme) -> Bool {
        return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
    }
}

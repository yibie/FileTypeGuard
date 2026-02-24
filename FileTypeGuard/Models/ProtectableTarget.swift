import Foundation

/// 可保护目标：文件类型或 URL Scheme
enum ProtectableTarget: Codable, Hashable {
    case fileType(FileType)
    case urlScheme(URLScheme)

    // MARK: - Computed Properties

    /// 显示名称
    var displayName: String {
        switch self {
        case .fileType(let ft):
            return ft.localizedDisplayName
        case .urlScheme(let scheme):
            return scheme.displayName
        }
    }

    /// 查找键：UTI 字符串（文件类型）或 scheme 字符串（URL Scheme）
    var lookupKey: String {
        switch self {
        case .fileType(let ft):
            return ft.uti
        case .urlScheme(let scheme):
            return scheme.scheme
        }
    }

    /// 是否为文件类型
    var isFileType: Bool {
        if case .fileType = self { return true }
        return false
    }

    /// 是否为 URL Scheme
    var isURLScheme: Bool {
        if case .urlScheme = self { return true }
        return false
    }
}

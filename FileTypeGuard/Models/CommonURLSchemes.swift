import Foundation

/// 常见 URL Scheme 预设清单
struct CommonURLSchemes {

    /// URL Scheme 分类
    enum Category: String, CaseIterable, Identifiable {
        case web
        case communication
        case system

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .web: return String(localized: "category_web")
            case .communication: return String(localized: "category_communication")
            case .system: return String(localized: "category_system")
            }
        }

        var icon: String {
            switch self {
            case .web: return "globe"
            case .communication: return "message.fill"
            case .system: return "gearshape.fill"
            }
        }
    }

    /// 预设 URL Scheme 定义
    struct PresetURLScheme: Identifiable, Hashable {
        let id = UUID()
        let displayName: String
        let scheme: String
        let category: Category
        let icon: String

        /// 转换为 URLScheme
        func toURLScheme() -> URLScheme {
            URLScheme(
                scheme: scheme,
                displayName: displayName
            )
        }
    }

    // MARK: - 预设列表

    static let allSchemes: [PresetURLScheme] = [
        // Web
        PresetURLScheme(
            displayName: String(localized: "scheme_http"),
            scheme: "http",
            category: .web,
            icon: "globe"
        ),
        PresetURLScheme(
            displayName: String(localized: "scheme_https"),
            scheme: "https",
            category: .web,
            icon: "lock.fill"
        ),
        PresetURLScheme(
            displayName: String(localized: "scheme_ftp"),
            scheme: "ftp",
            category: .web,
            icon: "externaldrive.connected.to.line.below.fill"
        ),

        // Communication
        PresetURLScheme(
            displayName: String(localized: "scheme_mailto"),
            scheme: "mailto",
            category: .communication,
            icon: "envelope.fill"
        ),
        PresetURLScheme(
            displayName: String(localized: "scheme_tel"),
            scheme: "tel",
            category: .communication,
            icon: "phone.fill"
        ),
        PresetURLScheme(
            displayName: String(localized: "scheme_sms"),
            scheme: "sms",
            category: .communication,
            icon: "message.fill"
        ),
        PresetURLScheme(
            displayName: String(localized: "scheme_facetime"),
            scheme: "facetime",
            category: .communication,
            icon: "video.fill"
        ),
        PresetURLScheme(
            displayName: String(localized: "scheme_facetime_audio"),
            scheme: "facetime-audio",
            category: .communication,
            icon: "phone.arrow.up.right.fill"
        ),

        // System
        PresetURLScheme(
            displayName: String(localized: "scheme_ssh"),
            scheme: "ssh",
            category: .system,
            icon: "terminal.fill"
        ),
        PresetURLScheme(
            displayName: String(localized: "scheme_vnc"),
            scheme: "vnc",
            category: .system,
            icon: "desktopcomputer"
        ),
        PresetURLScheme(
            displayName: String(localized: "scheme_maps"),
            scheme: "maps",
            category: .system,
            icon: "map.fill"
        ),
        PresetURLScheme(
            displayName: String(localized: "scheme_itms"),
            scheme: "itms-apps",
            category: .system,
            icon: "bag.fill"
        ),
    ]

    // MARK: - 辅助方法

    /// 按分类组织 URL Scheme
    static func schemesByCategory() -> [Category: [PresetURLScheme]] {
        var result: [Category: [PresetURLScheme]] = [:]
        for category in Category.allCases {
            result[category] = allSchemes.filter { $0.category == category }
        }
        return result
    }

    /// 查找 URL Scheme
    static func find(scheme: String) -> PresetURLScheme? {
        allSchemes.first { $0.scheme == scheme.lowercased() }
    }
}

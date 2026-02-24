import Foundation

/// 保护规则模型
struct ProtectionRule: Identifiable, Hashable {

    // MARK: - Properties

    let id: UUID
    var target: ProtectableTarget
    var expectedApplication: Application
    var isEnabled: Bool
    let createdAt: Date
    var lastVerified: Date?
    var notes: String?

    // MARK: - Computed Properties

    var displayName: String {
        return "\(target.displayName) → \(expectedApplication.name)"
    }

    /// 便捷访问：如果目标是文件类型，返回 FileType
    var fileType: FileType? {
        if case .fileType(let ft) = target { return ft }
        return nil
    }

    /// 便捷访问：如果目标是 URL Scheme，返回 URLScheme
    var urlScheme: URLScheme? {
        if case .urlScheme(let scheme) = target { return scheme }
        return nil
    }

    var statusDescription: String {
        if isEnabled {
            if let lastVerified = lastVerified {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .short
                let timeString = formatter.localizedString(for: lastVerified, relativeTo: Date())
                return String(localized: "enabled") + " • " + String(localized: "last verified: \(timeString)")
            }
            return String(localized: "enabled")
        }
        return String(localized: "disabled")
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        target: ProtectableTarget,
        expectedApplication: Application,
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        lastVerified: Date? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.target = target
        self.expectedApplication = expectedApplication
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.lastVerified = lastVerified
        self.notes = notes
    }

    /// 便捷初始化：从 FileType 创建（保持向后兼容的 API）
    init(
        id: UUID = UUID(),
        fileType: FileType,
        expectedApplication: Application,
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        lastVerified: Date? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.target = .fileType(fileType)
        self.expectedApplication = expectedApplication
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.lastVerified = lastVerified
        self.notes = notes
    }

    /// 便捷初始化：从 URLScheme 创建
    init(
        id: UUID = UUID(),
        urlScheme: URLScheme,
        expectedApplication: Application,
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        lastVerified: Date? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.target = .urlScheme(urlScheme)
        self.expectedApplication = expectedApplication
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.lastVerified = lastVerified
        self.notes = notes
    }

    // MARK: - Validation

    /// 验证规则是否有效（应用是否仍存在）
    func isValid() -> Bool {
        return expectedApplication.isInstalled()
    }

    /// 更新最后验证时间
    mutating func updateLastVerified() {
        self.lastVerified = Date()
    }
}

// MARK: - Codable (backward compatible)

extension ProtectionRule: Codable {
    enum CodingKeys: String, CodingKey {
        case id, target, expectedApplication, isEnabled, createdAt, lastVerified, notes
        // Legacy key
        case fileType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        expectedApplication = try container.decode(Application.self, forKey: .expectedApplication)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastVerified = try container.decodeIfPresent(Date.self, forKey: .lastVerified)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)

        // 尝试解码新的 target 字段，若不存在则回退到旧的 fileType 字段
        if let t = try? container.decode(ProtectableTarget.self, forKey: .target) {
            target = t
        } else {
            let ft = try container.decode(FileType.self, forKey: .fileType)
            target = .fileType(ft)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(target, forKey: .target)
        try container.encode(expectedApplication, forKey: .expectedApplication)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(lastVerified, forKey: .lastVerified)
        try container.encodeIfPresent(notes, forKey: .notes)
    }
}

// MARK: - CustomStringConvertible

extension ProtectionRule: CustomStringConvertible {
    var description: String {
        return displayName
    }
}

// MARK: - Comparable

extension ProtectionRule: Comparable {
    static func < (lhs: ProtectionRule, rhs: ProtectionRule) -> Bool {
        return lhs.target.displayName.localizedCaseInsensitiveCompare(rhs.target.displayName) == .orderedAscending
    }
}

// MARK: - Convenience Extensions

extension ProtectionRule {

    /// 创建示例规则（用于预览和测试）
    static var preview: ProtectionRule {
        let fileType = FileType(
            uti: "com.adobe.pdf",
            extensions: [".pdf"],
            displayName: "PDF Document"
        )

        let app = Application(
            bundleID: "com.apple.Preview",
            name: "Preview",
            path: "/System/Applications/Preview.app"
        )

        return ProtectionRule(
            fileType: fileType,
            expectedApplication: app
        )
    }
}

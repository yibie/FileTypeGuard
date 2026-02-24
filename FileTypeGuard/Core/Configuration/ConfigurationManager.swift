import Foundation

extension Notification.Name {
    static let protectionRulesDidChange = Notification.Name("protectionRulesDidChange")
}

/// 配置管理器
/// 负责保护规则的持久化存储和加载
final class ConfigurationManager {

    // MARK: - Singleton

    static let shared = ConfigurationManager()
    private init() {}

    // MARK: - Properties

    private let fileManager = FileManager.default
    private var configurationURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("FileTypeGuard")

        // 确保目录存在
        try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)

        return appDirectory.appendingPathComponent("config.json")
    }

    // MARK: - Configuration Model

    struct Configuration: Codable {
        var version: String
        var protectedTypes: [ProtectionRule]
        var preferences: UserPreferences
        var lastModified: Date

        init(
            version: String = "1.0",
            protectedTypes: [ProtectionRule] = [],
            preferences: UserPreferences = UserPreferences(),
            lastModified: Date = Date()
        ) {
            self.version = version
            self.protectedTypes = protectedTypes
            self.preferences = preferences
            self.lastModified = lastModified
        }
    }

    /// 用户偏好设置
    struct UserPreferences: Codable {
        var monitoringEnabled: Bool = true
        var checkInterval: TimeInterval = 5.0
        var recoveryStrategy: RecoveryStrategy = .immediate
        var showNotifications: Bool = true
        var notificationSound: Bool = true
        var autoRecoveryEnabled: Bool = true
        var logRetentionDays: Int = 30
        var startAtLogin: Bool = false
    }

    // MARK: - Error Types

    enum ConfigError: Error {
        case loadFailed(Error)
        case saveFailed(Error)
        case corruptedData
        case directoryCreationFailed

        var localizedDescription: String {
            switch self {
            case .loadFailed(let error):
                return "加载配置失败: \(error.localizedDescription)"
            case .saveFailed(let error):
                return "保存配置失败: \(error.localizedDescription)"
            case .corruptedData:
                return "配置文件已损坏"
            case .directoryCreationFailed:
                return "无法创建配置目录"
            }
        }
    }

    // MARK: - Public Methods

    /// 加载配置
    /// - Returns: 配置对象，如果不存在则返回默认配置
    func loadConfiguration() -> Configuration {
        // 检查文件是否存在
        guard fileManager.fileExists(atPath: configurationURL.path) else {
            print("⚠️  配置文件不存在，返回默认配置")
            return Configuration()
        }

        do {
            // 读取文件数据
            let data = try Data(contentsOf: configurationURL)

            // 解码 JSON
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let configuration = try decoder.decode(Configuration.self, from: data)
            print("✅ 成功加载配置，包含 \(configuration.protectedTypes.count) 个保护规则")

            return configuration

        } catch {
            print("❌ 加载配置失败: \(error)")
            print("   返回默认配置")
            return Configuration()
        }
    }

    /// 保存配置
    /// - Parameter configuration: 要保存的配置
    /// - Throws: ConfigError 如果保存失败
    func saveConfiguration(_ configuration: Configuration) throws {
        do {
            // 更新最后修改时间
            var config = configuration
            config.lastModified = Date()

            // 编码为 JSON
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601

            let data = try encoder.encode(config)

            // 写入文件
            try data.write(to: configurationURL, options: .atomic)

            print("✅ 成功保存配置到: \(configurationURL.path)")
            NotificationCenter.default.post(name: .protectionRulesDidChange, object: nil)

        } catch {
            print("❌ 保存配置失败: \(error)")
            throw ConfigError.saveFailed(error)
        }
    }

    /// 添加保护规则
    /// - Parameter rule: 保护规则
    func addProtectionRule(_ rule: ProtectionRule) throws {
        var config = loadConfiguration()

        // 检查是否已存在相同目标的保护规则
        let lookupKey = rule.target.lookupKey
        if config.protectedTypes.contains(where: { $0.target.lookupKey == lookupKey }) {
            print("⚠️  已存在相同目标的保护规则: \(lookupKey)")
            // 替换现有规则
            config.protectedTypes.removeAll { $0.target.lookupKey == lookupKey }
        }

        config.protectedTypes.append(rule)
        try saveConfiguration(config)
    }

    /// 移除保护规则
    /// - Parameter ruleID: 规则 ID
    func removeProtectionRule(id: UUID) throws {
        var config = loadConfiguration()
        config.protectedTypes.removeAll { $0.id == id }
        try saveConfiguration(config)
    }

    /// 更新保护规则
    /// - Parameter rule: 更新后的规则
    func updateProtectionRule(_ rule: ProtectionRule) throws {
        var config = loadConfiguration()

        if let index = config.protectedTypes.firstIndex(where: { $0.id == rule.id }) {
            config.protectedTypes[index] = rule
            try saveConfiguration(config)
        }
    }

    /// 更新用户偏好设置
    /// - Parameter preferences: 新的偏好设置
    func updatePreferences(_ preferences: UserPreferences) throws {
        var config = loadConfiguration()
        config.preferences = preferences
        try saveConfiguration(config)
    }

    /// 获取所有保护规则
    /// - Returns: 保护规则数组
    func getProtectionRules() -> [ProtectionRule] {
        return loadConfiguration().protectedTypes
    }

    /// 获取用户偏好设置
    /// - Returns: 用户偏好设置
    func getPreferences() -> UserPreferences {
        return loadConfiguration().preferences
    }

    /// 获取所有文件类型保护规则
    func getFileTypeRules() -> [ProtectionRule] {
        return getProtectionRules().filter { $0.target.isFileType }
    }

    /// 获取所有 URL Scheme 保护规则
    func getURLSchemeRules() -> [ProtectionRule] {
        return getProtectionRules().filter { $0.target.isURLScheme }
    }

    /// 导出配置到指定路径
    /// - Parameter url: 导出路径
    func exportConfiguration(to url: URL) throws {
        let config = loadConfiguration()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(config)
        try data.write(to: url, options: .atomic)

        print("✅ 配置已导出到: \(url.path)")
    }

    /// 从指定路径导入配置
    /// - Parameter url: 导入路径
    func importConfiguration(from url: URL) throws {
        let data = try Data(contentsOf: url)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let config = try decoder.decode(Configuration.self, from: data)

        try saveConfiguration(config)

        print("✅ 配置已导入，包含 \(config.protectedTypes.count) 个保护规则")
    }

    /// 重置配置为默认值
    func resetConfiguration() throws {
        let defaultConfig = Configuration()
        try saveConfiguration(defaultConfig)
        print("✅ 配置已重置为默认值")
    }

    /// 获取配置文件路径
    /// - Returns: 配置文件 URL
    func getConfigurationPath() -> URL {
        return configurationURL
    }
}

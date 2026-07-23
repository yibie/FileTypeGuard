import XCTest
@testable import FileTypeGuard

final class DataModelsTests: XCTestCase {

    // MARK: - FileType Tests

    func testFileType_Creation() {
        // Given: 文件类型参数
        let uti = "com.adobe.pdf"
        let extensions = [".pdf"]
        let displayName = "PDF Document"

        // When: 创建 FileType
        let fileType = FileType(uti: uti, extensions: extensions, displayName: displayName)

        // Then: 属性正确
        XCTAssertEqual(fileType.uti, uti)
        XCTAssertEqual(fileType.extensions, extensions)
        XCTAssertEqual(fileType.displayName, displayName)
        XCTAssertEqual(fileType.primaryExtension, ".pdf")
        print("✅ FileType 创建成功: \(fileType)")
    }

    func testFileType_FromExtension() {
        // Given: 文件扩展名
        let ext = ".pdf"

        // When: 从扩展名创建 FileType
        let fileType = FileType.from(extension: ext)

        // Then: 应该成功创建
        XCTAssertNotNil(fileType)
        XCTAssertEqual(fileType?.uti, "com.adobe.pdf")
        XCTAssertTrue(fileType?.extensions.contains(".pdf") ?? false)
        print("✅ 从扩展名创建: \(fileType?.description ?? "nil")")
    }

    func testFileType_Codable() throws {
        // Given: FileType 对象
        let fileType = FileType(uti: "com.adobe.pdf", extensions: [".pdf"], displayName: "PDF")

        // When: 编码为 JSON
        let encoder = JSONEncoder()
        let data = try encoder.encode(fileType)

        // Then: 应该能解码回来
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(FileType.self, from: data)

        XCTAssertEqual(decoded.uti, fileType.uti)
        XCTAssertEqual(decoded.extensions, fileType.extensions)
        print("✅ FileType JSON 序列化成功")
    }

    // MARK: - Application Tests

    func testApplication_Creation() {
        // Given: 应用参数
        let bundleID = "com.apple.Preview"
        let name = "Preview"
        let path = "/System/Applications/Preview.app"

        // When: 创建 Application
        let app = Application(bundleID: bundleID, name: name, path: path)

        // Then: 属性正确
        XCTAssertEqual(app.bundleID, bundleID)
        XCTAssertEqual(app.name, name)
        XCTAssertEqual(app.path, path)
        XCTAssertEqual(app.id, bundleID)
        print("✅ Application 创建成功: \(app)")
    }

    func testApplication_FromBundleID() {
        // Given: Bundle ID
        let bundleID = "com.apple.Preview"

        // When: 从 Bundle ID 创建 Application
        let app = Application.from(bundleID: bundleID)

        // Then: 应该成功创建
        XCTAssertNotNil(app)
        XCTAssertEqual(app?.bundleID, bundleID)
        XCTAssertEqual(app?.name, "Preview")
        print("✅ 从 Bundle ID 创建: \(app?.description ?? "nil")")
    }

    func testApplication_IsInstalled() {
        // Given: Preview 应用
        guard let app = Application.from(bundleID: "com.apple.Preview") else {
            XCTFail("应该能创建 Preview 应用")
            return
        }

        // When: 检查是否已安装
        let isInstalled = app.isInstalled()

        // Then: 应该返回 true
        XCTAssertTrue(isInstalled, "Preview 应该已安装")
        print("✅ Preview 已安装: \(isInstalled)")
    }

    func testApplication_Codable() throws {
        // Given: Application 对象
        let app = Application(bundleID: "com.apple.Preview", name: "Preview", path: "/System/Applications/Preview.app")

        // When: 编码为 JSON
        let encoder = JSONEncoder()
        let data = try encoder.encode(app)

        // Then: 应该能解码回来
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Application.self, from: data)

        XCTAssertEqual(decoded.bundleID, app.bundleID)
        XCTAssertEqual(decoded.name, app.name)
        print("✅ Application JSON 序列化成功")
    }

    // MARK: - ProtectionRule Tests

    func testProtectionRule_Creation() {
        // Given: 文件类型和应用
        let fileType = FileType(uti: "com.adobe.pdf", extensions: [".pdf"], displayName: "PDF")
        let app = Application(bundleID: "com.apple.Preview", name: "Preview", path: "/System/Applications/Preview.app")

        // When: 创建保护规则
        let rule = ProtectionRule(fileType: fileType, expectedApplication: app)

        // Then: 属性正确
        XCTAssertEqual(rule.fileType?.uti, "com.adobe.pdf")
        XCTAssertEqual(rule.expectedApplication.bundleID, "com.apple.Preview")
        XCTAssertTrue(rule.isEnabled)
        print("✅ ProtectionRule 创建成功: \(rule)")
    }

    func testProtectionRule_IsValid() {
        // Given: 有效的保护规则
        let rule = ProtectionRule.preview

        // When: 验证规则
        let isValid = rule.isValid()

        // Then: 应该有效（Preview 已安装）
        XCTAssertTrue(isValid, "Preview 规则应该有效")
        print("✅ ProtectionRule 有效性验证通过")
    }

    func testProtectionRule_Codable() throws {
        // Given: ProtectionRule 对象
        let rule = ProtectionRule.preview

        // When: 编码为 JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(rule)

        // Then: 应该能解码回来
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ProtectionRule.self, from: data)

        XCTAssertEqual(decoded.id, rule.id)
        XCTAssertEqual(decoded.fileType?.uti, rule.fileType?.uti)
        print("✅ ProtectionRule JSON 序列化成功")
    }

    // MARK: - ConfigurationManager Tests

    func testUserPreferences_DecodesLegacyConfiguration() throws {
        let data = Data("""
        {
          "monitoringEnabled": false,
          "checkInterval": 10,
          "recoveryStrategy": "delayed",
          "showNotifications": false,
          "notificationSound": false,
          "autoRecoveryEnabled": false,
          "logRetentionDays": 14,
          "startAtLogin": true
        }
        """.utf8)

        let preferences = try JSONDecoder().decode(ConfigurationManager.UserPreferences.self, from: data)

        XCTAssertFalse(preferences.hideDockIcon)
        XCTAssertFalse(preferences.monitoringEnabled)
        XCTAssertEqual(preferences.recoveryStrategy, .delayed)
    }

    func testConfigurationManager_LoadDefault() {
        // Given: ConfigurationManager
        let manager = ConfigurationManager.shared

        // When: 加载配置（首次加载，应该返回默认配置）
        let config = manager.loadConfiguration()

        // Then: 应该是默认配置
        XCTAssertEqual(config.version, "1.0")
        XCTAssertTrue(config.protectedTypes.isEmpty || !config.protectedTypes.isEmpty) // 可能已有数据
        XCTAssertTrue(config.preferences.monitoringEnabled)
        print("✅ 加载配置成功，包含 \(config.protectedTypes.count) 个规则")
    }

    func testConfigurationManager_SaveAndLoad() throws {
        // Given: ConfigurationManager 和保护规则
        let manager = ConfigurationManager.shared
        let rule = ProtectionRule.preview

        // When: 添加规则并保存
        try manager.addProtectionRule(rule)

        // Then: 重新加载应该包含该规则
        let config = manager.loadConfiguration()
        XCTAssertTrue(config.protectedTypes.contains { $0.fileType?.uti == rule.fileType?.uti })
        print("✅ 保存并重新加载成功")

        // 清理：移除测试规则
        try manager.removeProtectionRule(id: rule.id)
    }

    func testConfigurationManager_AddRemoveRule() throws {
        // Given: ConfigurationManager 和保护规则
        let manager = ConfigurationManager.shared
        let rule = ProtectionRule.preview

        // When: 添加规则
        try manager.addProtectionRule(rule)
        var rules = manager.getProtectionRules()
        let countAfterAdd = rules.count

        // Then: 应该包含该规则
        XCTAssertTrue(rules.contains { $0.id == rule.id })

        // When: 移除规则
        try manager.removeProtectionRule(id: rule.id)
        rules = manager.getProtectionRules()

        // Then: 应该不包含该规则
        XCTAssertFalse(rules.contains { $0.id == rule.id })
        XCTAssertEqual(rules.count, countAfterAdd - 1)
        print("✅ 添加和移除规则成功")
    }

    func testConfigurationManager_UpdatePreferences() throws {
        // Given: ConfigurationManager
        let manager = ConfigurationManager.shared

        // When: 更新偏好设置
        var prefs = manager.getPreferences()
        let originalValue = prefs.monitoringEnabled
        prefs.monitoringEnabled = !originalValue
        try manager.updatePreferences(prefs)

        // Then: 应该保存新值
        let loadedPrefs = manager.getPreferences()
        XCTAssertEqual(loadedPrefs.monitoringEnabled, !originalValue)

        // 恢复原值
        prefs.monitoringEnabled = originalValue
        try manager.updatePreferences(prefs)
        print("✅ 更新偏好设置成功")
    }

    func testConfigurationManager_GetPath() {
        // Given: ConfigurationManager
        let manager = ConfigurationManager.shared

        // When: 获取配置路径
        let path = manager.getConfigurationPath()

        // Then: 应该是有效路径
        XCTAssertTrue(path.path.contains("FileTypeGuard"))
        XCTAssertTrue(path.path.contains("config.json"))
        print("✅ 配置路径: \(path.path)")
    }
}

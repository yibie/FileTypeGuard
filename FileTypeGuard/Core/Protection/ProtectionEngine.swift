import Foundation
import AppKit

/// 保护引擎
/// 核心功能：检测文件关联变化并自动恢复
final class ProtectionEngine {

    // MARK: - Properties

    private let configManager = ConfigurationManager.shared
    private let lsManager = LaunchServicesManager.shared
    private let logger = EventLogger.shared
    private var recoveryTasks: [String: DispatchWorkItem] = [:]  // lookupKey -> 恢复任务
    private let queue = DispatchQueue(label: "com.filetypeprotector.protection", qos: .userInitiated)

    /// 最大重试次数
    private let maxRetries = 3

    /// 恢复成功回调
    var onRecoverySuccess: ((String, String, String) -> Void)?  // (lookupKey, oldApp, newApp)

    /// 恢复失败回调
    var onRecoveryFailure: ((String, Error) -> Void)?  // (lookupKey, error)

    // MARK: - Error Types

    enum ProtectionError: Error {
        case ruleNotFound
        case ruleDisabled
        case recoveryFailed(String)
        case maxRetriesExceeded

        var localizedDescription: String {
            switch self {
            case .ruleNotFound:
                return "未找到保护规则"
            case .ruleDisabled:
                return "保护规则已禁用"
            case .recoveryFailed(let message):
                return "恢复失败: \(message)"
            case .maxRetriesExceeded:
                return "已达到最大重试次数"
            }
        }
    }

    // MARK: - Public Methods

    /// 验证并恢复指定 UTI 的文件关联
    /// - Parameter uti: 文件类型的 UTI
    func validateAndRecover(uti: String) {
        queue.async { [weak self] in
            guard let self = self else { return }

            do {
                try self._validateAndRecover(uti: uti)
            } catch {
                print("❌ 验证和恢复失败: \(error)")
                DispatchQueue.main.async {
                    self.onRecoveryFailure?(uti, error)
                }
            }
        }
    }

    /// 验证并恢复指定 URL Scheme 的关联
    /// - Parameter scheme: URL Scheme 字符串
    func validateAndRecoverURLScheme(scheme: String) {
        queue.async { [weak self] in
            guard let self = self else { return }

            do {
                try self._validateAndRecoverURLScheme(scheme: scheme)
            } catch {
                print("❌ URL Scheme 验证和恢复失败: \(error)")
                DispatchQueue.main.async {
                    self.onRecoveryFailure?(scheme, error)
                }
            }
        }
    }

    /// 验证所有保护规则
    func validateAllRules() {
        let rules = configManager.getProtectionRules()
        print("🔍 开始验证所有保护规则，共 \(rules.count) 个")

        for rule in rules {
            guard rule.isEnabled else {
                continue
            }

            switch rule.target {
            case .fileType(let ft):
                validateAndRecover(uti: ft.uti)
            case .urlScheme(let scheme):
                validateAndRecoverURLScheme(scheme: scheme.scheme)
            }
        }
    }

    /// 取消指定键的待执行恢复任务
    /// - Parameter key: UTI 或 URL Scheme
    func cancelRecovery(uti key: String) {
        queue.async { [weak self] in
            self?.recoveryTasks[key]?.cancel()
            self?.recoveryTasks.removeValue(forKey: key)
            print("🚫 已取消 \(key) 的恢复任务")
        }
    }

    // MARK: - Private Methods (File Type)

    /// 内部验证和恢复方法（在队列中执行）
    private func _validateAndRecover(uti: String) throws {
        // 1. 获取保护规则
        guard let rule = findRule(for: uti) else {
            throw ProtectionError.ruleNotFound
        }

        guard rule.isEnabled else {
            throw ProtectionError.ruleDisabled
        }

        // 2. 读取当前文件关联（主 UTI）
        let currentBundleID = try lsManager.getDefaultApplication(for: uti)
        let expectedBundleID = rule.expectedApplication.bundleID

        // 3. 检查主 UTI 是否需要恢复
        var needsRecovery = (currentBundleID != expectedBundleID)

        // 4. 检查所有动态 UTI 是否也被修改
        if let ft = rule.fileType, let ext = ft.extensions.first {
            let allUTIs = lsManager.findAllUTIs(forExtension: ext)
            for dynUTI in allUTIs {
                if dynUTI == uti { continue }
                let dynApp = try? lsManager.getDefaultApplication(for: dynUTI)
                if dynApp != nil && dynApp != expectedBundleID {
                    print("⚠️  动态 UTI \(dynUTI) 被设置为: \(dynApp ?? "nil")，期望: \(expectedBundleID)")
                    needsRecovery = true
                }
            }
        }

        if !needsRecovery {
            print("✅ \(uti) 的文件关联正常: \(expectedBundleID)")
            return
        }

        print("⚠️  检测到 \(uti) 的文件关联被修改:")
        print("   期望: \(expectedBundleID)")
        print("   当前: \(currentBundleID ?? "nil")")

        // 记录检测事件
        let currentApp = currentBundleID.flatMap { Application.from(bundleID: $0) }
        logger.logDetected(
            fileType: uti,
            fileTypeName: rule.fileType?.displayName ?? uti,
            fromApp: currentBundleID,
            fromAppName: currentApp?.name,
            toApp: expectedBundleID,
            toAppName: rule.expectedApplication.name
        )

        // 5. 根据策略执行恢复
        let preferences = configManager.getPreferences()
        let strategy = preferences.recoveryStrategy

        switch strategy {
        case .immediate:
            try performRecovery(
                uti: uti,
                expectedBundleID: expectedBundleID,
                currentBundleID: currentBundleID
            )

        case .delayed:
            scheduleDelayedRecovery(
                key: uti,
                isURLScheme: false,
                expectedBundleID: expectedBundleID,
                currentBundleID: currentBundleID,
                delay: strategy.delaySeconds
            )

        case .askUser:
            print("⏸️  询问用户模式暂未实现，跳过恢复")
        }
    }

    /// 执行恢复操作（带重试）
    private func performRecovery(
        uti: String,
        expectedBundleID: String,
        currentBundleID: String?,
        retryCount: Int = 0
    ) throws {
        do {
            // 获取文件扩展名，使用扩展名级别的设置（覆盖所有相关 UTI，包括动态 UTI）
            let extensions = UTIManager.shared.getExtensions(forUTI: uti)
            if let ext = extensions.first {
                try lsManager.setDefaultApplicationForExtension(
                    expectedBundleID,
                    extension: ext,
                    primaryUTI: uti
                )
            } else {
                // 回退到仅设置主 UTI
                try lsManager.setDefaultApplication(expectedBundleID, for: uti)
            }

            // 验证是否成功
            let verifiedBundleID = try lsManager.getDefaultApplication(for: uti)

            if verifiedBundleID == expectedBundleID {
                print("✅ 成功恢复 \(uti) 的文件关联: \(expectedBundleID)")

                // 记录恢复成功
                if let rule = findRule(for: uti) {
                    let currentApp = currentBundleID.flatMap { Application.from(bundleID: $0) }
                    logger.logRestored(
                        fileType: uti,
                        fileTypeName: rule.fileType?.displayName ?? uti,
                        fromApp: currentBundleID,
                        fromAppName: currentApp?.name,
                        toApp: expectedBundleID,
                        toAppName: rule.expectedApplication.name
                    )
                }

                DispatchQueue.main.async {
                    self.onRecoverySuccess?(uti, currentBundleID ?? "unknown", expectedBundleID)
                }
            } else {
                throw ProtectionError.recoveryFailed("验证失败，当前值: \(verifiedBundleID ?? "nil")")
            }

        } catch {
            print("❌ 恢复失败 (\(retryCount + 1)/\(maxRetries)): \(error)")

            // 记录恢复失败
            if retryCount == maxRetries - 1, let rule = findRule(for: uti) {
                let currentApp = currentBundleID.flatMap { Application.from(bundleID: $0) }
                logger.logRestoreFailed(
                    fileType: uti,
                    fileTypeName: rule.fileType?.displayName ?? uti,
                    fromApp: currentBundleID,
                    fromAppName: currentApp?.name,
                    toApp: expectedBundleID,
                    toAppName: rule.expectedApplication.name,
                    error: error
                )
            }

            // 重试逻辑
            if retryCount < maxRetries - 1 {
                let retryDelay: TimeInterval = 1.0 * Double(retryCount + 1)  // 递增延迟
                print("⏳ 将在 \(retryDelay) 秒后重试...")

                Thread.sleep(forTimeInterval: retryDelay)
                try performRecovery(
                    uti: uti,
                    expectedBundleID: expectedBundleID,
                    currentBundleID: currentBundleID,
                    retryCount: retryCount + 1
                )
            } else {
                throw ProtectionError.maxRetriesExceeded
            }
        }
    }

    // MARK: - Private Methods (URL Scheme)

    /// 内部 URL Scheme 验证和恢复方法
    private func _validateAndRecoverURLScheme(scheme: String) throws {
        guard let rule = findSchemeRule(for: scheme) else {
            throw ProtectionError.ruleNotFound
        }

        guard rule.isEnabled else {
            throw ProtectionError.ruleDisabled
        }

        let currentBundleID = try lsManager.getDefaultHandlerForURLScheme(scheme)
        let expectedBundleID = rule.expectedApplication.bundleID

        guard currentBundleID != expectedBundleID else {
            print("✅ \(scheme):// 的 URL Scheme 关联正常: \(expectedBundleID)")
            return
        }

        print("⚠️  检测到 \(scheme):// 的 URL Scheme 关联被修改:")
        print("   期望: \(expectedBundleID)")
        print("   当前: \(currentBundleID ?? "nil")")

        let schemeName = rule.urlScheme?.displayName ?? scheme
        let currentApp = currentBundleID.flatMap { Application.from(bundleID: $0) }
        logger.logDetected(
            fileType: scheme,
            fileTypeName: schemeName,
            fromApp: currentBundleID,
            fromAppName: currentApp?.name,
            toApp: expectedBundleID,
            toAppName: rule.expectedApplication.name
        )

        let preferences = configManager.getPreferences()
        let strategy = preferences.recoveryStrategy

        switch strategy {
        case .immediate:
            try performURLSchemeRecovery(
                scheme: scheme,
                expectedBundleID: expectedBundleID,
                currentBundleID: currentBundleID
            )

        case .delayed:
            scheduleDelayedRecovery(
                key: scheme,
                isURLScheme: true,
                expectedBundleID: expectedBundleID,
                currentBundleID: currentBundleID,
                delay: strategy.delaySeconds
            )

        case .askUser:
            print("⏸️  询问用户模式暂未实现，跳过恢复")
        }
    }

    /// 执行 URL Scheme 恢复操作（带重试）
    private func performURLSchemeRecovery(
        scheme: String,
        expectedBundleID: String,
        currentBundleID: String?,
        retryCount: Int = 0
    ) throws {
        do {
            try lsManager.setDefaultHandlerForURLScheme(expectedBundleID, scheme: scheme)

            // 验证是否成功
            let verifiedBundleID = try lsManager.getDefaultHandlerForURLScheme(scheme)

            if verifiedBundleID == expectedBundleID {
                print("✅ 成功恢复 \(scheme):// 的 URL Scheme 关联: \(expectedBundleID)")

                if let rule = findSchemeRule(for: scheme) {
                    let schemeName = rule.urlScheme?.displayName ?? scheme
                    let currentApp = currentBundleID.flatMap { Application.from(bundleID: $0) }
                    logger.logRestored(
                        fileType: scheme,
                        fileTypeName: schemeName,
                        fromApp: currentBundleID,
                        fromAppName: currentApp?.name,
                        toApp: expectedBundleID,
                        toAppName: rule.expectedApplication.name
                    )
                }

                DispatchQueue.main.async {
                    self.onRecoverySuccess?(scheme, currentBundleID ?? "unknown", expectedBundleID)
                }
            } else {
                throw ProtectionError.recoveryFailed("验证失败，当前值: \(verifiedBundleID ?? "nil")")
            }

        } catch {
            print("❌ URL Scheme 恢复失败 (\(retryCount + 1)/\(maxRetries)): \(error)")

            if retryCount == maxRetries - 1, let rule = findSchemeRule(for: scheme) {
                let schemeName = rule.urlScheme?.displayName ?? scheme
                let currentApp = currentBundleID.flatMap { Application.from(bundleID: $0) }
                logger.logRestoreFailed(
                    fileType: scheme,
                    fileTypeName: schemeName,
                    fromApp: currentBundleID,
                    fromAppName: currentApp?.name,
                    toApp: expectedBundleID,
                    toAppName: rule.expectedApplication.name,
                    error: error
                )
            }

            if retryCount < maxRetries - 1 {
                let retryDelay: TimeInterval = 1.0 * Double(retryCount + 1)
                print("⏳ 将在 \(retryDelay) 秒后重试...")

                Thread.sleep(forTimeInterval: retryDelay)
                try performURLSchemeRecovery(
                    scheme: scheme,
                    expectedBundleID: expectedBundleID,
                    currentBundleID: currentBundleID,
                    retryCount: retryCount + 1
                )
            } else {
                throw ProtectionError.maxRetriesExceeded
            }
        }
    }

    // MARK: - Shared Private Methods

    /// 计划延迟恢复（通用）
    private func scheduleDelayedRecovery(
        key: String,
        isURLScheme: Bool,
        expectedBundleID: String,
        currentBundleID: String?,
        delay: TimeInterval
    ) {
        // 取消现有任务
        recoveryTasks[key]?.cancel()

        // 创建新任务
        let task = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            do {
                if isURLScheme {
                    print("⏰ 延迟恢复任务开始: \(key)://")
                    try self.performURLSchemeRecovery(
                        scheme: key,
                        expectedBundleID: expectedBundleID,
                        currentBundleID: currentBundleID
                    )
                } else {
                    print("⏰ 延迟恢复任务开始: \(key)")
                    try self.performRecovery(
                        uti: key,
                        expectedBundleID: expectedBundleID,
                        currentBundleID: currentBundleID
                    )
                }
            } catch {
                print("❌ 延迟恢复失败: \(error)")
                DispatchQueue.main.async {
                    self.onRecoveryFailure?(key, error)
                }
            }

            // 清理任务
            self.recoveryTasks.removeValue(forKey: key)
        }

        recoveryTasks[key] = task
        queue.asyncAfter(deadline: .now() + delay, execute: task)

        print("⏳ 已计划在 \(delay) 秒后恢复 \(key)")
    }

    /// 查找指定 UTI 的保护规则
    private func findRule(for uti: String) -> ProtectionRule? {
        let rules = configManager.getProtectionRules()
        return rules.first { $0.target.lookupKey == uti && $0.target.isFileType }
    }

    /// 查找指定 URL Scheme 的保护规则
    private func findSchemeRule(for scheme: String) -> ProtectionRule? {
        let rules = configManager.getProtectionRules()
        return rules.first { $0.target.lookupKey == scheme && $0.target.isURLScheme }
    }

    // MARK: - Smart Strategy Selection

    /// 智能选择恢复策略（基于上下文）
    func selectStrategy(for uti: String) -> RecoveryStrategy {
        // 检测前台应用
        if let frontApp = NSWorkspace.shared.frontmostApplication,
           let bundleID = frontApp.bundleIdentifier {

            // 如果是系统设置，可能是用户手动修改，使用延迟策略
            if bundleID == "com.apple.systempreferences" || bundleID == "com.apple.Settings" {
                print("🤔 检测到系统设置在前台，使用延迟恢复策略")
                return .delayed
            }
        }

        // 默认使用配置的策略
        return configManager.getPreferences().recoveryStrategy
    }
}

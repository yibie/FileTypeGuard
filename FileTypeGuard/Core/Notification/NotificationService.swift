import Foundation
import UserNotifications

/// 系统通知服务
@MainActor
final class NotificationService {

    // MARK: - Singleton

    static let shared = NotificationService()
    private init() {
        // 检查是否在有效的 Bundle 环境中运行
        guard Bundle.main.bundleIdentifier != nil else {
            print("⚠️  NotificationService: 运行在非 App Bundle 环境，通知功能将被禁用")
            isAvailable = false
            return
        }
        isAvailable = true
    }

    // MARK: - Properties

    private var center: UNUserNotificationCenter? {
        guard isAvailable else { return nil }
        return UNUserNotificationCenter.current()
    }
    private var isAvailable: Bool = true
    private var notificationHistory: [String: Date] = [:]  // fileType -> lastNotificationTime
    private let throttleInterval: TimeInterval = 60.0  // 1 分钟

    // MARK: - Notification Type

    enum NotificationType {
        case associationRestored(fileType: String, fileTypeName: String, fromApp: String, toApp: String)
        case recoveryFailed(fileType: String, fileTypeName: String, error: String)

        var identifier: String {
            switch self {
            case .associationRestored:
                return "association.restored"
            case .recoveryFailed:
                return "recovery.failed"
            }
        }
    }

    // MARK: - Public Methods

    /// 请求通知权限
    func requestAuthorization() async -> Bool {
        guard isAvailable, let center = center else {
            print("⚠️  通知服务不可用（非 App Bundle 环境）")
            return false
        }

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])

            if granted {
                print("✅ 通知权限已授予")
            } else {
                print("⚠️  通知权限被拒绝")
            }

            return granted

        } catch {
            print("❌ 请求通知权限失败: \(error)")
            return false
        }
    }

    /// 检查通知权限状态
    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        guard isAvailable, let center = center else {
            return .notDetermined
        }
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    /// 发送通知
    /// - Parameter type: 通知类型
    func send(_ type: NotificationType) {
        guard isAvailable, let center = center else {
            print("⚠️  通知服务不可用，跳过发送")
            return
        }

        Task { @MainActor in
            // 检查权限
            let status = await center.notificationSettings().authorizationStatus
            guard status == .authorized else {
                print("⚠️  通知权限未授予，跳过发送")
                return
            }

            // 防止通知轰炸
            let fileType = extractFileType(from: type)
            if shouldThrottle(fileType: fileType) {
                print("⏸️  跳过重复通知: \(fileType)")
                return
            }

            // 创建通知内容
            let content = createNotificationContent(for: type)

            // 创建请求
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil  // 立即发送
            )

            // 发送通知
            do {
                try await center.add(request)
                print("✅ 通知已发送: \(type.identifier)")

                // 记录通知时间
                notificationHistory[fileType] = Date()

            } catch {
                print("❌ 发送通知失败: \(error)")
            }
        }
    }

    /// 清除所有通知
    func clearAllNotifications() {
        guard isAvailable, let center = center else { return }
        center.removeAllDeliveredNotifications()
        print("🗑️  已清除所有通知")
    }

    // MARK: - Private Methods

    /// 创建通知内容
    private func createNotificationContent(for type: NotificationType) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()

        switch type {
        case .associationRestored(_, let fileTypeName, let fromApp, let toApp):
            content.title = String(localized: "notification_association_restored")
            content.body = String(localized: "\(fileTypeName) from \(fromApp) restored to \(toApp)")
            content.sound = .default

        case .recoveryFailed(_, let fileTypeName, let error):
            content.title = String(localized: "notification_recovery_failed")
            content.body = String(localized: "\(fileTypeName) recovery failed \(error)")
            content.sound = .defaultCritical
        }

        return content
    }

    /// 提取文件类型（用于防轰炸）
    private func extractFileType(from type: NotificationType) -> String {
        switch type {
        case .associationRestored(let fileType, _, _, _):
            return fileType
        case .recoveryFailed(let fileType, _, _):
            return fileType
        }
    }

    /// 检查是否应该节流（防止重复通知）
    private func shouldThrottle(fileType: String) -> Bool {
        guard let lastTime = notificationHistory[fileType] else {
            return false
        }

        let elapsed = Date().timeIntervalSince(lastTime)
        return elapsed < throttleInterval
    }
}

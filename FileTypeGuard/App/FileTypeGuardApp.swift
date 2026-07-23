import SwiftUI

@main
struct FileTypeGuardApp: App {
    @StateObject private var appCoordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup(id: "main") {
            MainView()
                .environmentObject(appCoordinator)
        }
        .defaultSize(width: 900, height: 600)

        // 隐藏 Dock 图标时，通过菜单栏图标访问应用
        MenuBarExtra(String(localized: "open_filetypeguard"), systemImage: "shield.checkered", isInserted: $appCoordinator.hideDockIcon) {
            MenuBarMenuView()
        }
    }
}

/// 菜单栏菜单
/// 仅在「隐藏 Dock 图标」开启时显示
struct MenuBarMenuView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(String(localized: "open_filetypeguard")) {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }

        Divider()

        Button(String(localized: "quit_filetypeguard")) {
            NSApp.terminate(nil)
        }
    }
}

/// 应用协调器
/// 负责管理监控和保护引擎的生命周期
@MainActor
final class AppCoordinator: ObservableObject {

    // MARK: - Properties

    private let monitor: FileAssociationMonitor
    private let protectionEngine: ProtectionEngine
    private let notificationService = NotificationService.shared
    private let configManager = ConfigurationManager.shared

    @Published var isMonitoring = false
    @Published var lastCheckTime: Date?
    @Published var hideDockIcon = false

    // MARK: - Initialization

    init() {
        // 获取用户配置的轮询间隔
        let preferences = configManager.getPreferences()
        let interval = preferences.checkInterval

        // 初始化监控器和保护引擎
        self.monitor = FileAssociationMonitor(pollingInterval: interval)
        self.protectionEngine = ProtectionEngine()

        // 设置回调
        setupCallbacks()

        // 请求通知权限
        Task {
            await notificationService.requestAuthorization()
        }

        // 如果配置了自动启动监控，则启动
        if preferences.monitoringEnabled {
            startMonitoring()
        }

        // 应用 Dock 图标显示策略
        setHideDockIcon(preferences.hideDockIcon)
    }

    // MARK: - Public Methods

    /// 设置是否隐藏 Dock 图标（仅菜单栏模式）
    func setHideDockIcon(_ hide: Bool) {
        hideDockIcon = hide
        NSApp.setActivationPolicy(hide ? .accessory : .regular)
        if !hide {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// 启动监控
    func startMonitoring() {
        guard !isMonitoring else { return }

        monitor.startMonitoring()
        isMonitoring = true

        print("✅ AppCoordinator: 监控已启动")
    }

    /// 停止监控
    func stopMonitoring() {
        guard isMonitoring else { return }

        monitor.stopMonitoring()
        isMonitoring = false

        print("✅ AppCoordinator: 监控已停止")
    }

    /// 手动触发检查
    func checkNow() {
        monitor.checkNow()
    }

    // MARK: - Private Methods

    /// 设置监控和保护引擎的回调
    private func setupCallbacks() {
        // 监控器检测到变化时，触发保护引擎验证所有规则
        monitor.onDetectedChange = { [weak self] in
            guard let self = self else { return }

            Task { @MainActor in
                self.lastCheckTime = Date()
                self.protectionEngine.validateAllRules()
            }
        }

        // 保护引擎恢复成功回调
        protectionEngine.onRecoverySuccess = { [weak self] uti, oldApp, newApp in
            guard let self = self else { return }

            print("✅ 恢复成功: \(uti)")
            print("   旧应用: \(oldApp)")
            print("   新应用: \(newApp)")

            // 获取显示名称
            Task { @MainActor in
                if let rule = ConfigurationManager.shared.getProtectionRules().first(where: { $0.target.lookupKey == uti }) {
                    let oldAppInfo = Application.from(bundleID: oldApp)
                    let newAppInfo = Application.from(bundleID: newApp)

                    // 发送成功通知
                    if ConfigurationManager.shared.getPreferences().showNotifications {
                        self.notificationService.send(.associationRestored(
                            fileType: uti,
                            fileTypeName: rule.target.displayName,
                            fromApp: oldAppInfo?.name ?? oldApp,
                            toApp: newAppInfo?.name ?? newApp
                        ))
                    }
                }
            }
        }

        // 保护引擎恢复失败回调
        protectionEngine.onRecoveryFailure = { [weak self] uti, error in
            guard let self = self else { return }

            print("❌ 恢复失败: \(uti)")
            print("   错误: \(error.localizedDescription)")

            // 获取显示名称
            Task { @MainActor in
                if let rule = ConfigurationManager.shared.getProtectionRules().first(where: { $0.target.lookupKey == uti }) {
                    // 发送失败通知
                    if ConfigurationManager.shared.getPreferences().showNotifications {
                        self.notificationService.send(.recoveryFailed(
                            fileType: uti,
                            fileTypeName: rule.target.displayName,
                            error: error.localizedDescription
                        ))
                    }
                }
            }
        }
    }
}


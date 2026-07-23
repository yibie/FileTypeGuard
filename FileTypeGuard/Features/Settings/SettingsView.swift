import SwiftUI

/// 设置页面
struct SettingsView: View {

    // MARK: - State

    @StateObject private var viewModel = SettingsViewModel()
    @EnvironmentObject var appCoordinator: AppCoordinator

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 标题
                Text("settings")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.bottom, 8)

                // 监控设置
                monitoringSection

                Divider()

                // 通知设置
                notificationSection

                Divider()

                // 高级设置
                advancedSection

                Divider()

                // 关于
                aboutSection
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
        .onAppear {
            viewModel.loadPreferences()
        }
    }

    // MARK: - Monitoring Section

    private var monitoringSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("monitoring_settings")
                .font(.headline)

            Toggle(String(localized: "enable_monitoring"), isOn: $viewModel.monitoringEnabled)
                .onChange(of: viewModel.monitoringEnabled) { newValue in
                    viewModel.savePreferences()
                    if newValue {
                        appCoordinator.startMonitoring()
                    } else {
                        appCoordinator.stopMonitoring()
                    }
                }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("check_interval")
                    Spacer()
                    Text(String(localized: "\(Int(viewModel.checkInterval)) seconds"))
                        .foregroundStyle(.secondary)
                }

                Slider(value: $viewModel.checkInterval, in: 5...60, step: 5)
                    .onChange(of: viewModel.checkInterval) { _ in
                        viewModel.savePreferences()
                    }
            }
            .disabled(!viewModel.monitoringEnabled)

            Toggle(String(localized: "auto_recovery"), isOn: $viewModel.autoRecoveryEnabled)
                .onChange(of: viewModel.autoRecoveryEnabled) { _ in
                    viewModel.savePreferences()
                }
                .disabled(!viewModel.monitoringEnabled)
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Notification Section

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("notification_settings")
                .font(.headline)

            Toggle(String(localized: "show_notifications"), isOn: $viewModel.showNotifications)
                .onChange(of: viewModel.showNotifications) { _ in
                    viewModel.savePreferences()
                }

            Toggle(String(localized: "notification_sound"), isOn: $viewModel.notificationSound)
                .onChange(of: viewModel.notificationSound) { _ in
                    viewModel.savePreferences()
                }
                .disabled(!viewModel.showNotifications)
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Advanced Section

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("advanced_settings")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("log_retention_days")
                    Spacer()
                    Text(String(localized: "\(viewModel.logRetentionDays) days"))
                        .foregroundStyle(.secondary)
                }

                Slider(value: Binding(
                    get: { Double(viewModel.logRetentionDays) },
                    set: { viewModel.logRetentionDays = Int($0) }
                ), in: 7...90, step: 1)
                    .onChange(of: viewModel.logRetentionDays) { _ in
                        viewModel.savePreferences()
                    }
            }

            Toggle(String(localized: "start_at_login"), isOn: $viewModel.startAtLogin)
                .onChange(of: viewModel.startAtLogin) { _ in
                    viewModel.savePreferences()
                }

            Toggle(String(localized: "hide_dock_icon"), isOn: $viewModel.hideDockIcon)
                .onChange(of: viewModel.hideDockIcon) { newValue in
                    viewModel.savePreferences()
                    appCoordinator.setHideDockIcon(newValue)
                }
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("about")
                .font(.headline)

            HStack {
                Text("version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("config_location")
                Spacer()
                Button(String(localized: "open")) {
                    viewModel.openConfigDirectory()
                }
            }
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - ViewModel

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var monitoringEnabled = true
    @Published var checkInterval: TimeInterval = 30.0
    @Published var autoRecoveryEnabled = true
    @Published var showNotifications = true
    @Published var notificationSound = true
    @Published var logRetentionDays = 30
    @Published var startAtLogin = false
    @Published var hideDockIcon = false

    private let configManager = ConfigurationManager.shared

    func loadPreferences() {
        let prefs = configManager.getPreferences()
        monitoringEnabled = prefs.monitoringEnabled
        checkInterval = prefs.checkInterval
        autoRecoveryEnabled = prefs.autoRecoveryEnabled
        showNotifications = prefs.showNotifications
        notificationSound = prefs.notificationSound
        logRetentionDays = prefs.logRetentionDays
        startAtLogin = prefs.startAtLogin
        hideDockIcon = prefs.hideDockIcon
    }

    func savePreferences() {
        var prefs = configManager.getPreferences()
        prefs.monitoringEnabled = monitoringEnabled
        prefs.checkInterval = checkInterval
        prefs.autoRecoveryEnabled = autoRecoveryEnabled
        prefs.showNotifications = showNotifications
        prefs.notificationSound = notificationSound
        prefs.logRetentionDays = logRetentionDays
        prefs.startAtLogin = startAtLogin
        prefs.hideDockIcon = hideDockIcon

        do {
            try configManager.updatePreferences(prefs)
            print("✅ 保存用户偏好设置成功")
        } catch {
            print("❌ 保存设置失败: \(error)")
        }
    }

    func openConfigDirectory() {
        let configPath = configManager.getConfigurationPath()
        let directoryURL = configPath.deletingLastPathComponent()
        NSWorkspace.shared.open(directoryURL)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(AppCoordinator())
        .frame(width: 600, height: 600)
}

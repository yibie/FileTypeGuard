import SwiftUI

/// 应用选择器组件
/// 显示本机所有已安装应用，推荐应用（能打开该文件类型/URL Scheme 的）排在前面
struct ApplicationPicker: View {

    // MARK: - Properties

    let target: ProtectableTarget?
    @Binding var selectedApplication: Application?

    // MARK: - State

    @State private var recommendedApps: [Application] = []
    @State private var otherApps: [Application] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var loadedKey: String = ""

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 搜索栏
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField(String(localized: "search_app"), text: $searchText)
                    .textFieldStyle(.roundedBorder)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // 应用列表
            if isLoading {
                loadingView
            } else if recommendedApps.isEmpty && otherApps.isEmpty {
                emptyView
            } else {
                applicationList
            }
        }
        .onAppear {
            loadIfNeeded()
        }
        .onChange(of: target?.lookupKey) { _ in
            loadIfNeeded()
        }
    }

    // MARK: - Load Guard

    /// 只在目标真正变化时才重新加载
    private func loadIfNeeded() {
        let currentKey = target?.lookupKey ?? ""
        guard currentKey != loadedKey else { return }
        loadedKey = currentKey
        loadAllApplications()
    }

    // MARK: - Application List

    private var applicationList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // 推荐应用分组
                if !filteredRecommended.isEmpty {
                    sectionHeader(String(localized: "recommended_apps"), subtitle: String(localized: "can_open_this_type"))

                    ForEach(filteredRecommended) { app in
                        appRow(app, isRecommended: true)
                    }
                }

                // 其他应用分组
                if !filteredOther.isEmpty {
                    sectionHeader(String(localized: "other_apps"), subtitle: String(localized: "all_installed_apps"))

                    ForEach(filteredOther) { app in
                        appRow(app, isRecommended: false)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String, subtitle: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Text("·")
                .foregroundStyle(.tertiary)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    // MARK: - App Row

    private func appRow(_ app: Application, isRecommended: Bool) -> some View {
        let isSelected = selectedApplication?.id == app.id

        return HStack(spacing: 12) {
            // 应用图标
            if let icon = app.getIcon() {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 28, height: 28)
                    .cornerRadius(6)
            } else {
                Image(systemName: "app.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 28, height: 28)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(app.name)
                        .font(.body)
                        .fontWeight(isSelected ? .semibold : .regular)

                    if isRecommended {
                        Text("recommended")
                            .font(.system(size: 9))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .cornerRadius(3)
                    }
                }

                Text(app.bundleID)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedApplication = app
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.7)
            Text("loading_app_list")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "app.dashed")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("no_apps_found")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Filtered

    private var filteredRecommended: [Application] {
        filterApps(recommendedApps)
    }

    private var filteredOther: [Application] {
        filterApps(otherApps)
    }

    private func filterApps(_ apps: [Application]) -> [Application] {
        guard !searchText.isEmpty else { return apps }
        return apps.filter { app in
            app.name.localizedCaseInsensitiveContains(searchText) ||
            app.bundleID.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Load

    private func loadAllApplications() {
        isLoading = true

        Task {
            let lsm = LaunchServicesManager.shared

            // 获取推荐应用（能处理此目标的）
            var recommendedBundleIDs = Set<String>()
            if let t = target {
                switch t {
                case .fileType(let ft):
                    recommendedBundleIDs = Set(lsm.getAvailableApplications(for: ft.uti))
                case .urlScheme(let scheme):
                    recommendedBundleIDs = Set(lsm.getAvailableHandlersForURLScheme(scheme.scheme))
                }
            }

            // 获取所有已安装应用
            let allBundleIDs = lsm.getAllInstalledApplications()

            var recommended: [Application] = []
            var other: [Application] = []

            for bundleID in allBundleIDs {
                guard let app = Application.from(bundleID: bundleID) else { continue }

                if recommendedBundleIDs.contains(bundleID) {
                    recommended.append(app)
                } else {
                    other.append(app)
                }
            }

            // 把不在 allBundleIDs 中但在推荐列表中的也加上
            let allBundleIDSet = Set(allBundleIDs)
            for bundleID in recommendedBundleIDs {
                if !allBundleIDSet.contains(bundleID) {
                    if let app = Application.from(bundleID: bundleID) {
                        recommended.append(app)
                    }
                }
            }

            recommended.sort()
            other.sort()

            await MainActor.run {
                recommendedApps = recommended
                otherApps = other
                isLoading = false

                // 只在没有选中应用时，自动选中当前默认应用
                if selectedApplication == nil, let t = target {
                    let defaultBundleID: String?
                    switch t {
                    case .fileType(let ft):
                        defaultBundleID = try? lsm.getDefaultApplication(for: ft.uti)
                    case .urlScheme(let scheme):
                        defaultBundleID = try? lsm.getDefaultHandlerForURLScheme(scheme.scheme)
                    }

                    if let defaultBundleID = defaultBundleID {
                        let all = recommended + other
                        if let defaultApp = all.first(where: { $0.bundleID == defaultBundleID }) {
                            selectedApplication = defaultApp
                        }
                    }
                }

                print("✅ 加载了 \(recommended.count) 个推荐应用, \(other.count) 个其他应用")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        ApplicationPicker(
            target: .fileType(FileType(
                uti: "com.adobe.pdf",
                extensions: [".pdf"],
                displayName: "PDF Document"
            )),
            selectedApplication: .constant(nil)
        )
    }
    .padding()
    .frame(width: 500, height: 600)
}

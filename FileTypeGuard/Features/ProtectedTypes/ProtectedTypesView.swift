import SwiftUI

/// 保护类型列表视图
struct ProtectedTypesView: View {

    // MARK: - State

    @StateObject private var viewModel = ProtectedTypesViewModel()
    @State private var showingAddSheet = false
    @State private var showingEditSheet = false
    @State private var ruleToEdit: ProtectionRule?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            toolbar

            Divider()

            // 内容区
            if viewModel.protectionRules.isEmpty {
                emptyState
            } else {
                rulesList
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .sheet(isPresented: $showingAddSheet) {
            FileTypePickerView(isPresented: $showingAddSheet)
        }
        .sheet(isPresented: $showingEditSheet) {
            if let rule = ruleToEdit {
                FileTypePickerView(isPresented: $showingEditSheet, editingRule: rule)
            }
        }
        .onAppear {
            viewModel.loadRules()
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            Text("protected_types")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            Button {
                viewModel.loadRules()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help(String(localized: "refresh_list"))

            Button {
                showingAddSheet = true
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.plain)
            .help(String(localized: "add_protection_type"))
        }
        .padding()
    }

    // MARK: - Rules List

    private var rulesList: some View {
        List {
            ForEach(viewModel.protectionRules) { rule in
                RuleRow(rule: rule)
                    .contextMenu {
                        Button(String(localized: "edit")) {
                            ruleToEdit = rule
                            showingEditSheet = true
                        }

                        Button(rule.isEnabled ? String(localized: "disable") : String(localized: "enable")) {
                            viewModel.toggleRule(rule)
                        }

                        Divider()

                        Button(String(localized: "delete"), role: .destructive) {
                            viewModel.deleteRule(rule)
                        }
                    }
            }
        }
        .listStyle(.inset)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "shield.slash")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("no_protection_types")
                .font(.title2)
                .fontWeight(.semibold)

            Text("add_type_hint")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showingAddSheet = true
            } label: {
                Label(String(localized: "add_protection_type"), systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

// MARK: - Rule Row

struct RuleRow: View {
    let rule: ProtectionRule

    var body: some View {
        HStack(spacing: 12) {
            // 图标：文件类型用 doc.fill，URL Scheme 用 link
            Image(systemName: rule.target.isURLScheme ? "link" : "doc.fill")
                .font(.title2)
                .foregroundStyle(rule.isEnabled ? (rule.target.isURLScheme ? .purple : .blue) : .secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                // 显示名称
                Text(rule.displayName)
                    .font(.body)
                    .fontWeight(.medium)

                // 副标题：文件扩展名或 scheme://
                Text(ruleSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // 状态指示器
            VStack(alignment: .trailing, spacing: 4) {
                if rule.isEnabled {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                        Text("enabled")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.gray)
                            .frame(width: 8, height: 8)
                        Text("disabled")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // 最后验证时间
                if let lastVerified = rule.lastVerified {
                    Text(lastVerified, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var ruleSubtitle: String {
        switch rule.target {
        case .fileType(let ft):
            return ft.extensionsString
        case .urlScheme(let scheme):
            return scheme.schemeString
        }
    }
}

// MARK: - ViewModel

@MainActor
final class ProtectedTypesViewModel: ObservableObject {
    @Published var protectionRules: [ProtectionRule] = []

    private let configManager = ConfigurationManager.shared
    private var cancellable: Any?

    init() {
        cancellable = NotificationCenter.default.addObserver(
            forName: .protectionRulesDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.loadRules()
            }
        }
    }

    deinit {
        if let cancellable = cancellable {
            NotificationCenter.default.removeObserver(cancellable)
        }
    }

    func loadRules() {
        protectionRules = configManager.getProtectionRules()
        print("✅ 加载了 \(protectionRules.count) 个保护规则")
    }

    func toggleRule(_ rule: ProtectionRule) {
        var updatedRule = rule
        updatedRule.isEnabled.toggle()

        do {
            try configManager.updateProtectionRule(updatedRule)
            loadRules()
            print("✅ 已\(updatedRule.isEnabled ? "启用" : "禁用")规则: \(rule.displayName)")
        } catch {
            print("❌ 更新规则失败: \(error)")
        }
    }

    func deleteRule(_ rule: ProtectionRule) {
        do {
            try configManager.removeProtectionRule(id: rule.id)
            loadRules()
            print("✅ 已删除规则: \(rule.displayName)")
        } catch {
            print("❌ 删除规则失败: \(error)")
        }
    }
}

// MARK: - Preview

#Preview {
    ProtectedTypesView()
        .frame(width: 700, height: 500)
}

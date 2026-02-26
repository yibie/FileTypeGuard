import SwiftUI

/// 保护目标选择模式
enum PickerMode: String, CaseIterable {
    case fileTypes
    case urlSchemes

    var displayName: String {
        switch self {
        case .fileTypes: return String(localized: "file_types")
        case .urlSchemes: return String(localized: "url_schemes")
        }
    }
}

/// 可视化文件类型/URL Scheme 选择器
struct FileTypePickerView: View {

    // MARK: - Binding

    @Binding var isPresented: Bool

    // MARK: - Properties

    /// 可选：要编辑的现有规则。如果为 nil，则是添加新规则
    var editingRule: ProtectionRule?

    // MARK: - State

    @StateObject private var viewModel = AddTypeViewModel()
    @State private var pickerMode: PickerMode = .fileTypes
    @State private var selectedCategory: CommonFileTypes.Category = .documents
    @State private var selectedSchemeCategory: CommonURLSchemes.Category = .web
    @State private var selectedPresetType: CommonFileTypes.PresetFileType?
    @State private var selectedPresetScheme: CommonURLSchemes.PresetURLScheme?
    @State private var selectedApplication: Application?
    @State private var customExtension = ""
    @State private var customScheme = ""
    @State private var showCustomInput = false
    @State private var showCustomSchemeInput = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @FocusState private var isCustomInputFocused: Bool
    @FocusState private var isCustomSchemeInputFocused: Bool

    private let typesByCategory = CommonFileTypes.typesByCategory()
    private let schemesByCategory = CommonURLSchemes.schemesByCategory()

    // MARK: - Initialization

    init(isPresented: Binding<Bool>, editingRule: ProtectionRule? = nil) {
        self._isPresented = isPresented
        self.editingRule = editingRule
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            header

            Divider()

            HStack(spacing: 0) {
                // 左侧：分类 + 列表
                leftPanel

                Divider()

                // 右侧：应用选择
                rightPanel
            }

            Divider()

            // 底部按钮
            footer
        }
        .frame(width: 900, height: 600)
        .alert(String(localized: "error"), isPresented: $showingError) {
            Button(String(localized: "ok"), role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            loadEditingRule()
        }
    }

    /// 加载要编辑的规则的现有值
    private func loadEditingRule() {
        guard let rule = editingRule else { return }

        // 预选择应用
        selectedApplication = rule.expectedApplication

        switch rule.target {
        case .fileType(let fileType):
            pickerMode = .fileTypes

            // 查找是否匹配预设类型
            if let preset = CommonFileTypes.allTypes.first(where: { $0.uti == fileType.uti }) {
                selectedCategory = preset.category
                selectedPresetType = preset
            } else if let firstExt = fileType.extensions.first {
                // 自定义类型
                showCustomInput = true
                customExtension = firstExt
            }

        case .urlScheme(let scheme):
            pickerMode = .urlSchemes

            // 查找是否匹配预设 scheme
            if let preset = CommonURLSchemes.allSchemes.first(where: { $0.scheme == scheme.scheme }) {
                selectedSchemeCategory = preset.category
                selectedPresetScheme = preset
            } else {
                // 自定义 scheme
                showCustomSchemeInput = true
                customScheme = scheme.scheme
            }
        }
    }

    // MARK: - Header

    private var isEditing: Bool {
        editingRule != nil
    }

    private var header: some View {
        HStack {
            Text(isEditing ? "edit_protection_rule" : "add_file_type_protection")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            // 模式切换
            Picker("", selection: $pickerMode) {
                ForEach(PickerMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 240)
            .onChange(of: pickerMode) { _ in
                // 切换模式时清除选择
                selectedPresetType = nil
                selectedPresetScheme = nil
                selectedApplication = nil
                showCustomInput = false
                showCustomSchemeInput = false
                customExtension = ""
                customScheme = ""
            }

            Spacer()

            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    // MARK: - Left Panel

    private var leftPanel: some View {
        VStack(spacing: 0) {
            if pickerMode == .fileTypes {
                // 文件类型分类标签
                categoryTabs

                Divider()

                // 文件类型网格
                fileTypeGrid

                // 自定义输入选项
                if showCustomInput {
                    Divider()
                    customInputSection
                }
            } else {
                // URL Scheme 分类标签
                schemeCategoryTabs

                Divider()

                // URL Scheme 网格
                urlSchemeGrid

                // 自定义 Scheme 输入
                if showCustomSchemeInput {
                    Divider()
                    customSchemeInputSection
                }
            }
        }
        .frame(width: 450)
    }

    // MARK: - Category Tabs (File Types)

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CommonFileTypes.Category.allCases) { category in
                    Button {
                        selectedCategory = category
                        selectedPresetType = nil
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: category.icon)
                            Text(category.displayName)
                        }
                        .font(.subheadline)
                        .fontWeight(selectedCategory == category ? .semibold : .regular)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedCategory == category ? Color.accentColor : Color.clear)
                        .foregroundStyle(selectedCategory == category ? .white : .primary)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Scheme Category Tabs

    private var schemeCategoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CommonURLSchemes.Category.allCases) { category in
                    Button {
                        selectedSchemeCategory = category
                        selectedPresetScheme = nil
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: category.icon)
                            Text(category.displayName)
                        }
                        .font(.subheadline)
                        .fontWeight(selectedSchemeCategory == category ? .semibold : .regular)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedSchemeCategory == category ? Color.accentColor : Color.clear)
                        .foregroundStyle(selectedSchemeCategory == category ? .white : .primary)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    // MARK: - File Type Grid

    private var fileTypeGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(typesByCategory[selectedCategory] ?? []) { presetType in
                    FileTypeCard(
                        presetType: presetType,
                        isSelected: selectedPresetType?.id == presetType.id
                    )
                    .onTapGesture {
                        selectedPresetType = presetType
                        showCustomInput = false
                        selectedApplication = nil
                    }
                }

                // 自定义选项卡片
                CustomTypeCard(isActive: showCustomInput)
                    .onTapGesture {
                        showCustomInput = true
                        selectedPresetType = nil
                        selectedApplication = nil
                        // 延迟聚焦，确保视图已显示
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isCustomInputFocused = true
                        }
                    }
            }
            .padding()
        }
    }

    // MARK: - URL Scheme Grid

    private var urlSchemeGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(schemesByCategory[selectedSchemeCategory] ?? []) { presetScheme in
                    URLSchemeCard(
                        presetScheme: presetScheme,
                        isSelected: selectedPresetScheme?.id == presetScheme.id
                    )
                    .onTapGesture {
                        selectedPresetScheme = presetScheme
                        showCustomSchemeInput = false
                        selectedApplication = nil
                    }
                }

                // 自定义 Scheme 卡片
                CustomSchemeCard(isActive: showCustomSchemeInput)
                    .onTapGesture {
                        showCustomSchemeInput = true
                        selectedPresetScheme = nil
                        selectedApplication = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isCustomSchemeInputFocused = true
                        }
                    }
            }
            .padding()
        }
    }

    // MARK: - Custom Input Section

    private var customInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("custom_file_extension")
                .font(.headline)

            TextField(String(localized: "eg_xyz"), text: $customExtension)
                .textFieldStyle(.roundedBorder)
                .frame(height: 24)
                .focused($isCustomInputFocused)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .allowsHitTesting(true)
        .onAppear {
            if showCustomInput {
                isCustomInputFocused = true
            }
        }
    }

    // MARK: - Custom Scheme Input Section

    private var customSchemeInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("custom_scheme")
                .font(.headline)

            TextField(String(localized: "enter_scheme"), text: $customScheme)
                .textFieldStyle(.roundedBorder)
                .frame(height: 24)
                .focused($isCustomSchemeInputFocused)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .allowsHitTesting(true)
        .onAppear {
            if showCustomSchemeInput {
                isCustomSchemeInputFocused = true
            }
        }
    }

    // MARK: - Right Panel

    private var rightPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            if pickerMode == .fileTypes {
                // 文件类型模式
                if let presetType = selectedPresetType {
                    selectedTypeInfo(presetType)
                } else if showCustomInput && !customExtension.isEmpty {
                    customTypeInfo
                } else {
                    emptySelection
                }
            } else {
                // URL Scheme 模式
                if let presetScheme = selectedPresetScheme {
                    selectedSchemeInfo(presetScheme)
                } else if showCustomSchemeInput && !customScheme.isEmpty {
                    customSchemeInfo
                } else {
                    emptySelection
                }
            }

            Divider()

            // 应用选择器
            if currentTarget != nil {
                applicationPickerSection
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Selected Type Info

    private func selectedTypeInfo(_ presetType: CommonFileTypes.PresetFileType) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: presetType.icon)
                    .font(.largeTitle)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text(presetType.displayName)
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text(presetType.extensions.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("UTI: \(presetType.uti)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(4)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
    }

    // MARK: - Selected Scheme Info

    private func selectedSchemeInfo(_ presetScheme: CommonURLSchemes.PresetURLScheme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: presetScheme.icon)
                    .font(.largeTitle)
                    .foregroundStyle(.purple)

                VStack(alignment: .leading, spacing: 4) {
                    Text(presetScheme.displayName)
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text("\(presetScheme.scheme)://")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.purple.opacity(0.05))
        .cornerRadius(8)
    }

    private var customTypeInfo: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.badge.plus")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("custom_file_type")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text(customExtension)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.05))
        .cornerRadius(8)
    }

    private var customSchemeInfo: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "link.badge.plus")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("custom_scheme")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text("\(customScheme)://")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.05))
        .cornerRadius(8)
    }

    private var emptySelection: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text(pickerMode == .fileTypes ? "select_file_type" : "select_url_scheme")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("click_file_type_card")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Application Picker Section

    private var applicationPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("select_default_app")
                .font(.headline)

            if let target = currentTarget {
                ApplicationPicker(
                    target: target,
                    selectedApplication: $selectedApplication
                )
            } else {
                Text("identifying_file_type")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Spacer()

            Button(String(localized: "cancel")) {
                isPresented = false
            }
            .keyboardShortcut(.cancelAction)

            Button(String(localized: isEditing ? "save" : "add_protection")) {
                addProtectionRule()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(!canAddRule)
        }
        .padding()
    }

    // MARK: - Computed Properties

    private var currentTarget: ProtectableTarget? {
        if pickerMode == .fileTypes {
            if let presetType = selectedPresetType {
                return .fileType(presetType.toFileType())
            } else if showCustomInput && !customExtension.isEmpty {
                if let ft = FileType.from(extension: customExtension) {
                    return .fileType(ft)
                }
            }
        } else {
            if let presetScheme = selectedPresetScheme {
                return .urlScheme(presetScheme.toURLScheme())
            } else if showCustomSchemeInput && !customScheme.isEmpty {
                return .urlScheme(URLScheme(scheme: customScheme, displayName: customScheme.uppercased()))
            }
        }
        return nil
    }

    private var canAddRule: Bool {
        currentTarget != nil && selectedApplication != nil
    }

    // MARK: - Actions

    private func addProtectionRule() {
        guard let target = currentTarget,
              let app = selectedApplication else {
            return
        }

        do {
            let rule: ProtectionRule
            if let existingRule = editingRule {
                // 编辑模式：保留原有 ID
                rule = ProtectionRule(
                    id: existingRule.id,
                    target: target,
                    expectedApplication: app,
                    isEnabled: existingRule.isEnabled,
                    createdAt: existingRule.createdAt
                )
                try ConfigurationManager.shared.updateProtectionRule(rule)
            } else {
                // 添加新模式
                rule = ProtectionRule(
                    target: target,
                    expectedApplication: app
                )
                try ConfigurationManager.shared.addProtectionRule(rule)
            }

            // 立即设置默认应用
            switch target {
            case .fileType(let fileType):
                if let ext = fileType.extensions.first {
                    try LaunchServicesManager.shared.setDefaultApplicationForExtension(
                        app.bundleID,
                        extension: ext,
                        primaryUTI: fileType.uti
                    )
                } else {
                    try LaunchServicesManager.shared.setDefaultApplication(app.bundleID, for: fileType.uti)
                }
            case .urlScheme(let scheme):
                try LaunchServicesManager.shared.setDefaultHandlerForURLScheme(app.bundleID, scheme: scheme.scheme)
            }

            print("✅ 成功添加保护规则: \(rule.displayName)")
            isPresented = false

        } catch {
            errorMessage = String(localized: "add rule failed: \(error.localizedDescription)")
            showingError = true
        }
    }
}

// MARK: - File Type Card

struct FileTypeCard: View {
    let presetType: CommonFileTypes.PresetFileType
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: presetType.icon)
                .font(.title)
                .foregroundStyle(isSelected ? .white : .blue)

            Text(presetType.displayName)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : .primary)
                .multilineTextAlignment(.center)

            Text(presetType.extensions.joined(separator: ", "))
                .font(.caption2)
                .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - URL Scheme Card

struct URLSchemeCard: View {
    let presetScheme: CommonURLSchemes.PresetURLScheme
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: presetScheme.icon)
                .font(.title)
                .foregroundStyle(isSelected ? .white : .purple)

            Text(presetScheme.displayName)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : .primary)
                .multilineTextAlignment(.center)

            Text("\(presetScheme.scheme)://")
                .font(.caption2)
                .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Custom Type Card

struct CustomTypeCard: View {
    let isActive: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .font(.title)
                .foregroundStyle(isActive ? .white : .orange)

            Text("custom_type")
                .font(.subheadline)
                .fontWeight(isActive ? .semibold : .regular)
                .foregroundStyle(isActive ? .white : .primary)

            Text("enter_extension")
                .font(.caption2)
                .foregroundStyle(isActive ? .white.opacity(0.8) : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(isActive ? Color.orange : Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Custom Scheme Card

struct CustomSchemeCard: View {
    let isActive: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .font(.title)
                .foregroundStyle(isActive ? .white : .orange)

            Text("custom_scheme")
                .font(.subheadline)
                .fontWeight(isActive ? .semibold : .regular)
                .foregroundStyle(isActive ? .white : .primary)

            Text("enter_scheme")
                .font(.caption2)
                .foregroundStyle(isActive ? .white.opacity(0.8) : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(isActive ? Color.orange : Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    FileTypePickerView(isPresented: .constant(true))
}

import SwiftUI

/// 添加保护类型的表单
struct AddTypeSheet: View {

    // MARK: - Binding

    @Binding var isPresented: Bool

    // MARK: - State

    @StateObject private var viewModel = AddTypeViewModel()
    @State private var fileExtension = ""
    @State private var selectedApplication: Application?
    @State private var showingError = false
    @State private var errorMessage = ""
    @FocusState private var isExtensionFieldFocused: Bool

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            header

            Divider()

            // 表单内容
            form

            Divider()

            // 底部按钮
            footer
        }
        .frame(width: 600, height: 500)
        .alert(String(localized: "error"), isPresented: $showingError) {
            Button(String(localized: "ok"), role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("add_protection_type")
                .font(.title2)
                .fontWeight(.semibold)

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

    // MARK: - Form

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 文件扩展名输入
                extensionSection

                Divider()

                // 应用选择
                applicationSection

                Divider()

                // 预览
                if viewModel.fileType != nil || selectedApplication != nil {
                    previewSection
                }
            }
            .padding()
        }
    }

    // MARK: - Extension Section

    private var extensionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("file_type")
                .font(.headline)

            HStack {
                TextField(String(localized: "enter_extension_eg_pdf"), text: $fileExtension)
                    .textFieldStyle(.roundedBorder)
                    .frame(height: 24)
                    .focused($isExtensionFieldFocused)
                    .onChange(of: fileExtension) { newValue in
                        viewModel.updateFileType(extension: newValue)
                    }

                Button {
                    viewModel.updateFileType(extension: fileExtension)
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .disabled(fileExtension.isEmpty)
            }
            .allowsHitTesting(true)
            .onTapGesture {
                isExtensionFieldFocused = true
            }

            if let fileType = viewModel.fileType {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "file type: \(fileType.displayName)"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("UTI: \(fileType.uti)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 4)
            } else if !fileExtension.isEmpty {
                Text("unrecognized_file_type")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Application Section

    private var applicationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("default_app")
                .font(.headline)

            ApplicationPicker(
                target: viewModel.fileType.map { .fileType($0) },
                selectedApplication: $selectedApplication
            )
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("preview")
                .font(.headline)

            HStack(spacing: 12) {
                Image(systemName: "doc.fill")
                    .font(.title)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    if let fileType = viewModel.fileType {
                        Text(fileType.displayName)
                            .font(.body)
                            .fontWeight(.medium)
                        Text(fileType.extensionsString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let app = selectedApplication {
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)

                    Image(systemName: "app.fill")
                        .font(.title)
                        .foregroundStyle(.green)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.name)
                            .font(.body)
                            .fontWeight(.medium)
                        Text(app.bundleID)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
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

            Button(String(localized: "add")) {
                addProtectionRule()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(!canAddRule)
        }
        .padding()
    }

    // MARK: - Computed Properties

    private var canAddRule: Bool {
        viewModel.fileType != nil && selectedApplication != nil
    }

    // MARK: - Actions

    private func addProtectionRule() {
        guard let fileType = viewModel.fileType,
              let app = selectedApplication else {
            return
        }

        do {
            let rule = ProtectionRule(
                fileType: fileType,
                expectedApplication: app
            )

            try ConfigurationManager.shared.addProtectionRule(rule)

            print("✅ 成功添加保护规则: \(rule.displayName)")
            isPresented = false

        } catch {
            errorMessage = String(localized: "add rule failed: \(error.localizedDescription)")
            showingError = true
        }
    }
}

// MARK: - ViewModel

@MainActor
final class AddTypeViewModel: ObservableObject {
    @Published var fileType: FileType?

    func updateFileType(extension ext: String) {
        guard !ext.isEmpty else {
            fileType = nil
            return
        }

        fileType = FileType.from(extension: ext)
    }
}

// MARK: - Preview

#Preview {
    AddTypeSheet(isPresented: .constant(true))
}

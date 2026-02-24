import Foundation
import ApplicationServices
import UniformTypeIdentifiers
import CoreServices

/// Launch Services 管理器
/// 封装 macOS Launch Services API，用于读取和设置文件类型关联
final class LaunchServicesManager {

    // MARK: - Error Types

    enum LSError: Error {
        case notFound
        case setFailed(OSStatus)
        case invalidUTI
        case unknown(OSStatus)

        var localizedDescription: String {
            switch self {
            case .notFound:
                return "未找到默认应用"
            case .setFailed(let status):
                return "设置文件关联失败，错误码: \(status)"
            case .invalidUTI:
                return "无效的 UTI"
            case .unknown(let status):
                return "未知错误，错误码: \(status)"
            }
        }
    }

    // MARK: - Singleton

    static let shared = LaunchServicesManager()
    private init() {}

    // MARK: - Public Methods

    /// 获取指定 UTI 的默认打开应用
    /// - Parameter uti: 统一类型标识符 (Uniform Type Identifier)，如 "com.adobe.pdf"
    /// - Returns: 默认应用的 Bundle ID，如 "com.apple.Preview"
    /// - Throws: LSError 如果获取失败
    func getDefaultApplication(for uti: String) throws -> String? {
        guard !uti.isEmpty else {
            throw LSError.invalidUTI
        }

        let utiCF = uti as CFString

        // 调用 Launch Services API 获取默认应用
        guard let bundleID = LSCopyDefaultRoleHandlerForContentType(
            utiCF,
            LSRolesMask.all  // kLSRolesAll - 所有角色（查看、编辑等）
        )?.takeRetainedValue() as String? else {
            // 没有设置默认应用
            return nil
        }

        return bundleID
    }

    /// 设置指定 UTI 的默认打开应用
    /// - Parameters:
    ///   - bundleID: 应用的 Bundle ID，如 "com.apple.Preview"
    ///   - uti: 统一类型标识符，如 "com.adobe.pdf"
    /// - Throws: LSError 如果设置失败
    func setDefaultApplication(_ bundleID: String, for uti: String) throws {
        guard !uti.isEmpty, !bundleID.isEmpty else {
            throw LSError.invalidUTI
        }

        let bundleIDCF = bundleID as CFString
        let utiCF = uti as CFString

        // 调用 Launch Services API 设置默认应用
        let status = LSSetDefaultRoleHandlerForContentType(
            utiCF,
            LSRolesMask.all,  // kLSRolesAll
            bundleIDCF
        )

        guard status == noErr else {
            throw LSError.setFailed(status)
        }

        // 验证设置是否成功
        let currentApp = try getDefaultApplication(for: uti)
        guard currentApp == bundleID else {
            throw LSError.setFailed(-1)
        }
    }

    /// 设置指定文件扩展名的默认应用（覆盖所有相关 UTI）
    /// 这是更彻底的设置方式，会同时设置主 UTI 和所有动态 UTI
    /// - Parameters:
    ///   - bundleID: 应用的 Bundle ID
    ///   - ext: 文件扩展名，如 ".md"
    ///   - primaryUTI: 主 UTI 标识符
    func setDefaultApplicationForExtension(_ bundleID: String, extension ext: String, primaryUTI: String) throws {
        guard !bundleID.isEmpty, !ext.isEmpty else {
            throw LSError.invalidUTI
        }

        let bundleIDCF = bundleID as CFString

        // 1. 设置主 UTI
        let primaryStatus = LSSetDefaultRoleHandlerForContentType(
            primaryUTI as CFString,
            LSRolesMask.all,
            bundleIDCF
        )
        if primaryStatus != noErr {
            print("⚠️  设置主 UTI \(primaryUTI) 失败: \(primaryStatus)")
        } else {
            print("✅ 已设置主 UTI: \(primaryUTI) -> \(bundleID)")
        }

        // 2. 查找并设置所有动态 UTI
        //    某些应用通过动态 UTI 劫持文件关联，需要逐一覆盖
        let dynamicUTIs = findAllUTIs(forExtension: ext)
        for dynUTI in dynamicUTIs {
            if dynUTI == primaryUTI { continue }

            let status = LSSetDefaultRoleHandlerForContentType(
                dynUTI as CFString,
                LSRolesMask.all,
                bundleIDCF
            )
            if status == noErr {
                print("✅ 已设置动态 UTI: \(dynUTI) -> \(bundleID)")
            } else {
                print("⚠️  设置动态 UTI \(dynUTI) 失败: \(status)")
            }
        }
    }

    /// 查找一个文件扩展名关联的所有 UTI（包括动态 UTI）
    /// - Parameter ext: 文件扩展名，如 ".md" 或 "md"
    /// - Returns: 所有关联的 UTI 标识符
    func findAllUTIs(forExtension ext: String) -> [String] {
        var cleanExt = ext
        if cleanExt.hasPrefix(".") {
            cleanExt = String(cleanExt.dropFirst())
        }

        var utis = Set<String>()

        // 方法 1: 通过 UTType 获取
        if let utType = UTType(filenameExtension: cleanExt) {
            utis.insert(utType.identifier)
        }

        // 方法 2: 通过 UTType API 查找所有匹配类型（包括动态 UTI）
        let allTypes = UTType.types(tag: cleanExt, tagClass: .filenameExtension, conformingTo: nil)
        for t in allTypes {
            utis.insert(t.identifier)
        }

        return Array(utis)
    }

    /// 获取可以打开指定 UTI 的所有应用
    /// - Parameter uti: 统一类型标识符
    /// - Returns: 应用 Bundle ID 数组
    func getAvailableApplications(for uti: String) -> [String] {
        guard !uti.isEmpty else {
            return []
        }

        let utiCF = uti as CFString

        // 调用 Launch Services API 获取所有可用应用
        guard let apps = LSCopyAllRoleHandlersForContentType(
            utiCF,
            LSRolesMask.all
        )?.takeRetainedValue() as? [String] else {
            return []
        }

        return apps
    }

    /// 重置指定 UTI 为系统默认应用
    /// 注意：此功能在某些 macOS 版本上可能不可用
    /// - Parameter uti: 统一类型标识符
    /// - Throws: LSError 如果重置失败
    func resetToSystemDefault(for uti: String) throws {
        // 注意: LSSetDefaultRoleHandlerForContentType 不接受 nil
        // 暂时移除此功能，后续可以通过其他方式实现
        throw LSError.unknown(-1)
    }

    /// 获取本机所有已安装应用的 Bundle ID
    /// - Returns: 应用 Bundle ID 数组
    func getAllInstalledApplications() -> [String] {
        var bundleIDs = Set<String>()

        let searchPaths = [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            NSHomeDirectory() + "/Applications"
        ]

        let fileManager = FileManager.default

        for searchPath in searchPaths {
            guard let enumerator = fileManager.enumerator(
                at: URL(fileURLWithPath: searchPath),
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension == "app" {
                    // 不再递归进入 .app 包内部
                    enumerator.skipDescendants()

                    if let bundle = Bundle(url: fileURL),
                       let bid = bundle.bundleIdentifier {
                        bundleIDs.insert(bid)
                    }
                }
            }
        }

        return Array(bundleIDs)
    }

    // MARK: - URL Scheme Methods

    /// 获取指定 URL Scheme 的默认处理应用
    /// - Parameter scheme: URL Scheme 字符串，如 "https"、"mailto"
    /// - Returns: 默认应用的 Bundle ID
    /// - Throws: LSError 如果获取失败
    func getDefaultHandlerForURLScheme(_ scheme: String) throws -> String? {
        guard !scheme.isEmpty else {
            throw LSError.invalidUTI
        }

        let schemeCF = scheme as CFString

        guard let bundleID = LSCopyDefaultHandlerForURLScheme(schemeCF)?.takeRetainedValue() as String? else {
            return nil
        }

        return bundleID
    }

    /// 设置指定 URL Scheme 的默认处理应用
    /// - Parameters:
    ///   - bundleID: 应用的 Bundle ID
    ///   - scheme: URL Scheme 字符串
    /// - Throws: LSError 如果设置失败
    func setDefaultHandlerForURLScheme(_ bundleID: String, scheme: String) throws {
        guard !scheme.isEmpty, !bundleID.isEmpty else {
            throw LSError.invalidUTI
        }

        let bundleIDCF = bundleID as CFString
        let schemeCF = scheme as CFString

        let status = LSSetDefaultHandlerForURLScheme(schemeCF, bundleIDCF)

        guard status == noErr else {
            throw LSError.setFailed(status)
        }

        // 验证设置是否成功
        let currentApp = try getDefaultHandlerForURLScheme(scheme)
        guard currentApp == bundleID else {
            throw LSError.setFailed(-1)
        }
    }

    /// 获取可以处理指定 URL Scheme 的所有应用
    /// - Parameter scheme: URL Scheme 字符串
    /// - Returns: 应用 Bundle ID 数组
    func getAvailableHandlersForURLScheme(_ scheme: String) -> [String] {
        guard !scheme.isEmpty else {
            return []
        }

        let schemeCF = scheme as CFString

        guard let apps = LSCopyAllHandlersForURLScheme(schemeCF)?.takeRetainedValue() as? [String] else {
            return []
        }

        return apps
    }
}

import Foundation

/// 事件日志记录器
final class EventLogger {

    // MARK: - Singleton

    static let shared = EventLogger()
    private init() {
        setupLogDirectory()
    }

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.filetypeprotector.logger", qos: .utility)
    private var memoryCache: [LogEntry] = []
    private let maxCacheSize = 1000
    private var recentEventTimestamps: [String: [Date]] = [:]
    private var lastStormReportAt: [String: Date] = [:]
    private let diagnosticWindow: TimeInterval = 10
    private let stormThreshold = 8

    /// 日志目录
    private var logDirectoryURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("FileTypeGuard")
            .appendingPathComponent("logs")
    }

    /// 当前日志文件
    private var currentLogFileURL: URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        return logDirectoryURL.appendingPathComponent("\(dateString).log")
    }

    // MARK: - Public Methods

    /// 记录日志
    /// - Parameter entry: 日志条目
    func log(_ entry: LogEntry) {
        queue.async { [weak self] in
            guard let self = self else { return }

            // 添加到内存缓存
            self.memoryCache.append(entry)

            // 限制缓存大小
            if self.memoryCache.count > self.maxCacheSize {
                self.memoryCache.removeFirst(self.memoryCache.count - self.maxCacheSize)
            }

            self.recordStormDiagnostic(for: entry)

            // 异步写入磁盘
            self.writeToFile(entry)

            print("📝 日志记录: \(entry.eventType.displayName) - \(entry.description)")
        }
    }

    /// 创建并记录检测事件
    func logDetected(
        fileType: String,
        fileTypeName: String,
        fromApp: String?,
        fromAppName: String?,
        toApp: String,
        toAppName: String
    ) {
        let entry = LogEntry(
            eventType: .detected,
            fileType: fileType,
            fileTypeName: fileTypeName,
            fromApp: fromApp,
            fromAppName: fromAppName,
            toApp: toApp,
            toAppName: toAppName,
            status: .pending
        )
        log(entry)
    }

    /// 创建并记录恢复成功事件
    func logRestored(
        fileType: String,
        fileTypeName: String,
        fromApp: String?,
        fromAppName: String?,
        toApp: String,
        toAppName: String
    ) {
        let entry = LogEntry(
            eventType: .restored,
            fileType: fileType,
            fileTypeName: fileTypeName,
            fromApp: fromApp,
            fromAppName: fromAppName,
            toApp: toApp,
            toAppName: toAppName,
            status: .success
        )
        log(entry)
    }

    /// 创建并记录恢复失败事件
    func logRestoreFailed(
        fileType: String,
        fileTypeName: String,
        fromApp: String?,
        fromAppName: String?,
        toApp: String,
        toAppName: String,
        error: Error
    ) {
        let entry = LogEntry(
            eventType: .restoreFailed,
            fileType: fileType,
            fileTypeName: fileTypeName,
            fromApp: fromApp,
            fromAppName: fromAppName,
            toApp: toApp,
            toAppName: toAppName,
            status: .failed,
            errorMessage: error.localizedDescription
        )
        log(entry)
    }

    /// 获取内存缓存中的日志
    func getRecentLogs(limit: Int = 100) -> [LogEntry] {
        queue.sync {
            let sorted = memoryCache.sorted()
            return Array(sorted.prefix(limit))
        }
    }

    // MARK: - Private Methods

    /// 设置日志目录
    private func setupLogDirectory() {
        do {
            try fileManager.createDirectory(at: logDirectoryURL, withIntermediateDirectories: true)
            print("✅ 日志目录已创建: \(logDirectoryURL.path)")
        } catch {
            print("❌ 创建日志目录失败: \(error)")
        }
    }

    private func recordStormDiagnostic(for entry: LogEntry) {
        let now = entry.timestamp
        let key = "\(entry.fileType)|\(entry.eventType.rawValue)"
        let cutoff = now.addingTimeInterval(-diagnosticWindow)

        var timestamps = recentEventTimestamps[key, default: []]
        timestamps.append(now)
        timestamps.removeAll { $0 < cutoff }
        recentEventTimestamps[key] = timestamps

        guard timestamps.count >= stormThreshold else { return }

        if let lastReport = lastStormReportAt[key], now.timeIntervalSince(lastReport) < diagnosticWindow {
            return
        }

        lastStormReportAt[key] = now

        print("⚠️  Log storm suspected: fileType=\(entry.fileType) event=\(entry.eventType.rawValue) count=\(timestamps.count) window=\(Int(diagnosticWindow))s logFile=\(currentLogFileURL.lastPathComponent)")
    }

    /// 写入日志到文件
    private func writeToFile(_ entry: LogEntry) {
        do {
            // 编码为 JSON
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(entry)

            // 添加换行符
            var logData = data
            logData.append(contentsOf: "\n".utf8)

            // 追加到文件
            let fileURL = currentLogFileURL

            if fileManager.fileExists(atPath: fileURL.path) {
                // 文件存在，追加
                if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(logData)
                    fileHandle.closeFile()
                }
            } else {
                // 文件不存在，创建
                try logData.write(to: fileURL, options: .atomic)
            }

        } catch {
            print("❌ 写入日志文件失败: \(error)")
        }
    }
}

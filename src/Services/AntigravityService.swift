import Foundation
import SQLite3

public struct AntigravityBackupInfo: Identifiable {
    public var id: String { path }
    public let name: String
    public let path: String
    public let date: Date
    public let sizeBytes: Int64

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }

    public var formattedDate: String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: date)
    }
}

public final class AntigravityService {
    public static let shared = AntigravityService()

    private let fileManager = FileManager.default

    public var antigravityDir: URL {
        let home = fileManager.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".gemini/antigravity", isDirectory: true)
    }

    public var summariesDBPath: String {
        antigravityDir.appendingPathComponent("conversation_summaries.db").path
    }

    public var vscodeStateDBPath: String {
        let home = fileManager.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Library/Application Support/Antigravity/User/globalStorage/state.vscdb").path
    }

    public var backupsDirectory: URL {
        let home = fileManager.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".gemini/antigravity_backups", isDirectory: true)
    }

    private init() {}

    /// Reads conversation counts from conversation_summaries.db mapped by standardized folder path
    public func getConversationCounts() -> [String: Int] {
        var counts: [String: Int] = [:]
        let dbPath = summariesDBPath

        guard fileManager.fileExists(atPath: dbPath) else {
            return counts
        }

        var db: OpaquePointer?
        if sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            return counts
        }
        defer { sqlite3_close(db) }

        let query = "SELECT workspace_uris, count(*) FROM conversation_summaries GROUP BY workspace_uris"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let rawUris = sqlite3_column_text(stmt, 0) {
                    let urisJson = String(cString: rawUris)
                    let count = Int(sqlite3_column_int(stmt, 1))
                    
                    if let data = urisJson.data(using: .utf8),
                       let urisArray = try? JSONSerialization.jsonObject(with: data) as? [String] {
                        for uri in urisArray {
                            if let normalized = normalizeWorkspacePath(from: uri) {
                                counts[normalized, default: 0] += count
                            }
                        }
                    }
                }
            }
            sqlite3_finalize(stmt)
        }

        return counts
    }

    public func normalizeWorkspacePath(from uriString: String) -> String? {
        guard let url = URL(string: uriString) else { return nil }
        if url.scheme == "file" {
            var path = url.path
            if path.hasSuffix("/") && path.count > 1 {
                path.removeLast()
            }
            return (path as NSString).standardizingPath
        }
        return nil
    }

    /// Creates a complete safety backup of the Antigravity conversation database and VS Code state
    public func createSafetyBackup() throws -> String {
        try fileManager.createDirectory(at: backupsDirectory, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = formatter.string(from: Date())
        let backupFolder = backupsDirectory.appendingPathComponent("backup_\(timestamp)", isDirectory: true)
        try fileManager.createDirectory(at: backupFolder, withIntermediateDirectories: true)

        // 1. Backup conversation_summaries.db
        if fileManager.fileExists(atPath: summariesDBPath) {
            let dest = backupFolder.appendingPathComponent("conversation_summaries.db")
            try? fileManager.copyItem(at: URL(fileURLWithPath: summariesDBPath), to: dest)
        }

        // 2. Backup antigravity_state.pbtxt if exists
        let pbtxt = antigravityDir.appendingPathComponent("antigravity_state.pbtxt")
        if fileManager.fileExists(atPath: pbtxt.path) {
            let dest = backupFolder.appendingPathComponent("antigravity_state.pbtxt")
            try? fileManager.copyItem(at: pbtxt, to: dest)
        }

        // 3. Backup state.vscdb
        if fileManager.fileExists(atPath: vscodeStateDBPath) {
            let dest = backupFolder.appendingPathComponent("state.vscdb")
            try? fileManager.copyItem(at: URL(fileURLWithPath: vscodeStateDBPath), to: dest)
        }

        // 4. Create metadata manifest
        let manifest = """
        Backup creato: \(Date())
        Database chat: \(summariesDBPath)
        State VSCode: \(vscodeStateDBPath)
        """
        let manifestURL = backupFolder.appendingPathComponent("backup_info.txt")
        try? manifest.write(to: manifestURL, atomically: true, encoding: .utf8)

        return backupFolder.path
    }

    public func listExistingBackups() -> [AntigravityBackupInfo] {
        guard let contents = try? fileManager.contentsOfDirectory(at: backupsDirectory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey], options: [.skipsHiddenFiles]) else {
            return []
        }

        var results: [AntigravityBackupInfo] = []
        for url in contents {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()
                let size = folderSize(url.path)
                results.append(AntigravityBackupInfo(name: url.lastPathComponent, path: url.path, date: date, sizeBytes: size))
            }
        }
        return results.sorted { $0.date > $1.date }
    }

    private func folderSize(_ path: String) -> Int64 {
        guard let enumerator = fileManager.enumerator(at: URL(fileURLWithPath: path), includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }
}
